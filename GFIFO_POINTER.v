module GFIFO_POINTER #(
    parameter LENGTH = -1,  // Length of the FIFO
    parameter PTR_w = -1,   // Width of FIFO pointer
    parameter ASYNCHRONOUS = -1,
    parameter PTR_DEF = 0   // Default pointer value
) (
    /////////////////////////////////////////////////////
    // Inputs
    /////////////////////////////////////////////////////
    input               clk,    // Active high clock
    input               rst_an, // Asynchronous, active low rst
    input               clear,  // Synchronous clear (empmty FIFO)
    input               enable, // Increment the pointer

    /////////////////////////////////////////////////////
    // Outputs
    /////////////////////////////////////////////////////
    output [PTR_W-1:0]  ptr_binary,     // Oversized pointer, binary version
    output [PTR_W-1:0]  ptr_gray,       // Oversized pointer, gray-coded
    output [PTR_W:0]    ptr_bin_next    // Next binary pointer value
);

    /////////////////////////////////////////////////////
    // Internal parameters
    /////////////////////////////////////////////////////
    localparam POWER2_LEN = ((1<<PTR_W) == LENGTH);

    /////////////////////////////////////////////////////
    // Internal signals
    /////////////////////////////////////////////////////
    reg [PTR_W:0]       int_ptr;        // Internal, normal length pointer
    wire                rollover;       // Indicates non-2^N pointer has rolled over
    wire [PTR_W:0]      start;          // Start value of section of binary count to be bypassed for
                                        // even lengths less than 2^N in asynchronous mode
    wire [PTR_W:0]      stp;            // stop value of section of binary count to be bypassed for
                                        // even lengths less than 2^N in asynchronous mode
    wire [PTR_W:0]      ptr_bin_i;      // internal binary pointer value

    /////////////////////////////////////////////////////
    // Main code
    /////////////////////////////////////////////////////
    // Start/Stop bypass binary counter values
    assign start = $unsigned(LENGTH>>1);
    assign stp = $unsigned(1<<PTR_W) - start;

    // In ASYNCHRONOUS mode, add bypass offset to binary pointer
    assign ptr_binary = (ptr_bin_i[PTR_W-1:0] >= start[PTR_W-1:0]) && (POWER2_LEN==0) && (ASYNCHRONOUS==1) ? 
                        ptr_bin_i - stp + start : ptr_bin_i;

    // Generate pointer. We support any integer length for the FIFO so we need to compare with the length for rollover
    always @(posedge clk or negedge rst_an) begin
        if (rst_an == 1'b0)
            int_ptr <= binary_to_gray(PTR_DEF, ASYNCHRONOUS);
        else
            // Synchronous clear
            if (clear == 1'b1)
                int_ptr <= binary_to_gray(PTR_DEF, ASYNCHRONOUS);
            // Enable (in all modes)
            else if (enable) begin
                // Increment pointer, binary_to_gray handles disabling Gray counter
                // in synchronous mode. Bypass a section of count if in async mode
                if ((ptr_bin_next[PTR_W-1:0] == start[PTR_W-1:0]) && (ASYNCHRONOUS == 1))
                    int_ptr <= binary_to_gray({ptr_bin_next[PTR_W], stp[PTR_W-1:0]}, ASYNCHRONOUS);
                else
                    int_ptr <= binary_to_gray(ptr_bin_next, ASYNCHRONOUS);
            end
    end

    // Binary pointer is from the registered pointer, which is Gray in async mode. The gray_to_binary function handles
    // removing the Gray conversion in synchronous mode
    assign ptr_bin_i = gray_to_binary(int_ptr, ASYNCHRONOUS);

    // We only need the gray counter output in asynchronous mode
    assign ptr_gray = ASYNCHRONOUS ? int_ptr : 0;

    // Calculate binary incremented pointer value, we handle the rollover here
    // for the non-2^N lengths allowed in a async and sync modes
    assign ptr_bin_next = (!POWER2_LEN && (rollover==1'b1)) ? ASYNCHRONOUS ? 
                            {PTR_W+1{1'b0}} : {~int_ptr[PTR_W], {PTR_W{1'b0}}} :
                            (ptr_bin_i + 1);

    // For non-2^N length FIFOs we need to check for FIFO rollover
    assign rollover = ASYNCHRONOUS ? (gray_to_binary(int_ptr, ASYNCHRONOUS) == {PTR_W+1{1'b1}}) :
                                        (int_ptr[PTR_w-1:0] == $unsigned(LENGTH-1));
    
    // Converts the data from binary to Gray when enabled. When disabled it passes the value unchanged.
    function [PTR_W:0] binary_to_gray;
        input [PTR_W:0] gray;
        input           enable;
        binary_to_gray = enable ? gray ^ (gray >> 1) : gray;
    endfunction // binary_to_gray

    // Converts the data from Gray to binary when enabled. When disabled it passes the value unchanged.
    function [PTR_W:0] gray_to_binary;
        INPUT [PTR_W:0] gray;
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
            end else begin
                gray_to_binary = gray;
            end
        end
    endfunction // gray_to_binary

endmodule