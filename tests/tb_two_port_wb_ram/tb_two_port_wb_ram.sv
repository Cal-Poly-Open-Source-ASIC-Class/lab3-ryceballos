`timescale 1ns/1ps

`ifdef VERILATOR
  `include "../../rtl/two_port_wb_ram.sv"
  `include "../../rtl/DFFRAM256x32.v"
`endif

module tb_two_port_wb_ram;
  logic clk = 0;
  always #5 clk = ~clk;

  // Port A
  logic        cycA, stbA, weA, ackA, stallA;
  logic [8:0]  addrA;
  logic [31:0] dinA, doutA;

  // Port B
  logic        cycB, stbB, weB, ackB, stallB;
  logic [8:0]  addrB;
  logic [31:0] dinB, doutB;
  `ifdef USE_POWER_PINS
    wire VPWR;
    wire VGND;
    assign VPWR=1;
    assign VGND=0;
  `endif

  two_port_wb_ram U (
    .clk        (clk),
    .pA_cyc_i   (cycA), .pA_stb_i  (stbA), .pA_we_i  (weA),
    .pA_addr_i  (addrA),.pA_dat_i  (dinA),
    .pA_ack_o   (ackA), .pA_stall_o(stallA), .pA_dat_o (doutA),
    .pB_cyc_i   (cycB), .pB_stb_i  (stbB), .pB_we_i  (weB),
    .pB_addr_i  (addrB),.pB_dat_i  (dinB),
    .pB_ack_o   (ackB), .pB_stall_o(stallB), .pB_dat_o (doutB)
    `ifdef USE_POWER_PINS
    ,.VPWR(VPWR),
    .VGND(VGND)
    `endif
  );

  initial begin
    $dumpfile("tb_two_port_wb_ram.vcd");
    $dumpvars(2, tb_two_port_wb_ram);
  end

  // Reset
  initial begin
    {cycA,stbA,weA,addrA,dinA} = '0;
    {cycB,stbB,weB,addrB,dinB} = '0;
  end

  // Port‐A write: wait for ack
  task writeA(input [8:0] a, input [31:0] d);
    @(posedge clk);
      addrA = a; dinA = d; cycA = 1; stbA = 1; weA = 1;
    do @(posedge clk); while (!ackA);
    @(posedge clk);
      cycA = 0; stbA = 0; weA = 0;
      $display(">>> Port A WRITE @%0d <= 0x%08x", a, d);
  endtask

  // Port‐A read: wait for ack & check
  task readA(input [8:0] a, input [31:0] exp);
    @(posedge clk);
      addrA = a; cycA = 1; stbA = 1; weA = 0;
    do @(posedge clk); while (!ackA);
    @(posedge clk);
      if (doutA !== exp)
        $error("Port A READ @%0d: expected 0x%08x, got 0x%08x", a, exp, doutA);
      cycA = 0; stbA = 0;
      $display(">>> Port A READ  @%0d => 0x%08x (expected 0x%08x)", a, doutA, exp);
  endtask

  // Port‐B write: wait for ack
  task writeB(input [8:0] a, input [31:0] d);
    @(posedge clk);
      addrB = a; dinB = d; cycB = 1; stbB = 1; weB = 1;
    do @(posedge clk); while (!ackB);
    @(posedge clk);
      cycB = 0; stbB = 0; weB = 0;
      $display(">>> Port B WRITE @%0d <= 0x%08x", a, d);
  endtask

  // Port‐B read: wait for ack & check
  task readB(input [8:0] a, input [31:0] exp);
    @(posedge clk);
      addrB = a; cycB = 1; stbB = 1; weB = 0;
    do @(posedge clk); while (!ackB);
    @(posedge clk);
      if (doutB !== exp)
        $error("Port B READ @%0d: expected 0x%08x, got 0x%08x", a, exp, doutB);
      cycB = 0; stbB = 0;
      $display(">>> Port B READ  @%0d => 0x%08x (expected 0x%08x)", a, doutB, exp);
  endtask

  initial begin
    repeat (2) @(posedge clk);

    writeA(9'd10, 32'hDEADBEEF);
    readA (9'd10, 32'hDEADBEEF);

    writeB(9'd260,32'hABCDEF01);
    readB (9'd260,32'hABCDEF01);

    writeA(9'd5,  32'h11111111);
    writeB(9'd5,  32'h22222222);

    readA (9'd5,  32'h22222222);
    readB (9'd5,  32'h22222222);

    $display("** ALL TESTS PASSED **");
    $finish;
  end

endmodule
