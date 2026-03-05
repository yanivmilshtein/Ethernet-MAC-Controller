module fifo_tx #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16
)(
    input  wire clk,
    input  wire rst_n,
    input  wire write_en,
    input  wire read_en,
    input  wire [DATA_WIDTH-1:0] data_in,
    output wire [DATA_WIDTH-1:0] data_out,
    output reg  full,
    output reg  empty
);

    localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);

    reg [DATA_WIDTH-1:0] fifo_mem [FIFO_DEPTH-1:0];
    reg [ADDR_WIDTH-1:0] write_ptr;
    reg [ADDR_WIDTH-1:0] read_ptr;
    reg [ADDR_WIDTH:0] fifo_count;

    // Combinatorial read: data_out shows what's at read_ptr immediately
    assign data_out = (fifo_count > 0) ? fifo_mem[read_ptr] : {DATA_WIDTH{1'b0}};

    // ====== WRITE LOGIC ======
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 0;
        end else begin
            // Write data when write_en is high and FIFO is not full
            if (write_en && !full) begin
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
            // Advance read pointer when read_en is high and FIFO is not empty
            if (read_en && !empty) begin
                read_ptr <= (read_ptr == (FIFO_DEPTH - 1)) ? 0 : read_ptr + 1;
            end
        end
    end

    // ====== COUNTER & FLAGS LOGIC ======
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_count <= 0;
            full       <= 1'b0;
            empty      <= 1'b1;
        end else begin
            // Update fifo_count based on read and write operations
            if (write_en && !full && read_en && !empty) begin
                // Both read and write: count stays same
                fifo_count <= fifo_count;
            end else if (write_en && !full) begin
                // Write only: increment count
                fifo_count <= fifo_count + 1;
            end else if (read_en && !empty) begin
                // Read only: decrement count
                fifo_count <= fifo_count - 1;
            end
            // else: no change

            // Update flags based on new count
            full  <= (fifo_count == FIFO_DEPTH);
            empty <= (fifo_count == 0);
        end
    end

endmodule
