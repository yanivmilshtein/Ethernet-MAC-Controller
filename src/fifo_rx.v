module fifo_rx (
    input  wire       clk,
    input  wire       rst_n,        // Active low reset
    input  wire [7:0] data_in,
    input  wire       write_enable,
    input  wire       read_enable,
    output wire [7:0] data_out,
    output reg        full_flag,
    output reg        empty_flag
);

    parameter FIFO_DEPTH = 8;

    reg [7:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [3:0] write_ptr;
    reg [3:0] read_ptr;
    reg [3:0] data_count;

    // Combinatorial read: data_out shows what's at read_ptr immediately
    assign data_out = (data_count > 0) ? fifo_mem[read_ptr] : 8'b0;

    // ====== WRITE LOGIC ======
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 0;
            fifo_mem[0] <= 8'b0;
            fifo_mem[1] <= 8'b0;
            fifo_mem[2] <= 8'b0;
            fifo_mem[3] <= 8'b0;
            fifo_mem[4] <= 8'b0;
            fifo_mem[5] <= 8'b0;
            fifo_mem[6] <= 8'b0;
            fifo_mem[7] <= 8'b0;
        end else begin
            // Write data when write_enable is high and FIFO is not full
            if (write_enable && !full_flag) begin
                fifo_mem[write_ptr] <= data_in;
                write_ptr <= (write_ptr == (FIFO_DEPTH - 1)) ? 0 : write_ptr + 1;
            end
        end
    end

    // ====== READ LOGIC ======
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_ptr <= 0;
        end else begin
            // Advance read pointer when read_enable is high and FIFO is not empty
            if (read_enable && !empty_flag) begin
                read_ptr <= (read_ptr == (FIFO_DEPTH - 1)) ? 0 : read_ptr + 1;
            end
        end
    end

    // ====== COUNTER & FLAGS LOGIC ======
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_count <= 0;
            full_flag  <= 1'b0;
            empty_flag <= 1'b1;
        end else begin
            // Update data_count based on read and write operations
            if (write_enable && !full_flag && read_enable && !empty_flag) begin
                // Both read and write: count stays same
                data_count <= data_count;
            end else if (write_enable && !full_flag) begin
                // Write only: increment count
                data_count <= data_count + 1;
            end else if (read_enable && !empty_flag) begin
                // Read only: decrement count
                data_count <= data_count - 1;
            end
            // else: no change

            // Update flags based on new count
            full_flag  <= (data_count == FIFO_DEPTH);
            empty_flag <= (data_count == 0);
        end
    end

endmodule
