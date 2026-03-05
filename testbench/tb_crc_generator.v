`timescale 1ns/1ps

module tb_crc_generator;

    // Inputs
    reg clk;
    reg rst_n;
    reg [7:0] data_in;
    reg data_valid;
    reg crc_en;

    // Outputs
    wire [31:0] crc_out;
    wire crc_done;
    wire crc_valid;  // New: indicates if CRC verification passes

    // Test tracking
    integer errors = 0;
    reg [31:0] computed_crc;
    reg [31:0] crc_residue;

    // Instantiate the CRC generator
    crc_generator uut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_valid(data_valid),
        .crc_en(crc_en),
        .crc_out(crc_out),
        .crc_done(crc_done),
        .crc_valid(crc_valid)
    );

    // Clock generation
    always #5 clk = ~clk; // 10ns clock period (100 MHz)

    // Monitor CRC activity
    always @(posedge clk) begin
        if (data_valid && crc_en)
            $display("[CRC_IN] Byte: 0x%02H | CRC Reg: 0x%08H", data_in, uut.crc_reg);
        
        if (crc_done)
            $display("[CRC_OUT] Final CRC: 0x%08H", crc_out);
    end

    // Task to send one byte for CRC calculation
    task send_crc_byte(input [7:0] byte_val);
    begin
        @(posedge clk);
        data_in = byte_val;
        data_valid = 1;
        @(posedge clk);
        data_valid = 0;
    end
    endtask

    // Task to send byte during verification phase
    task send_verify_byte(input [7:0] byte_val);
    begin
        @(posedge clk);
        data_in = byte_val;
        data_valid = 1;
        @(posedge clk);
        data_valid = 0;
    end
    endtask

    // Task to wait for CRC computation
    task wait_for_crc;
    begin
        @(posedge clk);
        crc_en = 0;  // Signal end of data
        wait(crc_done == 1);
        @(posedge clk);
    end
    endtask

    // Test procedure
    initial begin
        $display("\n========================================");
        $display("  CRC32 GENERATOR TESTBENCH");
        $display("  Ethernet Frame CRC Verification");
        $display("========================================\n");

        // Initialize signals
        clk = 0;
        rst_n = 0;
        data_in = 8'b0;
        data_valid = 0;
        crc_en = 0;
        errors = 0;
        computed_crc = 32'h00000000;
        crc_residue = 32'h00000000;

        // Apply reset
        #20 rst_n = 1;
        $display("[RESET] CRC Generator reset released\n");

        // ====== TEST CASE 1: CRC Computation ======
        $display("TEST CASE 1: Compute CRC for 4-byte Ethernet Payload");
        $display("  Input Data: 0x12 0x34 0x56 0x78");
        $display("  ------");
        
        @(posedge clk);
        crc_en = 1;  // Start CRC accumulation

        send_crc_byte(8'h12);
        send_crc_byte(8'h34);
        send_crc_byte(8'h56);
        send_crc_byte(8'h78);

        wait_for_crc;
        
        computed_crc = crc_out;
        $display("  Computed CRC: 0x%08H\n", computed_crc);

        #50;

        // ====== TEST CASE 2: CRC Verification ======
        $display("TEST CASE 2: Verify CRC by Re-processing Data + CRC");
        $display("  Re-sending: Data (0x12 0x34 0x56 0x78) + CRC (0x%02H 0x%02H 0x%02H 0x%02H)",
                 computed_crc[31:24], computed_crc[23:16], computed_crc[15:8], computed_crc[7:0]);
        $display("  Expected: crc_valid signal should be asserted (1)");
        $display("  ------");

        @(posedge clk);
        crc_en = 1;  // Start CRC accumulation for verification

        // Send original data
        send_verify_byte(8'h12);
        send_verify_byte(8'h34);
        send_verify_byte(8'h56);
        send_verify_byte(8'h78);

        // Send the computed CRC in big-endian byte order
        send_verify_byte(computed_crc[31:24]);
        send_verify_byte(computed_crc[23:16]);
        send_verify_byte(computed_crc[15:8]);
        send_verify_byte(computed_crc[7:0]);

        wait_for_crc;

        $display("  CRC Valid: %b (should be 1)", crc_valid);
        if (crc_valid) begin
            $display("  PASS: CRC verification successful - frame is valid ✓\n");
        end else begin
            $display("  FAIL: CRC verification failed - frame is corrupted ✗\n");
            errors = errors + 1;
        end

        #50;

        // ====== TEST CASE 3: Single Byte CRC ======
        $display("TEST CASE 3: Single Byte CRC Computation");
        $display("  Input Data: 0xB6");
        $display("  ------");

        @(posedge clk);
        crc_en = 1;
        send_crc_byte(8'hB6);
        wait_for_crc;

        $display("  Computed CRC: 0x%08H\n", crc_out);

        #50;

        // ====== TEST CASE 4: Different Data Pattern ======
        $display("TEST CASE 4: Compute and Verify Different Pattern");
        $display("  Input Data: 0xAA 0xBB 0xCC 0xDD");
        $display("  ------");

        @(posedge clk);
        crc_en = 1;
        send_crc_byte(8'hAA);
        send_crc_byte(8'hBB);
        send_crc_byte(8'hCC);
        send_crc_byte(8'hDD);
        wait_for_crc;

        computed_crc = crc_out;
        $display("  Computed CRC: 0x%08H", computed_crc);

        // Verify this CRC
        #50;
        @(posedge clk);
        crc_en = 1;
        send_verify_byte(8'hAA);
        send_verify_byte(8'hBB);
        send_verify_byte(8'hCC);
        send_verify_byte(8'hDD);
        send_verify_byte(computed_crc[31:24]);
        send_verify_byte(computed_crc[23:16]);
        send_verify_byte(computed_crc[15:8]);
        send_verify_byte(computed_crc[7:0]);
        wait_for_crc;

        crc_residue = crc_out;
        $display("  Verification CRC: 0x%08H", crc_residue);
        
        if (crc_valid) begin
            $display("  PASS: CRC verification successful ✓\n");
        end else begin
            $display("  FAIL: CRC verification failed ✗\n");
            errors = errors + 1;
        end

        // Summary
        #100;
        $display("========================================");
        $display("  TEST SUMMARY");
        $display("========================================");
        $display("  Total Test Cases: 4");
        $display("  Individual Verification Tests: 2");
        $display("  Errors Found: %d", errors);
        if (errors == 0) begin
            $display("  CRC Computation: Working ✓");
            $display("  CRC Verification: Working ✓");
            $display("  Status: ✓ CRC TESTBENCH COMPLETE - ALL TESTS PASSED");
        end else begin
            $display("  Status: ✗ SOME TESTS FAILED");
        end
        $display("========================================\n");

        $stop;
    end

endmodule
