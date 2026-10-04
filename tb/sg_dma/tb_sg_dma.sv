// ============================================================================
// tb_sg_dma.sv
//   Bring-up testbench for sg_dma_top (SG, MM->MM, single clock)
//
//   TEST 1 : single descriptor, 256B copy
//   TEST 2 : 3-descriptor chain, gather (scattered src -> contiguous dst)
//
//   Checks : IDENTIFICATION register, IRQ, data compare, dst overrun
//
//   NOTE: this is the first-pass testbench.  It answers "does it work at all",
//   not "is it still working after I changed the RTL".  Step 10 restructures
//   it into a sanity suite with per-TC scoring.
// ============================================================================
`timescale 1ns/1ps

module tb_sg_dma;
  import tb_mem_pkg::*;

  localparam int AW = 32;
  localparam int DW = 64;

  // ---------------- register map (byte address) ----------------
  localparam logic [10:0] REG_VERSION         = 11'h000;
  localparam logic [10:0] REG_IDENTIFICATION  = 11'h00C;
  localparam logic [10:0] REG_IRQ_MASK        = 11'h080;
  localparam logic [10:0] REG_IRQ_PENDING     = 11'h084;
  localparam logic [10:0] REG_CONTROL         = 11'h400;
  localparam logic [10:0] REG_TRANSFER_SUBMIT = 11'h408;
  localparam logic [10:0] REG_TRANSFER_DONE   = 11'h428;
  localparam logic [10:0] REG_DESCRIPTOR_ID   = 11'h454;
  localparam logic [10:0] REG_SG_ADDRESS      = 11'h47C;

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

  // ---------------- DUT ----------------
  sg_dma_top #(
    .ADDR_WIDTH (AW),
    .DATA_WIDTH (DW)
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

  int errors = 0;

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
    if (s_axi_bresp != 2'b00) begin
      $error("AXI-Lite write resp error: addr=0x%03h bresp=%0d", addr, s_axi_bresp);
      errors++;
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

  // ==========================================================================
  // Descriptor / memory helpers
  // ==========================================================================
  // Descriptor layout (from dmac_sg.v : 6 x 64-bit beats = 48 bytes)
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
    mem_write64(a + 32'h28, 64'd0);                         // strides (2D only)
    $display("  DESC @0x%08h : id=0x%0h flags=%b src=0x%08h dst=0x%08h len=%0d next=0x%08h",
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
        if (errs < 8)
          $display("  MISMATCH %s : dst[0x%08h]=0x%02h exp=0x%02h%s", tag, dst + i, got_b, exp_b,
                   mem_written(dst + i) ? "" : " (never written)");
        errs++;
      end
    end
    if (errs == 0) $display("[PASS] %s : %0d bytes 0x%08h -> 0x%08h", tag, len, src, dst);
    else           $display("[FAIL] %s : %0d mismatches", tag, errs);
    errors += errs;
  endtask

  task automatic check_untouched(bit [31:0] a, int len, string tag);
    int errs = 0;
    for (int i = 0; i < len; i++) if (mem_written(a + i)) errs++;
    if (errs == 0) $display("[PASS] %s : no overrun after 0x%08h", tag, a);
    else           $display("[FAIL] %s : %0d bytes written past 0x%08h", tag, errs, a);
    errors += errs;
  endtask

  // ==========================================================================
  // DMA control helpers
  // ==========================================================================
  task automatic start_sg(bit [31:0] first_desc);
    axil_write(REG_SG_ADDRESS, first_desc);
    axil_write(REG_TRANSFER_SUBMIT, 32'h1);
    $display("[%0t] submitted SG transfer, first desc = 0x%08h", $time, first_desc);
  endtask

  task automatic wait_done(string tag, int timeout_cycles = 50000);
    logic [31:0] rd;
    bit timeout = 0;
    fork : f_wait
      wait (irq === 1'b1);
      begin repeat (timeout_cycles) @(posedge clk); timeout = 1; end
    join_any
    disable f_wait;

    if (timeout) begin
      $display("[FAIL] %s : TIMEOUT, irq not asserted within %0d cycles", tag, timeout_cycles);
      errors++;
    end else begin
      $display("[%0t] %s : irq asserted", $time, tag);
    end

    axil_read(REG_IRQ_PENDING, rd);
    $display("  IRQ_PENDING   = 0x%08h", rd);
    if (!timeout && rd[1] !== 1'b1) begin
      $display("[FAIL] %s : TRANSFER_COMPLETED irq bit not set", tag);
      errors++;
    end
    axil_write(REG_IRQ_PENDING, rd);          // W1C clear
    axil_read(REG_TRANSFER_DONE, rd);
    $display("  TRANSFER_DONE = 0x%08h", rd);
    axil_read(REG_DESCRIPTOR_ID, rd);
    $display("  DESCRIPTOR_ID = 0x%08h", rd);
  endtask

  // ==========================================================================
  // Tests
  // ==========================================================================
  task automatic test_single();
    bit [31:0] src  = 32'h0001_0000;
    bit [31:0] dst  = 32'h0002_0000;
    bit [31:0] desc = 32'h0000_1000;
    int        len  = 256;

    $display("\n===== TEST 1 : single descriptor (%0d bytes) =====", len);
    fill_pattern(src, len, 8'h10);
    write_desc(desc, 2'b11, 32'hA0, dst, src, 32'h0, len);   // last + irq
    start_sg(desc);
    wait_done("TEST1");
    check_copy(src, dst, len, "TEST1");
    check_untouched(dst + len, 16, "TEST1 tail");
  endtask

  task automatic test_gather();
    bit [31:0] src [3] = '{32'h0001_1000, 32'h0001_3000, 32'h0001_5000};
    int        len [3] = '{128, 256, 64};
    bit [31:0] desc[3] = '{32'h0000_1100, 32'h0000_1140, 32'h0000_1180};
    bit [31:0] dst_base = 32'h0002_1000;
    bit [31:0] dst[3];
    bit [31:0] total;

    $display("\n===== TEST 2 : 3-descriptor chain, gather =====");
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
    wait_done("TEST2");
    for (int i = 0; i < 3; i++)
      check_copy(src[i], dst[i], len[i], $sformatf("TEST2 seg%0d", i));
    check_untouched(dst_base + total, 16, "TEST2 tail");
  endtask

  // ==========================================================================
  // Main
  // ==========================================================================
  initial begin
    logic [31:0] rd;

    $display("==================================================");
    $display("  SG DMA bring-up testbench");
    $display("==================================================");

    repeat (10) @(posedge clk);
    resetn <= 1'b1;
    repeat (10) @(posedge clk);

    axil_read(REG_VERSION, rd);
    $display("VERSION        = 0x%08h", rd);
    axil_read(REG_IDENTIFICATION, rd);
    $display("IDENTIFICATION = 0x%08h", rd);
    if (rd !== 32'h444D_4143) begin
      $display("[FAIL] IDENTIFICATION mismatch (expected 0x444D4143 'DMAC')");
      errors++;
    end

    axil_write(REG_IRQ_MASK, 32'h1);   // mask TRANSFER_QUEUED, enable TRANSFER_COMPLETED
    axil_write(REG_CONTROL,  32'h5);   // ENABLE | HWDESC

    test_single();
    test_gather();

    $display("\n==================================================");
    if (errors == 0) $display("  TEST PASSED");
    else             $display("  TEST FAILED (%0d errors)", errors);
    $display("==================================================");
    $finish;
  end

  // global watchdog
  initial begin
    #2_000_000;
    $display("[FAIL] GLOBAL TIMEOUT");
    $finish;
  end

endmodule