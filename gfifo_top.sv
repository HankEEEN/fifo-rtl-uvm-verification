module gfifo_top #(
    parameter DATA_W        = 24,   // Width of input/output data
    parameter PTR_W         =  4,   // Wdith of the pointer 
    parameter LENGTH        = 12,   // Length of FIFO, even value for async
    parameter CHANS         =  8,   // Number of channels
    parameter ADDR_W        =  3,   // Width of the channel address
    parameter ASYNCHRONOUS  =  1,   // Enable asynchronous operation
    parameter AE_LIMIT      =  1,   // Limit for almost_empty flag
    parameter AF_LIMIT      = 13,   // Limit for almost_full flag
    parameter NEWEST_DATA   =  1,   // 0: take previous data to be read in the case of read co-inciding with rinc (DATA IF RX)
                                    // 1: enable newest data to be read (DATA IF TX)
    parameter RD_CLK_5050   =  0,   // 1: clk_rd has 50:50 duty cycle, 0: clk_rd has undefined duty cycle
    parameter WR_CLK_5050   =  0,   // 1: clk_wr has 50:50 duty cycle, 0: clk_Wr has undefined duty cycle
    parameter LOW_LATENCY   = -1,   // Enable low-latency mode (sync only)
    parameter MEN_RST_VAL   =  0,   // Reset valud for data
    parameter WR_PTR_DEF    =  0,   // Default write pointer value
    parameter RD_PTR_DEF    =  0,   // Default read pointer value        
) (
    /*AUTOINPUTS*/
    input               block_rinc,
    input               block_winc,
    input   [CHANS-1:0] clear_chan_rd,
    input   [CHANS-1:0] clear_chan_wr,
    input               clear_rd,
    input               clear_wr,
    input               clk_rd,
    input               clk_wr,
    input   [DATA_W*CHANS-1:0] din,
    input               rinc,
    input               rst_rd_an,
    input               rst_wr_an,
    input               winc,
    input   [CHANS-1:0] write,

    /*AUTOOUTPUT*/
    output              almost_empty,
    output              almost_full,
    output   [DATA_W*CHANS-1:0] dout,
    output              empty,
    output              full,
    output  [PTR_W:0]   how_full_rd,
    output  [PTR_W:0]   how_full_wr,
    output  [PTR_W:0]   rd_ptr_bin,
    output              underflow,
    output  [PTR_W:0]   wr_ptr_bin
);

gfifo_core #(
    /*AUTOINSTPARAM*/
    .DATA_W             (DATA_W),
    .PTR_W              (PTR_W),
    .LENGTH             (LENGTH),
    .CHANS              (CHANS),
    .ADDR_W             (ADDR_W),
    .ASYNCHRONOUS       (ASYNCHRONOUS),
    .AE_LIMIT           (AE_LIMIT),
    .AF_LIMIT           (AF_LIMIT),
    .NEWEST_DATA        (NEWEST_DATA),
    .RD_CLK_5050        (RD_CLK_5050),
    .WR_CLK_5050        (WR_CLK_5050),
    .LOW_LATENCY        (LOW_LATENCY),
    .MEM_RST_VAL        (MEM_RST_VAL),
    .WR_PTR_DEF         (WR_PTR_DEF),
    .RD_PTR_DEF         (RD_PTR_DEF)
) u_gfifo_core (
    // Outputs
    .full               (full),
    .almost_full        (almost_full),
    .underflow          (underflow),
    .dout               (dout[DATA_W*CHANS-1:0]),
    .empty              (empty),
    .almost_empty       (almost_empty),
    .how_full_wr        (how_full_wr[PTR_W:0]),
    .how_full_rd        (how_full_rd[PTR_W:0]),
    .wr_ptr_bin         (wr_ptr_bin[PTR_W:0]),
    .rd_ptr_bin         (rd_ptr_bin[PTR_W:0]),
    // Inputs
    .clk_wr             (clk_wr),
    .rst_wr_an          (rst_wr_an),
    .clear_wr           (clear_wr),
    .write              (write[CHANS-1:0]),
    .winc               (winc),
    .block_winc         (block_winc),
    .din                (din[DATA_W*CHANS-1:0]),
    .clk_rd             (clk_rd),
    .rst_rd_an          (rst_rd_an),
    .clear_rd           (clear_rd),
    .clear_chan_wr      (clear_chan_wr[CHANS-1:0]),
    .clear_chan_rd      (clear_chan_rd[CHANS-1:0]),
    .rinc               (rinc),
    .block_rinc         (block_rinc)
);


endmodule