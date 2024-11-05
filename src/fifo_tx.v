module fifo_tx #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire write_en,
    input wire read_en,
    input wire [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out,
    output reg full,
    output reg empty
);

reg [DATA_WIDTH-1:0] fifo_mem[FIFO_DEPTH-1:0];
reg [3:0] write_ptr;
reg [3:0] read_ptr;
reg [4:0] fifo_count;
// write operation
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_ptr <= 0;
        fifo_count <= 0;
        full <= 0;
    end
    else if (write_en && !full) begin
        fifo_mem[write_ptr] <= data_in;
        write_ptr <= (write_ptr + 1) % FIFO_DEPTH;
        fifo_count <= fifo_count + 1;
    end
end

// read operation
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        read_ptr <= 0;
        data_out <= 0;
        fifo_count <= 0;
        empty <= 1;
    end
    else if (read_en && !empty) begin
        data_out <= fifo_mem[read_ptr];
        read_ptr <= (read_ptr + 1) % FIFO_DEPTH;
        fifo_count <= fifo_count - 1;
        
    end
end
//flag setup 
always @(*) begin
    full = (fifo_count == FIFO_DEPTH);
    empty = (fifo_count == 0);
end
endmodule