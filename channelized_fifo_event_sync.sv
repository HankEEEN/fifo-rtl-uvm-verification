`timescale 1ns/1ps
`default_nettype none

// Request/acknowledge event synchronizer. A source-domain event becomes one
// destination-clock pulse. While an event is awaiting acknowledgement,
// additional source events are intentionally coalesced into that pending
// indication rather than being sampled unreliably as a narrow pulse.
module channelized_fifo_event_sync (
    input  wire src_clk,
    input  wire src_rst_an,
    input  wire src_clear,
    input  wire src_event,
    input  wire dst_clk,
    input  wire dst_rst_an,
    input  wire dst_clear,
    output logic dst_pulse
);
    logic req_toggle;
    logic ack_toggle;

    (* ASYNC_REG = "TRUE" *) logic req_sync_ff1;
    (* ASYNC_REG = "TRUE" *) logic req_sync_ff2;
    (* ASYNC_REG = "TRUE" *) logic ack_sync_ff1;
    (* ASYNC_REG = "TRUE" *) logic ack_sync_ff2;

    always_ff @(posedge src_clk or negedge src_rst_an) begin
        if (!src_rst_an) begin
            req_toggle <= 1'b0;
        end else if (src_clear) begin
            req_toggle <= 1'b0;
        end else begin
            if (src_event && (ack_sync_ff2 == req_toggle)) begin
                req_toggle <= ~req_toggle;
            end
        end
    end

    always_ff @(posedge dst_clk or negedge dst_rst_an) begin
        if (!dst_rst_an) begin
            req_sync_ff1 <= 1'b0;
            req_sync_ff2 <= 1'b0;
            ack_toggle   <= 1'b0;
            dst_pulse    <= 1'b0;
        end else if (dst_clear) begin
            req_sync_ff1 <= 1'b0;
            req_sync_ff2 <= 1'b0;
            ack_toggle   <= 1'b0;
            dst_pulse    <= 1'b0;
        end else begin
            req_sync_ff1 <= req_toggle;
            req_sync_ff2 <= req_sync_ff1;
            dst_pulse    <= 1'b0;

            if (req_sync_ff2 != ack_toggle) begin
                ack_toggle <= req_sync_ff2;
                dst_pulse  <= 1'b1;
            end
        end
    end

    always_ff @(posedge src_clk or negedge src_rst_an) begin
        if (!src_rst_an) begin
            ack_sync_ff1 <= 1'b0;
            ack_sync_ff2 <= 1'b0;
        end else if (src_clear) begin
            ack_sync_ff1 <= 1'b0;
            ack_sync_ff2 <= 1'b0;
        end else begin
            ack_sync_ff1 <= ack_toggle;
            ack_sync_ff2 <= ack_sync_ff1;
        end
    end
endmodule

`default_nettype wire
