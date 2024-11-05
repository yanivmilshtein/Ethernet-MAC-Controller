module fifo_rx (
    input wire clk,
    input wire rst_n,             // Active low reset
    input wire [7:0] data_in,     // Data input (from MAC layer or external source)
    input wire write_enable,      // Write enable signal (asserted when new data is ready to be received)
    input wire read_enable,       // Read enable signal (asserted when data needs to be read)
    output reg [7:0] data_out,    // Data output
    output reg full_flag,         // FIFO full flag
    output reg empty_flag         // FIFO empty flag
);

    // Define parameters for FIFO depth
    parameter FIFO_DEPTH = 8;
    reg [7:0] fifo_mem [FIFO_DEPTH-1:0]; // FIFO memory
    reg [3:0] write_ptr = 0; // Write pointer (4 bits to address up to 16 locations)
    reg [3:0] read_ptr = 0;  // Read pointer
    reg [3:0] data_count = 0; // Counter to keep track of how many elements are in the FIFO

    // Write Operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 0;
            data_count <= 0;
            full_flag <= 0;
            empty_flag <= 1;
        end else if (write_enable && !full_flag) begin
            fifo_mem[write_ptr] <= data_in; // Write data into FIFO
            write_ptr <= write_ptr + 1;     // Increment write pointer
            data_count <= data_count + 1;   // Increment data count
            empty_flag <= 0;                // FIFO is not empty
            if (data_count == FIFO_DEPTH-1) begin
                full_flag <= 1;             // FIFO becomes full
            end
        end
    end

    // Read Operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_ptr <= 0;
            data_out <= 0;
        end else if (read_enable && !empty_flag) begin
            data_out <= fifo_mem[read_ptr]; // Read data from FIFO
            read_ptr <= read_ptr + 1;       // Increment read pointer
            data_count <= data_count - 1;   // Decrement data count
            full_flag <= 0;                 // FIFO is not full
            if (data_count == 1) begin
                empty_flag <= 1;            // FIFO becomes empty
            end
        end
    end

endmodule
