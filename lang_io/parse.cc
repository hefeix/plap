// Copyright 2008 Google Inc. All Rights Reserved.
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

#include "parse.h"
#include <vector>
#include <streambuf> 
#include <boost/spirit/core.hpp>
#include <boost/spirit/tree/ast.hpp>
#include <boost/spirit/tree/parse_tree.hpp>
#include <boost/spirit/utility/confix.hpp>
#include <boost/spirit/iterator/multi_pass.hpp>
#include "algorithm.h"
#include "io.h"
#include "tree.h"
#include "operators.h"
#include "names.h"
#include "builtin.h"


#include <iostream>//fixme
#include "tree_io.h"

namespace plap { namespace lang_io {

namespace {
using namespace boost::spirit;
using std::string;
using namespace lang;

bool special_name(const string& s,subsexpr d) {
  if (s==")") { //not used but needed to get parsing right
    assert(!d.childless());
    if (++d.begin_child()==d.end_child()) {
      std::swap(d.root(),d.front());
      d.erase(d.flatten(d.begin_child()));
    }
    special_name(d.root(),d);
    return true;
  }
  if (s=="") { //a potential apply-expression
    if (d.front_sub().childless()) {
      std::swap(d.root(),d.front());
      d.erase(d.begin_child());
    } else {
      assert(d.arity()>1);
      d.root()=*func2name(lang_apply::instance());
      d.insert(d[1],*func2name(lang_list::instance()));
      d.splice(d[1].begin_child(),d[2].begin(),d.end_child());
    }
  } else if (s==def_symbol) { //a definition (explicitly set up structure)
    d.prepend(d[0].root());
    d[1].root()=*func2name(lang_list::instance());
    d.root()=operator2name(def_symbol,3);
  } else if (s=="\\") {
    d[0][0].prepend(*func2name(lang_list::instance()));
    std::swap(d[0][0].root(),d[0][0][0].root());
    d.root()=operator2name(s,1);
  } else {
    return false;
  }
  return true;
}

template<typename TreeNode>
inline string tostr(const TreeNode& s) {
    return string(s.value.begin(),s.value.end());
}

//debug
#if 0
template<typename TreeNode>
void tosexpr(const TreeNode& s,subsexpr d) {
  d.root()=tostr(s);
  d.append(s.children.size(),string());
  for_each(s.children.begin(),s.children.end(),d.begin_sub_child(),
           &tosexpr<TreeNode>);
}
#endif
//#if 0
template<typename TreeNode>
void tosexpr(const TreeNode& s,subsexpr d) {
  d.append(s.children.size(),string());
  string name=tostr(s);

  if (name==string_symbol) {
    assert(d.size()==d.arity()+1);
    d.root()=string_symbol;
    std::transform(s.children.begin(),s.children.end(),d.begin_sub_child(),
                   &tostr<TreeNode>);
    return;
  }

  for_each(s.children.begin(),s.children.end(),d.begin_sub_child(),
           &tosexpr<TreeNode>);

  if (!special_name(name,d)) {
    if (*name.rbegin()=='.' && name!="." && name!=".." && name!="...")
      throw std::runtime_error
          ("bad number literal '"+name+"' - can't have a trailing '.'.");
    d.root()=operator2name(name,s.children.size());
  }
}
//#endif

struct sexpr_grammar : public grammar<sexpr_grammar> {
  template<typename Scanner>
  struct definition {
    definition(const sexpr_grammar&) {
      foo    = listh | rangeh | commah | def | term;
      sexpr  = no_node_d[ch_p('(')] >> +list >> root_node_d[ch_p(')')];
 
      list   = range    |  listh;
      range  = comma    |  rangeh;
      comma  = def      |  commah;

      def    = lambda   >> !(root_node_d[ch_p('=')] >>
                             eps_p(~ch_p('=') >> *anychar_p)       >> lambda);
      lambda = fact     |  lambdah;
      fact   =             ! root_node_d[str_p("<-")]              >> decl;
      decl   = arrow    >> !(root_node_d[ch_p('^')]                >> int_p);
      arrow  = seq      >> *(root_node_d[str_p("->")]              >> lambda);
      seq    = or_op    >> *(lambdah|or_op);
      or_op  = and_op   >> *(root_node_d[str_p("||")]              >> and_op);
      and_op = cons     >> *(root_node_d[str_p("&&")]              >> cons);
      cons   = eq       >> !(root_node_d[ch_p(':')]                >> cons);
      eq     = cmp      >> *(root_node_d[str_p("==")|"!="]         >> cmp);
      cmp    = add      >> *(root_node_d[str_p("<=")|">="|'<'|'>'] >> add);
      add    = cat      >> *(root_node_d[ch_p('+')|'-']            >> cat);
      cat    = mlt      >> *(root_node_d[ch_p('~')]                >> mlt);
      mlt    = neg      >> *(root_node_d[ch_p('*')|'/']            >> neg);
      neg    =             ! root_node_d[ch_p('!')|ch_p('-')]      >> prime;

      prime  = sexpr | term | listh | rangeh | commah;// | "()";
      term   = inner_node_d[ch_p('(') >> term >> ch_p(')')] | "[]" | str | chr
             | lexeme_d[token_node_d
                        [!ch_p('$') >> (alpha_p | '_') >> *(alnum_p | '_') 
                         >> ~eps_p(('.' >> ~ch_p('.')) | alnum_p | '$')] |
                        (real_p >> ~eps_p('.' | alnum_p | '$'))];
      str    = lexeme_d[root_node_d[ch_p('\"')] 
                        >> *((ch_p('\\') >> '\"') | anychar_p - '\"')
                        >> no_node_d[ch_p('\"')]];
      chr    = lexeme_d['\'' >> !ch_p('\\') >> anychar_p 
                        >> no_node_d[ch_p('\'')]];

      listh  = (root_node_d[ch_p('[')] >> (list % no_node_d[ch_p(',')])
                >> no_node_d[ch_p(']')]);
      rangeh = (no_node_d[ch_p('[')] >> (int_p|seq|sexpr) 
                >> root_node_d[str_p("...")|".."]
                >> (int_p|seq|sexpr) >> no_node_d[ch_p(']')]);
      commah = (root_node_d[ch_p('(')] >> (list % no_node_d[ch_p(',')])
                >> no_node_d[ch_p(')')]);
      lambdah= root_node_d[ch_p('\\')] >> arrow;
      declh  = ((alpha_p | '_') >> *(alnum_p | '_') >> root_node_d[ch_p('^')] 
                >> int_p);
    }
    rule<Scanner> foo,sexpr,list,range,comma,def,lambda,fact,decl,arrow,seq;
    rule<Scanner> or_op,and_op,cons,eq,cmp,add,cat,mlt,neg;
    rule<Scanner> prime,term,str,chr,listh,rangeh,commah,lambdah,declh;
    const rule<Scanner>& start() const { return foo; }//sexpr; }
  };
};

bool whitespace(char c) { return (c==' ' || c=='\t'); }
bool newline(char c) { return (c=='\n'); }
bool eof(char c) { return (c==EOF); }

struct reader {
  reader() : mode(normal) {}
  mutable enum { incomment,escaped,normal } mode;
  mutable std::vector<char> buffer;
  mutable tree_parse_info<std::vector<char>::iterator> t;

  bool operator()(std::istream& in) const {
    char c=in.get();
    
    if (c=='#' && mode!=escaped) {
      mode=incomment;
      return true;
    }
    if (newline(c)) {
      mode=normal;
      if (parses())
        return false;
    }
    if (mode!=incomment) {
      if (c=='\\')
        mode=escaped;
      else
        mode=normal;
      buffer.push_back(c);
    }

    return !eof(c);
  }

  bool parses() const {
    t=ast_parse(buffer.begin(),buffer.end(),sexpr_grammar(),space_p);
    return (t.match && t.full && t.trees.size()==1);
  }
};
} //namespace

bool parse(std::istream& in,sexpr& dst,bool interactive) {
  dst=sexpr(string());

  if (interactive) {
    reader r;
    util::input_loop(in,r);
    if (r.buffer.empty() || eof(r.buffer.back())) {
      dst.clear();
      return false;
    }
    //std::cout << "XX" << string(r.buffer.begin(),r.buffer.end()) 
    //        << "XX" << std::endl;
    if (!r.t.match || !r.t.full || r.t.trees.size()!=1)
      throw std::runtime_error("Couldn't parse expression.");
    tosexpr(r.t.trees.front(),dst);
  } else {
    typedef multi_pass<std::istreambuf_iterator<char>,
                       multi_pass_policies::input_iterator,
                       multi_pass_policies::first_owner> iterator_t;
    iterator_t from=iterator_t(std::istreambuf_iterator<char>(in)),to;
    tree_parse_info<iterator_t> t=ast_parse(from,to,sexpr_grammar(),space_p);
    if (!t.match || t.trees.size()!=1)
      throw std::runtime_error("Couldn't parse expression.");
    tosexpr(t.trees.front(),dst);
  }
  //std::cout << "parsed " << dst << std::endl;
  return true;
}

}} //namespace plap::lang
