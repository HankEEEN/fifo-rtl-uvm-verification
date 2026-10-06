`timescale 1ns/1ps
`default_nettype none

module channelized_fifo_core #(
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
    output logic [DATA_W*CHANS-1:0]   dout,
    output logic                      full,
    output logic                      almost_full,
    output logic                      empty,
    output logic                      almost_empty,
    output logic [PTR_W:0]            how_full_wr,
    output logic [PTR_W:0]            how_full_rd,
    output logic                      underflow,
    output logic                      overflow,
    output logic [PTR_W:0]            wr_ptr_bin,
    output logic [PTR_W:0]            rd_ptr_bin
);
    localparam int ADDR_SPACE = (1 << PTR_W);
    localparam bit POWER_OF_TWO_LENGTH = (LENGTH == ADDR_SPACE);
    localparam int SKIP_START  = LENGTH / 2;
    localparam int SKIP_STOP   = ADDR_SPACE - SKIP_START;
    localparam int SKIP_OFFSET = SKIP_STOP - SKIP_START;
    localparam logic [PTR_W-1:0] SKIP_STOP_ADDR = PTR_W'(SKIP_STOP);
    localparam logic [PTR_W-1:0] SKIP_OFFSET_ADDR = PTR_W'(SKIP_OFFSET);
    localparam logic [PTR_W:0] LENGTH_VALUE = (PTR_W+1)'(LENGTH);
    localparam logic [PTR_W:0] AF_THRESHOLD =
        (PTR_W+1)'(LENGTH - AF_LIMIT);
    localparam logic [PTR_W:0] AE_THRESHOLD = (PTR_W+1)'(AE_LIMIT);

    logic [PTR_W:0] wr_ptr_gray;
    logic [PTR_W:0] rd_ptr_gray;
    logic [PTR_W:0] wr_ptr_gray_sync;
    logic [PTR_W:0] rd_ptr_gray_sync;
    logic [PTR_W:0] wr_ptr_bin_sync;
    logic [PTR_W:0] rd_ptr_bin_sync;
    logic [PTR_W:0] wr_ptr_bin_next;
    logic [PTR_W:0] rd_ptr_bin_next;

    logic valid_rinc;
    logic valid_winc;
    logic can_write;
    logic [CHANS-1:0] valid_write;
    logic memory_read;
    logic [PTR_W-1:0] memory_rptr;
    logic underflow_event_rd;

    function automatic logic [PTR_W:0] gray_to_binary(
        input logic [PTR_W:0] gray_value
    );
        logic [PTR_W:0] binary_value;
        integer bit_index;
        begin
            binary_value[PTR_W] = gray_value[PTR_W];
            for (bit_index = PTR_W-1; bit_index >= 0; bit_index = bit_index - 1)
                binary_value[bit_index] =
                    binary_value[bit_index+1] ^ gray_value[bit_index];
            return binary_value;
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

    function automatic logic [PTR_W:0] logical_to_raw(
        input logic [PTR_W:0] logical_ptr
    );
        logic [PTR_W:0] converted;
        begin
            converted = logical_ptr;
            if ((LENGTH > 1) && ASYNCHRONOUS && !POWER_OF_TWO_LENGTH &&
                (logical_ptr[PTR_W-1:0] >= PTR_W'(SKIP_START))) begin
                converted[PTR_W-1:0] =
                    logical_ptr[PTR_W-1:0] + SKIP_OFFSET_ADDR;
            end
            return converted;
        end
    endfunction

    localparam logic [PTR_W:0] WR_PTR_RESET_RAW =
        logical_to_raw(WR_PTR_DEF);
    localparam logic [PTR_W:0] RD_PTR_RESET_RAW =
        logical_to_raw(RD_PTR_DEF);
    localparam logic [PTR_W:0] WR_PTR_RESET_GRAY =
        WR_PTR_RESET_RAW ^ (WR_PTR_RESET_RAW >> 1);
    localparam logic [PTR_W:0] RD_PTR_RESET_GRAY =
        RD_PTR_RESET_RAW ^ (RD_PTR_RESET_RAW >> 1);

    // Distance from the synchronized read pointer to the local write pointer.
    // Pointer MSBs are wrap bits, so the arithmetic is modulo 2*LENGTH.
    function automatic logic [PTR_W:0] pointer_distance(
        input logic [PTR_W:0] newer_ptr,
        input logic [PTR_W:0] older_ptr
    );
        integer newer_position;
        integer older_position;
        integer distance;
        begin
            newer_position = int'(newer_ptr[PTR_W-1:0]) +
                             (newer_ptr[PTR_W] ? LENGTH : 0);
            older_position = int'(older_ptr[PTR_W-1:0]) +
                             (older_ptr[PTR_W] ? LENGTH : 0);
            distance = newer_position - older_position;
            if (distance < 0)
                distance = distance + (2 * LENGTH);
            pointer_distance = (PTR_W+1)'(distance);
        end
    endfunction

    channelized_fifo_pointer #(
        .LENGTH       (LENGTH),
        .PTR_W        (PTR_W),
        .ASYNCHRONOUS (ASYNCHRONOUS),
        .PTR_DEF      (WR_PTR_DEF)
    ) u_write_pointer (
        .clk          (clk_wr),
        .rst_an       (rst_wr_an),
        .clear        (clear_wr),
        .enable       (valid_winc),
        .ptr_binary   (wr_ptr_bin),
        .ptr_gray     (wr_ptr_gray),
        .ptr_bin_next (wr_ptr_bin_next)
    );

    channelized_fifo_pointer #(
        .LENGTH       (LENGTH),
        .PTR_W        (PTR_W),
        .ASYNCHRONOUS (ASYNCHRONOUS),
        .PTR_DEF      (RD_PTR_DEF)
    ) u_read_pointer (
        .clk          (clk_rd),
        .rst_an       (rst_rd_an),
        .clear        (clear_rd),
        .enable       (valid_rinc),
        .ptr_binary   (rd_ptr_bin),
        .ptr_gray     (rd_ptr_gray),
        .ptr_bin_next (rd_ptr_bin_next)
    );

    generate
        if (ASYNCHRONOUS) begin : g_async_pointer_cdc
            channelized_fifo_gray_sync #(
                .WIDTH       (PTR_W + 1),
                .RESET_VALUE (RD_PTR_RESET_GRAY)
            ) u_rd_to_wr_sync (
                .clk_dest    (clk_wr),
                .rst_dest_an (rst_wr_an),
                .clear_dest  (clear_wr),
                .gray_async  (rd_ptr_gray),
                .gray_sync   (rd_ptr_gray_sync)
            );

            channelized_fifo_gray_sync #(
                .WIDTH       (PTR_W + 1),
                .RESET_VALUE (WR_PTR_RESET_GRAY)
            ) u_wr_to_rd_sync (
                .clk_dest    (clk_rd),
                .rst_dest_an (rst_rd_an),
                .clear_dest  (clear_rd),
                .gray_async  (wr_ptr_gray),
                .gray_sync   (wr_ptr_gray_sync)
            );

            always_comb begin
                rd_ptr_bin_sync = raw_to_logical(
                    gray_to_binary(rd_ptr_gray_sync));
                wr_ptr_bin_sync = raw_to_logical(
                    gray_to_binary(wr_ptr_gray_sync));
            end
        end else begin : g_sync_pointer_view
            always_comb begin
                rd_ptr_gray_sync = '0;
                wr_ptr_gray_sync = '0;
                rd_ptr_bin_sync = rd_ptr_bin;
                wr_ptr_bin_sync = wr_ptr_bin;
            end
        end
    endgenerate

    always_comb begin
        how_full_wr = pointer_distance(wr_ptr_bin, rd_ptr_bin_sync);
        how_full_rd = pointer_distance(wr_ptr_bin_sync, rd_ptr_bin);

        full         = (how_full_wr == LENGTH_VALUE);
        empty        = (how_full_rd == 0);
        if (AF_LIMIT == LENGTH)
            almost_full = 1'b1;
        else
            almost_full = (how_full_wr >= AF_THRESHOLD);
        almost_empty = (how_full_rd <= AE_THRESHOLD);

        valid_rinc = rinc && !block_rinc && !clear_rd && !empty;

        // Synchronous LOW_LATENCY mode permits a read and write on a full
        // queue in the same cycle because the read releases one entry.
        can_write = !full ||
                    (!ASYNCHRONOUS && LOW_LATENCY && valid_rinc);
        valid_winc = winc && !block_winc && !clear_wr && can_write;

        // Preserve the original contract: channel data writes are masked per
        // channel and are independent of pointer advancement.  The caller
        // normally asserts write and winc together for a FIFO enqueue.
        valid_write = write & {CHANS{can_write && !clear_wr}};

        memory_read = valid_rinc;
        memory_rptr = rd_ptr_bin[PTR_W-1:0];

        if (!ASYNCHRONOUS && LOW_LATENCY) begin
            // Keep the output register prefetched with the next FIFO head.
            if (valid_rinc && (how_full_rd > 1)) begin
                memory_read = 1'b1;
                memory_rptr = rd_ptr_bin_next[PTR_W-1:0];
            end else if (valid_winc && (empty || valid_rinc)) begin
                memory_read = 1'b1;
                memory_rptr = wr_ptr_bin[PTR_W-1:0];
            end else begin
                memory_read = 1'b0;
            end
        end

        underflow_event_rd = rinc && !block_rinc && !clear_rd && empty;
    end

    channelized_fifo_memory #(
        .DATA_W       (DATA_W),
        .PTR_W        (PTR_W),
        .LENGTH       (LENGTH),
        .CHANS        (CHANS),
        .LOW_LATENCY  (LOW_LATENCY),
        .MEM_RST_VAL  (MEM_RST_VAL)
    ) u_memory (
        .clk_wr   (clk_wr),
        .clk_rd   (clk_rd),
        .rst_wr_an(rst_wr_an),
        .rst_rd_an(rst_rd_an),
        .clear_wr (clear_chan_wr),
        .clear_rd (clear_chan_rd),
        .wptr     (wr_ptr_bin[PTR_W-1:0]),
        .rptr     (memory_rptr),
        .write    (valid_write),
        .read     (memory_read),
        .din      (din),
        .dout     (dout)
    );

    // Overflow is already in the write-clock domain.  It is a one-cycle pulse
    // for an unblocked enqueue request rejected by a full FIFO.
    always_ff @(posedge clk_wr or negedge rst_wr_an) begin
        if (!rst_wr_an)
            overflow <= 1'b0;
        else if (clear_wr)
            overflow <= 1'b0;
        else
            overflow <= winc && !block_winc && !can_write;
    end

    generate
        if (ASYNCHRONOUS) begin : g_async_underflow_event
            channelized_fifo_event_sync u_underflow_sync (
                .src_clk    (clk_rd),
                .src_rst_an (rst_rd_an),
                .src_clear  (clear_rd),
                .src_event  (underflow_event_rd),
                .dst_clk    (clk_wr),
                .dst_rst_an (rst_wr_an),
                .dst_clear  (clear_wr),
                .dst_pulse  (underflow)
            );
        end else begin : g_sync_underflow_event
            always_ff @(posedge clk_wr or negedge rst_wr_an) begin
                if (!rst_wr_an)
                    underflow <= 1'b0;
                else if (clear_wr)
                    underflow <= 1'b0;
                else
                    underflow <= underflow_event_rd;
            end
        end
    endgenerate

`ifndef SYNTHESIS
    initial begin
        if ((DATA_W < 1) || (CHANS < 1) || (PTR_W < 1))
            $fatal(1, "channelized_fifo_core: DATA_W, CHANS and PTR_W must be positive");
        if ((LENGTH < 1) || (LENGTH > ADDR_SPACE))
            $fatal(1, "channelized_fifo_core: LENGTH must be in [1, 2**PTR_W]");
        if ((LENGTH > 1) && ASYNCHRONOUS &&
            !POWER_OF_TWO_LENGTH && ((LENGTH % 2) != 0))
            $fatal(1,
                "channelized_fifo_core: asynchronous non-power-of-two LENGTH must be even");
        if ((AE_LIMIT > LENGTH) || (AF_LIMIT > LENGTH))
            $fatal(1, "channelized_fifo_core: almost-empty/full limits exceed LENGTH");
        if (LOW_LATENCY && ASYNCHRONOUS)
            $fatal(1, "channelized_fifo_core: LOW_LATENCY requires synchronous operation");
        if (WR_PTR_DEF != RD_PTR_DEF)
            $fatal(1,
                "channelized_fifo_core: WR_PTR_DEF and RD_PTR_DEF must match");
    end

    always_ff @(posedge clk_wr or negedge rst_wr_an) begin
        if (!rst_wr_an) begin
            // Assertion state is reset by the RTL reset itself.
        end else if (!clear_wr) begin
            assert (how_full_wr <= LENGTH_VALUE)
                else $error("channelized_fifo_core: write-domain occupancy exceeded LENGTH");
            assert (!(valid_winc && full &&
                      !(!ASYNCHRONOUS && LOW_LATENCY && valid_rinc)))
                else $error("channelized_fifo_core: write pointer advanced while full");
            assert (!$isunknown(wr_ptr_bin_next))
                else $error("channelized_fifo_core: next write pointer contains X/Z");
        end
    end

    always_ff @(posedge clk_rd or negedge rst_rd_an) begin
        if (!rst_rd_an) begin
            // Assertion state is reset by the RTL reset itself.
        end else if (!clear_rd) begin
            assert (how_full_rd <= LENGTH_VALUE)
                else $error("channelized_fifo_core: read-domain occupancy exceeded LENGTH");
            assert (!(valid_rinc && empty))
                else $error("channelized_fifo_core: read pointer advanced while empty");
            assert (!$isunknown(rd_ptr_bin_next))
                else $error("channelized_fifo_core: next read pointer contains X/Z");
        end
    end
`endif

endmodule

`default_nettype wire
