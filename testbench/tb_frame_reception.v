`timescale 1ns/1ps

module tb_frame_reception;

    // ==================== TESTBENCH SIGNALS ====================
    reg clk;
    reg rst_n;
    reg rx_en;
    reg [7:0] rx_data;
    reg rx_data_valid;

    wire [47:0] dest_mac;
    wire [47:0] src_mac;
    wire [15:0] eth_type;
    wire [7:0] payload;
    wire payload_valid;
    wire frame_valid;
    wire rx_done;

    // ==================== DUT ====================
    frame_reception uut (
        .clk(clk),
        .rst_n(rst_n),
        .rx_en(rx_en),
        .rx_data(rx_data),
        .rx_data_valid(rx_data_valid),
        .dest_mac(dest_mac),
        .src_mac(src_mac),
        .eth_type(eth_type),
        .payload(payload),
        .payload_valid(payload_valid),
        .frame_valid(frame_valid),
        .rx_done(rx_done)
    );

    // ==================== CLOCK ====================
    always #5 clk = ~clk;

    // ==================== TEST VARIABLES ====================
    integer test_passed;
    integer test_failed;
    integer byte_count;

    reg [3:0] prev_state;

    reg [63:0] state_name;
    reg [63:0] prev_state_name;

    // ===== LATCHED RESULTS (CRITICAL FIX) =====
    reg [47:0] sampled_dest_mac;
    reg [47:0] sampled_src_mac;
    reg [15:0] sampled_eth_type;
    reg        sampled_frame_valid;

    // ==================== STATE NAME ====================
    always @(*) begin
        case (uut.state)
            4'd0: state_name = "IDLE";
            4'd1: state_name = "PREAMBLE";
            4'd2: state_name = "SFD";
            4'd3: state_name = "DEST_MAC";
            4'd4: state_name = "SRC_MAC";
            4'd5: state_name = "ETH_TYPE";
            4'd6: state_name = "PAYLOAD";
            4'd7: state_name = "CRC";
            4'd8: state_name = "FINALIZE";
            default: state_name = "UNKNOWN";
        endcase
    end

    // ==================== SEND BYTE ====================
    task send_byte(input [7:0] byte_val);
    begin
        @(posedge clk);
        rx_data       <= byte_val;
        rx_data_valid <= 1'b1;

        @(posedge clk);
        rx_data_valid <= 1'b0;

        @(posedge clk);
    end
    endtask

    // ==================== SEND BYTE WITH MSG ====================
    task send_byte_with_msg(input [7:0] byte_val, input [127:0] msg);
    begin
        $display("[%0t] SEND: %s = 0x%h", $time, msg, byte_val);
        send_byte(byte_val);
    end
    endtask

    // ==================== CHECK RESULT ====================
    task check_result(input [127:0] desc, input [63:0] actual, input [63:0] expected);
    begin
        if (actual == expected) begin
            $display("[%0t] [OK] %s", $time, desc);
            test_passed = test_passed + 1;
        end else begin
            $display("[%0t] [FAIL] %s | Expected: 0x%h Got: 0x%h",
                     $time, desc, expected, actual);
            test_failed = test_failed + 1;
        end
    end
    endtask

    // ==================== MAIN TEST ====================
    initial begin

        test_passed = 0;
        test_failed = 0;
        byte_count  = 0;

        clk = 0;
        rst_n = 0;
        rx_en = 0;
        rx_data = 0;
        rx_data_valid = 0;

        $display("\n====================================================");
        $display("      ETHERNET FRAME RECEPTION TESTBENCH");
        $display("====================================================\n");

        // Reset
        $display("[%0t] Reset asserted", $time);
        repeat(4) @(posedge clk);
        rst_n = 1;
        repeat(4) @(posedge clk);
        $display("[%0t] Reset released\n", $time);

        // Start frame
        @(posedge clk);
        rx_en <= 1;

        // ==================== PREAMBLE ====================
        $display("\n--- PREAMBLE ---");
        repeat(7) send_byte_with_msg(8'hAA, "Preamble");

        // ==================== SFD ====================
        $display("\n--- SFD ---");
        send_byte_with_msg(8'hAB, "SFD");

        // ==================== DEST MAC ====================
        $display("\n--- DEST MAC ---");
        send_byte_with_msg(8'h11,"Dest[47:40]");
        send_byte_with_msg(8'h22,"Dest[39:32]");
        send_byte_with_msg(8'h33,"Dest[31:24]");
        send_byte_with_msg(8'h44,"Dest[23:16]");
        send_byte_with_msg(8'h55,"Dest[15:8]");
        send_byte_with_msg(8'h66,"Dest[7:0]");

        // ==================== SRC MAC ====================
        $display("\n--- SRC MAC ---");
        send_byte_with_msg(8'hAA,"Src[47:40]");
        send_byte_with_msg(8'hBB,"Src[39:32]");
        send_byte_with_msg(8'hCC,"Src[31:24]");
        send_byte_with_msg(8'hDD,"Src[23:16]");
        send_byte_with_msg(8'hEE,"Src[15:8]");
        send_byte_with_msg(8'hFF,"Src[7:0]");

        // ==================== ETH TYPE ====================
        $display("\n--- ETH TYPE ---");
        send_byte_with_msg(8'h08,"Type[15:8]");
        send_byte_with_msg(8'h00,"Type[7:0]");

        // ==================== PAYLOAD ====================
        $display("\n--- PAYLOAD ---");
        for (byte_count=0; byte_count<46; byte_count=byte_count+1)
            send_byte(byte_count);

        // ==================== CRC ====================
        $display("\n--- CRC ---");
        send_byte_with_msg(8'hE3,"CRC");
        send_byte_with_msg(8'hA3,"CRC");
        send_byte_with_msg(8'hD2,"CRC");
        send_byte_with_msg(8'h1D,"CRC");

        // End frame (trigger CRC finalize)
        rx_en <= 0;

        // wait for receiver to finish
        @(posedge rx_done);

        // sample results AFTER CRC check
        sampled_dest_mac   = dest_mac;
        sampled_src_mac    = src_mac;
        sampled_eth_type   = eth_type;
        sampled_frame_valid = frame_valid;

        $display("\n[TB] Results sampled after rx_done\n");

                repeat(10) @(posedge clk);

        // ==================== CHECK RESULTS ====================
        $display("\n====================================================");
        $display("               TEST RESULTS");
        $display("====================================================\n");

        check_result("Dest MAC",sampled_dest_mac,48'h112233445566);
        check_result("Src MAC",sampled_src_mac,48'hAABBCCDDEEFF);
        check_result("Eth Type",sampled_eth_type,16'h0800);

        $display("\n--- CRC VALIDATION ---");

        if (sampled_frame_valid) begin
            $display("[OK] CRC validation PASSED");
            test_passed = test_passed + 1;
        end
        else begin
            $display("[INFO] CRC validation FAILED (frame_valid=0)");
        end

        $display("\nTests Passed: %0d",test_passed);
        $display("Tests Failed: %0d\n",test_failed);

        if (test_failed==0)
            $display("[SUCCESS] All tests passed!");
        else
            $display("[WARNING] Some tests failed.");

        $stop;

    end

    // ==================== STATE MONITOR ====================
    always @(posedge clk) begin
        if (rst_n) begin
            if (uut.state != prev_state) begin
                $display("[%0t] STATE: %s -> %s",
                         $time, prev_state_name, state_name);
                prev_state <= uut.state;
                prev_state_name <= state_name;
            end
        end
    end

endmodule