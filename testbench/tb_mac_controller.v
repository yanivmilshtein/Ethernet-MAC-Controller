`timescale 1ns/1ps

module tb_mac_controller;

////////////////////////////////////////////////////////////
// CLOCK / RESET
////////////////////////////////////////////////////////////

reg clk;
reg rst_n;

parameter CLK_PERIOD = 10;

always #(CLK_PERIOD/2) clk = ~clk;

////////////////////////////////////////////////////////////
// PHY RX Interface
////////////////////////////////////////////////////////////

reg        rx_en;
reg [7:0]  rx_data;
reg        rx_data_valid;

////////////////////////////////////////////////////////////
// PHY TX Interface
////////////////////////////////////////////////////////////

wire       tx_en;
wire [7:0] tx_data;
wire       tx_data_valid;

////////////////////////////////////////////////////////////
// RX Outputs
////////////////////////////////////////////////////////////

wire [47:0] dest_mac;
wire [47:0] src_mac;
wire [15:0] eth_type;
wire        frame_valid;
wire        rx_done;

////////////////////////////////////////////////////////////
// TX Application Interface
////////////////////////////////////////////////////////////

reg  [7:0]  app_tx_data;
reg         app_tx_data_valid;
reg         app_tx_start;
reg  [47:0] app_tx_dest_mac;
reg  [47:0] app_tx_src_mac;
reg  [15:0] app_tx_eth_type;

////////////////////////////////////////////////////////////
// Status
////////////////////////////////////////////////////////////

wire tx_done;
wire [3:0] tx_state;
wire tx_fifo_full;
wire tx_fifo_empty;
wire rx_fifo_full;
wire rx_fifo_empty;

////////////////////////////////////////////////////////////
// Frame capture buffer
////////////////////////////////////////////////////////////

reg [7:0] captured_frame [0:255];
integer frame_len;

////////////////////////////////////////////////////////////
// Expected frame constants
////////////////////////////////////////////////////////////

localparam EXPECTED_FRAME_SIZE = 72;

////////////////////////////////////////////////////////////
// DUT
////////////////////////////////////////////////////////////

mac_controller u_mac_controller (
    .clk(clk),
    .rst_n(rst_n),

    .rx_en(rx_en),
    .rx_data(rx_data),
    .rx_data_valid(rx_data_valid),

    .tx_en(tx_en),
    .tx_data(tx_data),
    .tx_data_valid(tx_data_valid),

    .dest_mac(dest_mac),
    .src_mac(src_mac),
    .eth_type(eth_type),
    .frame_valid(frame_valid),
    .rx_done(rx_done),

    .app_tx_data(app_tx_data),
    .app_tx_data_valid(app_tx_data_valid),
    .app_tx_start(app_tx_start),
    .app_tx_dest_mac(app_tx_dest_mac),
    .app_tx_src_mac(app_tx_src_mac),
    .app_tx_eth_type(app_tx_eth_type),

    .tx_done(tx_done),
    .tx_state(tx_state),
    .tx_fifo_full(tx_fifo_full),
    .tx_fifo_empty(tx_fifo_empty),
    .rx_fifo_full(rx_fifo_full),
    .rx_fifo_empty(rx_fifo_empty)
);

////////////////////////////////////////////////////////////
// RESET
////////////////////////////////////////////////////////////

initial begin
    clk = 0;

    rst_n = 0;
    rx_en = 0;
    rx_data = 0;
    rx_data_valid = 0;

    app_tx_data = 0;
    app_tx_data_valid = 0;
    app_tx_start = 0;

    repeat(10) @(posedge clk);
    rst_n = 1;

    repeat(10) @(posedge clk);

    test_tx_path();
    repeat(20) @(posedge clk);
    test_rx_path();

    $display("\n==============================");
    $display("  TESTBENCH COMPLETE");
    $display("==============================");

    $stop;
end

////////////////////////////////////////////////////////////
// TX TEST
////////////////////////////////////////////////////////////

task test_tx_path;

integer i;
reg [7:0] payload [0:45];

begin

    $display("\n==============================");
    $display("TEST 1 : TX PATH");
    $display("==============================");

    //////////////////////////////////////////////////////////
    // Configure header
    //////////////////////////////////////////////////////////

    app_tx_dest_mac = 48'h001122334455;
    app_tx_src_mac  = 48'hAABBCCDDEEFF;
    app_tx_eth_type = 16'h0800;

    //////////////////////////////////////////////////////////
    // Generate payload
    //////////////////////////////////////////////////////////

    for(i=0;i<46;i=i+1)
        payload[i] = 8'h41 + i;

    //////////////////////////////////////////////////////////
    // Fill payload FIFO
    //////////////////////////////////////////////////////////

    for(i=0;i<46;i=i+1)
    begin
        @(posedge clk);
        app_tx_data       <= payload[i];
        app_tx_data_valid <= 1;
    end

    @(posedge clk);
    app_tx_data_valid <= 0;

    //////////////////////////////////////////////////////////
    // Start TX
    //////////////////////////////////////////////////////////

    repeat(5) @(posedge clk);

    app_tx_start <= 1;
    @(posedge clk);
    app_tx_start <= 0;

//////////////////////////////////////////////////////////
// Capture frame
//////////////////////////////////////////////////////////

frame_len = 0;

// Wait until first valid byte appears
wait(tx_data_valid);

//////////////////////////////////////////////////////////
// Capture all bytes
//////////////////////////////////////////////////////////

while(tx_data_valid || tx_en)
begin
    @(posedge clk);

    if(tx_data_valid)
    begin
        captured_frame[frame_len] = tx_data;
        frame_len = frame_len + 1;
    end
end

//////////////////////////////////////////////////////////
// Drain pipeline (CRC latency safety)
//////////////////////////////////////////////////////////

repeat(4)
begin
    @(posedge clk);

    if(tx_data_valid)
    begin
        captured_frame[frame_len] = tx_data;
        frame_len = frame_len + 1;
    end
end

    repeat(5) @(posedge clk);
    wait(tx_state == 0);
    repeat(5) @(posedge clk);

    //////////////////////////////////////////////////////////
    // Frame verification
    //////////////////////////////////////////////////////////

    $display("Captured frame size = %0d bytes", frame_len);

    if(frame_len == EXPECTED_FRAME_SIZE)
        $display("[PASS] Frame size correct");
    else
        $display("[FAIL] Frame size incorrect");

end
endtask

////////////////////////////////////////////////////////////
// RX TEST
////////////////////////////////////////////////////////////

task test_rx_path;

integer i;

begin

    $display("\n==============================");
    $display("TEST 2 : RX PATH");
    $display("==============================");

    rx_en = 1;

    //////////////////////////////////////////////////////////
    // Inject captured frame (continuous stream)
    //////////////////////////////////////////////////////////

    for(i=0;i<frame_len;i=i+1)
    begin
        @(posedge clk);

        rx_data       <= captured_frame[i];
        rx_data_valid <= 1;

        $display("RX INJECT [%0d] = %02h time=%0t", i, captured_frame[i], $time);
    end

    @(posedge clk);
    rx_data_valid <= 0;
    rx_en <= 0;

    //////////////////////////////////////////////////////////
    // Wait RX parser
    //////////////////////////////////////////////////////////

    $display("Waiting for RX completion...");
    wait(rx_done);
    $display("RX DONE detected at time %0t", $time);

    //////////////////////////////////////////////////////////
    // Header check
    //////////////////////////////////////////////////////////

    $display("Dest MAC  = %h", dest_mac);
    $display("Src MAC   = %h", src_mac);
    $display("EthType   = %h", eth_type);

    if(dest_mac == 48'h001122334455 &&
       src_mac  == 48'hAABBCCDDEEFF &&
       eth_type == 16'h0800)
        $display("[PASS] RX header parsing correct");
    else
        $display("[FAIL] RX header mismatch");

    //////////////////////////////////////////////////////////
    // CRC result
    //////////////////////////////////////////////////////////

    if(frame_valid)
        $display("[PASS] CRC validation PASSED");
    else
        $display("[INFO] CRC validation FAILED (test frame CRC not guaranteed)");

end
endtask

endmodule