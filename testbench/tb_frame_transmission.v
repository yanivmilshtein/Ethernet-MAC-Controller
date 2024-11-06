module tb_frame_transmission;

    reg clk;
    reg rst_n;
    reg [31:0] data_in;
    reg tx_en;
    wire tx_done;
    wire [7:0] tx_out;

    // Instantiate frame transmission module
    frame_transmission uut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .tx_en(tx_en),
        .tx_out(tx_out),
        .tx_done(tx_done)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize inputs
        clk = 0;
        rst_n = 0;
        data_in = 32'h0;
        tx_en = 0;

        // Apply reset
        #10 rst_n = 1;

        // Begin frame transmission
        #20 data_in = 32'hAABBCCDD;
        tx_en = 1;

        // Wait for transmission to complete
        wait(tx_done);
        #20;
        $display("Transmission Completed. Output: %h", tx_out);

        // End simulation
        #40;
        $finish;
    end

endmodule
