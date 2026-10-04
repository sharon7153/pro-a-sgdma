// ============================================================================
// tb_mem_pkg.sv
//   Sparse byte-addressable memory shared by all AXI slave models and the TB.
//   (src read / dest write / sg read ports all see the same memory,
//    like a single DDR behind an interconnect in a real SoC)
// ============================================================================
`timescale 1ns/1ps

package tb_mem_pkg;

  bit [7:0] mem [bit [31:0]];

  function automatic void mem_write8(bit [31:0] a, bit [7:0] d);
    mem[a] = d;
  endfunction

  function automatic bit [7:0] mem_read8(bit [31:0] a);
    return mem.exists(a) ? mem[a] : 8'h00;
  endfunction

  function automatic bit mem_written(bit [31:0] a);
    return mem.exists(a);
  endfunction

  function automatic void mem_write64(bit [31:0] a, bit [63:0] d);
    for (int i = 0; i < 8; i++) mem[a + i] = d[8*i +: 8];
  endfunction

  function automatic void mem_clear();
    mem.delete();
  endfunction

endpackage