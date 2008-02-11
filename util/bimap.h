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

//bimap is actually a typedef - to use as foo, do:
//  typedef bimap<l,r,ltag,rtag>::type foo;

#ifndef PLAP_UTIL_BIMAP_H__
#define PLAP_UTIL_BIMAP_H__

#include <utility>
#include <boost/multi_index_container.hpp>
#include <boost/multi_index/member.hpp>
#include <boost/multi_index/hashed_index.hpp>

namespace plap { namespace util {

template<typename Left,typename Right,
         typename LeftTag,typename RightTag>
struct bimap {
  typedef std::pair<Left,Right> pair_t;
  typedef boost::multi_index_container
  <pair_t,
   boost::multi_index::indexed_by<
     boost::multi_index::hashed_unique<
       boost::multi_index::tag<LeftTag>,
       boost::multi_index::member<pair_t,Left,&pair_t::first> >,
     boost::multi_index::hashed_unique<
       boost::multi_index::tag<RightTag>,
       boost::multi_index::member<pair_t,Right,&pair_t::second> > > > type;
};

}} //namespace plap::util
#endif //PLAP_UTIL_BIMAP_H__
