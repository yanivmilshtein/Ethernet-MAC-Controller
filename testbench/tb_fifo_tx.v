// fifo_tx_tb.v
// Testbench for FIFO Transmission Buffer

module fifo_tx_tb;

    // Parameters
    localparam DATA_WIDTH = 8;
    localparam FIFO_DEPTH = 16;

    // Testbench signals
    reg clk;
    reg rst_n;
    reg write_en;
    reg read_en;
    reg [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;
    wire full;
    wire empty;

    // Instantiate the FIFO module
    fifo_tx #(.DATA_WIDTH(DATA_WIDTH), .FIFO_DEPTH(FIFO_DEPTH)) uut (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .read_en(read_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty)
    );

    // Clock generation
    always #5 clk = ~clk;  // 10ns clock period (100 MHz)

    // Test procedure
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        write_en = 0;
        read_en = 0;
        data_in = 0;

        // Reset the FIFO
        #10;
        rst_n = 1;

        // Write some data into the FIFO
        #10;
        write_en = 1;
        data_in = 8'hAA;  // Write data 0xAA
        #10;
        data_in = 8'hBB;  // Write data 0xBB
        #10;
        write_en = 0;     // Stop writing

        // Read data from the FIFO
        #10;
        read_en = 1;
        #10;
        read_en = 0;      // Stop reading

        // Finish the simulation
        #20;
        $finish;
    end

endmodule
