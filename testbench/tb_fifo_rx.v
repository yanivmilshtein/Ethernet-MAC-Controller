`timescale 1ns/1ps

module tb_fifo_rx;

    // Testbench signals
    reg clk;
    reg rst_n;
    reg [7:0] data_in;
    reg write_enable;
    reg read_enable;
    wire [7:0] data_out;
    wire full_flag;
    wire empty_flag;

    // Instantiate the fifo_rx module
    fifo_rx uut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .write_enable(write_enable),
        .read_enable(read_enable),
        .data_out(data_out),
        .full_flag(full_flag),
        .empty_flag(empty_flag)
    );

    // Clock generation
    always #5 clk = ~clk; // 10ns clock period (100MHz)

    // Test scenario
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        data_in = 8'b0;
        write_enable = 0;
        read_enable = 0;

        // Reset the system
        #10 rst_n = 1; // Release reset after 10ns

        // Write first value into FIFO
        #10 data_in = 8'hAA;
            write_enable = 1;
        #10 write_enable = 0; // Stop writing

        // Write second value into FIFO
        #10 data_in = 8'hBB;
            write_enable = 1;
        #10 write_enable = 0;

        // Read first value from FIFO
        #10 read_enable = 1;
        #10 read_enable = 0;

        // Read second value from FIFO
        #10 read_enable = 1;
        #10 read_enable = 0;

        // Finish simulation
        #50 $stop;
    end

endmodule
