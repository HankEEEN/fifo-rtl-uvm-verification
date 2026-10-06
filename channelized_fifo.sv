`timescale 1ns/1ps
`default_nettype none

module channelized_fifo #(
    parameter int DATA_W = 24,
    parameter int PTR_W  = 4,
    parameter int LENGTH = 12,
    parameter int CHANS  = 8,
    parameter bit ASYNCHRONOUS = 1'b1,
    parameter int unsigned AE_LIMIT = 1,
    parameter int unsigned AF_LIMIT = 1,
    parameter bit LOW_LATENCY = 1'b0,
    parameter logic [DATA_W-1:0] MEM_RST_VAL = '0,
    parameter logic [PTR_W:0] WR_PTR_DEF = '0,
    parameter logic [PTR_W:0] RD_PTR_DEF = '0
) (
    input  wire                       clk_wr,
    input  wire                       clk_rd,
    input  wire                       rst_wr_an,
    input  wire                       rst_rd_an,
    input  wire                       clear_wr,
    input  wire                       clear_rd,
    input  wire [CHANS-1:0]           clear_chan_wr,
    input  wire [CHANS-1:0]           clear_chan_rd,
    input  wire                       rinc,
    input  wire                       winc,
    input  wire                       block_rinc,
    input  wire                       block_winc,
    input  wire [CHANS-1:0]           write,
    input  wire [DATA_W*CHANS-1:0]    din,
    output wire [DATA_W*CHANS-1:0]    dout,
    output wire                       full,
    output wire                       almost_full,
    output wire                       empty,
    output wire                       almost_empty,
    output wire [PTR_W:0]             how_full_wr,
    output wire [PTR_W:0]             how_full_rd,
    output wire                       underflow,
    output wire                       overflow,
    output wire [PTR_W:0]             wr_ptr_bin,
    output wire [PTR_W:0]             rd_ptr_bin
);
    channelized_fifo_core #(
        .DATA_W       (DATA_W),
        .PTR_W        (PTR_W),
        .LENGTH       (LENGTH),
        .CHANS        (CHANS),
        .ASYNCHRONOUS (ASYNCHRONOUS),
        .AE_LIMIT     (AE_LIMIT),
        .AF_LIMIT     (AF_LIMIT),
        .LOW_LATENCY  (LOW_LATENCY),
        .MEM_RST_VAL  (MEM_RST_VAL),
        .WR_PTR_DEF   (WR_PTR_DEF),
        .RD_PTR_DEF   (RD_PTR_DEF)
    ) u_fifo_core (
        .clk_wr        (clk_wr),
        .clk_rd        (clk_rd),
        .rst_wr_an     (rst_wr_an),
        .rst_rd_an     (rst_rd_an),
        .clear_wr      (clear_wr),
        .clear_rd      (clear_rd),
        .clear_chan_wr (clear_chan_wr),
        .clear_chan_rd (clear_chan_rd),
        .rinc          (rinc),
        .winc          (winc),
        .block_rinc    (block_rinc),
        .block_winc    (block_winc),
        .write         (write),
        .din           (din),
        .dout          (dout),
        .full          (full),
        .almost_full   (almost_full),
        .empty         (empty),
        .almost_empty  (almost_empty),
        .how_full_wr   (how_full_wr),
        .how_full_rd   (how_full_rd),
        .underflow     (underflow),
        .overflow      (overflow),
        .wr_ptr_bin    (wr_ptr_bin),
        .rd_ptr_bin    (rd_ptr_bin)
    );
endmodule

`default_nettype wire
