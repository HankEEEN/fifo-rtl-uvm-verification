`timescale 1ns/1ps
`default_nettype none

interface channelized_fifo_if;
    import channelized_fifo_uvm_cfg_pkg::*;

    logic clk_wr = 1'b0;
    logic clk_rd = 1'b0;
    logic rst_wr_an = 1'b0;
    logic rst_rd_an = 1'b0;
    logic clear_wr = 1'b0;
    logic clear_rd = 1'b0;
    logic [CHANS-1:0] clear_chan_wr = '0;
    logic [CHANS-1:0] clear_chan_rd = '0;
    logic rinc = 1'b0;
    logic winc = 1'b0;
    logic block_rinc = 1'b0;
    logic block_winc = 1'b0;
    logic [CHANS-1:0] write = '0;
    logic [DATA_W*CHANS-1:0] din = '0;
    logic [DATA_W*CHANS-1:0] dout;
    logic full;
    logic almost_full;
    logic empty;
    logic almost_empty;
    logic [PTR_W:0] how_full_wr;
    logic [PTR_W:0] how_full_rd;
    logic underflow;
    logic overflow;
    logic [PTR_W:0] wr_ptr_bin;
    logic [PTR_W:0] rd_ptr_bin;
endinterface

`default_nettype wire

