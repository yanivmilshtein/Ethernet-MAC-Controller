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
    wire crc_valid;

    // Test tracking
    integer errors = 0;
    reg [31:0] computed_crc;
    reg [31:0] crc_residue;

    // Instantiate DUT
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
    always #5 clk = ~clk; // 100 MHz clock

    // Monitor activity
    always @(posedge clk) begin
        if (data_valid && crc_en)
            $display("[CRC_IN] Byte: 0x%02H | CRC Reg (before update): 0x%08H",
                     data_in, uut.crc_reg);

        if (crc_done)
            $display("[CRC_OUT] Final CRC: 0x%08H", crc_out);
    end

    // =========================
    // TASK: Send CRC byte
    // =========================
    task send_crc_byte(input [7:0] byte_val);
    begin
        @(posedge clk);
        data_in = byte_val;
        data_valid = 1;
        @(posedge clk);
        data_valid = 0;
    end
    endtask


    // =========================
    // TASK: Wait for CRC finish
    // =========================
    task wait_for_crc;
    begin
        @(posedge clk);
        crc_en = 0;           // signal end of stream
        wait(crc_done == 1);
        @(posedge clk);       // allow outputs to settle
    end
    endtask


    // =========================
    // TEST PROCEDURE
    // =========================
    initial begin

        $display("\n========================================");
        $display("  CRC32 GENERATOR TESTBENCH");
        $display("  Ethernet CRC Calculation + Verification");
        $display("========================================\n");

        // Init
        clk = 0;
        rst_n = 0;
        data_in = 8'h00;
        data_valid = 0;
        crc_en = 0;
        errors = 0;

        // Reset
        #20 rst_n = 1;
        $display("[RESET] CRC Generator reset released\n");



        // =====================================
        // TEST CASE 1 : CRC COMPUTATION
        // =====================================
        $display("TEST CASE 1: Compute CRC for payload");
        $display("Input Data: 0x12 0x34 0x56 0x78");
        $display("------------------------------------");

        @(posedge clk);
        crc_en = 1;

        send_crc_byte(8'h12);
        send_crc_byte(8'h34);
        send_crc_byte(8'h56);
        send_crc_byte(8'h78);

        wait_for_crc;

        computed_crc = crc_out;

        $display("Computed CRC: 0x%08H", computed_crc);
        $display("NOTE: Residue check is NOT expected here (data only)\n");



        #50;



        // =====================================
        // TEST CASE 2 : CRC VERIFICATION
        // =====================================
        $display("TEST CASE 2: CRC Verification");
        $display("Re-sending: Data + CRC");
        $display("CRC Bytes: %02H %02H %02H %02H",
                 computed_crc[31:24],
                 computed_crc[23:16],
                 computed_crc[15:8],
                 computed_crc[7:0]);
        $display("------------------------------------");

        @(posedge clk);
        crc_en = 1;

        // Original data
        send_crc_byte(8'h12);
        send_crc_byte(8'h34);
        send_crc_byte(8'h56);
        send_crc_byte(8'h78);

        // CRC bytes
        send_crc_byte(computed_crc[31:24]);
        send_crc_byte(computed_crc[23:16]);
        send_crc_byte(computed_crc[15:8]);
        send_crc_byte(computed_crc[7:0]);

        wait_for_crc;

        if (crc_valid) begin
            $display("PASS: CRC residue detected -> frame VALID ✓\n");
        end
        else begin
            $display("FAIL: CRC residue not detected -> frame INVALID ✗\n");
            errors = errors + 1;
        end



        #50;



        // =====================================
        // TEST CASE 3 : SINGLE BYTE CRC
        // =====================================
        $display("TEST CASE 3: Single Byte CRC");
        $display("Input Data: 0xB6");
        $display("------------------------------------");

        @(posedge clk);
        crc_en = 1;

        send_crc_byte(8'hB6);

        wait_for_crc;

        $display("Computed CRC: 0x%08H", crc_out);
        $display("NOTE: No residue expected (data only)\n");



        #50;



        // =====================================
        // TEST CASE 4 : DIFFERENT DATA PATTERN
        // =====================================
        $display("TEST CASE 4: Compute + Verify pattern");
        $display("Input Data: 0xAA 0xBB 0xCC 0xDD");
        $display("------------------------------------");

        @(posedge clk);
        crc_en = 1;

        send_crc_byte(8'hAA);
        send_crc_byte(8'hBB);
        send_crc_byte(8'hCC);
        send_crc_byte(8'hDD);

        wait_for_crc;

        computed_crc = crc_out;

        $display("Computed CRC: 0x%08H", computed_crc);



        // Verification phase
        #50;

        @(posedge clk);
        crc_en = 1;

        send_crc_byte(8'hAA);
        send_crc_byte(8'hBB);
        send_crc_byte(8'hCC);
        send_crc_byte(8'hDD);

        send_crc_byte(computed_crc[31:24]);
        send_crc_byte(computed_crc[23:16]);
        send_crc_byte(computed_crc[15:8]);
        send_crc_byte(computed_crc[7:0]);

        wait_for_crc;

        if (crc_valid) begin
            $display("PASS: CRC verification successful ✓\n");
        end
        else begin
            $display("FAIL: CRC verification failed ✗\n");
            errors = errors + 1;
        end



        // =====================================
        // SUMMARY
        // =====================================
        #100;

        $display("========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("Total Test Cases: 4");
        $display("Verification Tests: 2");
        $display("Errors Found: %0d", errors);

        if (errors == 0) begin
            $display("CRC Computation: Working ✓");
            $display("CRC Verification: Working ✓");
            $display("Status: ✓ ALL TESTS PASSED");
        end
        else begin
            $display("Status: ✗ SOME TESTS FAILED");
        end

        $display("========================================\n");

        $stop;

    end

endmodule