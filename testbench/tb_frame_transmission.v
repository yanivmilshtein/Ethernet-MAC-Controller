module tb_frame_transmission();
    reg clk;
    reg rst_n;
    reg [47:0] dest_addr;
    reg [47:0] src_addr;
    reg [15:0] eth_type;
    reg [31:0] data_in;
    reg start;
    wire tx_en;
    wire [7:0] tx_out;
    wire tx_done;

    // Instantiate the frame_transmission module
    frame_transmission uut (
        .clk(clk),
        .rst_n(rst_n),
        .dest_addr(dest_addr),
        .src_addr(src_addr),
        .eth_type(eth_type),
        .data_in(data_in),
        .start(start),
        .tx_out(tx_out),
        .tx_done(tx_done),
        .tx_en(tx_en)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Testbench stimulus
    initial begin
        // Initialize inputs
        rst_n = 0;
        start = 0;
        dest_addr = 48'h123456789ABC;
        src_addr = 48'hABCDEF123456;
        eth_type = 16'h0800;
        data_in = 32'hDEADBEEF;

        // Reset and start sequence
        #10 rst_n = 1; // Release reset
        #10 start = 1; // Start frame transmission
        #10 start = 0; // De-assert start signal

        // Wait for transmission to complete
        wait (tx_done);
        #20 $finish;
    end

    // Monitor tx_out to observe the serialized output
    initial begin
        $monitor("Time: %0d, tx_out: %h, tx_en: %b, tx_done: %b",
                  $time, tx_out, tx_en, tx_done);
    end
endmodule
