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

    // Test tracking
    integer errors = 0;
    integer test_count = 0;

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

    // Monitor to display status changes
    always @(posedge clk) begin
        if (write_enable && !full_flag)
            $display("[WRITE] Data: 0x%02H written to FIFO | Count: %d | Full: %b | Empty: %b", 
                     data_in, uut.data_count, full_flag, empty_flag);
        
        if (read_enable && !empty_flag)
            $display("[READ]  Data: 0x%02H read from FIFO  | Count: %d | Full: %b | Empty: %b", 
                     data_out, uut.data_count, full_flag, empty_flag);
    end

    // Task to write data and verify
    task write_byte(input [7:0] byte_val);
        begin
            test_count = test_count + 1;
            @(posedge clk);
            data_in = byte_val;
            write_enable = 1;
            @(posedge clk);
            write_enable = 0;
            $display("  >> Test %d: Wrote 0x%02H", test_count, byte_val);
        end
    endtask

    // Task to read data and verify
    task read_byte_verify(input [7:0] expected_val);
        begin
            @(posedge clk);
            read_enable = 1;
            // data_out shows fifo_mem[read_ptr] combinatorially - check it now
            if (data_out === expected_val) begin
                $display("  << PASS: Read 0x%02H (expected 0x%02H) ✓", data_out, expected_val);
            end else begin
                $display("  << FAIL: Read 0x%02H (expected 0x%02H) ✗", data_out, expected_val);
                errors = errors + 1;
            end
            @(posedge clk);
            read_enable = 0;
        end
    endtask

    // Test scenario
    initial begin
        $display("\n========================================");
        $display("  FIFO RX TESTBENCH - COMPREHENSIVE TEST");
        $display("========================================\n");

        // Initialize signals
        clk = 0;
        rst_n = 0;
        data_in = 8'b0;
        write_enable = 0;
        read_enable = 0;
        errors = 0;
        test_count = 0;

        // Reset the system
        #10 rst_n = 1;
        $display("[RESET] System reset released\n");

        // TEST 1: Basic Write/Read
        $display("TEST 1: Sequential Write/Read (2 bytes)");
        write_byte(8'hAA);
        write_byte(8'hBB);
        read_byte_verify(8'hAA);
        read_byte_verify(8'hBB);
        @(posedge clk);  // Wait for flags to settle
        $display("  Status: FIFO should be empty");
        #10;
        $display("  Empty flag: %b (should be 1)\n", empty_flag);

        // TEST 2: Fill FIFO completely (depth=8)
        $display("TEST 2: Fill FIFO to capacity (8 bytes)");
        write_byte(8'h11);
        write_byte(8'h22);
        write_byte(8'h33);
        write_byte(8'h44);
        write_byte(8'h55);
        write_byte(8'h66);
        write_byte(8'h77);
        write_byte(8'h88);
        @(posedge clk);  // Wait for flags to settle
        #10;
        $display("  Full flag: %b (should be 1)\n", full_flag);

        // TEST 3: Read all bytes back
        $display("TEST 3: Read all bytes back (FIFO should maintain order)");
        read_byte_verify(8'h11);
        read_byte_verify(8'h22);
        read_byte_verify(8'h33);
        read_byte_verify(8'h44);
        read_byte_verify(8'h55);
        read_byte_verify(8'h66);
        read_byte_verify(8'h77);
        read_byte_verify(8'h88);
        @(posedge clk);  // Wait for flags to settle
        #10;
        $display("  Empty flag: %b (should be 1)\n", empty_flag);

        // TEST 4: Partial writes and reads
        $display("TEST 4: Partial writes and reads (interleaved)");
        write_byte(8'hCC);
        write_byte(8'hDD);
        read_byte_verify(8'hCC);
        write_byte(8'hEE);
        read_byte_verify(8'hDD);
        read_byte_verify(8'hEE);
        @(posedge clk);  // Wait for flags to settle
        #10;
        $display("  Final state - Empty flag: %b\n", empty_flag);

        // TEST 5: Attempt write when full (should not write)
        $display("TEST 5: Overflow protection - Write when full");
        write_byte(8'h01);
        write_byte(8'h02);
        write_byte(8'h03);
        write_byte(8'h04);
        write_byte(8'h05);
        write_byte(8'h06);
        write_byte(8'h07);
        write_byte(8'h08);
        @(posedge clk);  // Wait for flags to settle
        #10;
        $display("  FIFO is now FULL");
        @(posedge clk);
        data_in = 8'h99;
        write_enable = 1;  // Try to write while full
        @(posedge clk);
        write_enable = 0;
        @(posedge clk);  // Wait for flag update
        $display("  Attempted write of 0x99 while full");
        #10;
        $display("  This byte should NOT be in FIFO (protection working)\n");

        // Read and verify protection worked
        $display("TEST 6: Verify overflow protection");
        read_byte_verify(8'h01);
        read_byte_verify(8'h02);
        read_byte_verify(8'h03);
        read_byte_verify(8'h04);
        read_byte_verify(8'h05);
        read_byte_verify(8'h06);
        read_byte_verify(8'h07);
        read_byte_verify(8'h08);
        @(posedge clk);  // Wait for flags to settle
        #10;
        if (empty_flag && !read_enable) begin
            $display("  PASS: No 0x99 found - overflow protection working ✓\n");
        end else begin
            $display("  FAIL: Unexpected data - overflow protection failed ✗\n");
            errors = errors + 1;
        end

        // Summary
        #50;
        $display("========================================");
        $display("  TEST SUMMARY");
        $display("========================================");
        $display("  Total Test Groups: 6");
        $display("  Individual Bytes Tested: %d", test_count);
        $display("  Errors Found: %d", errors);
        if (errors == 0) begin
            $display("  STATUS: ✓ ALL TESTS PASSED!");
        end else begin
            $display("  STATUS: ✗ TESTS FAILED - Debug required");
        end
        $display("========================================\n");

        $stop;
    end

endmodule
