module GFIFO_CORE #(
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
    // Input Write Side
    input                   clk_wr,         // Rising edge input/write clock
    input                   rst_wr_an       // Asynchronous reset safe to write clock
    input                   clear_wr,       // Synchronous clear
    input   [CHANS-1:0]     write,          // Channel write enable (no ptr update)
    input                   winc,           // Write-increment (pointer update)
    input                   block_winc,     // Block all winc signals (for test)
    input   [DATA_W*CHANS-1:0] din,         // Write input data
    output                  full,           // Indicates the FIFO is full
    output                  almost_full,    // Indicates the FIFO is almost full
    output  reg             underflow,      // Synchronized in write domain

    // Output Read Side
    input                   clk_rd,         // Rising edge output/read clock
    input                   rst_rd_an,      // Asynchronous reset safe to read clock
    input                   clear_rd,       // Synchronous clear
    input   [CHANS-1:0]     clear_chan_wr,  // Channel enables used as synchronous clear a channel (Write clock domain)
    input   [CHANS-1:0]     clear_chan_rd,  // Channel enables used as synchronous clear a channel (Read clock domain)
    input                   rinc,           // Read-increment (pointer update)
    input                   block_rinc,     // Block all rinc signals (for test)
    output  [DATA_W*CHANS-1:0] dout,        // Output read data
    output                  empty,          // Indicates FIFO is empty
    output                  almost_empty,   // Indicates FIFO is almost empty
    output  [PTR_W:0]       how_full_wr,    // How full is the FIFO for write side
    output  [PTR_W:0]       how_full_rd,    // How full is the FIFO for read side
    output  [PTR_W:0]       wr_ptr_bin,     // Binary write pointer
    output  [PTR_W:0]       rd_ptr_bin      // Binary read pointer
);


    /////////////////////////////////////////////////////////////////
    // Internal Signals
    /////////////////////////////////////////////////////////////////
    wire                    valid_winc;     // Valid winc (not blocked or full)
    wire                    valid_rinc;     // Valid rinc (not blocked or empty)
    wire    [CHANS-1:0]     valid_write;    
    wire    [PTR_W:0]       wr_ptr_gray;    // Gray-coded write pointer
    wire    [PTR_W:0]       rd_ptr_gray;    // Gray-coded read pointer
    wire    [PTR_W:0]       wr_ptr_retime;  // Write pointer retiming onto clk_rd
    wire    [PTR_W:0]       rd_ptr_retime;  // Read pointer retiming onto clk_wr
    wire    [PTR_W:0]       wr_ptr_safe;    // Write pointer safe to clk_rd
    wire    [PTR_W:0]       rd_ptr_safe;    // Read pointer safe to clk_wr
    wire    [PTR_W:0]       rd_ptr_bin_next;// Next binary raed pointer value
    wire                    going_empty;    // FIFO will go empty on next rinc
    wire                    masked_rinc;    // Masked rinc (not blocked)
    reg     [PTR_W-1:0]     len1_status;    // Status of FIFO data for length 1
    wire    [PTR_W-1:0]     mem_rd_ptr;     // Read pointer value for memory storage
    wire                    mem_read;       // Update memory output d-types
    wire                    okay_to_write;  // Indicate okay to write (i.e. not full)
    reg                     okay_to_write_rt;   // okay_to_write retimed on clk_wr negedge

    wire    [PTR_W:0]       start;          // start valeu of section of binary count to be bypassed for even lengths less than 2^N in asynchronous mode
    wire    [PTR_W:0]       stp;            // stop value of section of binary count to be bypassed for even lengths less than 2^N in asynchronous mode
    wire    [PTR_W:0]       wr_ptr_bin_i;   // binary write pointer retimed to clk_rd
    wire    [PTR_W:0]       wr_ptr_binary;  // binary write pointer
    wire    [PTR_W:0]       rd_ptr_bin_i;   // binary read pointer retimed to clk_wr
    wire    [PTR_W:0]       rd_ptr_binary;  // binary read pointer

    wire                    empty_safe;     // FIFO empty indicator, safe for clk_wr
    wire                    full_safe;      // FIFO full indicator, safe for clk_rd
    reg                     underflow_int;
    reg                     underflow_int_r;
    reg                     underflow_sync;

    localparam POWER2_LEN = ((1<<PTR_W)==LENGTH);   // indicates LENGTH is 2^PTR_W

    /////////////////////////////////////////////////////////////////////
    // Write clock domain
    /////////////////////////////////////////////////////////////////////
    
    // Okay to write if not full, in synchronous, low-latency mode
    // Okay to write even when full as long as there is read at the same time
    assign okay_to_write = (~full | (full & rinc & (ASYNCHRONOUS==0) & (LOW_LATENCY==1)));

    // In synchronous, non-low-latency mode we support input and output on synchronous clocks running at different rates,
    // as the memory used uses clock-gated latches, there is a falling edge sensitivity here, as such we capture the
    // okay_to_write signal on the falling edge of the write clock to ensure consistency between the memory update and
    // the pointer update
    generate 
        if ((ASYNCHRONOUS==1) || (LOW_LATENCY==1)) begin: gen_ok2wr_nort
            always @* okay_to_write_rt = okay_to_write;
        end else begin: gen_ok2wr_rt
            always @(negedge clk_wr or negedge rst_wr_an)
                if (rst_wr_an == 1'b0)
                    okay_to_write_rt <= 1'b0;
                else
                    okay_to_write_rt <= okay_to_write;
        end
    endgenerate

    // Valid write when we get a write and okay to write
    // In SYNCHRONOUS mode full may be indicated when it is still safe to write to the memory
    assign valid_write = ASYNCHRONOUS? write & {CHANS{okay_to_write}} : write;

    // Valid winc when we get a winc, are not blocked and okay to write
    assign valid_winc = winc & ~block_winc & okay_to_write_rt;

    generate
        if (LENGTH == 1) begin: gen_wr_len_eq1
            // Length == 1 is a special case, we only want a d-type for memory and the flags become very simple.
            // There are no pointers (because there is only one value stored) but we do need to register whether we are full or empty
            always @(posedge clk_wr or negedge rst_wr_an)
                if (rst_wr_an == 1'b0)
                    len1_status <= 1'b0;
                else
                    if (clear_wr)
                        len1_status <= 1'b0;
                    else if (valid_winc)
                        len1_status <= 1'b1;
                    else if (valid_rinc)
                        len1_status <= 1'b0;
            assign full = len1_status;
            assign almost_full = full;
            assign wr_ptr_bin = 1'b0;
            assign wr_ptr_gray = 1'b0;
        end else begin: gen_wr_len_gt1
            // Write pointer
            GFIFO_POINTER #(
                .PTR_W(PTR_W),
                .LENGTH(LENGTH),
                .ASYNCHRONOUS(ASYNCHRONOUS),
                .PTR_DEF(WR_PTR_DEF)
            ) GFIFO_POINTER_WRITE (
                .clk(clk_wr),
                .rst_an(rst_wr_an),
                .clear(clear_wr),
                .enable(valid_winc),
                .ptr_binary(wr_ptr_bin),
                .ptr_gray(wr_ptr_gray),
                .ptr_bin_next()
            );

            // Calculate full status, we know we are full when the LSBs of the oversized pointers are equal but the MSBs
            // are different
            assign full = (wr_ptr_bin[PTR_W-1:0] == rd_ptr_safe[PTR_W-1:0]) && (wr_ptr_bin[PTR_W] != rd_ptr_safe[PTR_W]);

            // Calculate empty status, we know we are empty when the LSBs and MSB of the oversized pointers are equal
            assign empty_safe = (rd_ptr_safe == wr_ptr_bin);

            // Calculate how full we are using signals safe to clk_wr
            assign how_full_wr = ((rd_ptr_safe[PTR_W-1:0] > wr_ptr_bin[PTR_W-1:0]) || (full == 1'b1)) ? 
                                    LENGTH - (rd_ptr_safe[PTR_W-1:0] - wr_ptr_bin[PTR_W-1:0]) :
                                    (wr_ptr_bin[PTR_W-1:0] - rd_ptr_safe[PTR_W-1:0]);
        
            assign almost_full = (how_full_wr >= $unsigned(LENGTH-AF_LIMIT)) & ~empty_safe;
        end
    endgenerate


    ////////////////////////////////////////////////////////////////
    // Both clock domains
    ///////////////////////////////////////////////////////////////
    // Read pointer clocked across to the write pointer domain in asynchronous mode
    generate
        if (ASYNCHRONOUS == 1) begin: gen_rd_retime
            for (genvar i = 0; i <= PTR_W; i++) begin: gen_rd_sync_loop
                // Note that these synchronizer modules are used partially because of their ability to model jitter on 
                // the CDC transfer. This caused a problem in the DAC subsys which was overcome by creating a 
                // local version of the synchronizer which can sync the whole pointer as a bus and not as individual signals
                if (WR_CLK_5050 == 1) begin: gen_clk_wr_5050
                    // clk_wr has 50:50 duty cycle so can use neg-pos CDC
                    sync_2dff_fr #(
                        .DISABLE_CDC_JITTER(0)
                    ) sync_2dff_fr #(
                        .data_source (rd_ptr_gray[i]),  // Single bit connected to each instance
                        .clk_dest (clk_wr),             
                        .rst_clk_dest_b (rst_wr_an),    
                        .data_dest (rd_ptr_retime[i])   
                    );
                end
                else begin: gen_clk_wr_not_5050
                    // clk_wr does not have 50:50 duty cycle so use pos-pos CDC
                    sync_2dff #(
                        .DISABLE_CDC_JITTER(0)
                    ) sync_2dff_rd_ptr (
                        .data_source (rd_ptr_gray[i]), // Single bit connected to each instance
                        .clk_dest (clk_wr),
                        .rst_clk_dest_b (rst_wr_an),
                        .data_dest (rd_ptr_retime[i])
                    );
                end
            end

            assign rd_ptr_safe = rd_ptr_binary;
        end else begin: gen_rd_no_retime
            assign rd_ptr_safe = rd_ptr_bin;
            assign rd_ptr_retime = 0;
        end
    endgenerate

    // Memory
    GFIFO_MEMORY #(
        .DATA_W(DATA_W),
        .PTR_W(PTR_W),
        .ADDR_W(ADDR_W),
        .LENGTH(LENGTH),
        .CHANS(CHANS),
        .NEWEST_DATA(NEWEST_DATA),
        .MEM_RST_VAL(MEM_RST_VAL)
    ) GFIFO_MEMORY_I0 (
        .clk_wr(clk_wr),
        .rst_wr_an(rst_wr_an),
        .din(din),
        .write(valid_write),
        .wptr(wr_ptr_bin[PTR_W-1:0]),
        .clk_rd(clk_rd),
        .rst_rd_an(rst_rd_an),
        .read(mem_read),
        .rptr(mem_rd_ptr),
        .clear_wr(clear_chan_wr),
        .clear_rd(clear_chan_rd),
        .dout(dout)
    );

    // Write pointer clocked across to the read pointer domain in asynchronous mode
    generate
        if (ASYNCHRONOUS == 1) begin: gen_wr_retime
            for (genvar i=0; i<=PTR_W; i++) begin: gen_wr_sync_loop
                if (RD_CLK_5050 == 1) begin: gen_clk_rd_5050
                    // clk_rd has 50:50 duty cycle so can use neg-pos CDC
                    sync_2dff_fr #(
                        .DISABLE_CDC_JITTER(0)
                    ) sync_2dff_wr_ptr (
                        .data_source(wr_ptr_gray[i]),
                        .clk_dest(clk_rd),
                        .rst_clk_dest_b(rst_rd_an),
                        .data_dest(wr_ptr_retime[i])
                    );
                end
                else begin: gen_clk_rd_not_5050
                    // clk_rd does not have 50:50 duty cycle so use pos-pos CDC
                    sync_2dff #(
                        .DISABLE_CDC_JITTER(0)
                    ) sync_2dff_wr_ptr (
                        .data_source(wr_ptr_gray[i]),
                        .clk_dest(clk_rd),
                        .rst_clk_dest_b(rst_rd_an),
                        .data_dest(wr_ptr_retime[i])
                    );
                end
            end
            assign wr_ptr_safe = wr_ptr_binary;
        end else begin: gen_wr_no_retime
            assign wr_ptr_safe = wr_ptr_bin;
            assign wr_ptr_retime = 0;
        end
    endgenerate

    // Calculate start and stop values for binary counter bypass
    assign start = $unsigned(LENGTH>>1);
    assign stp = $unsigned(1<<PTR_W) - start;

    // Binary write pointer
    assign wr_ptr_bin_i = gray_to_binary(wr_ptr_retime, ASYNCHRONOUS);
    assign wr_ptr_binary = (wr_ptr_bin_i[PTR_W-1:0] >= start[PTR_W-1:0]) && (POWER2_LEN==0) && (ASYNCHRONOUS==1) ?
                            wr_ptr_bin_i - stp + start : wr_ptr_bin_i;

    // Binary read pointer
    assign rd_ptr_bin_i = gray_to_binary(rd_ptr_retime, ASYNCHRONOUS);
    assign rd_ptr_binary = (rd_ptr_bin_i[PTR_W-1:0] >= start[PTR_W-1:0]) && (POWER2_LEN==0) && (ASYNCHRONOUS==1) ?
                            rd_ptr_bin_i - stp + start : rd_ptr_bin_i;

    ///////////////////////////////////////////////////////////////////
    // Read clock domain
    ///////////////////////////////////////////////////////////////////
    // Masked rinc is rinc when not blocked
    assign masked_rinc = rinc & ~block_rinc;

    // Valid rinc when we get a rinc, are not empty and are not blocked
    assign valid_rinc = masked_rinc & ~empty;

    generate
        if (LENGTH == 1) begin: gen_rd_len_eq1
            // Length == 1 is a special case, we just want a d-type for memory and the flags become very simple
            assign mem_read = |valid_write;
            assign mem_rd_ptr = 1'b0;
            assign empty = ~full;
            assign almost_empty = empty;
            assign rd_ptr_bin = 1'b0;
            assign rd_ptr_gray = 1'b0;
        end else begin: gen_rd_len_gt1
            // The memory read depends on which mode we're in, this signal will bring a new read value to the output, 
            // there are three possibilities:
            // 
            //      1. Sync/Async readback (LOW_LATENCY=0):
            //          The simplest case, we just update the output when we receive a valid rinc signal
            //
            //      2. Sync (LOW_LATENCY=1):
            //          If we are in low-latency mode we need to update the memory output data if we get a winc 
            //          when empty, a rinc when not about to go empty or a rinc and winc at the same time when going empty.
            if (LOW_LATENCY == 1) begin: gen_low_latency
                // Read next pointer if we get a rinc and we are not going empty,
                // otherwise read the current pointer if we get a new piece of write data and we are currently empty
                // for single-cycle reads.
                // In async mode we have to use a transition on the empty flag to determine whether we have a new 
                // piece of data.

                // We do not support LOW_LATENCY=1 with ASYNCHRONOUS=1, the generate
                // if/else is only here to make sure that no logic is generated
                // if the used tries to do this (should also get picked up by  the assertions at the bottom of this file)
                if (ASYNCHRONOUS == 0) begin: get_sc_sync_read
                    // We need to calculate "going_empty" in single-cycle read mode as we don't want to update the memory
                    // output when there is no valid data to update them with
                    assign going_empty = (rd_ptr_bin_next == wr_ptr_safe);

                    // If we are empty then we only ever read if a write has happened, in which case we always read the
                    // current read-pointer value. All other reads for single-cycle readback are of the next value +crop
                    // MSB
                    assign mem_rd_ptr = empty ? rd_ptr_bin[PTR_W-1:0] : rd_ptr_bin_next[PTR_W-1:0];

                    // We read the next pointer in any of the following conditions:
                    //      - We get a valid rinc and we are not about to go empty
                    //      - We are currently empty and are writing
                    //      - We get any rinc at the same time as a valid write
                    // NB: read signal is ignored in single-cycle read mode
                    assign mem_read = (valid_rinc & ~going_empty) | (valid_winc & empty) | (valid_winc & masked_rinc);
                end else begin: gen_sc_async_read
                    // LOW-LATENCY READS ARE NOT SUPPORTED IN ASYNCHRONOUS MODE
                end
            end else begin: gen_not_low_latency
                // Read current read pointer value so it is available on the next cycle in two-cycle read mode +crop MSB
                assign mem_read = valid_rinc;
                assign mem_rd_ptr = rd_ptr_bin[PTR_W-1:0];
            end

            // Read pointer
            GFIFO_POINTER #(
                .PTR_W(PTR_W),
                .LENGTH(LENGTH),
                .ASYNCHRONOUS(ASYNCHRONOUS),
                .PTR_DEF(RD_PTR_DEF)
            ) GFIFO_POINTER_READ (
                .clk(clk_rd),
                .rst_an(rst_rd_an),
                .clear(clear_rd),
                .enable(valid_rinc),
                .ptr_binary(rd_ptr_bin),
                .ptr_gray(rd_ptr_gray),
                .ptr_bin_next(rd_ptr_bin_next)
            );

            // Calculate empty status, we know we are empty when the LSBs and MSB of the overszed pointers are equal
            assign empty = (rd_ptr_bin == wr_ptr_safe);

            // Calculate full status, we know we are full when the LSBs of the oversized pointers are equal but the MSBs
            // are different
            assign full_safe = (wr_ptr_safe[PTR_W-1:0] == rd_ptr_bin[PTR_W-1:0]) && (wr_ptr_safe[PTR_W] != rd_ptr_bin[PTR_W]);

            // Calculate how full we are using signals safe to clk_rd
            assign how_full_rd = ((rd_ptr_bin[PTR_W-1:0] > wr_ptr_safe[PTR_W-1:0]) || (full_safe == 1'b1)) ?
                                    LENGTH - (rd_ptr_bin[PTR_W-1:0] - rd_ptr_bin[PTR_W-1:0]) :
                                    (wr_ptr_safe[PTR_W-1:0] - rd_ptr_bin[PTR_W-1:0]);
            assign almost_empty = (how_full_rd <= AE_LIMIT) & ~full_safe;
        end
    endgenerate



    /////////////////////////////////////////////////////////////////////
    // Functions
    /////////////////////////////////////////////////////////////////////
    // Converts the data from Gray to binary when enabled. When disabled it passes the value unchanged.
    function [PTR_W:0] gray_to_binary;
        input [PTR_W:0] gray;
        input           enable;
        reg             mask;
        integer         k;
        begin
            if (enable == 1'b1) begin
                mask = {1'b0};
                for (k = PTR_W; k >= 0; k = k - 1) begin
                    mask = mask ^ gray[k];
                    gray_to_binary[k] = mask;
                end
            end else
                gray_to_binary = gray;
            end
        end
    endfunction // gray_to_binary

    
    // Generate errors when underflow or overflow occurs
    // Need to be able to switch this on and off
    always @(posedge clk_rd or negedge rst_rd_an) begin
        if (rst_rd_an == 1'b0) begin
            underflow_int <= 1'b0;
            underflow_int_r <= 1'b0;
        end
        else begin
            if (rinc & empty) begin
                underflow_int <= 1'b1;
                underflow_int_r <= underflow_int;
            end
            else begin
                underflow_int_r <= underflow_int;
                if (underflow_int_r)
                    underflow_int <= 1'b0;
            end
        end
    end

    always @(posedge clk_wr or negedge rst_wr_an) begin
        if (rst_wr_an == 1'b0) begin
            underflow_sync <= 1'b0;
            underflow <= 1'b0;
        end
        else begin
            underflow_sync <= underflow_int;
            underflow <= underflow_sync;
        end
    end

endmodule
