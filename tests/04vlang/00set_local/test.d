//---------------------------------------------------------------------- 
//   Copyright 2010-2011 Synopsys, Inc. 
//   Copyright 2010 Mentor Graphics Corporation
//   Copyright 2016 Coverify Systems Technology
//   All Rights Reserved Worldwide 
// 
//   Licensed under the Apache License, Version 2.0 (the 
//   "License"); you may not use this file except in 
//   compliance with the License.  You may obtain a copy of 
//   the License at 
// 
//       http://www.apache.org/licenses/LICENSE-2.0 
// 
//   Unless required by applicable law or agreed to in 
//   writing, software distributed under the License is 
//   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR 
//   CONDITIONS OF ANY KIND, either express or implied.  See 
//   the License for the specific language governing 
//   permissions and limitations under the License. 
//----------------------------------------------------------------------
import esdl;
import uvm;
import std.stdio;

class test_root: uvm_root
{
  mixin uvm_component_utils;
}

class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
}

@UVM_DEFAULT
class test: uvm_test
{
  foo bar;
  
  mixin uvm_component_utils;
  
  this(string name, uvm_component parent){
    super(name, parent);
    print_config_matches = true;
  }

  override void run_phase(uvm_phase phase) {
    set_local("ba?.x[2]", 2719);
    set_local("*z", "bla");
    bar.set_int_local("y", 1729);
    bar.print();
  }
  
  override void report() { // functions in d are by default virtual
    writeln("** UVM TEST PASSED **\n");
  }
}

class foo: uvm_component
{
  @UVM_DEFAULT:
  int[4] x;
  int y;

  string z;
  
  mixin uvm_component_utils;
  
  this(string name, uvm_component parent){
    super(name, parent);
    print_config_matches = true;
  }

  override void report() {//functions in d are by default virtual
    writeln("** UVM TEST PASSED **\n");
    writeln("x is: ", x);
    writeln("y is: ", y);
  }

}
  
int main(string[] argv) {
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  return tb.simulate();
}