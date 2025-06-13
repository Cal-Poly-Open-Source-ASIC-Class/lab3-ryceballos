`timescale 1ns/1ps

// Two-port pipelined Wishbone RAM
module two_port_wb_ram #(
  parameter AWIDTH = 9,
  parameter DWIDTH = 32
)(
  input  logic                 clk,
  // Port A
  input  logic                 pA_cyc_i,
  input  logic                 pA_stb_i,
  input  logic                 pA_we_i,
  input  logic [AWIDTH-1:0]    pA_addr_i,
  input  logic [DWIDTH-1:0]    pA_dat_i,
  output logic                 pA_ack_o,
  output logic [DWIDTH-1:0]    pA_dat_o,
  output logic                 pA_stall_o,

  // Port B
  input  logic                 pB_cyc_i,
  input  logic                 pB_stb_i,
  input  logic                 pB_we_i,
  input  logic [AWIDTH-1:0]    pB_addr_i,
  input  logic [DWIDTH-1:0]    pB_dat_i,
  output logic                 pB_ack_o,
  output logic [DWIDTH-1:0]    pB_dat_o,
  output logic                 pB_stall_o
  `ifdef USE_POWER_PINS
  , input logic VPWR
  , input logic VGND
  `endif
);

  // Bank select and collision detection
  wire bankA = pA_addr_i[AWIDTH-1];
  wire bankB = pB_addr_i[AWIDTH-1];

  wire reqA = pA_cyc_i & pA_stb_i;
  wire reqB = pB_cyc_i & pB_stb_i;

  wire selA0 = reqA & ~bankA;
  wire selA1 = reqA &  bankA;
  wire selB0 = reqB & ~bankB;
  wire selB1 = reqB &  bankB;

  wire collide0 = selA0 & selB0;
  wire collide1 = selA1 & selB1;

  // Port A never stalls, Port B stalls on collision
  assign pA_stall_o = 1'b0;
  assign pB_stall_o = collide0 | collide1;

  wire grantA0 = selA0;
  wire grantA1 = selA1;
  wire grantB0 = selB0 & ~pB_stall_o;
  wire grantB1 = selB1 & ~pB_stall_o;

  // Sub-bank addresses, 8 bits fr 256 word banks
  wire [7:0] subA = pA_addr_i[7:0];
  wire [7:0] subB = pB_addr_i[7:0];

  // Drive bank-0 macro
  logic en0;
  logic [3:0] we0;
  logic [7:0] addr0;
  logic [DWIDTH-1:0] di0;
  wire  [DWIDTH-1:0] do0;

  always_comb begin
    // Port A has priority over Port B
    if (grantA0) begin
      en0 = 1'b1;
      we0 = pA_we_i ? 4'hF : 4'h0;
      addr0 = subA;
      di0 = pA_dat_i;
    end else if (grantB0) begin
      en0 = 1'b1;
      we0 = pB_we_i ? 4'hF : 4'h0;
      addr0 = subB;
      di0 = pB_dat_i;
    end else begin
      en0 = 1'b0;
      we0 = 4'h0;
      addr0 = 8'h0;
      di0 = 32'h0;
    end
  end

  // Drive bank-1 macro
  logic en1;
  logic [3:0] we1;
  logic [7:0] addr1;
  logic [DWIDTH-1:0] di1;
  wire  [DWIDTH-1:0] do1;

  always_comb begin
    // Priority: Port A has priority over Port B
    if (grantA1) begin
      en1 = 1'b1;
      we1 = pA_we_i ? 4'hF : 4'h0;
      addr1 = subA;
      di1 = pA_dat_i;
    end else if (grantB1) begin
      en1 = 1'b1;
      we1 = pB_we_i ? 4'hF : 4'h0;
      addr1 = subB;
      di1 = pB_dat_i;
    end else begin
      en1 = 1'b0;
      we1 = 4'h0;
      addr1 = 8'h0;
      di1 = 32'h0;
    end
  end

  DFFRAM256x32 ram0 (
    .CLK (clk),
    .WE0 (we0),
    .EN0 (en0),
    .A0  (addr0),
    .Di0 (di0),
    .Do0 (do0)
    `ifdef USE_POWER_PINS
    , .VPWR(VPWR)
    , .VGND(VGND)
    `endif
  );

  DFFRAM256x32 ram1 (
    .CLK (clk),
    .WE0 (we1),
    .EN0 (en1),
    .A0  (addr1),
    .Di0 (di1),
    .Do0 (do1)
    `ifdef USE_POWER_PINS
    , .VPWR(VPWR)
    , .VGND(VGND)
    `endif
  );

  // Pipeline the granted requests, wishbone ACK+data
  logic reqA_d, reqB_d;
  logic bankA_d, bankB_d;
  logic [DWIDTH-1:0] do0_d, do1_d;

  always_ff @(posedge clk) begin
    // Request signals, granted only
    reqA_d <= reqA & ~pA_stall_o;
    reqB_d <= reqB & ~pB_stall_o;
    
    bankA_d <= bankA;
    bankB_d <= bankB;
    
    do0_d <= do0;
    do1_d <= do1;

    pA_ack_o <= reqA_d;
    pB_ack_o <= reqB_d;

    // Generate output data using pipelined RAM outputs
    pA_dat_o <= bankA_d ? do1_d : do0_d;
    pB_dat_o <= bankB_d ? do1_d : do0_d;
  end

endmodule