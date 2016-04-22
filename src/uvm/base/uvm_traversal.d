//----------------------------------------------------------------------
//   Copyright 2013 Cadence Design Systems, Inc.
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

//------------------------------------------------------------------------------
//
// CLASS: uvm_visitor #(NODE)
//
// The uvm_visitor class provides an abstract base class for a visitor. The visitor 
// visits instances of type NODE. For general information regarding the visitor pattern
// see http://en.wikipedia.org/wiki/Visitor_pattern
// 
//------------------------------------------------------------------------------

module uvm.base.uvm_traversal;

import uvm.base.uvm_object;
import uvm.base.uvm_component;
import uvm.base.uvm_root;
import uvm.base.uvm_globals;
import uvm.base.uvm_coreservice;

import std.regex;
import std.string: format;

abstract class uvm_visitor(NODE=uvm_component): uvm_object
{
  this(string name = "") {
    super(name);
  }

  // Function: begin_v
  //
  // This method will be invoked by the visitor before the first NODE is visited
	
  void begin_v() { }
	
  // Function: end_v
  //
  // This method will be invoked by the visitor after the last NODE is visited
		
  void end_v() { }

  // Function: visit
  //
  // This method will be invoked by the visitor for every visited ~node~ of the provided structure.
  // The user is expected to provide the own functionality in this function.
  //
  //| class count_nodes_visitor#(type T=uvm_component) extends uvm_visitor#(T); 
  //| 	function new (string name = "");
  //|	       super.new(name);
  //|     endfunction 
  //| 	local int cnt;
  //|     virtual function void begin_v(); cnt = 0; endfunction
  //| 	virtual function void end_v(); `uvm_info("TEXT",$sformatf("%d elements",cnt),UVM_NONE) endfunction
  //| 	virtual function void visit(T node); cnt++; endfunction
  //|	endclass
  abstract void visit(NODE node);
};

//------------------------------------------------------------------------------
//
// CLASS: uvm_structure_proxy #(STRUCTURE)
//
// The uvm_structure_proxy is a wrapper and provides a set of elements 
// of the STRUCTURE to the caller on demand. This is to decouple the retrieval of 
// the STRUCTUREs subelements from the actual function being invoked on STRUCTURE
// 
//------------------------------------------------------------------------------

abstract class uvm_structure_proxy(STRUCTURE=uvm_component): uvm_object
{
  this(string name = "") {
    super(name);
  }
  // Function: get_immediate_children
  //
  // This method will be return in ~children~ a set of the direct subelements of ~s~
		
  abstract void get_immediate_children(STRUCTURE s, STRUCTURE[] children);
};

//------------------------------------------------------------------------------
//
// CLASS: uvm_visitor_adapter #(STRUCTURE,uvm_visitor#(STRUCTURE))
//
// The visitor adaptor traverses all nodes of the STRUCTURE and will invoke visitor.visit() on every node.
// 
//------------------------------------------------------------------------------

abstract class uvm_visitor_adapter(STRUCTURE=uvm_component,
				   VISITOR=uvm_visitor!STRUCTURE): uvm_object
{
  // Function: accept()
  //
  // Calling this function will traverse through ~s~ (and every subnode of ~s~). For each node found 
  // ~v~.visit(node) will be invoked. The children of ~s~ are recursively determined 
  // by invoking ~p~.get_immediate_children().~invoke_begin_end~ determines whether the visitors begin/end functions 
  // should be invoked prior to traversal.
	
  abstract void accept(STRUCTURE s, VISITOR v,
		       uvm_structure_proxy!STRUCTURE p,
		       bool invoke_begin_end=true);

  this (string name = "") {
    super(name);
  }
};

//------------------------------------------------------------------------------
//
// CLASS: uvm_top_down_visitor_adapter
//
// This uvm_top_down_visitor_adapter traverses the STRUCTURE ~s~ (and will invoke the visitor) in a hierarchical fashion.
// During traversal ~s~ will be visited before all subnodes of ~s~ will be visited.
// 
//------------------------------------------------------------------------------

class uvm_top_down_visitor_adapter(STRUCTURE=uvm_component,
				   VISITOR=uvm_visitor!STRUCTURE):
  uvm_visitor_adapter!(STRUCTURE,VISITOR)
{
  this(string name = "") {
    super(name);
  }      

  override void accept(STRUCTURE s, VISITOR v, uvm_structure_proxy!STRUCTURE p,
	      bool invoke_begin_end=true) {

    STRUCTURE[] c;
    if(invoke_begin_end) {
      v.begin_v();
    }

    v.visit(s);
    p.get_immediate_children(s, c);

    foreach(x; c) {
      accept(x, v, p, false);
    }

    if(invoke_begin_end) {
      v.end_v();
    }

  }
};

//------------------------------------------------------------------------------
//
// CLASS: uvm_bottom_up_visitor_adapter
//
// This uvm_bottom_up_visitor_adapter traverses the STRUCTURE ~s~ (and will invoke the visitor) in a hierarchical fashion.
// During traversal all children of node ~s~ will be visited ~s~ will be visited.
// 
//------------------------------------------------------------------------------

class uvm_bottom_up_visitor_adapter(STRUCTURE=uvm_component,
				    VISITOR=uvm_visitor!STRUCTURE):
  uvm_visitor_adapter!(STRUCTURE,VISITOR)
{
  this(string name = "") {
    super(name);
  }
  
  void accept(STRUCTURE s, VISITOR v, uvm_structure_proxy!STRUCTURE p,
	      bool invoke_begin_end=true) {
    STRUCTURE[] c;

    if(invoke_begin_end) {
      v.begin_v();
    }

    p.get_immediate_children(s, c);
    foreach(x; c) {
      accept(x, v, p, false);
    }

    v.visit(s);

    if(invoke_begin_end) {
      v.end_v();
    }

  }
};

//------------------------------------------------------------------------------
//
// CLASS: uvm_by_level_visitor_adapter
//
// This uvm_by_level_visitor_adapter traverses the STRUCTURE ~s~ (and will invoke the visitor) in a hierarchical fashion.
// During traversal will visit all direct children of ~s~ before all grand-children are visited. 
//------------------------------------------------------------------------------

class uvm_by_level_visitor_adapter(STRUCTURE=uvm_component,
				   VISITOR=uvm_visitor!STRUCTURE):
  uvm_visitor_adapter!(STRUCTURE,VISITOR)
{
  this(string name = "") {
    super(name);
  }

  void accept(STRUCTURE s, VISITOR v, uvm_structure_proxy!STRUCTURE p,
	      bool invoke_begin_end=true) {
    STRUCTURE[] c;
    c ~= s;

    if(invoke_begin_end) {
      v.begin_v();
    }

    while(c.length > 0) {
      STRUCTURE[] q;

      foreach(x; c) {
	STRUCTURE[] t; 

	v.visit(x);
	p.get_immediate_children(x, t);
	q ~= t;
      }

      c = q;
    }

    if(invoke_begin_end) {
      v.end_v();
    }
  }
};

//------------------------------------------------------------------------------
//
// CLASS: uvm_component_proxy
//
// The class is providing the proxy to extract the direct subcomponents of ~s~ 
//------------------------------------------------------------------------------

class uvm_component_proxy: uvm_structure_proxy!uvm_component
{
  override void get_immediate_children(uvm_component s,
				       uvm_component[] children) {
    s.get_children(children);
  }

  this(string name = "") {
    super(name);
  }
};

//------------------------------------------------------------------------------
//
// CLASS: uvm_component_name_check_visitor 
//
// This specialized visitor analyze the naming of the current component. The established rule set
// ensures that a component.get_full_name() is parsable, unique, printable to order to avoid any ambiguities 
// when messages are being emitted.
// 
// ruleset a legal name is composed of
// - allowed charset "A-z:_0-9[](){}-: "
// - whitespace-as-is, no-balancing delimiter semantic, no escape sequences
// - path delimiter not allowed anywhere in the name
//   
// the check is coded here as a function to complete it in a single function call
// otherwise save/restore issues with the used dpi could occur
//------------------------------------------------------------------------------

  
class uvm_component_name_check_visitor: uvm_visitor!uvm_component
{
  private uvm_root _root;

  static Regex!char _compiled_regex;

  // Function: get_name_constraint
  //
  // This method should return a regex for what is being considered a valid/good component name.
  // The visitor will check all component names using this regex and report failing names
		
  string get_name_constraint() {
    // return "^[][[:alnum:](){}_:-]([][[:alnum:](){} _:-]*[][[:alnum:](){}_:-])?$";
    return "^[a-zA-Z_][a-zA-Z0-9_]*$";
  }

  override void visit(uvm_component node) {
    synchronized(this) {
      if(_compiled_regex == (Regex!char).init) {
	_compiled_regex = regex(get_name_constraint());
      }
		
      assert(_compiled_regex != (Regex!char).init);
		
      // dont check the root component
      if(_root !is node)
	if(matchFirst(node.get_name(), _compiled_regex).empty()) {
	  uvm_root_warning("UVM/COMP/NAME",
			   format("the name \"%s\" of the component \"%s\" violates the uvm component name constraints",
				  node.get_name(), node.get_full_name()));
	}
    }
  }

  this(string name = "") {
    super(name);
  }

  override void begin_v() {
    synchronized(this) {
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      _root =  cs.get_root();
    }
  }

  override void end_v() {
    synchronized(this) {
      _compiled_regex = (Regex!char).init;
    }
  }
};
