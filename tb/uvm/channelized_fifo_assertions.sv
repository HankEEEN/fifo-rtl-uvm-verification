`timescale 1ns/1ps
`default_nettype none

module channelized_fifo_assertions #(
    parameter int PTR_W = 2,
    parameter int LENGTH = 4,
    parameter bit ASYNCHRONOUS = 1'b0,
    parameter bit LOW_LATENCY = 1'b0,
    parameter int unsigned AE_LIMIT = 1,
    parameter int unsigned AF_LIMIT = 1,
    parameter logic [PTR_W:0] PTR_DEF = '0
) (
    input wire clk_wr,
    input wire clk_rd,
    input wire rst_wr_an,
    input wire rst_rd_an,
    input wire clear_wr,
    input wire clear_rd,
    input wire winc,
    input wire rinc,
    input wire block_winc,
    input wire block_rinc,
    input wire full,
    input wire empty,
    input wire almost_full,
    input wire almost_empty,
    input wire overflow,
    input wire underflow,
    input wire [PTR_W:0] how_full_wr,
    input wire [PTR_W:0] how_full_rd,
    input wire [PTR_W:0] wr_ptr_bin,
    input wire [PTR_W:0] rd_ptr_bin
);
    localparam logic [PTR_W:0] LENGTH_VALUE = (PTR_W+1)'(LENGTH);
    localparam logic [PTR_W:0] AE_VALUE = (PTR_W+1)'(AE_LIMIT);
    localparam logic [PTR_W:0] AF_VALUE = (PTR_W+1)'(LENGTH-AF_LIMIT);

    property p_wr_known;
        @(posedge clk_wr) disable iff (!rst_wr_an)
            !$isunknown({full, almost_full, overflow,
                         how_full_wr, wr_ptr_bin});
    endproperty
    assert property (p_wr_known)
        else $fatal(1, "FIFO assertion: unknown write-domain output");

    property p_rd_known;
        @(posedge clk_rd) disable iff (!rst_rd_an)
            !$isunknown({empty, almost_empty, underflow,
                         how_full_rd, rd_ptr_bin});
    endproperty
    assert property (p_rd_known)
        else $fatal(1, "FIFO assertion: unknown read-domain output");

    property p_wr_bounded;
        @(posedge clk_wr) disable iff (!rst_wr_an)
            how_full_wr <= LENGTH_VALUE;
    endproperty
    assert property (p_wr_bounded)
        else $fatal(1,
            "FIFO assertion: write occupancy=%0d exceeded depth=%0d, wr_ptr=%0d",
            how_full_wr, LENGTH, wr_ptr_bin);

    property p_rd_bounded;
        @(posedge clk_rd) disable iff (!rst_rd_an)
            how_full_rd <= LENGTH_VALUE;
    endproperty
    assert property (p_rd_bounded)
        else $fatal(1,
            "FIFO assertion: read occupancy=%0d exceeded depth=%0d, rd_ptr=%0d",
            how_full_rd, LENGTH, rd_ptr_bin);

    property p_full_consistent;
        @(posedge clk_wr) disable iff (!rst_wr_an)
            full == (how_full_wr == LENGTH_VALUE);
    endproperty
    assert property (p_full_consistent)
        else $fatal(1, "FIFO assertion: full disagrees with write occupancy");

    property p_empty_consistent;
        @(posedge clk_rd) disable iff (!rst_rd_an)
            empty == (how_full_rd == '0);
    endproperty
    assert property (p_empty_consistent)
        else $fatal(1, "FIFO assertion: empty disagrees with read occupancy");

    property p_almost_full_consistent;
        @(posedge clk_wr) disable iff (!rst_wr_an)
            almost_full == ((AF_LIMIT == LENGTH) ||
                            (how_full_wr >= AF_VALUE));
    endproperty
    assert property (p_almost_full_consistent)
        else $fatal(1,
            "FIFO assertion: almost_full disagrees with write occupancy");

    property p_almost_empty_consistent;
        @(posedge clk_rd) disable iff (!rst_rd_an)
            almost_empty == (how_full_rd <= AE_VALUE);
    endproperty
    assert property (p_almost_empty_consistent)
        else $fatal(1,
            "FIFO assertion: almost_empty disagrees with read occupancy");

    property p_blocked_write_holds;
        @(posedge clk_wr) disable iff (!rst_wr_an || clear_wr)
            (block_winc || (full && !(LOW_LATENCY && !ASYNCHRONOUS &&
              rinc && !block_rinc && !empty))) |=> $stable(wr_ptr_bin);
    endproperty
    assert property (p_blocked_write_holds)
        else $fatal(1, "FIFO assertion: rejected write advanced pointer");

    property p_blocked_read_holds;
        @(posedge clk_rd) disable iff (!rst_rd_an || clear_rd)
            (block_rinc || empty) |=> $stable(rd_ptr_bin);
    endproperty
    assert property (p_blocked_read_holds)
        else $fatal(1, "FIFO assertion: rejected read advanced pointer");

    property p_write_clear_default;
        @(posedge clk_wr) disable iff (!rst_wr_an)
            clear_wr |=> (wr_ptr_bin == PTR_DEF);
    endproperty
    assert property (p_write_clear_default)
        else $fatal(1, "FIFO assertion: write clear did not restore pointer");

    property p_read_clear_default;
        @(posedge clk_rd) disable iff (!rst_rd_an)
            clear_rd |=> (rd_ptr_bin == PTR_DEF);
    endproperty
    assert property (p_read_clear_default)
        else $fatal(1, "FIFO assertion: read clear did not restore pointer");
endmodule

`default_nettype wire
