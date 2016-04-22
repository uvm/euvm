//
//------------------------------------------------------------------------------
//   Copyright 2007-2010 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010      Synopsys, Inc.
//   Copyright 2014      NVIDIA Corporation
//   Copyright 2012-2016 Coverify Systems Technology
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
//------------------------------------------------------------------------------

module uvm.base.uvm_report_server;

//------------------------------------------------------------------------------
//
// CLASS: uvm_report_server
//
// uvm_report_server is a global server that processes all of the reports
// generated by an uvm_report_handler. None of its methods are intended to be
// called by normal testbench code, although in some circumstances the virtual
// methods process_report and/or compose_uvm_info may be overloaded in a
// subclass.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_coreservice;
import uvm.base.uvm_object;
import uvm.meta.mcd;
import uvm.meta.meta;
import uvm.base.uvm_globals;
import uvm.base.uvm_recorder;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_report_handler;
import uvm.base.uvm_report_object;
import uvm.base.uvm_report_catcher;
import uvm.base.uvm_report_message;
import uvm.base.uvm_root;
import uvm.base.uvm_tr_database;
import uvm.base.uvm_tr_stream;
import uvm.base.uvm_printer;

import esdl.base.core: finish, getRootEntity, Process, SimTime;

import std.traits: EnumMembers;
import std.string: format;
import std.conv: to;

class uvm_report_server: /*extends*/ uvm_object
{
  mixin uvm_sync;

  // Needed for callbacks
  override string get_type_name() {
    return qualifiedTypeName!(typeof(this));
  }

  this(string name="base") {
    super(name);
  }

  // Function: set_max_quit_count
  // ~count~ is the maximum number of ~UVM_QUIT~ actions the uvm_report_server
  // will tolerate before invoking client.die().
  // when ~overridable~ = 0 is passed, the set quit count cannot be changed again
  abstract void set_max_quit_count(int count, bool overridable = true);

  // Function: get_max_quit_count
  // returns the currently configured max quit count
  abstract int get_max_quit_count();

  // Function: set_quit_count
  // sets the current number of ~UVM_QUIT~ actions already passed through this uvm_report_server
  abstract void set_quit_count(int quit_count);

  // Function: get_quit_count
  // returns the current number of ~UVM_QUIT~ actions already passed through this server
  abstract int get_quit_count();

  // Function: set_severity_count
  // sets the count of already passed messages with severity ~severity~ to ~count~
  abstract void set_severity_count(uvm_severity severity, int count);
  // Function: get_severity_count
  // returns the count of already passed messages with severity ~severity~
  abstract int get_severity_count(uvm_severity severity);

  // Function: set_id_count
  // sets the count of already passed messages with ~id~ to ~count~
  abstract void set_id_count(string id, int count);

  // Function: get_id_count
  // returns the count of already passed messages with ~id~
  abstract int get_id_count(string id);


  // Function: get_id_set
  // returns the set of id's already used by this uvm_report_server
  abstract void get_id_set(out string[] q);

  // Function: get_severity_set
  // returns the set of severities already used by this uvm_report_server
  abstract void get_severity_set(out uvm_severity[] q);

  // Function: set_message_database
  // sets the <uvm_tr_database> used for recording messages
  abstract void set_message_database(uvm_tr_database database);

  // Function: get_message_database
  // returns the <uvm_tr_database> used for recording messages
  abstract uvm_tr_database get_message_database();

  // Function: do_copy
  // copies all message statistic severity,id counts to the destination uvm_report_server
  // the copy is cummulative (only items from the source are transferred, already existing entries are not deleted,
  // existing entries/counts are overridden when they exist in the source set)
  override void do_copy (uvm_object rhs) {
    synchronized(this) {
      super.do_copy(rhs);
      uvm_report_server rhs_ = cast(uvm_report_server) rhs;
      if(rhs_ !is null) {
	uvm_root_error("UVM/REPORT/SERVER/RPTCOPY", "cannot copy to report_server from the given datatype");
      }

      uvm_severity[] sev_set;
      rhs_.get_severity_set(sev_set);
      foreach(p; sev_set) {
	set_severity_count(p, rhs_.get_severity_count(p));
      }

      string[] id_set;
      rhs_.get_id_set(id_set);
      foreach(p; id_set) {
	set_id_count(p, rhs_.get_id_count(p));
      }

      set_message_database(rhs_.get_message_database());
      set_max_quit_count(rhs_.get_max_quit_count());
      set_quit_count(rhs_.get_quit_count());
    }
  }


  // Function- process_report_message
  //
  // Main entry for uvm_report_server, combines execute_report_message and compose_report_message

  abstract void process_report_message(uvm_report_message report_message);


  // Function: execute_report_message
  //
  // Processes the provided message per the actions contained within.
  //
  // Expert users can overload this method to customize action processing.

  abstract void execute_report_message(uvm_report_message report_message,
				       string composed_message);


  // Function: compose_report_message
  //
  // Constructs the actual string sent to the file or command line
  // from the severity, component name, report id, and the message itself.
  //
  // Expert users can overload this method to customize report formatting.

  abstract string compose_report_message(uvm_report_message report_message,
					 string report_object_name = "");


  // Function: report_summarize
  //
  // Outputs statistical information on the reports issued by this central report
  // server. This information will be sent to the command line if ~file~ is 0, or
  // to the file descriptor ~file~ if it is not 0.
  //
  // The <run_test> method in uvm_top calls this method.

  abstract void report_summarize(UVM_FILE file = 0);


  version(UVM_INCLUDE_DEPRECATED) {

    // Function- summarize
    //

    void summarize(UVM_FILE file=0) {
      report_summarize(file);
    }
  }

  // Function: set_server
  //
  // Sets the global report server to use for reporting.
  //
  // This method is provided as a convenience wrapper around
  // setting the report server via the <uvm_coreservice_t::set_report_server>
  // method.
  //
  // In addition to setting the server this also copies the severity/id counts
  // from the current report_server to the new one
  //
  // | // Using the uvm_coreservice_t:
  // | uvm_coreservice_t cs;
  // | cs = uvm_coreservice_t::get();
  // | your_server.copy(cs.get_report_server());
  // | cs.set_report_server(your_server);
  // |
  // | // Not using the uvm_coreservice_t:
  // | uvm_report_server::set_server(your_server);

  static void set_server(uvm_report_server server) {
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    server.copy(cs.get_report_server());
    cs.set_report_server(server);
  }


  // Function: get_server
  //
  // Gets the global report server used for reporting.
  //
  // This method is provided as a convenience wrapper
  // around retrieving the report server via the <uvm_coreservice_t::get_report_server>
  // method.
  //
  // | // Using the uvm_coreservice_t:
  // | uvm_coreservice_t cs;
  // | uvm_report_server rs;
  // | cs = uvm_coreservice_t::get();
  // | rs = cs.get_report_server();
  // |
  // | // Not using the uvm_coreservice_t:
  // | uvm_report_server rs;
  // | rs = uvm_report_server::get_server();
  //

  static uvm_report_server get_server() {
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    return cs.get_report_server();
  }
}

//------------------------------------------------------------------------------
//
// CLASS: uvm_default_report_server
//
// Default implementation of the UVM report server.
//

class uvm_default_report_server: uvm_report_server
{
  mixin uvm_sync;

  private int _m_max_quit_count;
  private int _m_quit_count;
  private bool _max_quit_overridable = true;
  private int[uvm_severity] _m_severity_count;
  private int[string] _m_id_count;
  private uvm_tr_database _m_message_db;
  private uvm_tr_stream[string][string] _m_streams; // ro.name,rh.name


  // Variable: enable_report_id_count_summary
  //
  // A flag to enable report count summary for each ID
  //
  @uvm_public_sync
  private bool _enable_report_id_count_summary = true;


  // Variable: record_all_messages
  //
  // A flag to force recording of all messages (add UVM_RM_RECORD action)
  //
  private bool _record_all_messages = false;


  // Variable: show_verbosity
  //
  // A flag to include verbosity in the messages, e.g.
  //
  // "UVM_INFO(UVM_MEDIUM) file.v(3) @ 60: reporter [ID0] Message 0"
  //
  private bool _show_verbosity = false;


  // Variable: show_terminator
  //
  // A flag to add a terminator in the messages, e.g.
  //
  // "UVM_INFO file.v(3) @ 60: reporter [ID0] Message 0 -UVM_INFO"
  //
  private bool _show_terminator = false;

  // Needed for callbacks
  override string get_type_name() {
    return qualifiedTypeName!(typeof(this));
  }

  // Function: new
  //
  // Creates an instance of the class.

  this(string name = "uvm_report_server") {
    synchronized(this) {
      super(name);
      set_max_quit_count(0);
      reset_quit_count();
      reset_severity_counts();
    }
  }

  // Function: print
  //
  // The uvm_report_server implements the <uvm_object::do_print()> such that
  // ~print~ method provides UVM printer formatted output
  // of the current configuration.  A snippet of example output is shown here:
  //
  // |uvm_report_server                 uvm_report_server  -     @13
  // |  quit_count                      int                32    'd0
  // |  max_quit_count                  int                32    'd5
  // |  max_quit_overridable            bit                1     'b1
  // |  severity_count                  severity counts    4     -
  // |    [UVM_INFO]                    integral           32    'd4
  // |    [UVM_WARNING]                 integral           32    'd2
  // |    [UVM_ERROR]                   integral           32    'd50
  // |    [UVM_FATAL]                   integral           32    'd10
  // |  id_count                        id counts          4     -
  // |    [ID1]                         integral           32    'd1
  // |    [ID2]                         integral           32    'd2
  // |    [RNTST]                       integral           32    'd1
  // |  enable_report_id_count_summary  bit                1     'b1
  // |  record_all_messages             bit                1     `b0
  // |  show_verbosity                  bit                1     `b0
  // |  show_terminator                 bit                1     `b0


  // Print to show report server state
  override void do_print (uvm_printer printer) {
    synchronized(this) {
      uvm_severity l_severity_count_index;
      string l_id_count_index;

      printer.print("quit_count", _m_quit_count, UVM_DEC, '.', "int");
      printer.print("max_quit_count", _m_max_quit_count,
		    UVM_DEC, '.', "int");
      printer.print("max_quit_overridable", _max_quit_overridable,
		    UVM_BIN, '.', "bit");

      if(_m_severity_count.length != 0) {
	printer.print_array_header("severity_count", _m_severity_count.length,
				   "severity counts");
	foreach(l_severity_count_index, count; _m_severity_count) {
	  printer.print(format("[%s]", l_severity_count_index.to!string()),
			count, UVM_DEC);
	}
	printer.print_array_footer();
      }

      if(_m_id_count.length != 0) {
	printer.print_array_header("id_count", _m_id_count.length,
				   "id counts");
	foreach(l_id_count_index, count; _m_id_count) {
	  printer.print(format("[%s]",l_id_count_index),
			count, UVM_DEC);
	}
	printer.print_array_footer();
      }

      printer.print("enable_report_id_count_summary", _enable_report_id_count_summary,
		    UVM_BIN, '.', "bit");
      printer.print("record_all_messages", _record_all_messages,
		    UVM_BIN, '.', "bit");
      printer.print("show_verbosity", _show_verbosity,
		    UVM_BIN, '.', "bit");
      printer.print("show_terminator", _show_terminator,
		    UVM_BIN, '.', "bit");
    }
  }

  //----------------------------------------------------------------------------
  // Group: Quit Count
  //----------------------------------------------------------------------------


  // Function: get_max_quit_count

  override int get_max_quit_count() {
    synchronized(this) {
      return _m_max_quit_count;
    }
  }

  // Function: set_max_quit_count
  //
  // Get or set the maximum number of COUNT actions that can be tolerated
  // before a UVM_EXIT action is taken. The default is 0, which specifies
  // no maximum.

  override void set_max_quit_count(int count, bool overridable = true) {
    synchronized(this) {
      if (_max_quit_overridable == 0) {
	uvm_report_info("NOMAXQUITOVR",
			format("The max quit count setting of " ~
			       "%0d is not overridable to %0d " ~
			       "due to a previous setting.",
			       _m_max_quit_count, count), UVM_NONE);
	return;
      }
      _max_quit_overridable = overridable;
      _m_max_quit_count = count < 0 ? 0 : count;
    }
  }


  // Function: get_quit_count

  override int get_quit_count() {
    synchronized(this) {
      return _m_quit_count;
    }
  }

  // Function: set_quit_count

  override void set_quit_count(int quit_count) {
    synchronized(this) {
      _m_quit_count = quit_count < 0 ? 0 : quit_count;
    }
  }

  // Function: incr_quit_count

  void incr_quit_count() {
    synchronized(this) {
      _m_quit_count++;
    }
  }

  // Function: reset_quit_count
  //
  // Set, get, increment, or reset to 0 the quit count, i.e., the number of
  // COUNT actions issued.

  void reset_quit_count() {
    synchronized(this) {
      _m_quit_count = 0;
    }
  }

  // Function: is_quit_count_reached
  //
  // If is_quit_count_reached returns 1, then the quit counter has reached
  // the maximum.

  bool is_quit_count_reached() {
    synchronized(this) {
      return (_m_quit_count >= _m_max_quit_count);
    }
  }


  //----------------------------------------------------------------------------
  // Group: Severity Count
  //----------------------------------------------------------------------------


  // Function: get_severity_count

  override int get_severity_count(uvm_severity severity) {
    synchronized(this) {
      return _m_severity_count[severity];
    }
  }

  // Function: set_severity_count

  override void set_severity_count(uvm_severity severity, int count) {
    synchronized(this) {
      _m_severity_count[severity] = count < 0 ? 0 : count;
    }
  }

  // Function: incr_severity_count

  void incr_severity_count(uvm_severity severity) {
    synchronized(this) {
      _m_severity_count[severity]++;
    }
  }

  // Function: reset_severity_counts
  //
  // Set, get, or increment the counter for the given severity, or reset
  // all severity counters to 0.

  void reset_severity_counts() {
    synchronized(this) {
      foreach(s; EnumMembers!uvm_severity) {
	_m_severity_count[s] = 0;
      }
    }
  }


  //----------------------------------------------------------------------------
  // Group: id Count
  //----------------------------------------------------------------------------


  // Function: get_id_count

  override int get_id_count(string id) {
    synchronized(this) {
      if(id in _m_id_count) {
	return _m_id_count[id];
      }
      return 0;
    }
  }

  // Function: set_id_count

  override void set_id_count(string id, int count) {
    synchronized(this) {
      _m_id_count[id] = count < 0 ? 0 : count;
    }
  }

  // Function: incr_id_count
  //
  // Set, get, or increment the counter for reports with the given id.

  void incr_id_count(string id) {
    synchronized(this) {
      if(id in _m_id_count) {
	_m_id_count[id]++;
      }
      else {
	_m_id_count[id] = 1;
      }
    }
  }

  //----------------------------------------------------------------------------
  // Group: message recording
  //
  // The ~uvm_default_report_server~ will record messages into the message
  // database, using one transaction per message, and one stream per report
  // object/handler pair.
  //
  //----------------------------------------------------------------------------

  // Function: set_message_database
  // sets the <uvm_tr_database> used for recording messages
  override void set_message_database(uvm_tr_database database) {
    synchronized(this) {
      _m_message_db = database;
    }
  }

  // Function: get_message_database
  // returns the <uvm_tr_database> used for recording messages
  //
  override uvm_tr_database get_message_database() {
    synchronized(this) {
      return _m_message_db;
    }
  }

  override void get_severity_set(out uvm_severity[] q) {
    synchronized(this) {
      foreach(l_severity, l_count; _m_severity_count) {
	q ~= l_severity;
      }
    }
  }


  override void get_id_set(out string[] q) {
    synchronized(this) {
      foreach(l_id, l_count; _m_id_count) {
	q ~= l_id;
      }
    }
  }


  // Function- f_display
  //
  // This method sends string severity to the command line if file is 0 and to
  // the file(s) specified by file if it is not 0.

  static void f_display(UVM_FILE file, string str) {
    if (file == 0) {
      vdisplay("%s", str);
    }
    else {
      vfdisplay(file, "%s", str);
    }
  }


  // Function- process_report_message
  //
  //

  override void process_report_message(uvm_report_message report_message) {
    synchronized(this) {
      uvm_report_handler l_report_handler = report_message.get_report_handler();
      Process p = Process.self();
      bool report_ok = true;

      // Set the report server for this message
      report_message.set_report_server(this);

      version(UVM_INCLUDE_DEPRECATED) {

      	// The hooks can do additional filtering.  If the hook function
      	// return 1 then continue processing the report.  If the hook
      	// returns 0 then skip processing the report.

      	if(report_message.get_action() & UVM_CALL_HOOK) {
      	  report_ok =
      	    l_report_handler.run_hooks(report_message.get_report_object(),
      				       report_message.get_severity(),
      				       report_message.get_id(),
      				       report_message.get_message(),
      				       report_message.get_verbosity(),
      				       report_message.get_filename(),
      				       report_message.get_line());
      	}
      }

      if(report_ok) {
	report_ok =
	  uvm_report_catcher.process_all_report_catchers(report_message);
      }

      if(report_message.get_action() == UVM_NO_ACTION) {
	report_ok = 0;
      }

      if(report_ok) {
	string m;
	uvm_coreservice_t cs = uvm_coreservice_t.get();
	// give the global server a chance to intercept the calls
	uvm_report_server svr = cs.get_report_server();

	version(UVM_DEPRECATED_REPORTING) {

	  // no need to compose when neither UVM_DISPLAY nor UVM_LOG is set
	  if (report_message.get_action() & (UVM_LOG|UVM_DISPLAY)) {
	    m = compose_message(report_message.get_severity(),
				l_report_handler.get_full_name(),
				report_message.get_id(),
				report_message.get_message(),
				report_message.get_filename(),
				report_message.get_line());
	  }

	  process_report(report_message.get_severity(),
			 l_report_handler.get_full_name(),
			 report_message.get_id(),
			 report_message.get_message(),
			 report_message.get_action(),
			 report_message.get_file(),
			 report_message.get_filename(),
			 report_message.get_line(),
			 m,
			 report_message.get_verbosity(),
			 report_message.get_report_object());
	}
	else {
	  // no need to compose when neither UVM_DISPLAY nor UVM_LOG is set
	  if (report_message.get_action() & (UVM_LOG|UVM_DISPLAY)) {
	    m = svr.compose_report_message(report_message);
	  }
	  svr.execute_report_message(report_message, m);
	}
      }
    }
  }


  //----------------------------------------------------------------------------
  // Group: Message Processing
  //----------------------------------------------------------------------------


  // Function: execute_report_message
  //
  // Processes the provided message per the actions contained within.
  //
  // Expert users can overload this method to customize action processing.

  override void execute_report_message(uvm_report_message report_message,
				       string composed_message) {
    synchronized(this) {
      Process p = Process.self();

      // Update counts
      incr_severity_count(report_message.get_severity());
      incr_id_count(report_message.get_id());

      if(_record_all_messages) {
	report_message.set_action(report_message.get_action() | UVM_RM_RECORD);
      }

      // UVM_RM_RECORD action
      if(report_message.get_action() & UVM_RM_RECORD) {
	uvm_tr_stream stream;
	uvm_report_object ro = report_message.get_report_object();
	uvm_report_handler rh = report_message.get_report_handler();

	// Check for pre-existing stream
	if ((ro.get_name in _m_streams) &&
	    (rh.get_name() in _m_streams[ro.get_name()])) {
	  stream = _m_streams[ro.get_name()][rh.get_name()];
	}

	// If no pre-existing stream (or for some reason pre-existing stream was ~null~)
	if (stream is null) {
	  uvm_tr_database db;

	  // Grab the database
	  db = get_message_database();

	  // If database is ~null~, use the default database
	  if (db is null) {
	    uvm_coreservice_t cs = uvm_coreservice_t.get();
	    db = cs.get_default_tr_database();
	  }
	  if (db !is null) {
	    // Open the stream.  Name=report object name, scope=report handler name, type=MESSAGES
	    stream = db.open_stream(ro.get_name(), rh.get_name(), "MESSAGES");
	    // Save off the openned stream
	    _m_streams[ro.get_name()][rh.get_name()] = stream;
	  }
	}
	if (stream !is null) {
	  uvm_recorder recorder =
	    stream.open_recorder(report_message.get_name(), SimTime(0),
				 report_message.get_type_name());
	  if (recorder !is null) {
	    report_message.record(recorder);
	    recorder.free();
	  }
	}
      }

      // DISPLAY action
      if(report_message.get_action() & UVM_DISPLAY)
	vdisplay("%s", composed_message);

      // LOG action
      // if log is set we need to send to the file but not resend to the
      // display. So, we need to mask off stdout for an mcd or we need
      // to ignore the stdout file handle for a file handle.
      if(report_message.get_action() & UVM_LOG) {
	if( (report_message.get_file() == 0) ||
	    (report_message.get_file() != 0x8000_0001) ) { //ignore stdout handle
	  UVM_FILE tmp_file = report_message.get_file();
	  if((report_message.get_file() & 0x8000_0000) == 0) { //is an mcd so mask off stdout
	    tmp_file = report_message.get_file() & 0xffff_fffe;
	  }
	  f_display(tmp_file, composed_message);
	}
      }

      // Process the UVM_COUNT action
      if(report_message.get_action() & UVM_COUNT) {
	if(get_max_quit_count() != 0) {
	  incr_quit_count();
	  // If quit count is reached, add the UVM_EXIT action.
	  if(is_quit_count_reached()) {
	    report_message.set_action(report_message.get_action() | UVM_EXIT);
	  }
	}
      }

      // Process the UVM_EXIT action
      if(report_message.get_action() & UVM_EXIT) {
	uvm_root l_root;
	uvm_coreservice_t cs;
	cs = uvm_coreservice_t.get();
	l_root = cs.get_root();
	l_root.die();
      }

      // Process the UVM_STOP action
      if (report_message.get_action() & UVM_STOP) {
	debug(FINISH) {
	  import std.stdio;
	  writeln("uvm_report_server.process_report");
	}
	finish(); // $stop;
      }
    }
  }

  // Function: compose_report_message
  //
  // Constructs the actual string sent to the file or command line
  // from the severity, component name, report id, and the message itself.
  //
  // Expert users can overload this method to customize report formatting.

  override string compose_report_message(uvm_report_message report_message,
					 string report_object_name = "") {
    synchronized(this) {

      string filename_line_string;
      string line_str;
      string context_str;
      string verbosity_str;
      string terminator_str;
      string msg_body_str;
      uvm_report_handler l_report_handler;

      uvm_severity l_severity = report_message.get_severity();
      string sev_string = l_severity.to!string();

      if(report_message.get_filename() != "") {
	line_str = report_message.get_line().to!string();
	filename_line_string = report_message.get_filename() ~ "(" ~
	  line_str ~ ") ";
      }

      // Make definable in terms of units.
      string time_str = format("%0s", getRootEntity.getSimTime);

      if(report_message.get_context() != "") {
	context_str = "@@" ~ report_message.get_context();
      }

      if(_show_verbosity) {
	uvm_verbosity l_verbosity =
	  cast(uvm_verbosity) report_message.get_verbosity();
	// if ($cast(l_verbosity, report_message.get_verbosity()))
	verbosity_str = l_verbosity.to!string();
	// else
	//   verbosity_str.itoa(report_message.get_verbosity());
	verbosity_str = "(" ~ verbosity_str ~ ")";
      }

      if (_show_terminator) {
	terminator_str = " -" ~ sev_string;
      }

      uvm_report_message_element_container el_container =
	report_message.get_element_container();
      if (el_container.length == 0) {
	msg_body_str = report_message.get_message();
      }
      else {
	string prefix = uvm_default_printer.knobs.prefix;
	uvm_default_printer.knobs.prefix = " +";
	msg_body_str =
	  report_message.get_message() ~ "\n" ~ el_container.sprint();
	uvm_default_printer.knobs.prefix = prefix;
      }

      if (report_object_name == "") {
	l_report_handler = report_message.get_report_handler();
	report_object_name = l_report_handler.get_full_name();
      }

      return sev_string ~ verbosity_str ~ " ", filename_line_string ~
	"@ " ~ time_str ~ ": " ~ report_object_name ~ context_str ~ " [" ~
	report_message.get_id() ~ "] " ~ msg_body_str ~ terminator_str;
    }
  }


  // Function: report_summarize
  //
  // Outputs statistical information on the reports issued by this central report
  // server. This information will be sent to the command line if ~file~ is 0, or
  // to the file descriptor ~file~ if it is not 0.
  //
  // The <run_test> method in uvm_top calls this method.

  override void report_summarize(UVM_FILE file = 0) {
    synchronized(this) {
      string q;

      uvm_report_catcher.summarize();
      q ~= "\n--- UVM Report Summary ---\n\n";

      if(_m_max_quit_count != 0) {
	if ( _m_quit_count >= _m_max_quit_count ) {
	  q ~= "Quit count reached!\n";
	}
	q ~= format("Quit count : %5d of %5d\n",
		    _m_quit_count, _m_max_quit_count);
      }

      q ~= "** Report counts by severity\n";
      foreach(l_severity, l_count; _m_severity_count) {
	q ~= format("%s :%5d\n", l_severity, l_count);
      }

      if(_enable_report_id_count_summary) {
	q ~= "** Report counts by id\n";
	foreach(l_id, l_count; _m_id_count) {
	  q ~= format("[%s] %5d\n", l_id, l_count);
	}
      }
      uvm_root_info("UVM/REPORT/SERVER", q ,UVM_LOW);
    }
  }


  version(UVM_INCLUDE_DEPRECATED) {

    // Function- process_report
    //
    // Calls <compose_message> to construct the actual message to be
    // output. It then takes the appropriate action according to the value of
    // action and file.
    //
    // This method can be overloaded by expert users to customize the way the
    // reporting system processes reports and the actions enabled for them.

    void process_report(uvm_severity severity,
			string name,
			string id,
			string message,
			uvm_action action,
			UVM_FILE file,
			string filename,
			size_t line,
			string composed_message,
			int verbosity_level,
			uvm_report_object client
			) {

      uvm_report_message l_report_message =
	uvm_report_message.new_report_message();
      l_report_message.set_report_message(severity, id, message,
					  verbosity_level, filename, line, "");
      l_report_message.set_report_object(client);
      l_report_message.set_report_handler(client.get_report_handler());
      l_report_message.set_file(file);
      l_report_message.set_action(action);
      l_report_message.set_report_server(this);

      this.execute_report_message(l_report_message, composed_message);
    }


    // Function- compose_message
    //
    // Constructs the actual string sent to the file or command line
    // from the severity, component name, report id, and the message itself.
    //
    // Expert users can overload this method to customize report formatting.

    string compose_message(uvm_severity severity,
			   string name,
			   string id,
			   string message,
			   string filename,
			   size_t line
			   ) {
      uvm_report_message l_report_message;

      l_report_message = uvm_report_message.new_report_message();
      l_report_message.set_report_message(severity, id, message,
					  UVM_NONE, filename, line, "");

      return compose_report_message(l_report_message, name);
    }
  }
}
