// ============================================================================
// sg_dma_top.v
//   Scatter-Gather DMA wrapper around ADI axi_dmac (hdl_2026_r1)
//
//   Fixed configuration:
//     - SG enabled, MM -> MM (memcpy), single clock domain
//     - AXI4 protocol, no 2D / cyclic / framelock / autorun / ext sync
//
//   Exposed interfaces:
//     - s_axi_*      : AXI4-Lite slave  (register map, 11-bit address)
//     - m_src_axi_*  : AXI4 master, read-only  (source data)
//     - m_dest_axi_* : AXI4 master, write-only (destination data)
//     - m_sg_axi_*   : AXI4 master, read-only  (descriptor fetch, 64-bit fixed)
//     - irq
// ============================================================================
`timescale 1ns/1ps
`default_nettype none

module sg_dma_top #(
  parameter ID                  = 0,
  parameter ADDR_WIDTH          = 32,
  parameter DATA_WIDTH          = 64,
  parameter LENGTH_WIDTH        = 24,
  parameter MAX_BYTES_PER_BURST = 128,
  parameter FIFO_SIZE           = 8     // in bursts
) (
  input  wire                     clk,
  input  wire                     resetn,

  // --------------------------------------------------------------------------
  // AXI4-Lite slave : register map
  // --------------------------------------------------------------------------
  input  wire                     s_axi_awvalid,
  output wire                     s_axi_awready,
  input  wire [10:0]              s_axi_awaddr,
  input  wire [2:0]               s_axi_awprot,
  input  wire                     s_axi_wvalid,
  output wire                     s_axi_wready,
  input  wire [31:0]              s_axi_wdata,
  input  wire [3:0]               s_axi_wstrb,
  output wire                     s_axi_bvalid,
  input  wire                     s_axi_bready,
  output wire [1:0]               s_axi_bresp,
  input  wire                     s_axi_arvalid,
  output wire                     s_axi_arready,
  input  wire [10:0]              s_axi_araddr,
  input  wire [2:0]               s_axi_arprot,
  output wire                     s_axi_rvalid,
  input  wire                     s_axi_rready,
  output wire [1:0]               s_axi_rresp,
  output wire [31:0]              s_axi_rdata,

  output wire                     irq,

  // --------------------------------------------------------------------------
  // AXI4 master (read-only) : source data
  // --------------------------------------------------------------------------
  output wire                     m_src_axi_arvalid,
  input  wire                     m_src_axi_arready,
  output wire [ADDR_WIDTH-1:0]    m_src_axi_araddr,
  output wire [7:0]               m_src_axi_arlen,
  output wire [2:0]               m_src_axi_arsize,
  output wire [1:0]               m_src_axi_arburst,
  output wire [2:0]               m_src_axi_arprot,
  output wire [3:0]               m_src_axi_arcache,
  input  wire                     m_src_axi_rvalid,
  output wire                     m_src_axi_rready,
  input  wire [DATA_WIDTH-1:0]    m_src_axi_rdata,
  input  wire [1:0]               m_src_axi_rresp,
  input  wire                     m_src_axi_rlast,

  // --------------------------------------------------------------------------
  // AXI4 master (write-only) : destination data
  // --------------------------------------------------------------------------
  output wire                     m_dest_axi_awvalid,
  input  wire                     m_dest_axi_awready,
  output wire [ADDR_WIDTH-1:0]    m_dest_axi_awaddr,
  output wire [7:0]               m_dest_axi_awlen,
  output wire [2:0]               m_dest_axi_awsize,
  output wire [1:0]               m_dest_axi_awburst,
  output wire [2:0]               m_dest_axi_awprot,
  output wire [3:0]               m_dest_axi_awcache,
  output wire                     m_dest_axi_wvalid,
  input  wire                     m_dest_axi_wready,
  output wire [DATA_WIDTH-1:0]    m_dest_axi_wdata,
  output wire [DATA_WIDTH/8-1:0]  m_dest_axi_wstrb,
  output wire                     m_dest_axi_wlast,
  input  wire                     m_dest_axi_bvalid,
  output wire                     m_dest_axi_bready,
  input  wire [1:0]               m_dest_axi_bresp,

  // --------------------------------------------------------------------------
  // AXI4 master (read-only) : SG descriptor fetch (data width fixed to 64)
  // --------------------------------------------------------------------------
  output wire                     m_sg_axi_arvalid,
  input  wire                     m_sg_axi_arready,
  output wire [ADDR_WIDTH-1:0]    m_sg_axi_araddr,
  output wire [7:0]               m_sg_axi_arlen,
  output wire [2:0]               m_sg_axi_arsize,
  output wire [1:0]               m_sg_axi_arburst,
  output wire [2:0]               m_sg_axi_arprot,
  output wire [3:0]               m_sg_axi_arcache,
  input  wire                     m_sg_axi_rvalid,
  output wire                     m_sg_axi_rready,
  input  wire [63:0]              m_sg_axi_rdata,
  input  wire [1:0]               m_sg_axi_rresp,
  input  wire                     m_sg_axi_rlast
);

  localparam SG_DATA_WIDTH = 64;   // ADI: DMA_DATA_WIDTH_SG supports 64 only
  localparam NUM_FRAMES_W  = 3;    // MAX_NUM_FRAMES_WIDTH default (unused)

  axi_dmac #(
    .ID                      (ID),
    .DMA_DATA_WIDTH_SRC      (DATA_WIDTH),
    .DMA_DATA_WIDTH_DEST     (DATA_WIDTH),
    .DMA_DATA_WIDTH_SG       (SG_DATA_WIDTH),
    .DMA_LENGTH_WIDTH        (LENGTH_WIDTH),
    .DMA_2D_TRANSFER         (0),
    .DMA_SG_TRANSFER         (1),
    .ASYNC_CLK_REQ_SRC       (0),
    .ASYNC_CLK_SRC_DEST      (0),
    .ASYNC_CLK_DEST_REQ      (0),
    .ASYNC_CLK_REQ_SG        (0),
    .ASYNC_CLK_SRC_SG        (0),
    .ASYNC_CLK_DEST_SG       (0),
    .AXI_SLICE_DEST          (0),
    .AXI_SLICE_SRC           (0),
    .SYNC_TRANSFER_START     (0),
    .CYCLIC                  (0),   // default is 1 in axi_dmac -> override
    .DMA_AXI_PROTOCOL_DEST   (0),   // AXI4
    .DMA_AXI_PROTOCOL_SRC    (0),   // AXI4
    .DMA_AXI_PROTOCOL_SG     (0),   // AXI4
    .DMA_TYPE_DEST           (0),   // AXI-MM
    .DMA_TYPE_SRC            (0),   // AXI-MM (default is 2=FIFO -> override)
    .DMA_AXI_ADDR_WIDTH      (ADDR_WIDTH),
    .MAX_BYTES_PER_BURST     (MAX_BYTES_PER_BURST),
    .FIFO_SIZE               (FIFO_SIZE),
    .AXI_ID_WIDTH_SRC        (1),
    .AXI_ID_WIDTH_DEST       (1),
    .AXI_ID_WIDTH_SG         (1),
    .DISABLE_DEBUG_REGISTERS (0),
    .ENABLE_DIAGNOSTICS_IF   (0),
    .ALLOW_ASYM_MEM          (0),
    .CACHE_COHERENT          (0),
    .FRAMELOCK               (0),
    .MAX_NUM_FRAMES_WIDTH    (NUM_FRAMES_W),
    .USE_EXT_SYNC            (0),
    .AUTORUN                 (0)
  ) i_axi_dmac (
    // ---------------- AXI4-Lite slave ----------------
    .s_axi_aclk         (clk),
    .s_axi_aresetn      (resetn),
    .s_axi_awvalid      (s_axi_awvalid),
    .s_axi_awaddr       (s_axi_awaddr),
    .s_axi_awready      (s_axi_awready),
    .s_axi_awprot       (s_axi_awprot),
    .s_axi_wvalid       (s_axi_wvalid),
    .s_axi_wdata        (s_axi_wdata),
    .s_axi_wstrb        (s_axi_wstrb),
    .s_axi_wready       (s_axi_wready),
    .s_axi_bvalid       (s_axi_bvalid),
    .s_axi_bresp        (s_axi_bresp),
    .s_axi_bready       (s_axi_bready),
    .s_axi_arvalid      (s_axi_arvalid),
    .s_axi_araddr       (s_axi_araddr),
    .s_axi_arready      (s_axi_arready),
    .s_axi_arprot       (s_axi_arprot),
    .s_axi_rvalid       (s_axi_rvalid),
    .s_axi_rready       (s_axi_rready),
    .s_axi_rresp        (s_axi_rresp),
    .s_axi_rdata        (s_axi_rdata),

    .irq                (irq),
    .sync               (1'b0),

    // ---------------- DEST master (write used) ----------------
    .m_dest_axi_aclk    (clk),
    .m_dest_axi_aresetn (resetn),
    .m_dest_axi_awaddr  (m_dest_axi_awaddr),
    .m_dest_axi_awlen   (m_dest_axi_awlen),
    .m_dest_axi_awsize  (m_dest_axi_awsize),
    .m_dest_axi_awburst (m_dest_axi_awburst),
    .m_dest_axi_awprot  (m_dest_axi_awprot),
    .m_dest_axi_awcache (m_dest_axi_awcache),
    .m_dest_axi_awvalid (m_dest_axi_awvalid),
    .m_dest_axi_awready (m_dest_axi_awready),
    .m_dest_axi_awid    (),
    .m_dest_axi_awlock  (),
    .m_dest_axi_wdata   (m_dest_axi_wdata),
    .m_dest_axi_wstrb   (m_dest_axi_wstrb),
    .m_dest_axi_wready  (m_dest_axi_wready),
    .m_dest_axi_wvalid  (m_dest_axi_wvalid),
    .m_dest_axi_wlast   (m_dest_axi_wlast),
    .m_dest_axi_wid     (),
    .m_dest_axi_bvalid  (m_dest_axi_bvalid),
    .m_dest_axi_bresp   (m_dest_axi_bresp),
    .m_dest_axi_bready  (m_dest_axi_bready),
    .m_dest_axi_bid     (1'b0),
    // DEST read channel: unused
    .m_dest_axi_arvalid (),
    .m_dest_axi_araddr  (),
    .m_dest_axi_arlen   (),
    .m_dest_axi_arsize  (),
    .m_dest_axi_arburst (),
    .m_dest_axi_arcache (),
    .m_dest_axi_arprot  (),
    .m_dest_axi_arready (1'b0),
    .m_dest_axi_rvalid  (1'b0),
    .m_dest_axi_rresp   (2'b00),
    .m_dest_axi_rdata   ({DATA_WIDTH{1'b0}}),
    .m_dest_axi_rready  (),
    .m_dest_axi_arid    (),
    .m_dest_axi_arlock  (),
    .m_dest_axi_rid     (1'b0),
    .m_dest_axi_rlast   (1'b0),

    // ---------------- SRC master (read used) ----------------
    .m_src_axi_aclk     (clk),
    .m_src_axi_aresetn  (resetn),
    .m_src_axi_arready  (m_src_axi_arready),
    .m_src_axi_arvalid  (m_src_axi_arvalid),
    .m_src_axi_araddr   (m_src_axi_araddr),
    .m_src_axi_arlen    (m_src_axi_arlen),
    .m_src_axi_arsize   (m_src_axi_arsize),
    .m_src_axi_arburst  (m_src_axi_arburst),
    .m_src_axi_arprot   (m_src_axi_arprot),
    .m_src_axi_arcache  (m_src_axi_arcache),
    .m_src_axi_arid     (),
    .m_src_axi_arlock   (),
    .m_src_axi_rdata    (m_src_axi_rdata),
    .m_src_axi_rready   (m_src_axi_rready),
    .m_src_axi_rvalid   (m_src_axi_rvalid),
    .m_src_axi_rresp    (m_src_axi_rresp),
    .m_src_axi_rid      (1'b0),
    .m_src_axi_rlast    (m_src_axi_rlast),
    // SRC write channel: unused
    .m_src_axi_awvalid  (),
    .m_src_axi_awaddr   (),
    .m_src_axi_awlen    (),
    .m_src_axi_awsize   (),
    .m_src_axi_awburst  (),
    .m_src_axi_awcache  (),
    .m_src_axi_awprot   (),
    .m_src_axi_awready  (1'b0),
    .m_src_axi_wvalid   (),
    .m_src_axi_wdata    (),
    .m_src_axi_wstrb    (),
    .m_src_axi_wlast    (),
    .m_src_axi_wready   (1'b0),
    .m_src_axi_bvalid   (1'b0),
    .m_src_axi_bresp    (2'b00),
    .m_src_axi_bready   (),
    .m_src_axi_awid     (),
    .m_src_axi_awlock   (),
    .m_src_axi_wid      (),
    .m_src_axi_bid      (1'b0),

    // ---------------- SG master (read used) ----------------
    .m_sg_axi_aclk      (clk),
    .m_sg_axi_aresetn   (resetn),
    .m_sg_axi_arready   (m_sg_axi_arready),
    .m_sg_axi_arvalid   (m_sg_axi_arvalid),
    .m_sg_axi_araddr    (m_sg_axi_araddr),
    .m_sg_axi_arlen     (m_sg_axi_arlen),
    .m_sg_axi_arsize    (m_sg_axi_arsize),
    .m_sg_axi_arburst   (m_sg_axi_arburst),
    .m_sg_axi_arprot    (m_sg_axi_arprot),
    .m_sg_axi_arcache   (m_sg_axi_arcache),
    .m_sg_axi_arid      (),
    .m_sg_axi_arlock    (),
    .m_sg_axi_rdata     (m_sg_axi_rdata),
    .m_sg_axi_rready    (m_sg_axi_rready),
    .m_sg_axi_rvalid    (m_sg_axi_rvalid),
    .m_sg_axi_rresp     (m_sg_axi_rresp),
    .m_sg_axi_rid       (1'b0),
    .m_sg_axi_rlast     (m_sg_axi_rlast),
    // SG write channel: unused
    .m_sg_axi_awvalid   (),
    .m_sg_axi_awaddr    (),
    .m_sg_axi_awlen     (),
    .m_sg_axi_awsize    (),
    .m_sg_axi_awburst   (),
    .m_sg_axi_awcache   (),
    .m_sg_axi_awprot    (),
    .m_sg_axi_awready   (1'b0),
    .m_sg_axi_wvalid    (),
    .m_sg_axi_wdata     (),
    .m_sg_axi_wstrb     (),
    .m_sg_axi_wlast     (),
    .m_sg_axi_wready    (1'b0),
    .m_sg_axi_bvalid    (1'b0),
    .m_sg_axi_bresp     (2'b00),
    .m_sg_axi_bready    (),
    .m_sg_axi_awid      (),
    .m_sg_axi_awlock    (),
    .m_sg_axi_wid       (),
    .m_sg_axi_bid       (1'b0),

    // ---------------- AXI-Stream slave: unused ----------------
    .s_axis_aclk        (clk),
    .s_axis_ready       (),
    .s_axis_valid       (1'b0),
    .s_axis_data        ({DATA_WIDTH{1'b0}}),
    .s_axis_strb        ({(DATA_WIDTH/8){1'b0}}),
    .s_axis_keep        ({(DATA_WIDTH/8){1'b0}}),
    .s_axis_user        (1'b0),
    .s_axis_id          (8'd0),
    .s_axis_dest        (4'd0),
    .s_axis_last        (1'b0),
    .s_axis_xfer_req    (),

    // ---------------- AXI-Stream master: unused ----------------
    .m_axis_aclk        (clk),
    .m_axis_ready       (1'b0),
    .m_axis_valid       (),
    .m_axis_data        (),
    .m_axis_strb        (),
    .m_axis_keep        (),
    .m_axis_user        (),
    .m_axis_id          (),
    .m_axis_dest        (),
    .m_axis_last        (),
    .m_axis_xfer_req    (),

    // ---------------- FIFO interfaces: unused ----------------
    .fifo_wr_clk        (clk),
    .fifo_wr_en         (1'b0),
    .fifo_wr_din        ({DATA_WIDTH{1'b0}}),
    .fifo_wr_overflow   (),
    .fifo_wr_xfer_req   (),
    .fifo_rd_clk        (clk),
    .fifo_rd_en         (1'b0),
    .fifo_rd_valid      (),
    .fifo_rd_dout       (),
    .fifo_rd_underflow  (),
    .fifo_rd_xfer_req   (),

    // ---------------- Framelock: unused ----------------
    .m_frame_in         ({NUM_FRAMES_W{1'b0}}),
    .m_frame_in_valid   (1'b0),
    .m_frame_out        (),
    .m_frame_out_valid  (),
    .s_frame_in         ({NUM_FRAMES_W{1'b0}}),
    .s_frame_in_valid   (1'b0),
    .s_frame_out        (),
    .s_frame_out_valid  (),

    // ---------------- External sync / diagnostics: unused ----------------
    .src_ext_sync       (1'b0),
    .dest_ext_sync      (1'b0),
    .dest_diag_level_bursts ()
  );

endmodule

`default_nettype wire