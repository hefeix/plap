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

#include "repl.h"
#include <stdexcept>
#include <iostream>
#include <sstream>
#include <fstream>
#include "parse.h"
#include "analyze.h"
#include "context.h"
#include "pretty_print.h"
#include "builtin.h"
#include "tree_io.h"
#include "io.h"

namespace plap { namespace lang_io {

void repl(std::istream& in,std::ostream& out,const std::string& prompt) {
  using std::endl;
  using boost::ref;
  using namespace plap::lang;

  context c;
  std::ifstream lib("combo/lib.co");
  try {
    load_lib(lib,c);
  }  catch (std::runtime_error e) {
    std::cerr << "\033[22;31mError loading combo/lib.co (standard library): "
              << e.what() << "\033[00;m" << endl;
  }
  lib.close();

  std::ostream* tmp=lang_print::print_to;
  lang_print::print_to=&out;
  out << util::sexpr_format << "ctrl+D exits" << endl;
  while (true) {
    try {
      util::io_loop<sexpr>(in,out,boost::bind(&parse,_1,_2,true),
                           boost::bind(&eval_print,_1,_2,ref(c)),ref(prompt));
      break;
    } catch (std::runtime_error e) {
      std::cerr << "\033[22;31m" << e.what() << "\033[00;m" << endl;
    }
  }
  lang_print::print_to=tmp;
}

void eval_print(std::ostream& out,const_subsexpr s,lang::context& c) {
  using namespace lang;

  //out << "goes to sexpr '" << s << "'" << std::endl;

  vtree expr=vtree(vertex());
  analyze(s,expr,c);
  //out << "analyzed" << std::endl;
  //pretty_print(out,expr);
  vtree res=vtree(vertex());
  //out << "OK" << std::endl;
  c.eval(expr,res);
  //out << "evals to" << std::endl;
  pretty_print(out,res);
}

void eval_quiet(const_subsexpr s,lang::context& c) {
  using namespace lang;
  vtree expr=vtree(vertex()),res=vtree(vertex());
  analyze(s,expr,c);
  c.eval(expr,res);
}

void load_lib(std::istream& in,lang::context& c) {
  std::stringstream tmp;
  util::io_loop<sexpr>(in,tmp,boost::bind(&parse,_1,_2,false),
                       boost::bind(&eval_quiet,_2,boost::ref(c)),"");
}

}} //namespace plap::lang_io
