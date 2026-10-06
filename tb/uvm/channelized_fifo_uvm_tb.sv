`timescale 1ns/1ps
`default_nettype none

module channelized_fifo_uvm_tb;
    import uvm_pkg::*;
    import channelized_fifo_uvm_cfg_pkg::*;
    import channelized_fifo_uvm_pkg::*;

    channelized_fifo_if vif();

    channelized_fifo #(
        .DATA_W       (DATA_W),
        .PTR_W        (PTR_W),
        .LENGTH       (LENGTH),
        .CHANS        (CHANS),
        .ASYNCHRONOUS (ASYNCHRONOUS),
        .AE_LIMIT     (AE_LIMIT),
        .AF_LIMIT     (AF_LIMIT),
        .LOW_LATENCY  (LOW_LATENCY),
        .MEM_RST_VAL  (MEM_RST_VAL),
        .WR_PTR_DEF   (PTR_DEF),
        .RD_PTR_DEF   (PTR_DEF)
    ) dut (
        .clk_wr        (vif.clk_wr),
        .clk_rd        (vif.clk_rd),
        .rst_wr_an     (vif.rst_wr_an),
        .rst_rd_an     (vif.rst_rd_an),
        .clear_wr      (vif.clear_wr),
        .clear_rd      (vif.clear_rd),
        .clear_chan_wr (vif.clear_chan_wr),
        .clear_chan_rd (vif.clear_chan_rd),
        .rinc          (vif.rinc),
        .winc          (vif.winc),
        .block_rinc    (vif.block_rinc),
        .block_winc    (vif.block_winc),
        .write         (vif.write),
        .din           (vif.din),
        .dout          (vif.dout),
        .full          (vif.full),
        .almost_full   (vif.almost_full),
        .empty         (vif.empty),
        .almost_empty  (vif.almost_empty),
        .how_full_wr   (vif.how_full_wr),
        .how_full_rd   (vif.how_full_rd),
        .underflow     (vif.underflow),
        .overflow      (vif.overflow),
        .wr_ptr_bin    (vif.wr_ptr_bin),
        .rd_ptr_bin    (vif.rd_ptr_bin)
    );

    channelized_fifo_assertions #(
        .PTR_W        (PTR_W),
        .LENGTH       (LENGTH),
        .ASYNCHRONOUS (ASYNCHRONOUS),
        .LOW_LATENCY  (LOW_LATENCY),
        .AE_LIMIT     (AE_LIMIT),
        .AF_LIMIT     (AF_LIMIT),
        .PTR_DEF      (PTR_DEF)
    ) assertions (
        .clk_wr(vif.clk_wr), .clk_rd(vif.clk_rd),
        .rst_wr_an(vif.rst_wr_an), .rst_rd_an(vif.rst_rd_an),
        .clear_wr(vif.clear_wr), .clear_rd(vif.clear_rd),
        .winc(vif.winc), .rinc(vif.rinc),
        .block_winc(vif.block_winc), .block_rinc(vif.block_rinc),
        .full(vif.full), .empty(vif.empty),
        .almost_full(vif.almost_full), .almost_empty(vif.almost_empty),
        .overflow(vif.overflow), .underflow(vif.underflow),
        .how_full_wr(vif.how_full_wr), .how_full_rd(vif.how_full_rd),
        .wr_ptr_bin(vif.wr_ptr_bin), .rd_ptr_bin(vif.rd_ptr_bin)
    );

    always #(WR_HALF_NS * 1ns) vif.clk_wr = ~vif.clk_wr;

    initial begin
        #(RD_PHASE_NS * 1ns);
        forever #(RD_HALF_NS * 1ns) vif.clk_rd = ~vif.clk_rd;
    end

    initial begin
        uvm_report_server report_server;
        uvm_config_db#(virtual channelized_fifo_if)::set(null, "*", "vif", vif);
        uvm_top.finish_on_completion = 1'b0;
        run_test();
        report_server = uvm_report_server::get_server();
        if ((report_server.get_severity_count(UVM_ERROR) != 0) ||
            (report_server.get_severity_count(UVM_FATAL) != 0))
            $fatal(1, "FIFO UVM test failed");
        $display("FIFO UVM test PASSED");
        $finish;
    end

    initial begin
        #2ms;
        $fatal(1, "FIFO UVM watchdog timeout");
    end
endmodule

`default_nettype wire

