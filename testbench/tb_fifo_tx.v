// fifo_tx_tb.v
// Testbench for FIFO Transmission Buffer

`timescale 1ns/1ps

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

    // Test tracking
    integer errors = 0;
    integer test_count = 0;

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

    // Monitor to display status changes
    always @(posedge clk) begin
        if (write_en && !full)
            $display("[WRITE] Data: 0x%02H written to FIFO | Count: %d | Full: %b | Empty: %b", 
                     data_in, uut.fifo_count, full, empty);
        
        if (read_en && !empty)
            $display("[READ]  Data: 0x%02H read from FIFO  | Count: %d | Full: %b | Empty: %b", 
                     data_out, uut.fifo_count, full, empty);
    end

    // Task to write data
    task write_byte(input [DATA_WIDTH-1:0] byte_val);
        begin
            test_count = test_count + 1;
            @(posedge clk);
            data_in = byte_val;
            write_en = 1;
            @(posedge clk);
            write_en = 0;
            $display("  >> Test %d: Wrote 0x%02H", test_count, byte_val);
        end
    endtask

    // Task to read data and verify
    task read_byte_verify(input [DATA_WIDTH-1:0] expected_val);
        begin
            @(posedge clk);
            read_en = 1;
            // data_out shows fifo_mem[read_ptr] combinatorially - check it now
            if (data_out === expected_val) begin
                $display("  << PASS: Read 0x%02H (expected 0x%02H) ✓", data_out, expected_val);
            end else begin
                $display("  << FAIL: Read 0x%02H (expected 0x%02H) ✗", data_out, expected_val);
                errors = errors + 1;
            end
            @(posedge clk);
            read_en = 0;
        end
    endtask

    // Test procedure
    initial begin
        $display("\n========================================");
        $display("  FIFO TX TESTBENCH - COMPREHENSIVE TEST");
        $display("========================================\n");

        // Initialize signals
        clk = 0;
        rst_n = 0;
        write_en = 0;
        read_en = 0;
        data_in = 0;
        errors = 0;
        test_count = 0;

        // Reset the FIFO
        #10;
        rst_n = 1;
        $display("[RESET] System reset released\n");

        // TEST 1: Basic Write/Read (2 bytes)
        $display("TEST 1: Sequential Write/Read (2 bytes)");
        write_byte(8'hAA);
        write_byte(8'hBB);
        read_byte_verify(8'hAA);
        read_byte_verify(8'hBB);
        @(posedge clk);  // Wait for flags to settle
        #10;
        $display("  Status: FIFO should be empty");
        $display("  Empty flag: %b (should be 1)\n", empty);

        // TEST 2: Fill FIFO partially (8 bytes out of 16)
        $display("TEST 2: Fill FIFO to half capacity (8 bytes)");
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
        $display("  Full flag: %b (should be 0, half full)\n", full);

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
        $display("  Empty flag: %b (should be 1)\n", empty);

        // TEST 4: Fill FIFO completely (all 16 slots)
        $display("TEST 4: Fill FIFO to capacity (16 bytes)");
        write_byte(8'h01);
        write_byte(8'h02);
        write_byte(8'h03);
        write_byte(8'h04);
        write_byte(8'h05);
        write_byte(8'h06);
        write_byte(8'h07);
        write_byte(8'h08);
        write_byte(8'h09);
        write_byte(8'h0A);
        write_byte(8'h0B);
        write_byte(8'h0C);
        write_byte(8'h0D);
        write_byte(8'h0E);
        write_byte(8'h0F);
        write_byte(8'h10);
        @(posedge clk);  // Wait for flags to settle
        #10;
        $display("  Full flag: %b (should be 1)\n", full);

        // TEST 5: Interleaved writes and reads
        $display("TEST 5: Interleaved writes and reads (simultaneous operations)");
        read_byte_verify(8'h01);
        write_byte(8'hAB);  // Write while reading
        read_byte_verify(8'h02);
        write_byte(8'hCD);
        read_byte_verify(8'h03);
        read_byte_verify(8'h04);
        write_byte(8'hEF);
        read_byte_verify(8'h05);
        @(posedge clk);  // Wait for flags to settle
        #10;
        $display("  Interleaved ops completed\n");

        // TEST 6: Read all remaining bytes
        $display("TEST 6: Read all remaining bytes");
        read_byte_verify(8'h06);
        read_byte_verify(8'h07);
        read_byte_verify(8'h08);
        read_byte_verify(8'h09);
        read_byte_verify(8'h0A);
        read_byte_verify(8'h0B);
        read_byte_verify(8'h0C);
        read_byte_verify(8'h0D);
        read_byte_verify(8'h0E);
        read_byte_verify(8'h0F);
        read_byte_verify(8'h10);
        read_byte_verify(8'hAB);
        read_byte_verify(8'hCD);
        read_byte_verify(8'hEF);
        @(posedge clk);  // Wait for flags to settle
        #10;
        $display("  Empty flag: %b (should be 1)\n", empty);

        // TEST 7: Overflow protection - Write when full
        $display("TEST 7: Overflow protection - Write when full");
        write_byte(8'hF1);
        write_byte(8'hF2);
        write_byte(8'hF3);
        write_byte(8'hF4);
        write_byte(8'hF5);
        write_byte(8'hF6);
        write_byte(8'hF7);
        write_byte(8'hF8);
        write_byte(8'hF9);
        write_byte(8'hFA);
        write_byte(8'hFB);
        write_byte(8'hFC);
        write_byte(8'hFD);
        write_byte(8'hFE);
        write_byte(8'hFF);
        write_byte(8'h20);
        @(posedge clk);  // Wait for flags to settle
        #10;
        $display("  FIFO is now FULL");
        @(posedge clk);
        data_in = 8'h99;
        write_en = 1;  // Try to write while full
        @(posedge clk);
        write_en = 0;
        @(posedge clk);  // Wait for flag update
        $display("  Attempted write of 0x99 while full");
        #10;
        $display("  This byte should NOT be in FIFO (protection working)\n");

        // TEST 8: Verify overflow protection
        $display("TEST 8: Verify overflow protection (read all and check for 0x99)");
        read_byte_verify(8'hF1);
        read_byte_verify(8'hF2);
        read_byte_verify(8'hF3);
        read_byte_verify(8'hF4);
        read_byte_verify(8'hF5);
        read_byte_verify(8'hF6);
        read_byte_verify(8'hF7);
        read_byte_verify(8'hF8);
        read_byte_verify(8'hF9);
        read_byte_verify(8'hFA);
        read_byte_verify(8'hFB);
        read_byte_verify(8'hFC);
        read_byte_verify(8'hFD);
        read_byte_verify(8'hFE);
        read_byte_verify(8'hFF);
        read_byte_verify(8'h20);
        @(posedge clk);  // Wait for flags to settle
        #10;
        if (empty && !read_en) begin
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
        $display("  Total Test Groups: 8");
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

