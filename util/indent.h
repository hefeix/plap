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

#ifndef PLAP_UTIL_INDENT_H__
#define PLAP_UTIL_INDENT_H__

#include <istream>
#include <ostream>

namespace plap { namespace util {

void indent2parens(std::istream& in,std::ostream& out);
void parens2indent(std::istream& in,std::ostream& out);

}} //namespace plap::util
#endif //PLAP_UTIL_INDENT_H__