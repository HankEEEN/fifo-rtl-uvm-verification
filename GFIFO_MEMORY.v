module GFIFO_MEMORY #(
    parameter DATA_W = -1,  // Data width
    parameter PTR_W = -1,   // Pointer width
    parameter ADDR_W = -1,  // Channel address width
    parameter LENGTH = -1,  // Length of FIFO
    parameter CHANS = -1,   // Number of channels
    parameter NEWEST_DATA = 0,  // 0: take previous data to be read in the case of read co-inciding with rinc (DATA IF RX)
                                // 1: enable newest data to be read (DATA IF TX)
    parameter MEM_RST_VAL = -1  // Reset value for data
) (
    //////////////////////////////////////////////////////
    // Clocks and resets
    //////////////////////////////////////////////////////
    input                   clk_wr,     // Rising edge clock for write
    input                   rst_wr_an,  // Asynchronous, active low reset
    input                   clk_rd,     // Rising edge clock for read
    input                   rst_rd_an,  // Asynchronous, active low reset

    //////////////////////////////////////////////////////
    // Inputs
    //////////////////////////////////////////////////////
    input [DATA_W*CHANS-1:0]    din,    // Input/write data
    input [CHANS-1:0]           write,  // Enable a write
    input [PTR_W-1:0]           wptr,   // Write pointer address
    input                       read,   // Enable a read (update output register)
    input [PTR_W-1:0]           rptr,   // Read pointer address
    input [CHANS-1:0]           clear_wr,   // Synchronous clear for o/p flops
    input [CHANS-1:0]           clear_rd,   // Synchronous clear for o/p flops

    //////////////////////////////////////////////////////
    // Outputs
    //////////////////////////////////////////////////////
    output [DATA_W*CHANS-1:0]   dout        // Separate output data for each channel
);

    //////////////////////////////////////////////////////
    // Internal Signals
    //////////////////////////////////////////////////////
    reg [(LENGTH-1):0][(CHANS-1):0][DATA_W-1:0] mem;    // Main data storage
    wire [LENGTH-1:0] ptr_match;                        // Write pointer address decode
    wire                clk_gated_rd;                   // Gated clock for output d-types
    reg [(CHANS-1):0][DATA_W-1:0] chan_mux;             // Current read data for each chan
    wire                read_clk_en;

    //////////////////////////////////////////////////////
    // Main code
    //////////////////////////////////////////////////////
    // Generate latches and clock gates
    genvar CHAN;
    genvar PTR;

    for (PTR=0; PTR<LENGTH; PTR = PTR + 1) begin: gen_ptr_enas
        // Generate the address decode for write pointer
        assign ptr_match[PTR] = (wptr[PTR_W-1:0] == PTR[PTR_W-1:0]);
    end

    for (CHAN=0; CHAN<CHANS; CHAN=CHAN+1) begin: gen_chans
        if ((LENGTH == 1) && (CHANS == 1)) begin: gen_ptrs_len_eq1
            // Don't need any latch sotrage if the FIFO is of length 1
            always @(*)
                mem[0][CHAN] = din;
        end else begin: gen_ptrs_len_gt1
            for (PTR = 0; PTR < LENGTH; PTR = PTR + 1) begin: gen_ptrs
                wire clk_gated_wr;
                wire clk_enable;

                // Generate enable for this channel and pointer location
                assign clk_enable = ptr_match[PTR] & write[CHAN];

                always @(posedge clk_wr or negedge rst_wr_an) begin
                    if (!rst_wr_an)
                        mem[PTR][CHAN] <= MEM_RST_VAL;
                    else if (clear_wr[CHAN])
                        mem[PTR][CHAN] <= MEM_RST_VAL;
                    else if (clk_enable)
                        mem[PTR][CHAN] <= din[DATA_W*CHAN+:DATA_W];
                end
            end
        end

        always @(posedge clk_rd or negedge rst_rd_an) begin
            if (rst_rd_an == 1'b0)
                chan_mux[CHAN] <= MEM_RST_VAL;
            else if (clear_rd[CHAN])
                chan_mux[CHAN] <= MEM_RST_VAL;
            else begin
                if (read == 1'b1) begin
                    chan_mux[CHAN] <= mem[rptr][CHAN];
                end
            end
        end

        if (NEWEST_DATA == 0) begin
            // take previous data to be read in the case of read co-inciding with rinc
            assign dout[DATA_W*CHAN+:DATA_W] = chan_mux[CHAN];
        end
        else begin
            // when rinc asserted get NEW data
            // This may not be CDC safe in ASYNC mode
            assign dout[DATA_W*CHAN+:DATA_W] = mem[rptr+read][CHAN];
        end
    end 




endmodule