`// Top-level MAC Controller integrating RX and TX pipelines
module mac_controller (
    input  wire         clk,
    input  wire         rst_n,

    // Physical interface (RX)
    input  wire         rx_en,
    input  wire  [7:0]  rx_data,
    input  wire         rx_data_valid,

    // Physical interface (TX)
    output wire         tx_en,
    output wire  [7:0]  tx_data,
    output wire         tx_data_valid,

    // Parsed RX outputs
    output wire [47:0]  dest_mac,
    output wire [47:0]  src_mac,
    output wire [15:0]  eth_type,
    output wire         frame_valid,
    output wire         rx_done,

    // Application-level TX inputs
    input  wire  [7:0]  app_tx_data,
    input  wire         app_tx_data_valid,
    input  wire         app_tx_start,

    // TX completion flag
    output wire         tx_done
);

// -----------------------------------------------------------------------------
// Internal signals
// -----------------------------------------------------------------------------
// FIFO RX
wire        rx_fifo_full;
wire        rx_fifo_empty;
wire [7:0]  rx_fifo_data_out;
wire        rx_fifo_wr_en;
wire        rx_fifo_rd_en;

// Gate data_valid from FIFO to frame_reception
wire        rx_frame_data_valid;

// CRC (RX)
wire [31:0] crc_rx_out;
wire        crc_rx_done;

// FIFO TX
wire        tx_fifo_full;
wire        tx_fifo_empty;
wire [7:0]  tx_fifo_data_out;
wire        tx_fifo_wr_en;
wire        tx_fifo_rd_en;

// CRC (TX)
wire [31:0] crc_tx_out;
wire        crc_tx_done;

// -----------------------------------------------------------------------------
// Assignments
// -----------------------------------------------------------------------------
assign rx_fifo_wr_en       = rx_en & rx_data_valid;
assign rx_fifo_rd_en       = rx_en & ~rx_fifo_empty;     // simple read when enabled
assign rx_frame_data_valid = ~rx_fifo_empty & rx_en;

assign tx_fifo_wr_en       = app_tx_data_valid;
assign tx_data_valid       = tx_en;                       // output valid when TX enabled
assign tx_data             = tx_fifo_data_out;            // send FIFO data through TX

// -----------------------------------------------------------------------------
// Instantiate FIFO for RX path
// -----------------------------------------------------------------------------
fifo_rx u_fifo_rx (
    .clk         (clk),
    .rst_n       (rst_n),
    .data_in     (rx_data),
    .write_enable(rx_fifo_wr_en),
    .read_enable (rx_fifo_rd_en),
    .data_out    (rx_fifo_data_out),
    .full_flag   (rx_fifo_full),
    .empty_flag  (rx_fifo_empty)
);

// -----------------------------------------------------------------------------
// Instantiate Frame Reception
// -----------------------------------------------------------------------------
frame_reception u_frame_reception (
    .clk           (clk),
    .rst_n         (rst_n),
    .rx_en         (rx_en),
    .rx_data       (rx_fifo_data_out),
    .rx_data_valid (rx_frame_data_valid),

    .dest_mac      (dest_mac),
    .src_mac       (src_mac),
    .eth_type      (eth_type),
    .frame_valid   (frame_valid),
    .rx_done       (rx_done)
);

// -----------------------------------------------------------------------------
// Instantiate CRC Generator for RX (debug)
// -----------------------------------------------------------------------------
crc_generator u_crc_rx (
    .clk        (clk),
    .rst_n      (rst_n),
    .data_in    (rx_fifo_data_out),
    .data_valid(rx_frame_data_valid),
    .crc_en     (rx_en),
    .crc_out    (crc_rx_out),
    .crc_done   (crc_rx_done)
);

// -----------------------------------------------------------------------------
// Instantiate FIFO for TX path
// -----------------------------------------------------------------------------
fifo_tx #(
    .DATA_WIDTH (8),
    .FIFO_DEPTH (16)
) u_fifo_tx (
    .clk      (clk),
    .rst_n    (rst_n),
    .write_en (tx_fifo_wr_en),
    .read_en  (tx_fifo_rd_en),
    .data_in  (app_tx_data),
    .data_out (tx_fifo_data_out),
    .full     (tx_fifo_full),
    .empty    (tx_fifo_empty)
);

// -----------------------------------------------------------------------------
// Instantiate CRC Generator for TX (debug)
// -----------------------------------------------------------------------------
crc_generator u_crc_tx (
    .clk        (clk),
    .rst_n      (rst_n),
    .data_in    ({24'd0, tx_fifo_data_out}), // pad to 32 bits if needed
    .data_valid(tx_en),
    .crc_en     (app_tx_start),
    .crc_out    (crc_tx_out),
    .crc_done   (crc_tx_done)
);

// -----------------------------------------------------------------------------
// Instantiate Frame Transmission
// -----------------------------------------------------------------------------
frame_transmission u_frame_transmission (
    .clk        (clk),
    .rst_n      (rst_n),
    .dest_addr  (),               // connect application-defined dest MAC
    .src_addr   (),               // connect application-defined src MAC
    .eth_type   (),               // connect application-defined Ethernet type
    .data_in    (tx_fifo_data_out),
    .start      (app_tx_start),
    .tx_out     (tx_data),
    .tx_done    (tx_done),
    .tx_en      (tx_en),
    .state      (),               // optional debug
    .next_state (),
    .crc_done   (crc_tx_done),
    .byte_count (),               // debug
    .crc__out   (crc_tx_out)
);

endmodule
