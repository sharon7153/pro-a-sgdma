// ============================================================================
// axi_mem_slave.sv
//   Simple AXI4 slave models backed by tb_mem_pkg::mem
//     - axi_rd_slave : AR/R channels only
//     - axi_wr_slave : AW/W/B channels only
//   Limitations (bring-up level): 1 outstanding transaction, INCR burst only,
//   always OKAY response, no random delay.
// ============================================================================
`timescale 1ns/1ps

// ----------------------------------------------------------------------------
// Read slave
// ----------------------------------------------------------------------------
module axi_rd_slave #(
  parameter int    AW      = 32,
  parameter int    DW      = 64,
  parameter string NAME    = "RD",
  parameter bit    VERBOSE = 1
) (
  input  logic          clk,
  input  logic          resetn,
  input  logic          arvalid,
  output logic          arready,
  input  logic [AW-1:0] araddr,
  input  logic [7:0]    arlen,
  input  logic [2:0]    arsize,
  input  logic [1:0]    arburst,
  output logic          rvalid,
  input  logic          rready,
  output logic [DW-1:0] rdata,
  output logic [1:0]    rresp,
  output logic          rlast
);
  import tb_mem_pkg::*;
  localparam int NB = DW/8;

  function automatic logic [DW-1:0] read_beat(bit [31:0] a);
    for (int b = 0; b < NB; b++) read_beat[8*b +: 8] = mem_read8(a + b);
  endfunction

  initial begin
    bit [31:0] base;
    int        len;
    int        step;

    arready = 1'b0;
    rvalid  = 1'b0;
    rlast   = 1'b0;
    rdata   = '0;
    rresp   = 2'b00;
    wait (resetn === 1'b1);

    forever begin
      // ---------------- address phase ----------------
      @(posedge clk);
      arready <= 1'b1;
      do @(posedge clk); while (arvalid !== 1'b1);
      base = araddr & ~(NB-1);
      len  = arlen;
      step = 1 << arsize;
      arready <= 1'b0;

      if (arburst != 2'b01)
        $error("[%s] only INCR burst is supported (arburst=%0d)", NAME, arburst);
      if (VERBOSE)
        $display("[%0t] %-4s AR  addr=0x%08h beats=%0d size=%0dB", $time, NAME, araddr, len+1, step);

      // ---------------- data phase ----------------
      for (int i = 0; i <= len; i++) begin
        rdata  <= read_beat(base + i*step);
        rvalid <= 1'b1;
        rlast  <= (i == len);
        do @(posedge clk); while (rready !== 1'b1);
      end
      rvalid <= 1'b0;
      rlast  <= 1'b0;
    end
  end
endmodule

// ----------------------------------------------------------------------------
// Write slave
// ----------------------------------------------------------------------------
module axi_wr_slave #(
  parameter int    AW      = 32,
  parameter int    DW      = 64,
  parameter string NAME    = "WR",
  parameter bit    VERBOSE = 1
) (
  input  logic            clk,
  input  logic            resetn,
  input  logic            awvalid,
  output logic            awready,
  input  logic [AW-1:0]   awaddr,
  input  logic [7:0]      awlen,
  input  logic [2:0]      awsize,
  input  logic [1:0]      awburst,
  input  logic            wvalid,
  output logic            wready,
  input  logic [DW-1:0]   wdata,
  input  logic [DW/8-1:0] wstrb,
  input  logic            wlast,
  output logic            bvalid,
  input  logic            bready,
  output logic [1:0]      bresp
);
  import tb_mem_pkg::*;
  localparam int NB = DW/8;

  initial begin
    bit [31:0] base;
    int        len;
    int        step;

    awready = 1'b0;
    wready  = 1'b0;
    bvalid  = 1'b0;
    bresp   = 2'b00;
    wait (resetn === 1'b1);

    forever begin
      // ---------------- address phase ----------------
      @(posedge clk);
      awready <= 1'b1;
      do @(posedge clk); while (awvalid !== 1'b1);
      base = awaddr & ~(NB-1);
      len  = awlen;
      step = 1 << awsize;
      awready <= 1'b0;

      if (awburst != 2'b01)
        $error("[%s] only INCR burst is supported (awburst=%0d)", NAME, awburst);
      if (VERBOSE)
        $display("[%0t] %-4s AW  addr=0x%08h beats=%0d size=%0dB", $time, NAME, awaddr, len+1, step);

      // ---------------- data phase ----------------
      wready <= 1'b1;
      for (int i = 0; i <= len; i++) begin
        do @(posedge clk); while (wvalid !== 1'b1);
        for (int b = 0; b < NB; b++)
          if (wstrb[b]) mem_write8(base + i*step + b, wdata[8*b +: 8]);
        if (wlast !== (i == len))
          $error("[%s] WLAST mismatch at beat %0d (expected last at %0d)", NAME, i, len);
      end
      wready <= 1'b0;

      // ---------------- response phase ----------------
      bvalid <= 1'b1;
      do @(posedge clk); while (bready !== 1'b1);
      bvalid <= 1'b0;
    end
  end
endmodule