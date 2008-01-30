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

#include "vertex.h"
//fixme#include "world.h"
//fixme#include "function.h"

namespace lang {

#ifndef PLAP_LANG_VERTEX_UNION
namespace lang_private {
std::string type_name(const vertex& v) {
  if (boost::get<list_t>(&v))   return "list_t";
  if (boost::get<disc_t>(&v))   return "disc_t";
  if (boost::get<contin_t>(&v)) return "contin_t";
  if (boost::get<world_t*>(&v)) return "world_t";
  assert(boost::get<function_t*>(&v));
  return "function_t";
}
std::string type_value(const vertex& v) {
#if 0
  if (const list_t* l=boost::get<list_t>(&v)) {
    assert(*l);
    return boost::lexical_cast<std::string>(**l);
  } else if (const world_t* w=boost::get<world_t>(&v)) {
    assert(*w);
    return boost::lexical_cast<std::string>(**w);
  } else if (const function_t* f=boost::get<function_t>(&v)) {
    assert(*f);
    return boost::lexical_cast<std::string>(**f);
  }
  assert(boost::get<disc_t>(&v) || boost::get<contin_t>(&v));
  return boost::lexical_cast<std::string>(v);
#endif
  return "foobar";
}
} //~namespace lang_private
#endif //~ifndef PLAP_LANG_VERTEX_UNION

} //~namespace lang
