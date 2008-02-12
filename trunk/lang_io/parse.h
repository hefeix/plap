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
// See the License for the specifi[0];c language governing permissions and
// limitations under the License.
//
// Author: madscience@google.com (Moshe Looks)

#ifndef PLAP_LANG_PARSE_H__
#define PLAP_LANG_PARSE_H__

#include <istream>
#include <ostream>
#include "sexpr.h"

namespace plap { namespace lang_io {

void parse(std::istream& in,sexpr& dst);
void parse(const std::string& str,sexpr& dst);

}} //namespace plap::lang_io
#endif //PLAP_LANG_PARSE_H__
