`timescale 1ns/1ps
`default_nettype none

module channelized_fifo_pointer #(
    parameter int LENGTH = 12,
    parameter int PTR_W  = 4,
    parameter bit ASYNCHRONOUS = 1'b1,
    parameter logic [PTR_W:0] PTR_DEF = '0
) (
    input  wire                clk,
    input  wire                rst_an,
    input  wire                clear,
    input  wire                enable,
    output logic [PTR_W:0]     ptr_binary,
    output logic [PTR_W:0]     ptr_gray,
    output logic [PTR_W:0]     ptr_bin_next
);
    localparam int ADDR_SPACE = (1 << PTR_W);
    localparam bit POWER_OF_TWO_LENGTH = (LENGTH == ADDR_SPACE);

    // For an even, non-power-of-two asynchronous depth, skip a centered
    // section of the raw binary count.  Both jumps occur at positions whose
    // Gray encodings differ by one bit, preserving the CDC property.
    localparam int SKIP_START  = LENGTH / 2;
    localparam int SKIP_STOP   = ADDR_SPACE - SKIP_START;
    localparam int SKIP_OFFSET = SKIP_STOP - SKIP_START;
    localparam logic [PTR_W-1:0] SKIP_START_ADDR = PTR_W'(SKIP_START);
    localparam logic [PTR_W-1:0] SKIP_STOP_ADDR  = PTR_W'(SKIP_STOP);
    localparam logic [PTR_W-1:0] SKIP_OFFSET_ADDR = PTR_W'(SKIP_OFFSET);
    localparam logic [PTR_W-1:0] LAST_ADDR = PTR_W'(LENGTH - 1);

    logic [PTR_W:0] raw_ptr_q;
    logic [PTR_W:0] raw_ptr_next;

    function automatic logic [PTR_W:0] logical_to_raw(
        input logic [PTR_W:0] logical_ptr
    );
        logic [PTR_W:0] converted;
        begin
            converted = logical_ptr;
            if ((LENGTH > 1) && ASYNCHRONOUS && !POWER_OF_TWO_LENGTH &&
                (logical_ptr[PTR_W-1:0] >= SKIP_START_ADDR)) begin
                converted[PTR_W-1:0] =
                    logical_ptr[PTR_W-1:0] + SKIP_OFFSET_ADDR;
            end
            return converted;
        end
    endfunction

    function automatic logic [PTR_W:0] raw_to_logical(
        input logic [PTR_W:0] raw_ptr
    );
        logic [PTR_W:0] converted;
        begin
            converted = raw_ptr;
            if ((LENGTH > 1) && ASYNCHRONOUS && !POWER_OF_TWO_LENGTH &&
                (raw_ptr[PTR_W-1:0] >= SKIP_STOP_ADDR)) begin
                converted[PTR_W-1:0] =
                    raw_ptr[PTR_W-1:0] - SKIP_OFFSET_ADDR;
            end
            return converted;
        end
    endfunction

    always_comb begin
        raw_ptr_next = raw_ptr_q;

        if (LENGTH == 1) begin
            raw_ptr_next = {~raw_ptr_q[PTR_W], {PTR_W{1'b0}}};
        end else if (ASYNCHRONOUS) begin
            raw_ptr_next = raw_ptr_q + {{PTR_W{1'b0}}, 1'b1};
            if (!POWER_OF_TWO_LENGTH &&
                (raw_ptr_next[PTR_W-1:0] == SKIP_START_ADDR)) begin
                raw_ptr_next[PTR_W-1:0] = SKIP_STOP_ADDR;
            end
        end else begin
            // In synchronous mode the pointer can use the direct logical
            // modulo-LENGTH sequence; no CDC-safe skip sequence is needed.
            if (raw_ptr_q[PTR_W-1:0] == LAST_ADDR) begin
                raw_ptr_next = {~raw_ptr_q[PTR_W], {PTR_W{1'b0}}};
            end else begin
                raw_ptr_next = raw_ptr_q + {{PTR_W{1'b0}}, 1'b1};
            end
        end
    end

    always_ff @(posedge clk or negedge rst_an) begin
        if (!rst_an)
            raw_ptr_q <= logical_to_raw(PTR_DEF);
        else if (clear)
            raw_ptr_q <= logical_to_raw(PTR_DEF);
        else if (enable)
            raw_ptr_q <= raw_ptr_next;
    end

    always_comb begin
        ptr_binary = raw_to_logical(raw_ptr_q);
        ptr_bin_next = raw_to_logical(raw_ptr_next);
        ptr_gray = ASYNCHRONOUS ? (raw_ptr_q ^ (raw_ptr_q >> 1)) : '0;
    end

`ifndef SYNTHESIS
    initial begin
        if (PTR_W < 1)
            $fatal(1, "channelized_fifo_pointer: PTR_W must be at least 1");
        if ((LENGTH < 1) || (LENGTH > ADDR_SPACE))
            $fatal(1, "channelized_fifo_pointer: LENGTH must be in [1, 2**PTR_W]");
        if ((LENGTH > 1) && ASYNCHRONOUS &&
            !POWER_OF_TWO_LENGTH && ((LENGTH % 2) != 0))
            $fatal(1,
                "channelized_fifo_pointer: asynchronous non-power-of-two LENGTH must be even");
        if ((LENGTH < ADDR_SPACE) &&
            (PTR_DEF[PTR_W-1:0] >= PTR_W'(LENGTH)))
            $fatal(1, "channelized_fifo_pointer: PTR_DEF address is outside LENGTH");
    end

    if (ASYNCHRONOUS) begin : g_gray_transition_check
        logic [PTR_W:0] previous_gray;
        logic gray_check_valid;

        always_ff @(posedge clk or negedge rst_an) begin
            if (!rst_an) begin
                previous_gray <= '0;
                gray_check_valid <= 1'b0;
            end else if (clear) begin
                previous_gray <= ptr_gray;
                gray_check_valid <= 1'b0;
            end else begin
                if (gray_check_valid)
                    assert ($onehot0(ptr_gray ^ previous_gray))
                        else $error(
                            "channelized_fifo_pointer: more than one Gray bit changed in a step");
                previous_gray <= ptr_gray;
                gray_check_valid <= 1'b1;
            end
        end
    end
`endif
endmodule

`default_nettype wire
