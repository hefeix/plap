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

#ifndef PLAP_UTIL_IO_H__
#define PLAP_UTIL_IO_H__

#include <istream>
#include <string>

namespace plap { namespace util {

void read_balanced(std::istream& in,std::string& str,
                   char lparen='(',char rparen=')',bool ignore_comments=false);

#define UTIL_IO_begin_loop                      \
  out << prompt; out.flush();                   \
  char c=in.get();                              \
  while (in.good()) { in.putback(c);
#define UTIL_IO_end_loop                        \
  out << prompt; out.flush();                   \
  c=in.get(); }

template<typename In,typename Reader,typename Writer>
void io_loop(std::istream& in,std::ostream& out,Reader read,Writer write,
             const std::string& prompt="") {
  UTIL_IO_begin_loop;
  In i;
  if (!read(in,i) || !in.good())
    break;
  write(out,i);
  UTIL_IO_end_loop;
}
template<typename ReadWrite>
void io_loop(std::istream& in,std::ostream& out,ReadWrite rw,
             bool final_call,const std::string& prompt="") {
  UTIL_IO_begin_loop;
  if (!rw(in,out))
      return;
  UTIL_IO_end_loop;
  if (final_call)
    rw(in,out);
}
#undef UTIL_IO_begin_loop
#undef UTIL_IO_end_loop

}} //namespace plap::util
#endif //PLAP_UTIL_IO_H__
