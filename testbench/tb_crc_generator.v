module tb_crc_generator;

    // Inputs
    reg clk;
    reg rst_n;
    reg [7:0] data_in;      // updated to 8-bit
    reg data_valid;
    reg crc_en;

    // Outputs
    wire [31:0] crc_out;
    wire crc_done;

    // Instantiate the CRC generator
    crc_generator uut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_valid(data_valid),
        .crc_en(crc_en),
        .crc_out(crc_out),
        .crc_done(crc_done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10 time units clock period
    end

    // Testbench stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        data_in = 8'b0;
        data_valid = 0;
        crc_en = 0;

        // Apply reset
        #20 rst_n = 1;

        // === Test Case 1: Single byte input ===
        #10 data_in = 8'hB6;
        data_valid = 1;
        crc_en = 1;

        #10 data_valid = 0;
        crc_en = 0;

        // Wait for CRC done
        wait(crc_done == 1);
        $display("Test Case 1: CRC32 Result = %h", crc_out);

        // === Test Case 2: Multiple byte inputs ===
        #20 crc_en = 1;

        // Send 0x12, 0x34, 0x56, 0x78 (as 4 bytes)
        send_byte(8'h12);
        send_byte(8'h34);
        send_byte(8'h56);
        send_byte(8'h78);

        // Send 0x9A, 0xBC, 0xDE, 0xF0
        send_byte(8'h9A);
        send_byte(8'hBC);
        send_byte(8'hDE);
        send_byte(8'hF0);

        #10 crc_en = 0;

        wait(crc_done == 1);
        $display("Test Case 2: CRC32 Result = %h", crc_out);

        #40 $finish;
    end

    // Task to send one byte
    task send_byte(input [7:0] byte);
    begin
        data_in = byte;
        data_valid = 1;
        #10;
        data_valid = 0;
        #10;
    end
    endtask

endmodule
