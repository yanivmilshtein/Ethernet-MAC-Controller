`timescale 1ns/1ps

module tb_frame_transmission;

reg clk;
reg rst_n;
reg [47:0] dest_addr;
reg [47:0] src_addr;
reg [15:0] eth_type;
reg [7:0] payload_data;
reg payload_valid;
reg [15:0] payload_length;
reg start;

wire [7:0] tx_data;
wire tx_en;
wire tx_done;
wire [31:0] crc_out;
wire crc_done;

frame_transmission uut (
    .clk(clk),
    .rst_n(rst_n),
    .dest_addr(dest_addr),
    .src_addr(src_addr),
    .eth_type(eth_type),
    .payload_data(payload_data),
    .payload_valid(payload_valid),
    .payload_length(payload_length),
    .start(start),
    .tx_data(tx_data),
    .tx_en(tx_en),
    .tx_done(tx_done),
    .crc_out(crc_out),
    .crc_done(crc_done)
);

always #5 clk = ~clk;

integer i;

initial begin

    clk = 0;
    rst_n = 0;
    start = 0;
    payload_valid = 0;

    dest_addr = 48'h112233445566;
    src_addr  = 48'hAABBCCDDEEFF;
    eth_type  = 16'h0800;

    payload_length = 46;

    $display("\n===============================");
    $display("Ethernet Frame TX Simulation");
    $display("===============================\n");

    repeat(5) @(posedge clk);
    rst_n = 1;

    repeat(5) @(posedge clk);

    start = 1;
    @(posedge clk);
    start = 0;

    wait(uut.state == 6);

    payload_valid = 1;

    for (i = 0; i < 46; i = i + 1) begin
        payload_data = i;
        @(posedge clk);
    end

    payload_valid = 0;

    wait(tx_done);

    $display("\nFrame transmission completed");
    $display("CRC = %h", crc_out);

    repeat(10) @(posedge clk);

    $stop;

end

always @(posedge clk) begin
    if (tx_en)
        $display("time=%0t  state=%0d  tx_data=%h",
                 $time, uut.state, tx_data);
end

endmodule