`timescale 1ns/1ps
`default_nettype none

module channelized_fifo_smoke_tb;
    localparam int DATA_W = 8;
    localparam int CHANS  = 2;
    localparam int PTR_W  = 2;
    localparam int LENGTH = 4;

    logic clk;
    logic rst_an;
    logic clear_wr;
    logic clear_rd;
    logic [CHANS-1:0] clear_chan_wr;
    logic [CHANS-1:0] clear_chan_rd;
    logic rinc;
    logic winc;
    logic block_rinc;
    logic block_winc;
    logic [CHANS-1:0] write;
    logic [DATA_W*CHANS-1:0] din;
    wire  [DATA_W*CHANS-1:0] dout;
    wire full;
    wire almost_full;
    wire empty;
    wire almost_empty;
    wire [PTR_W:0] how_full_wr;
    wire [PTR_W:0] how_full_rd;
    wire underflow;
    wire overflow;
    wire [PTR_W:0] wr_ptr_bin;
    wire [PTR_W:0] rd_ptr_bin;

    channelized_fifo #(
        .DATA_W       (DATA_W),
        .PTR_W        (PTR_W),
        .LENGTH       (LENGTH),
        .CHANS        (CHANS),
        .ASYNCHRONOUS (1'b0),
        .AE_LIMIT     (1),
        .AF_LIMIT     (1),
        .LOW_LATENCY  (1'b0),
        .WR_PTR_DEF   (3'd3),
        .RD_PTR_DEF   (3'd3)
    ) u_sync_fifo (
        .clk_wr(clk), .clk_rd(clk),
        .rst_wr_an(rst_an), .rst_rd_an(rst_an),
        .clear_wr(clear_wr), .clear_rd(clear_rd),
        .clear_chan_wr(clear_chan_wr), .clear_chan_rd(clear_chan_rd),
        .rinc(rinc), .winc(winc),
        .block_rinc(block_rinc), .block_winc(block_winc),
        .write(write), .din(din), .dout(dout),
        .full(full), .almost_full(almost_full),
        .empty(empty), .almost_empty(almost_empty),
        .how_full_wr(how_full_wr), .how_full_rd(how_full_rd),
        .underflow(underflow), .overflow(overflow),
        .wr_ptr_bin(wr_ptr_bin), .rd_ptr_bin(rd_ptr_bin)
    );

    // A second synchronous instance exercises first-word fall-through and
    // the simultaneous read/write replacement case.
    logic ll_rst_an;
    logic ll_rinc;
    logic ll_winc;
    logic ll_write;
    logic ll_clear_chan_wr;
    logic ll_clear_chan_rd;
    logic [DATA_W-1:0] ll_din;
    wire [DATA_W-1:0] ll_dout;
    wire ll_empty;
    wire [PTR_W:0] ll_how_full;

    channelized_fifo #(
        .DATA_W       (DATA_W),
        .PTR_W        (PTR_W),
        .LENGTH       (LENGTH),
        .CHANS        (1),
        .ASYNCHRONOUS (1'b0),
        .LOW_LATENCY  (1'b1)
    ) u_low_latency_fifo (
        .clk_wr(clk), .clk_rd(clk),
        .rst_wr_an(ll_rst_an), .rst_rd_an(ll_rst_an),
        .clear_wr(1'b0), .clear_rd(1'b0),
        .clear_chan_wr(ll_clear_chan_wr), .clear_chan_rd(ll_clear_chan_rd),
        .rinc(ll_rinc), .winc(ll_winc),
        .block_rinc(1'b0), .block_winc(1'b0),
        .write(ll_write), .din(ll_din), .dout(ll_dout),
        .full(), .almost_full(), .empty(ll_empty), .almost_empty(),
        .how_full_wr(ll_how_full), .how_full_rd(),
        .underflow(), .overflow(), .wr_ptr_bin(), .rd_ptr_bin()
    );

    // Depth-one remains a supported special case.
    logic one_rst_an;
    logic one_rinc;
    logic one_winc;
    logic one_write;
    logic [DATA_W-1:0] one_din;
    wire [DATA_W-1:0] one_dout;
    wire one_full;
    wire one_empty;
    wire one_overflow;

    channelized_fifo #(
        .DATA_W       (DATA_W),
        .PTR_W        (1),
        .LENGTH       (1),
        .CHANS        (1),
        .ASYNCHRONOUS (1'b0)
    ) u_depth_one_fifo (
        .clk_wr(clk), .clk_rd(clk),
        .rst_wr_an(one_rst_an), .rst_rd_an(one_rst_an),
        .clear_wr(1'b0), .clear_rd(1'b0),
        .clear_chan_wr(1'b0), .clear_chan_rd(1'b0),
        .rinc(one_rinc), .winc(one_winc),
        .block_rinc(1'b0), .block_winc(1'b0),
        .write(one_write), .din(one_din), .dout(one_dout),
        .full(one_full), .almost_full(),
        .empty(one_empty), .almost_empty(),
        .how_full_wr(), .how_full_rd(),
        .underflow(), .overflow(one_overflow),
        .wr_ptr_bin(), .rd_ptr_bin()
    );

    // Even, non-power-of-two asynchronous instance exercises the skipped
    // Gray sequence, both pointer crossings, and underflow event CDC.
    localparam int A_PTR_W  = 4;
    localparam int A_LENGTH = 12;
    logic a_clk_wr;
    logic a_clk_rd;
    logic a_rst_wr_an;
    logic a_rst_rd_an;
    logic a_clear_wr;
    logic a_clear_rd;
    logic a_rinc;
    logic a_winc;
    logic a_write;
    logic [DATA_W-1:0] a_din;
    wire [DATA_W-1:0] a_dout;
    wire a_full;
    wire a_empty;
    wire a_underflow;
    wire a_overflow;
    wire [A_PTR_W:0] a_how_full_wr;
    wire [A_PTR_W:0] a_how_full_rd;

    channelized_fifo #(
        .DATA_W       (DATA_W),
        .PTR_W        (A_PTR_W),
        .LENGTH       (A_LENGTH),
        .CHANS        (1),
        .ASYNCHRONOUS (1'b1),
        .AE_LIMIT     (1),
        .AF_LIMIT     (1),
        .LOW_LATENCY  (1'b0),
        .WR_PTR_DEF   (5'd3),
        .RD_PTR_DEF   (5'd3)
    ) u_async_fifo (
        .clk_wr(a_clk_wr), .clk_rd(a_clk_rd),
        .rst_wr_an(a_rst_wr_an), .rst_rd_an(a_rst_rd_an),
        .clear_wr(a_clear_wr), .clear_rd(a_clear_rd),
        .clear_chan_wr(1'b0), .clear_chan_rd(1'b0),
        .rinc(a_rinc), .winc(a_winc),
        .block_rinc(1'b0), .block_winc(1'b0),
        .write(a_write), .din(a_din), .dout(a_dout),
        .full(a_full), .almost_full(),
        .empty(a_empty), .almost_empty(),
        .how_full_wr(a_how_full_wr), .how_full_rd(a_how_full_rd),
        .underflow(a_underflow), .overflow(a_overflow),
        .wr_ptr_bin(), .rd_ptr_bin()
    );

    always #5 clk = ~clk;
    always #5 a_clk_wr = ~a_clk_wr;
    always #7 a_clk_rd = ~a_clk_rd;

    task automatic sync_enqueue(
        input logic [DATA_W-1:0] channel_0,
        input logic [DATA_W-1:0] channel_1,
        input logic [CHANS-1:0] channel_mask
    );
        begin
            @(negedge clk);
            din   = {channel_1, channel_0};
            write = channel_mask;
            winc  = 1'b1;
            @(posedge clk);
            #1;
            @(negedge clk);
            write = '0;
            winc  = 1'b0;
        end
    endtask

    task automatic sync_dequeue(
        input logic [DATA_W-1:0] expected_channel_0,
        input logic [DATA_W-1:0] expected_channel_1
    );
        begin
            @(negedge clk);
            rinc = 1'b1;
            @(posedge clk);
            #1;
            if (dout !== {expected_channel_1, expected_channel_0})
                $fatal(1, "sync data mismatch: got %h expected %h",
                       dout, {expected_channel_1, expected_channel_0});
            @(negedge clk);
            rinc = 1'b0;
        end
    endtask

    task automatic async_enqueue(input logic [DATA_W-1:0] value);
        begin
            @(negedge a_clk_wr);
            a_din   = value;
            a_write = 1'b1;
            a_winc  = 1'b1;
            @(posedge a_clk_wr);
            #1;
            @(negedge a_clk_wr);
            a_write = 1'b0;
            a_winc  = 1'b0;
        end
    endtask

    task automatic async_dequeue(input logic [DATA_W-1:0] expected_value);
        begin
            @(negedge a_clk_rd);
            a_rinc = 1'b1;
            @(posedge a_clk_rd);
            #1;
            if (a_dout !== expected_value)
                $fatal(1, "async data mismatch: got %h expected %h",
                       a_dout, expected_value);
            @(negedge a_clk_rd);
            a_rinc = 1'b0;
        end
    endtask

    integer index;
    integer timeout;
    logic [PTR_W:0] pointer_before_block;

    initial begin
        clk = 1'b0;
        a_clk_wr = 1'b0;
        a_clk_rd = 1'b0;

        rst_an = 1'b0;
        clear_wr = 1'b0;
        clear_rd = 1'b0;
        clear_chan_wr = '0;
        clear_chan_rd = '0;
        rinc = 1'b0;
        winc = 1'b0;
        block_rinc = 1'b0;
        block_winc = 1'b0;
        write = '0;
        din = '0;

        ll_rst_an = 1'b0;
        ll_rinc = 1'b0;
        ll_winc = 1'b0;
        ll_write = 1'b0;
        ll_clear_chan_wr = 1'b0;
        ll_clear_chan_rd = 1'b0;
        ll_din = '0;

        one_rst_an = 1'b0;
        one_rinc = 1'b0;
        one_winc = 1'b0;
        one_write = 1'b0;
        one_din = '0;

        a_rst_wr_an = 1'b0;
        a_rst_rd_an = 1'b0;
        a_clear_wr = 1'b0;
        a_clear_rd = 1'b0;
        a_rinc = 1'b0;
        a_winc = 1'b0;
        a_write = 1'b0;
        a_din = '0;

        repeat (4) @(posedge clk);
        @(negedge clk);
        rst_an = 1'b1;
        ll_rst_an = 1'b1;
        one_rst_an = 1'b1;
        a_rst_wr_an = 1'b1;
        a_rst_rd_an = 1'b1;
        repeat (2) @(posedge clk);
        #1;

        if (!empty || !almost_empty || (how_full_wr != 0) || (how_full_rd != 0))
            $fatal(1, "synchronous reset/empty status is incorrect");

        // Per-channel write enables retain the reset value on disabled lanes.
        sync_enqueue(8'hA1, 8'hB1, 2'b01);
        if ((how_full_wr != 1) || !almost_empty)
            $fatal(1, "occupancy after first synchronous enqueue is incorrect");
        sync_dequeue(8'hA1, 8'h00);

        // Clear one channel across all entries while preserving the other.
        sync_enqueue(8'h11, 8'h22, 2'b11);
        sync_enqueue(8'h33, 8'h44, 2'b11);
        @(negedge clk);
        clear_chan_wr = 2'b10;
        @(posedge clk);
        #1;
        @(negedge clk);
        clear_chan_wr = '0;
        sync_dequeue(8'h11, 8'h00);
        sync_dequeue(8'h33, 8'h00);

        // Blocking suppresses pointer movement.
        pointer_before_block = wr_ptr_bin;
        @(negedge clk);
        block_winc = 1'b1;
        write = 2'b11;
        winc = 1'b1;
        din = 16'hDEAD;
        @(posedge clk);
        #1;
        if (wr_ptr_bin != pointer_before_block)
            $fatal(1, "block_winc did not suppress pointer movement");
        @(negedge clk);
        block_winc = 1'b0;
        write = '0;
        winc = 1'b0;

        // Fill, almost-full/full flags, and rejected-write overflow pulse.
        for (index = 0; index < LENGTH; index = index + 1)
            sync_enqueue(8'h50 + index, 8'h80 + index, 2'b11);
        if (!full || !almost_full || (how_full_wr != LENGTH))
            $fatal(1, "full/almost-full status is incorrect");
        @(negedge clk);
        winc = 1'b1;
        write = 2'b11;
        din = 16'hFFFF;
        @(posedge clk);
        #1;
        if (!overflow || (how_full_wr != LENGTH))
            $fatal(1, "overflow pulse or full write rejection is incorrect");
        @(negedge clk);
        winc = 1'b0;
        write = '0;

        for (index = 0; index < LENGTH; index = index + 1)
            sync_dequeue(8'h50 + index, 8'h80 + index);
        if (!empty)
            $fatal(1, "FIFO did not become empty after synchronous drain");

        // A disabled channel retains the previous contents of the physical
        // memory slot. After wraparound, that value can come from an older
        // transaction rather than MEM_RST_VAL.
        sync_enqueue(8'hAA, 8'hFF, 2'b01);
        sync_dequeue(8'hAA, 8'h80);

        // Channel lanes can also be assembled across multiple write clocks.
        // The final winc commits the entry by advancing the shared pointer.
        @(negedge clk);
        din = {8'h00, 8'hC1};
        write = 2'b01;
        winc = 1'b0;
        @(posedge clk);
        @(negedge clk);
        din = {8'hD2, 8'h00};
        write = 2'b10;
        winc = 1'b1;
        @(posedge clk);
        @(negedge clk);
        write = '0;
        winc = 1'b0;
        sync_dequeue(8'hC1, 8'hD2);

        @(negedge clk);
        rinc = 1'b1;
        @(posedge clk);
        #1;
        if (!underflow)
            $fatal(1, "synchronous underflow pulse was not generated");
        @(negedge clk);
        rinc = 1'b0;

        // LOW_LATENCY keeps the oldest valid entry visible without rinc.
        @(negedge clk);
        ll_din = 8'hA5;
        ll_write = 1'b1;
        ll_winc = 1'b1;
        @(posedge clk);
        #1;
        if (ll_dout !== 8'hA5)
            $fatal(1, "low-latency first-word fall-through failed");
        @(negedge clk);
        ll_din = 8'hB6;
        @(posedge clk);
        #1;
        if (ll_dout !== 8'hA5)
            $fatal(1, "low-latency head changed on a second enqueue");
        @(negedge clk);
        ll_write = 1'b0;
        ll_winc = 1'b0;
        ll_rinc = 1'b1;
        @(posedge clk);
        #1;
        if (ll_dout !== 8'hB6)
            $fatal(1, "low-latency next-entry prefetch failed");

        // Consume the last entry while replacing it: occupancy stays one and
        // the new item becomes the visible head on the same edge.
        @(negedge clk);
        ll_din = 8'hC7;
        ll_write = 1'b1;
        ll_winc = 1'b1;
        ll_rinc = 1'b1;
        @(posedge clk);
        #1;
        if ((ll_dout !== 8'hC7) || (ll_how_full != 1) || ll_empty)
            $fatal(1, "low-latency simultaneous replacement failed");
        @(negedge clk);
        ll_write = 1'b0;
        ll_winc = 1'b0;
        ll_rinc = 1'b0;

        // Channel storage clear has priority over write-through when an empty
        // low-latency FIFO receives a write and pointer advance together.
        @(negedge clk);
        ll_rinc = 1'b1;
        @(posedge clk);
        @(negedge clk);
        ll_rinc = 1'b0;
        ll_din = 8'hE8;
        ll_write = 1'b1;
        ll_winc = 1'b1;
        ll_clear_chan_wr = 1'b1;
        @(posedge clk);
        #1;
        if ((ll_dout !== 8'h00) || ll_empty || (ll_how_full != 1))
            $fatal(1, "low-latency channel-clear priority failed");
        @(negedge clk);
        ll_write = 1'b0;
        ll_winc = 1'b0;
        ll_clear_chan_wr = 1'b0;
        ll_rinc = 1'b1;
        @(posedge clk);
        @(negedge clk);
        ll_rinc = 1'b0;

        // Depth-one fill, overflow protection, and drain.
        @(negedge clk);
        one_din = 8'hD8;
        one_write = 1'b1;
        one_winc = 1'b1;
        @(posedge clk);
        #1;
        if (!one_full || one_empty)
            $fatal(1, "depth-one FIFO did not become full");
        @(negedge clk);
        @(posedge clk);
        #1;
        if (!one_overflow)
            $fatal(1, "depth-one FIFO did not reject a second enqueue");
        @(negedge clk);
        one_write = 1'b0;
        one_winc = 1'b0;
        one_rinc = 1'b1;
        @(posedge clk);
        #1;
        if ((one_dout !== 8'hD8) || !one_empty)
            $fatal(1, "depth-one FIFO read/drain failed");
        @(negedge clk);
        one_rinc = 1'b0;

        // Coordinated clears reset both local pointers and their synchronized
        // remote views without exposing a multi-bit Gray transition.
        async_enqueue(8'h21);
        async_enqueue(8'h22);
        timeout = 0;
        while (a_empty && (timeout < 20)) begin
            @(posedge a_clk_rd);
            timeout = timeout + 1;
        end
        a_clear_wr = 1'b1;
        a_clear_rd = 1'b1;
        fork
            repeat (3) @(posedge a_clk_wr);
            repeat (3) @(posedge a_clk_rd);
        join
        fork
            begin @(negedge a_clk_wr); a_clear_wr = 1'b0; end
            begin @(negedge a_clk_rd); a_clear_rd = 1'b0; end
        join
        repeat (2) @(posedge a_clk_rd);
        #1;
        if (!a_empty || (a_how_full_wr != 0) || (a_how_full_rd != 0))
            $fatal(1, "coordinated asynchronous clear failed");

        // Traverse all 12 logical addresses, including both Gray skip points.
        for (index = 0; index < A_LENGTH; index = index + 1)
            async_enqueue(8'h40 + index);
        if (!a_full || (a_how_full_wr != A_LENGTH))
            $fatal(1, "asynchronous non-power-of-two FIFO did not become full");
        @(negedge a_clk_wr);
        a_winc = 1'b1;
        a_write = 1'b1;
        a_din = 8'hFF;
        @(posedge a_clk_wr);
        #1;
        if (!a_overflow)
            $fatal(1, "asynchronous overflow pulse was not generated");
        @(negedge a_clk_wr);
        a_winc = 1'b0;
        a_write = 1'b0;

        timeout = 0;
        while (a_empty && (timeout < 20)) begin
            @(posedge a_clk_rd);
            timeout = timeout + 1;
        end
        if (a_empty)
            $fatal(1, "write pointer did not cross into read clock domain");

        for (index = 0; index < A_LENGTH; index = index + 1)
            async_dequeue(8'h40 + index);
        if (!a_empty)
            $fatal(1, "asynchronous FIFO did not become empty after drain");

        @(negedge a_clk_rd);
        a_rinc = 1'b1;
        @(posedge a_clk_rd);
        @(negedge a_clk_rd);
        a_rinc = 1'b0;

        timeout = 0;
        while (!a_underflow && (timeout < 20)) begin
            @(posedge a_clk_wr);
            #1;
            timeout = timeout + 1;
        end
        if (!a_underflow)
            $fatal(1, "underflow event did not cross into write clock domain");

        $display("Channelized FIFO smoke test PASSED");
        $finish;
    end
endmodule

`default_nettype wire
