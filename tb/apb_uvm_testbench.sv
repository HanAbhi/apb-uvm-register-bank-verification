// EDA Playground Testbench pane: interface + UVM testbench
interface apb_if(input logic PCLK);
  logic PRESETn;
  logic PSEL, PENABLE, PWRITE;
  logic [7:0] PADDR;
  logic [31:0] PWDATA, PRDATA;
  logic [3:0] PSTRB;
  logic PREADY, PSLVERR;

  // Enable the three protocol assertions by adding +define+ENABLE_SVA
  // to EDA Playground Compile Options when using Questa 2025.2.
`ifdef ENABLE_SVA
  // Assertion 1: PENABLE must never be high unless PSEL is high.
  property p_enable_requires_select;
    @(posedge PCLK) disable iff (!PRESETn)
      PENABLE |-> PSEL;
  endproperty

  a_enable_requires_select:
    assert property (p_enable_requires_select)
    else $error("SVA FAIL: PENABLE high without PSEL");

  c_enable_requires_select:
    cover property (@(posedge PCLK) disable iff (!PRESETn)
      PENABLE && PSEL)
    $display("SVA COVER: PENABLE/PSEL condition exercised");

  // Assertion 2: APB controls and payload must remain stable during wait states.
  property p_stable_during_wait;
    @(posedge PCLK) disable iff (!PRESETn)
      (PSEL && PENABLE && !PREADY)
      |=> $stable({PSEL,PENABLE,PWRITE,PADDR,PWDATA,PSTRB});
  endproperty

  a_stable_during_wait:
    assert property (p_stable_during_wait)
    else $error("SVA FAIL: APB signals changed during wait");

  c_stable_during_wait:
    cover property (@(posedge PCLK) disable iff (!PRESETn)
      PSEL && PENABLE && !PREADY)
    $display("SVA COVER: Wait-state condition exercised");

  // Assertion 3: SETUP must progress to ACCESS on the next clock.
  property p_setup_to_access;
    @(posedge PCLK) disable iff (!PRESETn)
      (PSEL && !PENABLE) |=> (PSEL && PENABLE);
  endproperty

  a_setup_to_access:
    assert property (p_setup_to_access)
    else $error("SVA FAIL: SETUP did not progress to ACCESS");

  c_setup_to_access:
    cover property (@(posedge PCLK) disable iff (!PRESETn)
      PSEL && !PENABLE)
    $display("SVA COVER: SETUP phase exercised");
`endif
endinterface


`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_txn extends uvm_sequence_item;
  rand bit write;
  rand bit [7:0] addr;
  rand bit [31:0] data;
  rand bit [3:0] strb;
  bit [31:0] rdata;
  bit error;
  int unsigned wait_cycles;
  `uvm_object_utils_begin(apb_txn)
    `uvm_field_int(write,UVM_ALL_ON)
    `uvm_field_int(addr,UVM_ALL_ON)
    `uvm_field_int(data,UVM_ALL_ON)
    `uvm_field_int(strb,UVM_ALL_ON)
    `uvm_field_int(rdata,UVM_ALL_ON)
    `uvm_field_int(error,UVM_ALL_ON)
    `uvm_field_int(wait_cycles,UVM_ALL_ON)
  `uvm_object_utils_end
  function new(string name="apb_txn"); super.new(name); endfunction
endclass

class apb_sequencer extends uvm_sequencer #(apb_txn);
  `uvm_component_utils(apb_sequencer)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
endclass

class apb_driver extends uvm_driver #(apb_txn);
  `uvm_component_utils(apb_driver)
  virtual apb_if vif;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","Virtual interface not configured")
  endfunction
  task run_phase(uvm_phase phase);
    apb_txn tr;
    vif.PSEL<=0; vif.PENABLE<=0; vif.PWRITE<=0;
    vif.PADDR<=0; vif.PWDATA<=0; vif.PSTRB<=0;
    forever begin
      seq_item_port.get_next_item(tr);
      // SETUP phase
      @(negedge vif.PCLK);
      vif.PSEL<=1; vif.PENABLE<=0; vif.PWRITE<=tr.write;
      vif.PADDR<=tr.addr; vif.PWDATA<=tr.data; vif.PSTRB<=tr.strb;
      // ACCESS phase; hold all controls until PREADY.
      @(negedge vif.PCLK);
      vif.PENABLE<=1;
      tr.wait_cycles=0;
      do begin
        @(posedge vif.PCLK);
        if (!vif.PREADY) tr.wait_cycles++;
      end while (!vif.PREADY);
      tr.rdata=vif.PRDATA;
      tr.error=vif.PSLVERR;
      @(negedge vif.PCLK);
      vif.PSEL<=0; vif.PENABLE<=0;
      seq_item_port.item_done();
    end
  endtask
endclass

class apb_monitor extends uvm_component;
  `uvm_component_utils(apb_monitor)
  virtual apb_if vif;
  uvm_analysis_port #(apb_txn) ap;
  function new(string name, uvm_component parent);
    super.new(name,parent); ap=new("ap",this);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","Virtual interface not configured")
  endfunction
  task run_phase(uvm_phase phase);
    apb_txn tr;
    int unsigned wait_ctr=0;
    forever begin
      @(posedge vif.PCLK);
      if (!vif.PRESETn || !vif.PSEL || !vif.PENABLE) wait_ctr=0;
      else if (vif.PSEL && vif.PENABLE && !vif.PREADY) wait_ctr++;
      if (vif.PRESETn && vif.PSEL && vif.PENABLE && vif.PREADY) begin
        tr=apb_txn::type_id::create("observed");
        tr.write=vif.PWRITE; tr.addr=vif.PADDR; tr.data=vif.PWDATA;
        tr.strb=vif.PSTRB; tr.rdata=vif.PRDATA; tr.error=vif.PSLVERR;
        tr.wait_cycles=wait_ctr;
        ap.write(tr);
        wait_ctr=0;
      end
    end
  endtask
endclass

class apb_scoreboard extends uvm_component;
  `uvm_component_utils(apb_scoreboard)
  uvm_analysis_imp #(apb_txn,apb_scoreboard) analysis_export;
  bit [31:0] model_ctrl, model_int_status, model_scratch;
  int unsigned checked, errors;
  function new(string name, uvm_component parent);
    super.new(name,parent); analysis_export=new("analysis_export",this);
    reset_model();
  endfunction
  function void reset_model();
    model_ctrl=0; model_int_status=32'h0000_000F; model_scratch=0;
  endfunction
  function void write(apb_txn tr);
    bit [31:0] expected;
    bit exp_error;
    exp_error=0; expected=0;
    case (tr.addr)
      8'h00: expected=model_ctrl;
      8'h04: begin expected=32'h1; if (tr.write) exp_error=1; end
      8'h08: expected=model_int_status;
      8'h0C: expected=model_scratch;
      default: begin expected=0; exp_error=1; end
    endcase

    if (tr.error !== exp_error) begin
      `uvm_error("APB_SB",$sformatf("PSLVERR mismatch addr=%02h expected=%0b got=%0b",tr.addr,exp_error,tr.error))
      errors++;
    end
    if (!tr.write && tr.rdata !== expected) begin
      `uvm_error("APB_SB",$sformatf("Read mismatch addr=%02h expected=%08h got=%08h",tr.addr,expected,tr.rdata))
      errors++;
    end

    // Update reference model only for legal completed writes.
    if (tr.write && !exp_error && !tr.error) begin
      case (tr.addr)
        8'h00: for (int i=0;i<4;i++) if (tr.strb[i])
          model_ctrl[i*8 +: 8]=tr.data[i*8 +: 8];
        8'h08: model_int_status=model_int_status & ~tr.data;
        8'h0C: for (int i=0;i<4;i++) if (tr.strb[i])
          model_scratch[i*8 +: 8]=tr.data[i*8 +: 8];
        default: ;
      endcase
    end
    checked++;
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("APB_SB",$sformatf("Transactions checked=%0d scoreboard errors=%0d",checked,errors),UVM_LOW)
    if (checked==0) `uvm_error("APB_SB","No APB transactions were checked")
  endfunction
endclass

class apb_coverage extends uvm_subscriber #(apb_txn);
  `uvm_component_utils(apb_coverage)
  bit [7:0] c_addr;
  bit c_write, c_error;
  bit [3:0] c_strb;
  int unsigned c_wait;
  bit [1:0] c_data_class;
  covergroup apb_cg;
    cp_addr: coverpoint c_addr {
      bins ctrl={8'h00}; bins status={8'h04}; bins int_status={8'h08};
      bins scratch={8'h0C}; bins invalid={8'h10};
    }
    cp_dir: coverpoint c_write { bins read={0}; bins write={1}; }
    cp_error: coverpoint c_error { bins ok={0}; bins error={1}; }
    cp_strobe: coverpoint c_strb { bins none={0}; bins byte0={1}; bins byte1={2};
      bins byte2={4}; bins byte3={8}; bins all={15}; bins other={[3:14]}; }
    // The DUT is configured with WAIT_STATES=2, so every completed
    // transfer must observe exactly two wait cycles. Zero- and one-wait
    // bins are unreachable with this fixed-latency DUT configuration.
    cp_wait: coverpoint c_wait { bins fixed_two_waits = {2}; }
    cp_data: coverpoint c_data_class { bins zero={0}; bins ones={1}; bins alternating={2}; bins other={3}; }
    addr_x_dir: cross cp_addr, cp_dir;

    // Only six address/error combinations are legal for this register map:
    // CTRL: OK; STATUS: OK or ERROR; INT_STATUS: OK; SCRATCH: OK;
    // INVALID: ERROR. Ignore the four architecturally impossible pairs.
    addr_x_error: cross cp_addr, cp_error {
      ignore_bins ctrl_error =
        binsof(cp_addr) intersect {8'h00} && binsof(cp_error) intersect {1};
      ignore_bins int_status_error =
        binsof(cp_addr) intersect {8'h08} && binsof(cp_error) intersect {1};
      ignore_bins scratch_error =
        binsof(cp_addr) intersect {8'h0C} && binsof(cp_error) intersect {1};
      ignore_bins invalid_ok =
        binsof(cp_addr) intersect {8'h10} && binsof(cp_error) intersect {0};
    }
  endgroup
  function new(string name, uvm_component parent);
    super.new(name,parent); apb_cg=new();
  endfunction
  function void write(apb_txn t);
    c_addr=t.addr; c_write=t.write; c_error=t.error; c_strb=t.strb; c_wait=t.wait_cycles;
    if (t.data==0) c_data_class=0;
    else if (t.data==32'hFFFF_FFFF) c_data_class=1;
    else if (t.data==32'h5555_AAAA || t.data==32'hAAAA_5555) c_data_class=2;
    else c_data_class=3;
    apb_cg.sample();
  endfunction
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("APB_COV",$sformatf("Functional coverage = %0.2f%%",apb_cg.get_coverage()),UVM_LOW)
    $display("\n========== APB COVERAGE DETAILS ==========");
    $display("Wait-state model: fixed WAIT_STATES=2; unreachable bins excluded.");
    $display("Address/error cross: only protocol-legal combinations are counted.");
    $display("Address coverpoint       : %0.2f%%", apb_cg.cp_addr.get_coverage());
    $display("Direction coverpoint     : %0.2f%%", apb_cg.cp_dir.get_coverage());
    $display("Error coverpoint         : %0.2f%%", apb_cg.cp_error.get_coverage());
    $display("Strobe coverpoint        : %0.2f%%", apb_cg.cp_strobe.get_coverage());
    $display("Wait-state coverpoint    : %0.2f%%", apb_cg.cp_wait.get_coverage());
    $display("Data-class coverpoint    : %0.2f%%", apb_cg.cp_data.get_coverage());
    $display("Address x direction      : %0.2f%%", apb_cg.addr_x_dir.get_coverage());
    $display("Address x error          : %0.2f%%", apb_cg.addr_x_error.get_coverage());
    $display("==========================================\n");
  endfunction
endclass

class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)
  apb_sequencer sqr;
  apb_driver drv;
  apb_monitor mon;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon=apb_monitor::type_id::create("mon",this);
    if (is_active==UVM_ACTIVE) begin
      sqr=apb_sequencer::type_id::create("sqr",this);
      drv=apb_driver::type_id::create("drv",this);
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    if (is_active==UVM_ACTIVE) drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass

class apb_env extends uvm_env;
  `uvm_component_utils(apb_env)
  apb_agent agent;
  apb_scoreboard sb;
  apb_coverage cov;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent=apb_agent::type_id::create("agent",this);
    sb=apb_scoreboard::type_id::create("sb",this);
    cov=apb_coverage::type_id::create("cov",this);
  endfunction
  function void connect_phase(uvm_phase phase);
    agent.mon.ap.connect(sb.analysis_export);
    agent.mon.ap.connect(cov.analysis_export);
  endfunction
endclass

class apb_base_seq extends uvm_sequence #(apb_txn);
  `uvm_object_utils(apb_base_seq)
  function new(string name="apb_base_seq"); super.new(name); endfunction
  task send(bit wr, bit[7:0] a, bit[31:0] d, bit[3:0] s=4'hF);
    apb_txn t=apb_txn::type_id::create("t");
    start_item(t);
    t.write=wr; t.addr=a; t.data=d; t.strb=s;
    finish_item(t);
  endtask
  task body();
    // Directed baseline tests
    send(1,8'h00,32'h1234_5678); send(0,8'h00,0);
    send(1,8'h0C,32'hA5A5_5A5A); send(0,8'h0C,0);
    send(0,8'h04,0);
    send(1,8'h04,32'hFFFF_FFFF); // expected PSLVERR
    send(1,8'h10,32'h1);         // invalid address
    send(0,8'h10,0);
    // INT_STATUS resets to 0xF in this teaching DUT; verify W1C clearing.
    send(0,8'h08,0);
    send(1,8'h08,32'h0000_0005);
    send(0,8'h08,0);
    // Partial byte write and readback
    send(1,8'h00,32'h0000_AA00,4'b0010);
    send(0,8'h00,0);
    // Corner data patterns: explicitly hit all four data classes.
    send(1,8'h0C,32'h0000_0000); send(0,8'h0C,0); // zero
    send(1,8'h0C,32'hFFFF_FFFF); send(0,8'h0C,0); // all ones
    send(1,8'h0C,32'h5555_AAAA); send(0,8'h0C,0); // alternating
    send(1,8'h0C,32'h1234_5678); send(0,8'h0C,0); // other

    // Explicitly exercise every named strobe bin on a writable register.
    send(1,8'h00,32'h1122_3344,4'b0000); send(0,8'h00,0);
    send(1,8'h00,32'h1122_3344,4'b0001); send(0,8'h00,0);
    send(1,8'h00,32'h1122_3344,4'b0010); send(0,8'h00,0);
    send(1,8'h00,32'h1122_3344,4'b0100); send(0,8'h00,0);
    send(1,8'h00,32'h1122_3344,4'b1000); send(0,8'h00,0);
    send(1,8'h00,32'h1122_3344,4'b1111); send(0,8'h00,0);
    send(1,8'h00,32'h1122_3344,4'b0011); send(0,8'h00,0);

    // Random stress, valid and invalid addresses
    repeat (100) begin
      apb_txn t=apb_txn::type_id::create("rand_t");
      start_item(t);
      if (!t.randomize() with {
        addr inside {8'h00,8'h04,8'h08,8'h0C,8'h10};
        strb inside {[0:15]};
      }) `uvm_error("RAND","Randomization failed")
      finish_item(t);
    end
  endtask
endclass


// -----------------------------------------------------------------------------
// Additional focused sequences and derived tests required by Task 3.
// Select one test in tb_top.TEST_NAME for an individual run.
// -----------------------------------------------------------------------------
class apb_rw_seq extends apb_base_seq;
  `uvm_object_utils(apb_rw_seq)
  function new(string name="apb_rw_seq"); super.new(name); endfunction
  task body();
    // Reset-value checks followed by RW and byte-strobe readback.
    send(0,8'h00,0); send(0,8'h0C,0); send(0,8'h08,0);
    send(1,8'h00,32'hCAFE_BABE,4'hF); send(0,8'h00,0);
    send(1,8'h0C,32'h1234_5678,4'b0101); send(0,8'h0C,0);
    // Back-to-back independent transfers.
    send(1,8'h00,32'h0BAD_F00D,4'hF);
    send(1,8'h0C,32'h55AA_33CC,4'hF);
    send(0,8'h00,0); send(0,8'h0C,0);
  endtask
endclass

class apb_error_seq extends apb_base_seq;
  `uvm_object_utils(apb_error_seq)
  function new(string name="apb_error_seq"); super.new(name); endfunction
  task body();
    // RO write must return PSLVERR; invalid address accesses must error.
    send(0,8'h04,0);
    send(1,8'h04,32'hFFFF_FFFF);
    send(0,8'h04,0);
    send(0,8'h10,0);
    send(1,8'h10,32'h1234_5678);
    // Legal accesses after errors prove the bus recovers.
    send(1,8'h00,32'h8765_4321); send(0,8'h00,0);
  endtask
endclass

class apb_random_seq extends apb_base_seq;
  `uvm_object_utils(apb_random_seq)
  function new(string name="apb_random_seq"); super.new(name); endfunction
  task body();
    // Directed W1C check first, while reset pending bits are known to be 1.
    send(0,8'h08,0);
    send(1,8'h08,32'h0000_0005);
    send(0,8'h08,0);
    // Constrained-random traffic over all implemented and invalid addresses.
    repeat (100) begin
      apb_txn t=apb_txn::type_id::create("focused_rand_t");
      start_item(t);
      if (!t.randomize() with {
        addr inside {8'h00,8'h04,8'h08,8'h0C,8'h10};
        strb inside {[0:15]};
      }) `uvm_error("RAND","Randomization failed in apb_random_seq")
      finish_item(t);
    end
  endtask
endclass

class apb_test extends uvm_test;
  `uvm_component_utils(apb_test)
  apb_env env;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env=apb_env::type_id::create("env",this);
  endfunction
  task run_phase(uvm_phase phase);
    apb_base_seq seq;
    phase.raise_objection(this);
    seq=apb_base_seq::type_id::create("seq");
    seq.start(env.agent.sqr);
    repeat(3) @(posedge env.agent.drv.vif.PCLK);
    phase.drop_objection(this);
  endtask
endclass


// Base test: complete directed + corner + 100-transaction random regression.
// Three derived tests provide focused feature-level regressions.
class apb_rw_test extends apb_test;
  `uvm_component_utils(apb_rw_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    apb_rw_seq seq;
    phase.raise_objection(this);
    seq=apb_rw_seq::type_id::create("rw_seq");
    seq.start(env.agent.sqr);
    repeat(3) @(posedge env.agent.drv.vif.PCLK);
    phase.drop_objection(this);
  endtask
endclass

class apb_error_test extends apb_test;
  `uvm_component_utils(apb_error_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    apb_error_seq seq;
    phase.raise_objection(this);
    seq=apb_error_seq::type_id::create("error_seq");
    seq.start(env.agent.sqr);
    repeat(3) @(posedge env.agent.drv.vif.PCLK);
    phase.drop_objection(this);
  endtask
endclass

class apb_random_test extends apb_test;
  `uvm_component_utils(apb_random_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    apb_random_seq seq;
    phase.raise_objection(this);
    seq=apb_random_seq::type_id::create("random_seq");
    seq.start(env.agent.sqr);
    repeat(3) @(posedge env.agent.drv.vif.PCLK);
    phase.drop_objection(this);
  endtask
endclass

module tb_top;
  import uvm_pkg::*;
  initial begin
    $dumpfile("apb_waveform.vcd");
    $dumpvars(0, tb_top);
  end
  bit PCLK=0;
  always #5 PCLK=~PCLK;
  apb_if bus(PCLK);
  logic [31:0] PRDATA;
  logic PREADY, PSLVERR;
  localparam int BUG_MODE = 0; 
  // Golden=0; mutation runs use 1, 2, then 3.
  // For derived-test runs, change TEST_NAME to apb_rw_test, apb_error_test,
  // or apb_random_test. Keep apb_test for the complete baseline regression.
  localparam string TEST_NAME = "apb_test";

  apb_regbank #(.WAIT_STATES(2),.BUG_MODE(BUG_MODE)) dut(
    .PCLK(PCLK),.PRESETn(bus.PRESETn),.PSEL(bus.PSEL),.PENABLE(bus.PENABLE),
    .PWRITE(bus.PWRITE),.PADDR(bus.PADDR),.PWDATA(bus.PWDATA),.PSTRB(bus.PSTRB),
    .PRDATA(bus.PRDATA),.PREADY(bus.PREADY),.PSLVERR(bus.PSLVERR)
  );

  initial begin
    bus.PRESETn=0;
    bus.PSEL=0; bus.PENABLE=0; bus.PWRITE=0;
    bus.PADDR=0; bus.PWDATA=0; bus.PSTRB=0;
    repeat(4) @(negedge PCLK);
    bus.PRESETn=1;
  end

  initial begin
    uvm_config_db#(virtual apb_if)::set(null,"*","vif",bus);
    run_test(TEST_NAME);
  end
endmodule
