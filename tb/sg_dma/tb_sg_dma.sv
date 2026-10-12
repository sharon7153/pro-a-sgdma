// ============================================================================
// tb_sg_dma.sv
//   Sanity testbench for sgdma_top (SG, MM->MM, single clock)
//
//   SAN-001 : Register identity          (5 checks)
//   SAN-002 : Scratch R/W                (3 checks)
//   SAN-003 : Reset defaults            (10 checks)
//   SAN-007 : Parameter-masked bits     (11 checks)
//   SAN-004 : Single descriptor copy     (4 checks)
//   SAN-005 : 3-descriptor gather        (6 checks)
//   SAN-006 : IRQ & status               (7 checks)
//   ----------------------------------------------
//   Total                               (46 checks)
//
//   Ref  : SGDMA-SANITY-v1.0, SGDMA-SFR-v1.0
//   Exit : non-zero on any failure (regression gate)
// ============================================================================
`timescale 1ns/1ps

module tb_sg_dma;
  import tb_mem_pkg::*;

  localparam int AW  = 32;
  localparam int DW  = 64;
  localparam int IDW = 1;    // AXI_ID_WIDTH

  // ---------------- register map (byte address) ----------------
  localparam logic [10:0] REG_VERSION                 = 11'h000;
  localparam logic [10:0] REG_PERIPHERAL_ID           = 11'h004;
  localparam logic [10:0] REG_SCRATCH                 = 11'h008;
  localparam logic [10:0] REG_IDENTIFICATION          = 11'h00C;
  localparam logic [10:0] REG_INTERFACE_DESCRIPTION_1 = 11'h010;
  localparam logic [10:0] REG_INTERFACE_DESCRIPTION_2 = 11'h014;
  localparam logic [10:0] REG_IRQ_MASK                = 11'h080;
  localparam logic [10:0] REG_IRQ_PENDING             = 11'h084;
  localparam logic [10:0] REG_IRQ_SOURCE              = 11'h088;
  localparam logic [10:0] REG_CONTROL                 = 11'h400;
  localparam logic [10:0] REG_TRANSFER_ID             = 11'h404;
  localparam logic [10:0] REG_TRANSFER_SUBMIT         = 11'h408;
  localparam logic [10:0] REG_FLAGS                   = 11'h40C;
  localparam logic [10:0] REG_DEST_ADDRESS            = 11'h410;
  localparam logic [10:0] REG_SRC_ADDRESS             = 11'h414;
  localparam logic [10:0] REG_X_LENGTH                = 11'h418;
  localparam logic [10:0] REG_Y_LENGTH                = 11'h41C;
  localparam logic [10:0] REG_TRANSFER_DONE           = 11'h428;
  localparam logic [10:0] REG_DESCRIPTOR_ID           = 11'h454;
  localparam logic [10:0] REG_FRAMELOCK_CONFIG        = 11'h458;
  localparam logic [10:0] REG_SG_ADDRESS              = 11'h47C;
  localparam logic [10:0] REG_DEST_ADDR_HIGH          = 11'h490;
  localparam logic [10:0] REG_SRC_ADDR_HIGH           = 11'h494;
  localparam logic [10:0] REG_SG_ADDR_HIGH            = 11'h4BC;
  localparam logic [10:0] REG_UNMAPPED_A              = 11'h0F0;
  localparam logic [10:0] REG_UNMAPPED_B              = 11'h600;

  // ---------------- expected values (SGDMA-SFR-v1.0) ----------------
  localparam logic [31:0] EXP_VERSION                 = 32'h0004_0565;
  localparam logic [31:0] EXP_IDENTIFICATION          = 32'h444D_4143;  // "DMAC"
  // sgdma_top passes ID = 0 (wrapper parameter default) to axi_dmac.
  localparam logic [31:0] EXP_PERIPHERAL_ID           = 32'h0000_0000;
  localparam logic [31:0] EXP_INTERFACE_DESCRIPTION_1 = 32'h3807_0303;  // measured 2026-10-01
  // AXI_AXCACHE = 4'b0000 (Device Non-bufferable), AXI_AXPROT = 3'b000.
  // Explicitly specified in sgdma_top as of 2026-10-06 (team decision); before
  // that they relied on axi_dmac's own defaults and measured the same value.
  // NOTE: axi_dmac_regmap declares a LOCAL default of 4'b0011 - do NOT compute
  // the expected value from that file.  Two independent reviews did exactly
  // that, both got 0x30, and both were wrong.
  localparam logic [31:0] EXP_INTERFACE_DESCRIPTION_2 = 32'h0000_0000;
  localparam logic [31:0] EXP_FLAGS_RESET             = 32'h0000_0002;  // LAST defaults to 1

  // ---------------- clock / reset ----------------
  logic clk    = 1'b0;
  logic resetn = 1'b0;
  always #5 clk = ~clk;   // 100 MHz

  // ---------------- AXI4-Lite (TB = master) ----------------
  logic        s_axi_awvalid = 1'b0;
  logic        s_axi_awready;
  logic [10:0] s_axi_awaddr  = '0;
  logic [2:0]  s_axi_awprot  = '0;
  logic        s_axi_wvalid  = 1'b0;
  logic        s_axi_wready;
  logic [31:0] s_axi_wdata   = '0;
  logic [3:0]  s_axi_wstrb   = '0;
  logic        s_axi_bvalid;
  logic        s_axi_bready  = 1'b0;
  logic [1:0]  s_axi_bresp;
  logic        s_axi_arvalid = 1'b0;
  logic        s_axi_arready;
  logic [10:0] s_axi_araddr  = '0;
  logic [2:0]  s_axi_arprot  = '0;
  logic        s_axi_rvalid;
  logic        s_axi_rready  = 1'b0;
  logic [1:0]  s_axi_rresp;
  logic [31:0] s_axi_rdata;

  logic        irq;

  // ---------------- SRC read master ----------------
  logic          m_src_axi_arvalid, m_src_axi_arready;
  logic [AW-1:0] m_src_axi_araddr;
  logic [7:0]    m_src_axi_arlen;
  logic [2:0]    m_src_axi_arsize, m_src_axi_arprot;
  logic [1:0]    m_src_axi_arburst;
  logic [3:0]    m_src_axi_arcache;
  logic          m_src_axi_rvalid, m_src_axi_rready, m_src_axi_rlast;
  logic [DW-1:0] m_src_axi_rdata;
  logic [1:0]    m_src_axi_rresp;
  // AXI ID / LOCK : outputs observed only, inputs tied off (no interconnect here)
  logic [IDW-1:0] m_src_axi_arid;
  logic [0:0]     m_src_axi_arlock;
  logic [IDW-1:0] m_src_axi_rid = '0;

  // ---------------- DEST write master ----------------
  logic            m_dest_axi_awvalid, m_dest_axi_awready;
  logic [AW-1:0]   m_dest_axi_awaddr;
  logic [7:0]      m_dest_axi_awlen;
  logic [2:0]      m_dest_axi_awsize, m_dest_axi_awprot;
  logic [1:0]      m_dest_axi_awburst;
  logic [3:0]      m_dest_axi_awcache;
  logic            m_dest_axi_wvalid, m_dest_axi_wready, m_dest_axi_wlast;
  logic [DW-1:0]   m_dest_axi_wdata;
  logic [DW/8-1:0] m_dest_axi_wstrb;
  logic            m_dest_axi_bvalid, m_dest_axi_bready;
  logic [1:0]      m_dest_axi_bresp;
  logic [IDW-1:0]  m_dest_axi_awid;
  logic [0:0]      m_dest_axi_awlock;
  logic [IDW-1:0]  m_dest_axi_bid = '0;

  // ---------------- SG read master (64-bit fixed) ----------------
  logic          m_sg_axi_arvalid, m_sg_axi_arready;
  logic [AW-1:0] m_sg_axi_araddr;
  logic [7:0]    m_sg_axi_arlen;
  logic [2:0]    m_sg_axi_arsize, m_sg_axi_arprot;
  logic [1:0]    m_sg_axi_arburst;
  logic [3:0]    m_sg_axi_arcache;
  logic          m_sg_axi_rvalid, m_sg_axi_rready, m_sg_axi_rlast;
  logic [63:0]   m_sg_axi_rdata;
  logic [1:0]    m_sg_axi_rresp;
  logic [IDW-1:0] m_sg_axi_arid;
  logic [0:0]     m_sg_axi_arlock;
  logic [IDW-1:0] m_sg_axi_rid = '0;

  // ---------------- DUT ----------------
  sgdma_top #(
    .ADDR_WIDTH   (AW),
    .DATA_WIDTH   (DW),
    .AXI_ID_WIDTH (IDW)
  ) dut (.*);   // TB signal names == DUT port names

  // ---------------- memory models (shared memory) ----------------
  axi_rd_slave #(.AW(AW), .DW(DW), .NAME("SRC")) u_src_mem (
    .clk     (clk),               .resetn  (resetn),
    .arvalid (m_src_axi_arvalid), .arready (m_src_axi_arready),
    .araddr  (m_src_axi_araddr),  .arlen   (m_src_axi_arlen),
    .arsize  (m_src_axi_arsize),  .arburst (m_src_axi_arburst),
    .rvalid  (m_src_axi_rvalid),  .rready  (m_src_axi_rready),
    .rdata   (m_src_axi_rdata),   .rresp   (m_src_axi_rresp),
    .rlast   (m_src_axi_rlast));

  axi_rd_slave #(.AW(AW), .DW(64), .NAME("SG")) u_sg_mem (
    .clk     (clk),               .resetn  (resetn),
    .arvalid (m_sg_axi_arvalid),  .arready (m_sg_axi_arready),
    .araddr  (m_sg_axi_araddr),   .arlen   (m_sg_axi_arlen),
    .arsize  (m_sg_axi_arsize),   .arburst (m_sg_axi_arburst),
    .rvalid  (m_sg_axi_rvalid),   .rready  (m_sg_axi_rready),
    .rdata   (m_sg_axi_rdata),    .rresp   (m_sg_axi_rresp),
    .rlast   (m_sg_axi_rlast));

  axi_wr_slave #(.AW(AW), .DW(DW), .NAME("DST")) u_dst_mem (
    .clk     (clk),                .resetn  (resetn),
    .awvalid (m_dest_axi_awvalid), .awready (m_dest_axi_awready),
    .awaddr  (m_dest_axi_awaddr),  .awlen   (m_dest_axi_awlen),
    .awsize  (m_dest_axi_awsize),  .awburst (m_dest_axi_awburst),
    .wvalid  (m_dest_axi_wvalid),  .wready  (m_dest_axi_wready),
    .wdata   (m_dest_axi_wdata),   .wstrb   (m_dest_axi_wstrb),
    .wlast   (m_dest_axi_wlast),
    .bvalid  (m_dest_axi_bvalid),  .bready  (m_dest_axi_bready),
    .bresp   (m_dest_axi_bresp));

  // ==========================================================================
  // Scoreboard
  // ==========================================================================
  string cur_tc   = "";
  string cur_desc = "";
  int    cur_pass = 0;
  int    cur_fail = 0;

  string tc_names [$];
  string tc_descs [$];
  int    tc_passes[$];
  int    tc_fails [$];
  bit    tc_skips [$];

  int    tot_pass = 0;
  int    tot_fail = 0;

  // cleared only when the bus itself looks dead (VERSION / IDENTIFICATION)
  bit    bus_ok   = 1'b1;

  // xsim does not left-justify %-Ns for `string`, so pad explicitly
  function automatic string pad(input string s, input int n);
    string r = s;
    while (r.len() < n) r = {r, " "};
    return r;
  endfunction

  task automatic tc_begin(input string name, input string desc);
    cur_tc   = name;
    cur_desc = desc;
    cur_pass = 0;
    cur_fail = 0;
    $display("\n[%s] %s", name, desc);
  endtask

  task automatic tc_end();
    tc_names .push_back(cur_tc);
    tc_descs .push_back(cur_desc);
    tc_passes.push_back(cur_pass);
    tc_fails .push_back(cur_fail);
    tc_skips .push_back(1'b0);
    tot_pass += cur_pass;
    tot_fail += cur_fail;
    cur_tc = "";
  endtask

  task automatic tc_skip(input string name, input string desc, input string why);
    tc_names .push_back(name);
    tc_descs .push_back(desc);
    tc_passes.push_back(0);
    tc_fails .push_back(0);
    tc_skips .push_back(1'b1);
    $display("\n[%s] %s  --  SKIPPED (%s)", name, desc, why);
  endtask

  // value comparison
  task automatic check_eq(input string name,
                          input logic [31:0] got,
                          input logic [31:0] exp);
    if (got === exp) begin
      cur_pass++;
      $display("    [ ok ] %s 0x%08h", pad(name, 36), got);
    end else begin
      cur_fail++;
      $display("    [FAIL] %s exp=0x%08h got=0x%08h", pad(name, 36), exp, got);
    end
  endtask

  // boolean condition
  task automatic check_cond(input string name, input bit cond, input string detail = "");
    if (cond) begin
      cur_pass++;
      $display("    [ ok ] %s", name);
    end else begin
      cur_fail++;
      $display("    [FAIL] %s %s", name, detail);
    end
  endtask

  // ==========================================================================
  // AXI4-Lite master tasks
  // ==========================================================================
  task automatic axil_write(input logic [10:0] addr, input logic [31:0] data);
    bit aw_done = 0;
    bit w_done  = 0;
    @(posedge clk);
    s_axi_awaddr  <= addr;
    s_axi_awvalid <= 1'b1;
    s_axi_wdata   <= data;
    s_axi_wstrb   <= 4'hF;
    s_axi_wvalid  <= 1'b1;
    while (!(aw_done && w_done)) begin
      @(posedge clk);
      if (s_axi_awvalid && s_axi_awready) begin aw_done = 1; s_axi_awvalid <= 1'b0; end
      if (s_axi_wvalid  && s_axi_wready)  begin w_done  = 1; s_axi_wvalid  <= 1'b0; end
    end
    s_axi_bready <= 1'b1;
    do @(posedge clk); while (!(s_axi_bvalid && s_axi_bready));
    s_axi_bready <= 1'b0;
    if (s_axi_bresp !== 2'b00) begin
      cur_fail++;
      $display("    [FAIL] AXI-Lite write resp : addr=0x%03h bresp=%0d", addr, s_axi_bresp);
    end
  endtask

  task automatic axil_read(input logic [10:0] addr, output logic [31:0] data);
    @(posedge clk);
    s_axi_araddr  <= addr;
    s_axi_arvalid <= 1'b1;
    do @(posedge clk); while (!(s_axi_arvalid && s_axi_arready));
    s_axi_arvalid <= 1'b0;
    s_axi_rready  <= 1'b1;
    do @(posedge clk); while (!(s_axi_rvalid && s_axi_rready));
    data = s_axi_rdata;
    s_axi_rready <= 1'b0;
  endtask

  // read a register and compare in one step
  task automatic check_reg(input string name,
                           input logic [10:0] addr,
                           input logic [31:0] exp);
    logic [31:0] rd;
    axil_read(addr, rd);
    check_eq(name, rd, exp);
  endtask

  // ==========================================================================
  // Descriptor / memory helpers
  // ==========================================================================
  // Descriptor layout (dmac_sg.v : 6 x 64-bit beats = 48 bytes)
  //   +0x00 : [63:32] id           [1:0] flags (bit0: last, bit1: irq on done)
  //   +0x08 : dest_addr
  //   +0x10 : src_addr
  //   +0x18 : next_desc_addr
  //   +0x20 : [63:32] x_length     [31:0] y_length
  //   +0x28 : [63:32] dest_stride  [31:0] src_stride
  task automatic write_desc(bit [31:0] a, bit [1:0] flags, bit [31:0] id,
                            bit [31:0] dst, bit [31:0] src, bit [31:0] next,
                            int len_bytes);
    mem_write64(a + 32'h00, {id, 30'd0, flags});
    mem_write64(a + 32'h08, {32'd0, dst});
    mem_write64(a + 32'h10, {32'd0, src});
    mem_write64(a + 32'h18, {32'd0, next});
    mem_write64(a + 32'h20, {32'(len_bytes - 1), 32'd0});  // x_len = bytes-1
    mem_write64(a + 32'h28, 64'd0);                        // strides (2D only)
    $display("    desc @0x%08h : id=0x%0h flags=%b src=0x%08h dst=0x%08h len=%0d next=0x%08h",
             a, id, flags, src, dst, len_bytes, next);
  endtask

  task automatic fill_pattern(bit [31:0] addr, int len, bit [7:0] tag);
    for (int i = 0; i < len; i++) mem_write8(addr + i, 8'(tag + i));
  endtask

  task automatic check_copy(bit [31:0] src, bit [31:0] dst, int len, string tag);
    int errs = 0;
    for (int i = 0; i < len; i++) begin
      bit [7:0] exp_b;
      bit [7:0] got_b;
      exp_b = mem_read8(src + i);
      got_b = mem_read8(dst + i);
      if (!mem_written(dst + i) || got_b !== exp_b) begin
        if (errs < 4)
          $display("           mismatch dst[0x%08h]=0x%02h exp=0x%02h%s", dst + i, got_b, exp_b,
                   mem_written(dst + i) ? "" : " (never written)");
        errs++;
      end
    end
    check_cond($sformatf("%s : %0d bytes 0x%08h -> 0x%08h", tag, len, src, dst),
               errs == 0, $sformatf("(%0d mismatches)", errs));
  endtask

  task automatic check_untouched(bit [31:0] a, int len, string tag);
    int errs = 0;
    for (int i = 0; i < len; i++) if (mem_written(a + i)) errs++;
    check_cond($sformatf("%s : no overrun past 0x%08h", tag, a),
               errs == 0, $sformatf("(%0d bytes written)", errs));
  endtask

  // ==========================================================================
  // DMA control helpers
  // ==========================================================================
  task automatic start_sg(bit [31:0] first_desc);
    axil_write(REG_SG_ADDRESS, first_desc);
    axil_write(REG_TRANSFER_SUBMIT, 32'h1);
  endtask

  // waits for irq; a timeout is recorded as a failed check of the current TC
  task automatic wait_irq(input string tag, output bit timed_out,
                          input int timeout_cycles = 50000);
    bit t = 0;
    fork : f_wait
      wait (irq === 1'b1);
      begin repeat (timeout_cycles) @(posedge clk); t = 1; end
    join_any
    disable f_wait;
    timed_out = t;
    check_cond($sformatf("%s : irq asserted", tag), !t,
               $sformatf("(timeout after %0d cycles)", timeout_cycles));
  endtask

  // read IRQ_PENDING and write it back (W1C)
  task automatic clear_irq();
    logic [31:0] rd;
    axil_read(REG_IRQ_PENDING, rd);
    axil_write(REG_IRQ_PENDING, rd);
  endtask

  // ==========================================================================
  // SAN-001 : Register identity
  // ==========================================================================
  //   Only VERSION and IDENTIFICATION gate the rest of the run.  The other
  //   three are build-configuration registers: a mismatch there means the
  //   expected value is wrong, not that the bus is dead, so the run goes on.
  task automatic san_001();
    logic [31:0] rd;
    tc_begin("SAN-001", "Register identity");

    axil_read(REG_VERSION, rd);
    check_eq("VERSION", rd, EXP_VERSION);
    if (rd !== EXP_VERSION) bus_ok = 1'b0;

    axil_read(REG_IDENTIFICATION, rd);
    check_eq("IDENTIFICATION", rd, EXP_IDENTIFICATION);
    if (rd !== EXP_IDENTIFICATION) bus_ok = 1'b0;

    check_reg("PERIPHERAL_ID",           REG_PERIPHERAL_ID,           EXP_PERIPHERAL_ID);
    check_reg("INTERFACE_DESCRIPTION_1", REG_INTERFACE_DESCRIPTION_1, EXP_INTERFACE_DESCRIPTION_1);
    check_reg("INTERFACE_DESCRIPTION_2", REG_INTERFACE_DESCRIPTION_2, EXP_INTERFACE_DESCRIPTION_2);

    if (cur_fail != 0 && bus_ok) begin
      $display("    note : build-configuration register mismatch - confirm the");
      $display("           expected value before treating it as an RTL defect.");
    end
    tc_end();
  endtask

  // ==========================================================================
  // SAN-002 : Scratch R/W
  //   SCRATCH is not covered by SAN-003, so running this first is safe.
  // ==========================================================================
  task automatic san_002();
    tc_begin("SAN-002", "Scratch R/W");
    axil_write(REG_SCRATCH, 32'hA5A5_5A5A);
    check_reg("SCRATCH = 0xA5A55A5A", REG_SCRATCH, 32'hA5A5_5A5A);
    axil_write(REG_SCRATCH, 32'h5A5A_A5A5);   // inverted - catches stuck-at bits
    check_reg("SCRATCH = 0x5A5AA5A5", REG_SCRATCH, 32'h5A5A_A5A5);
    axil_write(REG_SCRATCH, 32'h0000_0000);
    check_reg("SCRATCH = 0x00000000", REG_SCRATCH, 32'h0000_0000);
    tc_end();
  endtask

  // ==========================================================================
  // SAN-003 : Reset defaults
  //   Must run before any register in this list is written.
  //
  //   Covers 10 of the ~30 registers listed in SFR map appendix A.  The rest
  //   are intentionally left to the verification team (SOR RST-007).  Do not
  //   read this TC as proof that every reset value has been checked.
  // ==========================================================================
  task automatic san_003();
    tc_begin("SAN-003", "Reset defaults");
    check_reg("CONTROL",       REG_CONTROL,       32'h0000_0000);
    check_reg("IRQ_MASK",      REG_IRQ_MASK,      32'h0000_0003);
    check_reg("IRQ_PENDING",   REG_IRQ_PENDING,   32'h0000_0000);
    check_reg("IRQ_SOURCE",    REG_IRQ_SOURCE,    32'h0000_0000);
    check_reg("FLAGS",         REG_FLAGS,         EXP_FLAGS_RESET);  // 0x2, not 0x0
    check_reg("TRANSFER_DONE", REG_TRANSFER_DONE, 32'h0000_0000);
    check_reg("TRANSFER_ID",   REG_TRANSFER_ID,   32'h0000_0000);
    check_reg("DEST_ADDRESS",  REG_DEST_ADDRESS,  32'h0000_0000);
    check_reg("SRC_ADDRESS",   REG_SRC_ADDRESS,   32'h0000_0000);
    check_reg("SG_ADDRESS",    REG_SG_ADDRESS,    32'h0000_0000);
    tc_end();
  endtask

  // ==========================================================================
  // SAN-007 : Parameter-masked bits
  //   Bits deliberately disabled by build parameters must stay disabled.
  //   Restores every register it touches before returning.
  //
  //   The purpose is NOT bug detection but misjudgement prevention: without a
  //   documented expected value, a naive "RW register write / read-back" test
  //   reports this correct behaviour as a defect.
  //
  //   0x450 (PARTIAL_TRANSFER_ID) is deliberately NOT read here - a read pops
  //   the internal FIFO.  See SFR map 4.5.5.
  // ==========================================================================
  task automatic san_007();
    logic [31:0] ra, rb;

    tc_begin("SAN-007", "Parameter-masked bits");

    // FRAMELOCK=0 -> CONTROL[3] write-masked
    axil_write(REG_CONTROL, 32'hFFFF_FFFF);
    check_reg("CONTROL[3] masked (FRAMELOCK=0)", REG_CONTROL, 32'h0000_0007);

    // DMA_CYCLIC=0 -> FLAGS[0] write-masked
    axil_write(REG_FLAGS, 32'hFFFF_FFFF);
    check_reg("FLAGS[0] masked (DMA_CYCLIC=0)", REG_FLAGS, 32'h0000_0006);

    // 64-bit datapath -> address registers are 8-byte aligned
    axil_write(REG_DEST_ADDRESS, 32'hFFFF_FFFF);
    check_reg("DEST_ADDRESS 8B aligned", REG_DEST_ADDRESS, 32'hFFFF_FFF8);
    axil_write(REG_SRC_ADDRESS, 32'hFFFF_FFFF);
    check_reg("SRC_ADDRESS 8B aligned",  REG_SRC_ADDRESS,  32'hFFFF_FFF8);
    axil_write(REG_SG_ADDRESS, 32'hFFFF_FFFF);
    check_reg("SG_ADDRESS 8B aligned",   REG_SG_ADDRESS,   32'hFFFF_FFF8);

    // ADDR_WIDTH=32 -> HAS_ADDR_HIGH=0, high registers hardwired to 0
    axil_write(REG_DEST_ADDR_HIGH, 32'hFFFF_FFFF);
    check_reg("DEST_ADDRESS_HIGH tied 0", REG_DEST_ADDR_HIGH, 32'h0000_0000);
    axil_write(REG_SRC_ADDR_HIGH, 32'hFFFF_FFFF);
    check_reg("SRC_ADDRESS_HIGH tied 0",  REG_SRC_ADDR_HIGH,  32'h0000_0000);
    axil_write(REG_SG_ADDR_HIGH, 32'hFFFF_FFFF);
    check_reg("SG_ADDRESS_HIGH tied 0",   REG_SG_ADDR_HIGH,   32'h0000_0000);

    // DMA_2D_TRANSFER=0 / FRAMELOCK=0
    check_reg("Y_LENGTH tied 0 (2D=0)",  REG_Y_LENGTH,         32'h0000_0000);
    check_reg("FRAMELOCK_CONFIG tied 0", REG_FRAMELOCK_CONFIG, 32'h0000_0000);

    // unmapped addresses fall through to the default branch
    axil_read(REG_UNMAPPED_A, ra);
    axil_read(REG_UNMAPPED_B, rb);
    check_cond("unmapped reads return 0", (ra === 32'h0) && (rb === 32'h0),
               $sformatf("(0x%03h=0x%08h 0x%03h=0x%08h)",
                         REG_UNMAPPED_A, ra, REG_UNMAPPED_B, rb));

    // --- restore ---------------------------------------------------------
    // CONTROL must go back to 0, otherwise SAN-004 starts with ENABLE set.
    axil_write(REG_CONTROL,      32'h0000_0000);
    axil_write(REG_FLAGS,        EXP_FLAGS_RESET);
    axil_write(REG_DEST_ADDRESS, 32'h0000_0000);
    axil_write(REG_SRC_ADDRESS,  32'h0000_0000);
    axil_write(REG_SG_ADDRESS,   32'h0000_0000);
    $display("    restored CONTROL / FLAGS / address registers");

    tc_end();
  endtask

  // ==========================================================================
  // SAN-004 : Single descriptor copy
  // ==========================================================================
  task automatic san_004();
    bit [31:0]   src  = 32'h0001_0000;
    bit [31:0]   dst  = 32'h0002_0000;
    bit [31:0]   desc = 32'h0000_1000;
    int          len  = 256;
    bit          t;
    logic [31:0] rd;

    tc_begin("SAN-004", $sformatf("Single descriptor copy (%0d B)", len));
    fill_pattern(src, len, 8'h10);
    write_desc(desc, 2'b11, 32'hA0, dst, src, 32'h0, len);   // last + irq

    start_sg(desc);
    wait_irq("SAN-004", t);
    clear_irq();

    check_copy(src, dst, len, "data");
    check_untouched(dst + len, 16, "tail");

    axil_read(REG_TRANSFER_DONE, rd);
    check_cond("TRANSFER_DONE bit set", rd[3:0] != 4'h0,
               $sformatf("(TRANSFER_DONE=0x%08h)", rd));
    tc_end();
  endtask

  // ==========================================================================
  // SAN-005 : 3-descriptor gather
  // ==========================================================================
  task automatic san_005();
    bit [31:0]   src [3] = '{32'h0001_1000, 32'h0001_3000, 32'h0001_5000};
    int          len [3] = '{128, 256, 64};
    bit [31:0]   desc[3] = '{32'h0000_1100, 32'h0000_1140, 32'h0000_1180};
    bit [31:0]   dst_base = 32'h0002_1000;
    bit [31:0]   dst[3];
    bit [31:0]   total;
    bit          t;
    logic [31:0] rd;

    tc_begin("SAN-005", "3-descriptor chain, gather");
    dst[0] = dst_base;
    dst[1] = dst[0] + len[0];
    dst[2] = dst[1] + len[1];
    total  = len[0] + len[1] + len[2];

    fill_pattern(src[0], len[0], 8'h40);
    fill_pattern(src[1], len[1], 8'h80);
    fill_pattern(src[2], len[2], 8'hC0);

    write_desc(desc[0], 2'b00, 32'hB0, dst[0], src[0], desc[1], len[0]);
    write_desc(desc[1], 2'b00, 32'hB1, dst[1], src[1], desc[2], len[1]);
    write_desc(desc[2], 2'b11, 32'hB2, dst[2], src[2], 32'h0,   len[2]);  // last + irq

    start_sg(desc[0]);
    wait_irq("SAN-005", t);
    clear_irq();

    for (int i = 0; i < 3; i++)
      check_copy(src[i], dst[i], len[i], $sformatf("seg%0d", i));
    check_untouched(dst_base + total, 16, "tail");

    // DESCRIPTOR_ID after chain completion.
    //   dmac_sg pops its completion FIFO on each destination response; once
    //   empty, util_axis_fifo holds the last popped value.  The register
    //   therefore keeps the id of the LAST COMPLETED descriptor (0xB2), not a
    //   stale value from an earlier TC - SAN-004 used 0xA0 and it does not
    //   appear here.  This is an implementation characteristic, NOT a
    //   documented contract (SFR map 4.6.2).  A driver must not rely on it;
    //   use the EOT interrupt or TRANSFER_DONE to detect completion.
    axil_read(REG_DESCRIPTOR_ID, rd);
    check_eq("DESCRIPTOR_ID = last of chain", rd, 32'h0000_00B2);

    tc_end();
  endtask

  // ==========================================================================
  // SAN-006 : IRQ & status
  //   A W1C write to IRQ_PENDING clears IRQ_SOURCE - see SFR map 4.2.2.
  //   IRQ_MASK = 0x1 keeps SOT masked, so IRQ_SOURCE[0] stays set after the
  //   clear while IRQ_PENDING reads back as 0.
  // ==========================================================================
  task automatic san_006();
    bit [31:0]   src  = 32'h0001_8000;
    bit [31:0]   dst  = 32'h0002_8000;
    bit [31:0]   desc = 32'h0000_1200;
    int          len  = 64;
    bit          t;
    logic [31:0] rd, pend;

    tc_begin("SAN-006", "IRQ & status");
    fill_pattern(src, len, 8'h20);
    write_desc(desc, 2'b11, 32'hC5, dst, src, 32'h0, len);

    axil_read(REG_IRQ_MASK, rd);
    check_eq("IRQ_MASK = 0x1 (EOT unmasked)", rd, 32'h0000_0001);

    start_sg(desc);
    wait_irq("SAN-006", t);                       // check : irq asserted

    axil_read(REG_IRQ_PENDING, pend);
    check_cond("IRQ_PENDING[1] set", pend[1] === 1'b1,
               $sformatf("(IRQ_PENDING=0x%08h)", pend));

    axil_write(REG_IRQ_PENDING, pend);            // W1C

    check_reg("IRQ_PENDING cleared", REG_IRQ_PENDING, 32'h0000_0000);
    check_reg("IRQ_SOURCE[0] survives W1C", REG_IRQ_SOURCE, 32'h0000_0001);

    repeat (4) @(posedge clk);
    check_cond("irq de-asserted after W1C", irq === 1'b0, $sformatf("(irq=%b)", irq));

    axil_read(REG_DESCRIPTOR_ID, rd);
    check_eq("DESCRIPTOR_ID", rd, 32'h0000_00C5);
    tc_end();
  endtask

  // ==========================================================================
  // Report
  // ==========================================================================
  task automatic report();
    int n_pass = 0, n_fail = 0, n_skip = 0;
    $display("\n==========================================================");
    $display("  SANITY SUMMARY");
    $display("==========================================================");
    for (int i = 0; i < tc_names.size(); i++) begin
      if (tc_skips[i]) begin
        $display("  %s %s SKIP", pad(tc_names[i], 8), pad(tc_descs[i], 32));
        n_skip++;
      end else if (tc_fails[i] == 0) begin
        $display("  %s %s PASS  (%0d/%0d)", pad(tc_names[i], 8), pad(tc_descs[i], 32),
                 tc_passes[i], tc_passes[i] + tc_fails[i]);
        n_pass++;
      end else begin
        $display("  %s %s FAIL  (%0d/%0d)", pad(tc_names[i], 8), pad(tc_descs[i], 32),
                 tc_passes[i], tc_passes[i] + tc_fails[i]);
        n_fail++;
      end
    end
    $display("----------------------------------------------------------");
    $display("  SANITY: %0d PASS / %0d FAIL / %0d SKIP     (%0d/%0d checks)",
             n_pass, n_fail, n_skip, tot_pass, tot_pass + tot_fail);
    $display("==========================================================");

    if (n_fail != 0 || n_skip != 0) begin
      $display("*** SANITY FAILED ***");
      $fatal(1, "sanity gate not passed");
    end else begin
      $display("*** SANITY PASSED ***");
      $finish;
    end
  endtask

  // ==========================================================================
  // Main
  // ==========================================================================
  initial begin
    $display("==========================================================");
    $display("  SG DMA sanity test   (SGDMA-SANITY-v1.0)");
    $display("==========================================================");

    repeat (10) @(posedge clk);
    resetn <= 1'b1;
    repeat (10) @(posedge clk);

    // ---- register layer -------------------------------------------------
    san_001();

    // Abort only if VERSION / IDENTIFICATION are wrong: the bus or the regmap
    // decode is broken and everything after this would be noise.
    if (!bus_ok) begin
      tc_skip("SAN-002", "Scratch R/W",            "SAN-001 failed");
      tc_skip("SAN-003", "Reset defaults",         "SAN-001 failed");
      tc_skip("SAN-007", "Parameter-masked bits",  "SAN-001 failed");
      tc_skip("SAN-004", "Single descriptor copy", "SAN-001 failed");
      tc_skip("SAN-005", "3-descriptor gather",    "SAN-001 failed");
      tc_skip("SAN-006", "IRQ & status",           "SAN-001 failed");
      report();
    end

    san_002();
    san_003();
    san_007();

    // ---- transfer layer -------------------------------------------------
    // IRQ_MASK = 0x1 : SOT masked, EOT (TRANSFER_COMPLETED) enabled
    axil_write(REG_IRQ_MASK, 32'h1);
    axil_write(REG_CONTROL,  32'h5);   // ENABLE | HWDESC

    san_004();
    san_005();
    san_006();

    report();
  end

  // global watchdog - a hung handshake must not hang the regression
  initial begin
    #2_000_000;
    $display("\n[FAIL] GLOBAL TIMEOUT - simulation did not finish");
    $fatal(1, "global watchdog");
  end

endmodule