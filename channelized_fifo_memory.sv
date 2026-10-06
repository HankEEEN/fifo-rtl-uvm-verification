`timescale 1ns/1ps
`default_nettype none

module channelized_fifo_memory #(
    parameter int DATA_W = 24,
    parameter int PTR_W  = 4,
    parameter int LENGTH = 12,
    parameter int CHANS  = 8,
    parameter bit LOW_LATENCY  = 1'b0,
    parameter logic [DATA_W-1:0] MEM_RST_VAL = '0
) (
    input  wire                       clk_wr,
    input  wire                       clk_rd,
    input  wire                       rst_wr_an,
    input  wire                       rst_rd_an,
    input  wire [CHANS-1:0]           clear_wr,
    input  wire [CHANS-1:0]           clear_rd,
    input  wire [PTR_W-1:0]           wptr,
    input  wire [PTR_W-1:0]           rptr,
    input  wire [CHANS-1:0]           write,
    input  wire                       read,
    input  wire [DATA_W*CHANS-1:0]    din,
    output logic [DATA_W*CHANS-1:0]   dout
);
    logic [DATA_W-1:0] mem [0:LENGTH-1][0:CHANS-1];

    integer wr_addr_index;
    integer wr_chan_index;
    integer rd_chan_index;

    // A channel clear has priority over a write to that same channel.  Other
    // channels may continue writing on the same clock edge.
    always_ff @(posedge clk_wr or negedge rst_wr_an) begin
        if (!rst_wr_an) begin
            for (wr_addr_index = 0; wr_addr_index < LENGTH; wr_addr_index = wr_addr_index + 1)
                for (wr_chan_index = 0; wr_chan_index < CHANS; wr_chan_index = wr_chan_index + 1)
                    mem[wr_addr_index][wr_chan_index] <= MEM_RST_VAL;
        end else begin
            for (wr_chan_index = 0; wr_chan_index < CHANS; wr_chan_index = wr_chan_index + 1) begin
                if (clear_wr[wr_chan_index]) begin
                    for (wr_addr_index = 0; wr_addr_index < LENGTH; wr_addr_index = wr_addr_index + 1)
                        mem[wr_addr_index][wr_chan_index] <= MEM_RST_VAL;
                end else if (write[wr_chan_index]) begin
                    mem[wptr][wr_chan_index] <=
                        din[wr_chan_index*DATA_W +: DATA_W];
                end
            end
        end
    end

    // Read data is registered in both modes. LOW_LATENCY uses explicit
    // write-through behavior when a synchronous enqueue supplies the next
    // visible FIFO head on the same edge.
    always_ff @(posedge clk_rd or negedge rst_rd_an) begin
        if (!rst_rd_an) begin
            dout <= {CHANS{MEM_RST_VAL}};
        end else begin
            for (rd_chan_index = 0; rd_chan_index < CHANS; rd_chan_index = rd_chan_index + 1) begin
                if (clear_rd[rd_chan_index]) begin
                    dout[rd_chan_index*DATA_W +: DATA_W] <= MEM_RST_VAL;
                end else if (read) begin
                    if (LOW_LATENCY &&
                        write[rd_chan_index] && (wptr == rptr))
                        dout[rd_chan_index*DATA_W +: DATA_W] <=
                            din[rd_chan_index*DATA_W +: DATA_W];
                    else
                        dout[rd_chan_index*DATA_W +: DATA_W] <=
                            mem[rptr][rd_chan_index];
                end
            end
        end
    end

`ifndef SYNTHESIS
    initial begin
        if ((DATA_W < 1) || (CHANS < 1) || (LENGTH < 1))
            $fatal(1, "channelized_fifo_memory: DATA_W, CHANS and LENGTH are invalid");
    end
`endif
endmodule

`default_nettype wire
