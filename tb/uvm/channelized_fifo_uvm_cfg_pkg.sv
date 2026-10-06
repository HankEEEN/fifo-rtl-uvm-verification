`timescale 1ns/1ps
`default_nettype none

`ifndef FIFO_DATA_W
  `define FIFO_DATA_W 8
`endif
`ifndef FIFO_CHANS
  `define FIFO_CHANS 2
`endif
`ifndef FIFO_LENGTH
  `define FIFO_LENGTH 4
`endif
`ifndef FIFO_PTR_W
  `define FIFO_PTR_W 2
`endif
`ifndef FIFO_ASYNC
  `define FIFO_ASYNC 0
`endif
`ifndef FIFO_LOW_LATENCY
  `define FIFO_LOW_LATENCY 0
`endif
`ifndef FIFO_AE_LIMIT
  `define FIFO_AE_LIMIT 1
`endif
`ifndef FIFO_AF_LIMIT
  `define FIFO_AF_LIMIT 1
`endif
`ifndef FIFO_MEM_RST_VAL
  `define FIFO_MEM_RST_VAL 0
`endif
`ifndef FIFO_PTR_DEF
  `define FIFO_PTR_DEF 0
`endif
`ifndef FIFO_WR_HALF_NS
  `define FIFO_WR_HALF_NS 5
`endif
`ifndef FIFO_RD_HALF_NS
  `define FIFO_RD_HALF_NS 5
`endif
`ifndef FIFO_RD_PHASE_NS
  `define FIFO_RD_PHASE_NS 0
`endif

package channelized_fifo_uvm_cfg_pkg;
    localparam int DATA_W = `FIFO_DATA_W;
    localparam int CHANS = `FIFO_CHANS;
    localparam int LENGTH = `FIFO_LENGTH;
    localparam int PTR_W = `FIFO_PTR_W;
    localparam bit ASYNCHRONOUS = `FIFO_ASYNC;
    localparam bit LOW_LATENCY = `FIFO_LOW_LATENCY;
    localparam int unsigned AE_LIMIT = `FIFO_AE_LIMIT;
    localparam int unsigned AF_LIMIT = `FIFO_AF_LIMIT;
    localparam logic [DATA_W-1:0] MEM_RST_VAL = DATA_W'(`FIFO_MEM_RST_VAL);
    localparam logic [PTR_W:0] PTR_DEF = (PTR_W+1)'(`FIFO_PTR_DEF);
    localparam int WR_HALF_NS = `FIFO_WR_HALF_NS;
    localparam int RD_HALF_NS = `FIFO_RD_HALF_NS;
    localparam int RD_PHASE_NS = `FIFO_RD_PHASE_NS;
endpackage

`default_nettype wire

