`timescale 1ns/1ps
`default_nettype none

// Multi-bit Gray-code synchronizer. Gray coding guarantees that a legal
// pointer advance changes only one bit; two rising-edge destination registers
// contain the metastability risk and provide a full cycle of resolution time.
module channelized_fifo_gray_sync #(
    parameter int WIDTH = 5,
    parameter logic [WIDTH-1:0] RESET_VALUE = '0
) (
    input  wire                 clk_dest,
    input  wire                 rst_dest_an,
    input  wire                 clear_dest,
    input  wire [WIDTH-1:0]     gray_async,
    output wire [WIDTH-1:0]     gray_sync
);
    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] sync_ff1;
    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] sync_ff2;

    always_ff @(posedge clk_dest or negedge rst_dest_an) begin
        if (!rst_dest_an) begin
            sync_ff1 <= RESET_VALUE;
            sync_ff2 <= RESET_VALUE;
        end else if (clear_dest) begin
            sync_ff1 <= RESET_VALUE;
            sync_ff2 <= RESET_VALUE;
        end else begin
            sync_ff1 <= gray_async;
            sync_ff2 <= sync_ff1;
        end
    end

    assign gray_sync = sync_ff2;
endmodule

`default_nettype wire
