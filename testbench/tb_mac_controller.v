`timescale 1ns/1ps

// ============================================================================
// MAC Controller Testbench - Focused TX and RX Testing
// ============================================================================
// Test 1: TX Path - Inject payload into FIFO, transmit complete frame to PHY
// Test 2: RX Path - Inject complete frame from Test 1, extract frame info
// ============================================================================

module tb_mac_controller;

    // =========================================================================
    // Clock and Reset
    // =========================================================================
    reg clk;
    reg rst_n;

    // =========================================================================
    // RX Interface (from PHY)
    // =========================================================================
    reg         rx_en;
    reg  [7:0]  rx_data;
    reg         rx_data_valid;

    // =========================================================================
    // TX Interface (to PHY)
    // =========================================================================
    wire        tx_en;
    wire [7:0]  tx_data;
    wire        tx_data_valid;

    // =========================================================================
    // RX Outputs (to Application)
    // =========================================================================
    wire [47:0] dest_mac;
    wire [47:0] src_mac;
    wire [15:0] eth_type;
    wire        frame_valid;
    wire        rx_done;

    // =========================================================================
    // TX Inputs (from Application)
    // =========================================================================
    reg  [7:0]  app_tx_data;
    reg         app_tx_data_valid;
    reg         app_tx_start;
    reg  [47:0] app_tx_dest_mac;
    reg  [47:0] app_tx_src_mac;
    reg  [15:0] app_tx_eth_type;

    // =========================================================================
    // TX Status
    // =========================================================================
    wire        tx_done;
    wire [3:0]  tx_state;
    wire        tx_fifo_full;
    wire        tx_fifo_empty;
    wire        rx_fifo_full;
    wire        rx_fifo_empty;

    // =========================================================================
    // Test Parameters
    // =========================================================================
    parameter CLK_PERIOD = 10;  // 100MHz
    integer tx_frame_count;
    reg [7:0] captured_tx_frame [0:127];

    // =========================================================================
    // Instantiate MAC Controller
    // =========================================================================
    mac_controller u_mac_controller (
        .clk                (clk),
        .rst_n              (rst_n),
        .rx_en              (rx_en),
        .rx_data            (rx_data),
        .rx_data_valid      (rx_data_valid),
        .tx_en              (tx_en),
        .tx_data            (tx_data),
        .tx_data_valid      (tx_data_valid),
        .dest_mac           (dest_mac),
        .src_mac            (src_mac),
        .eth_type           (eth_type),
        .frame_valid        (frame_valid),
        .rx_done            (rx_done),
        .app_tx_data        (app_tx_data),
        .app_tx_data_valid  (app_tx_data_valid),
        .app_tx_start       (app_tx_start),
        .app_tx_dest_mac    (app_tx_dest_mac),
        .app_tx_src_mac     (app_tx_src_mac),
        .app_tx_eth_type    (app_tx_eth_type),
        .tx_done            (tx_done),
        .tx_state           (tx_state),
        .tx_fifo_full       (tx_fifo_full),
        .tx_fifo_empty      (tx_fifo_empty),
        .rx_fifo_full       (rx_fifo_full),
        .rx_fifo_empty      (rx_fifo_empty)
    );

    // =========================================================================
    // Clock Generation
    // =========================================================================
    always begin
        clk = 1'b0;
        #(CLK_PERIOD/2);
        clk = 1'b1;
        #(CLK_PERIOD/2);
    end

    // =========================================================================
    // Main Test Stimulus
    // =========================================================================
    initial begin
        $display("\n");
        $display("═══════════════════════════════════════════════════════════");
        $display("  MAC CONTROLLER TESTBENCH - TX & RX FOCUSED TESTING");
        $display("═══════════════════════════════════════════════════════════\n");

        // Initialize
        rst_n = 1'b0;
        rx_en = 1'b0;
        rx_data = 8'h00;
        rx_data_valid = 1'b0;
        app_tx_data = 8'h00;
        app_tx_data_valid = 1'b0;
        app_tx_start = 1'b0;
        app_tx_dest_mac = 48'h000000000000;
        app_tx_src_mac = 48'h000000000000;
        app_tx_eth_type = 16'h0000;
        tx_frame_count = 0;

        // Reset
        #(CLK_PERIOD * 5);
        rst_n = 1'b1;
        #(CLK_PERIOD * 5);

        // =====================================================================
        // TEST 1: TX PATH - Fill payload FIFO and transmit frame to PHY
        // =====================================================================
        $display("┌─────────────────────────────────────────────────────────┐");
        $display("│ TEST 1: TX PATH - Frame Transmission                    │");
        $display("│ Fill Payload FIFO → Frame_Transmission → TX FIFO → PHY  │");
        $display("└─────────────────────────────────────────────────────────┘\n");

        test_tx_path();

        // =====================================================================
        // IDLE BETWEEN TESTS
        // =====================================================================
        $display("\n[IDLE] Waiting 10 cycles...\n");
        wait_cycles(10);

        // =====================================================================
        // TEST 2: RX PATH - Inject complete frame from Test 1 and extract info
        // =====================================================================
        $display("┌─────────────────────────────────────────────────────────┐");
        $display("│ TEST 2: RX PATH - Frame Reception                       │");
        $display("│ Inject Frame → RX FIFO → Frame_Reception → Parse Info   │");
        $display("└─────────────────────────────────────────────────────────┘\n");

        test_rx_path();

        // =====================================================================
        // Testbench Complete
        // =====================================================================
        $display("\n");
        $display("═══════════════════════════════════════════════════════════");
        $display("  ALL TESTS COMPLETED");
        $display("═══════════════════════════════════════════════════════════\n");
        $stop;
    end

    // =========================================================================
    // TEST 1: TX PATH TASK
    // =========================================================================
    task test_tx_path();
        integer i;
        integer payload_size;
        reg [7:0] payload [0:45];

        begin
            $display("[TEST 1] Starting TX path test\n");

            // ================================================================
            // STEP 1: Setup TX frame parameters
            // ================================================================
            $display("[STEP 1] Setting up TX frame parameters:");
            app_tx_dest_mac  = 48'h001122334455;
            app_tx_src_mac   = 48'hAABBCCDDEEFF;
            app_tx_eth_type  = 16'h0800;
            $display("  ├─ Destination MAC: %012h", app_tx_dest_mac);
            $display("  ├─ Source MAC:      %012h", app_tx_src_mac);
            $display("  └─ EtherType:       %04h\n", app_tx_eth_type);

            // ================================================================
            // STEP 2: Fill Payload FIFO
            // ================================================================
            $display("[STEP 2] Filling Payload FIFO with data:");
            payload_size = 46;  // Minimum Ethernet payload
            
            // Create payload pattern (0x41='A', 0x42='B', etc.)
            for (i = 0; i < payload_size; i = i + 1) begin
                payload[i] = i + 8'h41;
            end

            $display("  ├─ Payload size: %d bytes", payload_size);
            $display("  ├─ Writing to FIFO:");
            
            for (i = 0; i < payload_size; i = i + 1) begin
                @(posedge clk);
                app_tx_data = payload[i];
                app_tx_data_valid = 1'b1;
                
                // Print every 10 bytes
                if ((i % 10 == 0) || (i == payload_size - 1)) begin
                    $display("  │   [%2d-%2d] bytes written, FIFO Full: %b, Empty: %b", 
                             i, (i+9 < payload_size ? i+9 : payload_size-1), 
                             tx_fifo_full, tx_fifo_empty);
                end
            end
            
            app_tx_data_valid = 1'b0;
            $display("  └─ Payload FIFO fill complete\n");

            // ================================================================
            // STEP 3: Initiate Frame Transmission
            // ================================================================
            $display("[STEP 3] Initiating Frame Transmission:");
            wait_cycles(5);
            
            app_tx_start = 1'b1;
            @(posedge clk);
            app_tx_start = 1'b0;
            $display("  ├─ app_tx_start pulse sent\n");

            // ================================================================
            // STEP 4: Capture TX Frame Output to PHY
            // ================================================================
            $display("[STEP 4] Capturing Ethernet Frame to PHY:\n");
            $display("  [Byte] [Value] [ASCII] [Frame Structure]");
            $display("  ─────────────────────────────────────────");
            
            tx_frame_count = 0;
            
            // Wait for TX to start
            wait (tx_en == 1'b1) @(posedge clk);
            
            // Capture entire frame
            while (tx_en) begin
                captured_tx_frame[tx_frame_count] = tx_data;
                
                // Decode frame structure
                case (tx_frame_count)
                    0, 1, 2, 3, 4, 5, 6: begin
                        $display("  [%3d] 0x%02h  '%c'    [Preamble byte %d]", 
                                 tx_frame_count, tx_data, (tx_data >= 32 && tx_data < 127) ? tx_data : 46, 
                                 tx_frame_count);
                    end
                    7: begin
                        $display("  [%3d] 0x%02h  '%c'    [SFD (Start Frame Delimiter)]", 
                                 tx_frame_count, tx_data, (tx_data >= 32 && tx_data < 127) ? tx_data : 46);
                    end
                    8, 9, 10, 11, 12, 13: begin
                        $display("  [%3d] 0x%02h  '%c'    [Destination MAC byte %d]", 
                                 tx_frame_count, tx_data, (tx_data >= 32 && tx_data < 127) ? tx_data : 46,
                                 tx_frame_count - 8);
                    end
                    14, 15, 16, 17, 18, 19: begin
                        $display("  [%3d] 0x%02h  '%c'    [Source MAC byte %d]", 
                                 tx_frame_count, tx_data, (tx_data >= 32 && tx_data < 127) ? tx_data : 46,
                                 tx_frame_count - 14);
                    end
                    20, 21: begin
                        $display("  [%3d] 0x%02h  '%c'    [EtherType byte %d]", 
                                 tx_frame_count, tx_data, (tx_data >= 32 && tx_data < 127) ? tx_data : 46,
                                 tx_frame_count - 20);
                    end
                    default: begin
                        if (tx_frame_count < 68) begin
                            $display("  [%3d] 0x%02h  '%c'    [Payload byte %d]", 
                                     tx_frame_count, tx_data, (tx_data >= 32 && tx_data < 127) ? tx_data : 46,
                                     tx_frame_count - 22);
                        end else begin
                            $display("  [%3d] 0x%02h  '%c'    [CRC byte %d]", 
                                     tx_frame_count, tx_data, (tx_data >= 32 && tx_data < 127) ? tx_data : 46,
                                     tx_frame_count - 68);
                        end
                    end
                endcase
                
                tx_frame_count = tx_frame_count + 1;
                @(posedge clk);
            end
            
            $display("  ─────────────────────────────────────────");
            $display("  └─ Total frame size: %d bytes\n", tx_frame_count);

            // ================================================================
            // STEP 5: Verify Transmission Complete
            // ================================================================
            wait_cycles(50);
            $display("[STEP 5] TX Transmission Status:");
            $display("  ├─ TX Done: %b", tx_done);
            $display("  ├─ TX FIFO Empty: %b", tx_fifo_empty);
            $display("  └─ Frame transmitted to PHY\n");

            $display("[TEST 1] ✓ TX Path test completed\n");
        end
    endtask

    // =========================================================================
    // TEST 2: RX PATH TASK
    // =========================================================================
    task test_rx_path();
        integer i, j;

        begin
            $display("[TEST 2] Starting RX path test\n");

            // ================================================================
            // STEP 1: Setup to inject frame from Test 1
            // ================================================================
            $display("[STEP 1] Preparing to inject captured TX frame into RX FIFO:");
            $display("  ├─ Frame size: %d bytes", tx_frame_count);
            $display("  ├─ Injecting frame into PHY RX interface\n");

            // ================================================================
            // STEP 2: Inject captured frame into RX
            // ================================================================
            $display("[STEP 2] Injecting Ethernet frame into RX FIFO:\n");
            $display("  [Byte] [Value] [ASCII] [FIFO Status]");
            $display("  ──────────────────────────────────────");
            
            rx_en = 1'b1;
            
            for (i = 0; i < tx_frame_count; i = i + 1) begin
                @(posedge clk);
                rx_data = captured_tx_frame[i];
                rx_data_valid = 1'b1;
                
                $display("  [%3d] 0x%02h  '%c'    Full: %b, Empty: %b", 
                         i, rx_data, (rx_data >= 32 && rx_data < 127) ? rx_data : 46,
                         rx_fifo_full, rx_fifo_empty);
            end
            
            @(posedge clk);
            rx_data_valid = 1'b0;
            rx_en = 1'b0;
            
            $display("  ──────────────────────────────────────");
            $display("  └─ Frame injection complete\n");

            // ================================================================
            // STEP 3: Wait for frame processing
            // ================================================================
            $display("[STEP 3] Waiting for Frame_Reception to parse frame:");
            wait_cycles(300);
            $display("  └─ Frame processing complete\n");

            // ================================================================
            // STEP 4: Display parsed frame information
            // ================================================================
            $display("[STEP 4] Deconstructed Frame Information:\n");
            $display("  ┌─ Destination MAC Address");
            $display("  │   0x%012h", dest_mac);
            $display("  │   Expected: 0x%012h", 48'h001122334455);
            $display("  │   Match: %s", (dest_mac == 48'h001122334455) ? "✓ YES" : "✗ NO");
            
            $display("  ├─ Source MAC Address");
            $display("  │   0x%012h", src_mac);
            $display("  │   Expected: 0x%012h", 48'hAABBCCDDEEFF);
            $display("  │   Match: %s", (src_mac == 48'hAABBCCDDEEFF) ? "✓ YES" : "✗ NO");
            
            $display("  ├─ EtherType/Length");
            $display("  │   0x%04h", eth_type);
            $display("  │   Expected: 0x%04h", 16'h0800);
            $display("  │   Match: %s", (eth_type == 16'h0800) ? "✓ YES" : "✗ NO");
            
            $display("  ├─ Frame Valid (CRC Check)");
            $display("  │   %b", frame_valid);
            
            $display("  └─ RX Done Flag");
            $display("      %b\n", rx_done);

            // ================================================================
            // STEP 5: Overall result
            // ================================================================
            $display("[STEP 5] Frame Reception Status:");
            if (dest_mac == 48'h001122334455 && src_mac == 48'hAABBCCDDEEFF && eth_type == 16'h0800) begin
                $display("  └─ ✓ RX Path test PASSED - Frame correctly parsed\n");
            end else begin
                $display("  └─ ✗ RX Path test FAILED - Frame parsing mismatch\n");
            end

            $display("[TEST 2] ✓ RX Path test completed\n");
        end
    endtask

    // =========================================================================
    // Helper: Wait N clock cycles
    // =========================================================================
    task wait_cycles(input integer num_cycles);
        integer i;
        begin
            for (i = 0; i < num_cycles; i = i + 1) begin
                @(posedge clk);
            end
        end
    endtask

endmodule
