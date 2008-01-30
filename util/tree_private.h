// Copyright 2007 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License")
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an AS IS BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Author: madscience@google.com (Moshe Looks)

// private header - do not include directly

#include <cstddef>
#include <cassert>
#include <functional>
#include <algorithm>
#include <iterator>
#include <boost/next_prior.hpp>
#include <boost/iterator/iterator_facade.hpp>
#include <boost/operators.hpp>
#include "iterator_shorthands.h"

namespace util {

//forward declarations to make the compiler happy
template<typename T>
struct const_subtree;
template<typename T>
struct subtree;
template<typename T>
struct tree;

namespace util_private {

/////////
// node classes

//briliant evil-genius technique "adapted" from the gnu stl list
//implementation - node_base is used for sentinel nodes, and static_cast to
//node is used for when we want to access the data - this avoids the overhead
//of polymorphism and the wasted sizeof(T) space of using node for sentinels
struct node_base {
  node_base() : prev(this),next(this),end(this) {}
  node_base(node_base* parent) : prev(this),next(parent),end(this) {}
  node_base(node_base* p,node_base* n) : prev(p),next(n),end(NULL) {}
  node_base(node_base* p,node_base* n,node_base* e) : prev(p),next(n),end(e) {}

  node_base* prev;
  node_base* next;
  node_base* end; 

  node_base* sentinel() {     //creates sentinel if childless
    if (node_base* n=end)
      return n;
    return new_sentinel();
  }
  node_base* new_sentinel() { return end=new node_base(this); }
  node_base* first_child() {  //creates (& returns) sentinel if childless
    if (node_base* n=end)
      return n->end;
    return end=new node_base(this);
  }

  bool childless() const { 
    if (node_base* n=end)
      return n->prev==n;
    return true;
  }
  bool dereferenceable() const { return next->prev==this; }

  void set_first_child(node_base* child) {
    child->next=child->prev=end=new node_base(child,this,child);
  }

  void tie_in(node_base* prev,node_base* next) {
    if (prev->dereferenceable())
      prev->next=this;
    else
      prev->end=this;
    next->prev=this;
  }

  void cut_out() const { 
    left_cut(next);
    right_cut(prev);
  }
  void left_cut(node_base* nxt) const {
  if (prev->dereferenceable())
    prev->next=nxt;
  else
    prev->end=nxt;

  }
  void right_cut(node_base* prv) const { next->prev=prv; }
};

template<typename T>
struct node : public node_base {
  typedef T value_type;
  node(node_base* p,node_base* n,const value_type& d)
      : node_base(p,n),data(d) {}
  node(node_base* e,const value_type& d) : node_base(NULL,NULL,e),data(d) {
    if (e)
      e->next=this;
  }
  value_type data;
};

template<typename NodeBase>
inline void ascend(NodeBase*& n) {
  while (!n->dereferenceable())
    n=n->next->next;
}

template<typename NodeBase>
inline void descend(NodeBase*& n) {
  while (!n->childless())
    n=n->end->prev;
}

/////////
// iterator classes

template<typename BasePointer>
struct iter_base {
 protected:
  typedef BasePointer base_pointer;

  base_pointer _node;

  template<typename,typename>
  friend struct tr;
  template<typename,typename>
  friend struct mutable_tr;
  template<typename>
  friend struct const_subtree;
  template<typename>
  friend struct iter;
};

template<typename SubtreeT,typename IterBase>
struct sub_iter_base : public IterBase {
  typedef SubtreeT result_type;
  typedef SubtreeT reference;
 protected:
  result_type dereference() const { return result_type(this->_node); }
};
template<typename T,typename NodePointer,typename IterBase>
struct value_iter_base : public IterBase {
  typedef T             result_type;
  typedef result_type&  reference;
 protected:
  result_type& dereference() const { 
    return static_cast<NodePointer>(this->_node)->data; 
  }
};

template<typename IterBase>
struct pre_iter_base : public IterBase {
 protected:
  void increment() { 
    if (this->_node->childless()) {
      this->_node=this->_node->next;
      ascend(this->_node);
    } else {
      this->_node=this->_node->end->end;
    }
  }
  void decrement() {
    this->_node=this->_node->prev;
    if (this->_node->dereferenceable())
      descend(this->_node);
    else
      this->_node=this->_node->next;
  }
};
template<typename IterBase>
struct child_iter_base : public IterBase { 
 protected:
  void increment() { this->_node=this->_node->next; } 
  void decrement() { this->_node=this->_node->prev; }
};
template<typename IterBase>
struct post_iter_base : public IterBase {
 protected:
  void increment() {
    this->_node=make_post(this->_node->next);
    while (!this->_node->dereferenceable())
      this->_node=this->_node->next;
  }
  void decrement() {
    if (this->_node->childless()) {
      this->_node=this->_node->prev;
      while (!this->_node->dereferenceable())
        this->_node=this->_node->next->prev;
    } else {
      this->_node=this->_node->end->prev;
    }
  }
};
template<typename NodeBasePtr>
NodeBasePtr make_post(NodeBasePtr n) {
  while (!n->childless() && n->dereferenceable() && n->end!=n)
    n=n->end->end;
  return n;
}
  
template<typename IterBase>
struct iter : public IterBase,
              public boost::iterator_facade<iter<IterBase>,
                                            typename IterBase::result_type,
                                            boost::bidirectional_traversal_tag,
                                            typename IterBase::reference> {
  iter() { this->_node=NULL; }
  template <class OtherIterBase>
  iter(const iter<OtherIterBase>& other) { this->_node=other._node; }
  iter(typename IterBase::base_pointer n) { this->_node=n; }

  typedef typename IterBase::reference reference;
 protected:
  friend class boost::iterator_core_access;

  bool equal(const iter& rhs) const { return this->_node==rhs._node; }
};

/////////
// tree base classes

template<typename T,typename Tree>
struct tr : boost::equality_comparable<tr<T,Tree> > {
  typedef T                          value_type;
  typedef value_type*                pointer;
  typedef value_type&                reference;
  typedef const value_type&          const_reference;
  typedef std::size_t                size_type;
  typedef std::ptrdiff_t             difference_type;
 protected:
  typedef iter_base<const node_base*> const_node_iter_base;
  typedef sub_iter_base<const_subtree<value_type>,
                        const_node_iter_base>  const_sub_iter;
  typedef value_iter_base<T,const node<T>*,
                          const_node_iter_base> const_value_iter;
 public:
  typedef const_node_iter_base const_iterator;
  typedef iter<pre_iter_base<const_value_iter> > const_pre_iterator;
  typedef iter<pre_iter_base<const_sub_iter> > const_sub_pre_iterator;
  typedef iter<child_iter_base<const_value_iter> > const_child_iterator;
  typedef iter<child_iter_base<const_sub_iter> > const_sub_child_iterator;
  typedef iter<post_iter_base<const_value_iter> > const_post_iterator;
  typedef iter<post_iter_base<const_sub_iter> > const_sub_post_iterator;

  template<typename OtherTr>
  bool operator==(const OtherTr& rhs) const { 
    return this->equal(rhs,std::equal_to<value_type>());
  }

  template<typename OtherTr,typename NodeEq>
  bool equal(const OtherTr& rhs,NodeEq eq) const {
    if (empty())
      return rhs.empty();
    if (rhs.empty())
      return false;

    for (const_pre_iterator i=this->begin(),j=rhs.begin();;) {
      if (!eq(*i++,*j++))
        return false;

      if (i==this->end())
        return j==rhs.end();
      if (j==rhs.end())
        return false;

      if (i._node->next->dereferenceable()!=j._node->next->dereferenceable() ||
          i._node->childless()!=j._node->childless()) {
        if (++i==this->end())
          return ++j==rhs.end();
        return false;
      }
    }
  }

  size_type size() const { return std::distance(begin(),end()); }
  size_type arity() const { return std::distance(begin_child(),end_child()); }

  const_pre_iterator begin() const { return this->root_node(); }
  const_pre_iterator end() const { return this->end_node(); }
  const_child_iterator begin_child() const { 
    if (const node_base* n=this->root_node()->end)
      return n->next;
    return NULL;
  }
  const_child_iterator end_child() const { return this->root_node()->end; }
  const_sub_pre_iterator begin_sub() const { return this->root_node(); }
  const_sub_pre_iterator end_sub() const { return this->end_node(); }
  const_sub_child_iterator begin_sub_child() const { 
    if (const node_base* n=this->root_node()->end)
      return n->end;
    return NULL;
  }
  const_sub_child_iterator end_sub_child() const { 
    return this->root_node()->end; 
  }
  const_post_iterator begin_post() const { 
    return make_post(this->root_node()); 
  }
  const_post_iterator end_post() const { return this->end_node(); }
  const_sub_post_iterator begin_sub_post() const { 
    return make_post(this->root_node()); 
  }
  const_sub_post_iterator end_sub_post() const { return this->end_node(); }

  const value_type& root() const { return *this->begin(); }
  const_subtree<T> root_sub() const { return *this->begin_sub(); } 

  const_subtree<T> operator[](size_type idx) const {
    return *boost::next(this->begin_sub_child(),idx);
  }
  const value_type& front() const { return *this->begin_child(); }
  const value_type& back() const { 
    return static_cast<node<T>*>(this->root_node()->end->prev)->data;
  }
  const_subtree<T> front_sub() const { return *this->begin_sub_child(); }
  const_subtree<T> back_sub() const { return this->root_node()->end->prev; }

  bool childless() const { return this->root_node()->childless(); }

  //functionality that gets delegated to the subclass
  bool empty() const { return static_cast<const Tree*>(this)->empty(); }
 protected:
  const node_base* root_node() const { 
    return static_cast<const Tree*>(this)->root_node(); 
  }
  const node_base* end_node() const { 
    return static_cast<const Tree*>(this)->end_node(); 
  }
};

template<typename T,typename Tree>
struct mutable_tr : public tr<T,Tree> {
 protected:
  typedef T value_type;

  typedef iter_base<node_base*> node_iter_base;
  typedef sub_iter_base<subtree<value_type>,node_iter_base>  sub_iter;
  typedef value_iter_base<T,node<T>*,node_iter_base> value_iter;
  typedef tr<T,Tree> super;
 public:
  typedef node_iter_base iterator;
  typedef iter<pre_iter_base<value_iter> > pre_iterator;
  typedef iter<pre_iter_base<sub_iter> > sub_pre_iterator;
  typedef iter<child_iter_base<value_iter> > child_iterator;
  typedef iter<child_iter_base<sub_iter> > sub_child_iterator;
  typedef iter<post_iter_base<value_iter> > post_iterator;
  typedef iter<post_iter_base<sub_iter> > sub_post_iterator;

  typedef typename super::size_type size_type;

  //insertion may operate on any valid iterator i
  template<typename Iterator>
  Iterator insert(Iterator i,const value_type& v) { 
    return this->insert_n(i._node,v); 
  }
  template<typename Iterator>
  Iterator insert(Iterator i,const_subtree<value_type> s) {
    return this->insert_n(i._node,s);
  }
  template<typename InputIterator>
  void insert(iterator i,InputIterator f,InputIterator l) {
    this->insert_n(i._node,f,l);
  }
  void insert(iterator i,size_type n,const value_type& v) {
    this->insert_n(i._node,repeat_it(v),repeat_it(v,n));
  }
  void insert(iterator i,size_type n,const_subtree<value_type> s) {
    this->insert_n(i._node,repeat_it(s),repeat_it(s,n));
  }

  //append, prepend, insert_above, and insert_below require a dereferencable
  //iterator i
  template<typename Iterator>
  Iterator append(Iterator i,const value_type& v) {
    return this->insert_n(i._node->sentinel(),v);
  }
  template<typename Iterator>
  Iterator append(Iterator i,const_subtree<value_type> s) {
    return this->insert_n(i._node->sentinel(),s);
  }
  template<typename InputIterator>
  void append(iterator i,InputIterator f,InputIterator l) {
    this->insert_n(i._node->sentinel(),f,l);    
  }
  void append(iterator i,size_type n,const value_type& v) {
    this->insert_n(i._node->sentinel(),repeat_it(v),repeat_it(v,n));
  }
  void append(iterator i,size_type n,const_subtree<value_type> s) {
    this->insert_n(i._node->sentinel(),repeat_it(s),repeat_it(s,n));
  }

  template<typename Iterator>
  Iterator prepend(Iterator i,const value_type& v) {
    return this->insert_n(i._node->first_child(),v);
  }
  template<typename Iterator>
  Iterator prepend(Iterator i,const_subtree<value_type> s) {
    return this->insert_n(i._node->first_child(),s);
  }
  template<typename InputIterator>
  void prepend(iterator i,InputIterator f,InputIterator l) {
    this->insert_n(i._node->first_child(),f,l);    
  }
  void prepend(iterator i,size_type n,const value_type& v) {
    this->insert_n(i._node->first_child(),repeat_it(v),repeat_it(v,n));
  }
  void prepend(iterator i,size_type n,const_subtree<value_type> s) {
    this->insert_n(i._node->first_child(),repeat_it(s),repeat_it(s,n));
  }

  template<typename Iterator>
  Iterator insert_above(Iterator i,const value_type& v) {
    node_base* p=i._node;
    node_base* n=new node<T>(p->prev,p->next,v);

    n->tie_in(p->prev,p->next);
    n->set_first_child(p);

    return n;
  }

  template<typename Iterator>
  Iterator insert_below(Iterator i,const value_type& v) {
    node_base* n=new node<T>(i._node->end,v);
    i._node->set_first_child(n);
    return n;
  }

  //i's children are moved after i (becoming its siblings); i is returned
  template<typename Iterator>
  Iterator flatten(Iterator i) {
    node_base* n=i._node;
    
    if (node_base* end=n->end) {
      n->next->prev=end->prev;
      end->prev->next=n->next;
      
      n->next=end->end;
      end->end->prev=n;

      delete end;
      n->end=NULL;      
    }

    return i;
  }

  //erase return value is only sensible for child and post order iterators
  child_iterator erase(child_iterator i) { return erase_ret(i); }
  sub_child_iterator erase(sub_child_iterator i) { return erase_ret(i); }
  post_iterator erase(post_iterator i) { return erase_ret(i); }
  sub_post_iterator erase(sub_post_iterator i) { return erase_ret(i); }

  template<typename Iterator>
  void erase(Iterator i) { erase_n(i._node); }

  void erase(child_iterator f,child_iterator l) {
    if (f==l)
      return;

    node_base* n=f._node;
    node_base* final=l._node->prev;
    node_base* nprev=n->prev;
    n->left_cut(l._node);
    for (node_base* m=erase_descend(n);m!=final;) {
      n=m->dereferenceable() ? erase_descend(m->next) : m->next;
      delete m;
      m=n;
    }
    delete final;
    l._node->prev=nprev;
  }

  //unfortunately the compiler needs these to resolve overloads properly :p
  typename super::const_pre_iterator begin() const { return super::begin(); }
  typename super::const_pre_iterator end() const { return super::end(); }
  typename super::const_child_iterator begin_child() const { 
    return super::begin_child();
  }
  typename super::const_child_iterator end_child() const { 
    return super::end_child();
  }
  typename super::const_sub_pre_iterator begin_sub() const { 
    return super::begin_sub();
  }
  typename super::const_sub_pre_iterator end_sub() const { 
    return this->super::end_sub();
  }
  typename super::const_sub_child_iterator begin_sub_child() const { 
    return this->super::begin_sub_child();
  }
  typename super::const_sub_child_iterator end_sub_child() const { 
    return this->super::end_sub_child();
  }
  const value_type& root() const { return super::root(); }
  const_subtree<T> root_sub() const { return super::root_sub(); } 
  
  pre_iterator begin() { return this->root_node(); }
  pre_iterator end() { return this->end_node(); }
  child_iterator begin_child() { return this->root_node()->first_child(); }
  child_iterator end_child() { return this->root_node()->sentinel(); }
  sub_pre_iterator begin_sub() { return this->root_node(); }
  sub_pre_iterator end_sub() { return this->end_node(); }
  sub_child_iterator begin_sub_child() { 
    return this->root_node()->first_child();
  }
  sub_child_iterator end_sub_child() { return this->root_node()->sentinel(); }
  post_iterator begin_post() { return make_post(this->root_node()); }
  post_iterator end_post() { return this->end_node(); }
  sub_post_iterator begin_sub_post() { return make_post(this->root_node()); }
  sub_post_iterator end_sub_post() { return this->end_node(); }


  value_type& root() { return *this->begin(); }
  subtree<T> root_sub() { return *this->begin_sub(); } 
  subtree<T> operator[](size_type idx) {
    return *boost::next(this->begin_sub_child(),idx);
  }
  value_type& front() { return *this->begin_child(); }
  value_type& back() { 
    return static_cast<node<T>*>(this->root_node()->end->prev)->data;
  }
  subtree<T> front_sub() { return *this->begin_sub_child(); }
  subtree<T> back_sub() { return this->root_node()->end->prev; }

  void prune() { this->erase(begin_child(),end_child()); }

  template<typename Iterator,typename Subtree>
  void splice(Iterator i,Subtree s) {
    node_base* next=i._node;
    node_base* prev=next->prev;
    node_base* n=s._node;

    n->cut_out();
    n->tie_in(next->prev,next);
    n->prev=prev;
    n->next=next;
  }
  template<typename Iterator>
  void splice(Iterator i,tree<T>& tr) { splice(i,tr.root_sub()); }
  void splice(iterator i,sub_child_iterator fi,sub_child_iterator li) {
    if (fi==li)
      return;

    node_base* n=i._node;
    node_base* f=fi._node;
    node_base* l=li._node->prev;

    assert(f->dereferenceable());
    assert(l->dereferenceable());

    f->left_cut(l->next);
    l->right_cut(f->prev);
    f->prev=n->prev;
    l->next=n;

    n->left_cut(f);
    n->prev=l;
  }
 protected:
  //functionality that gets delegated to the subclass
  node_base* root_node() { return static_cast<Tree*>(this)->root_node(); }
  node_base* end_node() { return static_cast<Tree*>(this)->end_node(); }

 private:
  node_base* create_n(node_base* prev,node_base* next,const value_type& v) {
    return new node<T>(prev,next,v);
  }
  node_base* create_n(node_base* prev,node_base* next,const_subtree<T> s) {
    node<T>* n=new node<T>(prev,next,s.root());
    if (!s.childless())
      this->insert_n(n->new_sentinel(),s.begin_sub_child(),s.end_sub_child());
    return n;
  }

  node_base* insert_n(node_base* next,const value_type& v) {
    node_base* prev=next->prev;
    node_base* n=new node<T>(prev,next,v);

    n->tie_in(prev,next);

    return n;
  }
  node_base* insert_n(node_base* next,const_subtree<T> s) {
    node_base* n=insert_n(next,s.root());
    if (!s.childless()) //only create a sentinel node if we must
      insert_n(n->new_sentinel(),s.begin_sub_child(),s.end_sub_child());
    return n;
  }
  template<typename Iterator>
  void insert_n(node_base* next,Iterator f,Iterator l) {
    if (f==l)
      return;

    node_base* prev=this->insert_n(next,*f++);
    while (f!=l)
      prev=prev->next=create_n(prev,next,*f++);
    next->prev=prev;
  }

  template<typename Iterator>
  Iterator erase_ret(Iterator i) {
    Iterator tmp=i;
    ++tmp;
    erase_n(i._node);
    return tmp;
  }
  
  node_base* erase_descend(node_base* n) {
    while (n->end!=NULL && n->dereferenceable())
      n=n->end->end;
    return n;
  }
  void erase_n(node_base* n) {
    assert(n->dereferenceable());

    for (node_base* m=erase_descend(n);m!=n;) {
      node_base* tmp=m->dereferenceable() ? erase_descend(m->next) : m->next;
      delete m;
      m=tmp;
    }

    n->cut_out();
    delete n;
  }
};

template<typename T,typename Tree>
struct const_node_policy : public tr<T,Tree> {
  typedef T                  value_type;
  typedef const node_base*   node_base_pointer;
  typedef const node<T>*     node_pointer;
};
template<typename T,typename Tree>
struct mutable_node_policy : public mutable_tr<T,Tree> {
  typedef T                  value_type;
  typedef node_base*         node_base_pointer;
  typedef node<T>*           node_pointer;
};

template<typename NodePolicy>
struct subtr : public NodePolicy {
  typedef typename NodePolicy::value_type value_type;
  typedef typename NodePolicy::node_base_pointer node_base_pointer;
  typedef typename NodePolicy::node_pointer      node_pointer;

  subtr(node_base_pointer r) : _node(static_cast<node_pointer>(r)) {}

  bool empty() const { return false; }
 protected:
  template<typename,typename>
  friend struct tr;
  template<typename,typename>
  friend struct mutable_tr;

  node_pointer _node;

  const node_base* root_node() const { return _node; }
  const node_base* end_node() const { 
    const node_base* n=this->_node->next;
    ascend(n);
    return n;
  }
};

} //~namespace util_private

} //~namespace util
