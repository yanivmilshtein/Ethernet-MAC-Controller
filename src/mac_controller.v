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
    input  wire [47:0]  app_tx_dest_mac,      // Destination MAC from application
    input  wire [47:0]  app_tx_src_mac,       // Source MAC from application
    input  wire [15:0]  app_tx_eth_type,      // Ethernet type from application

    // TX completion flag
    output wire         tx_done,

    // Debug outputs (optional)
    output wire [3:0]   tx_state,
    output wire         tx_fifo_full,
    output wire         tx_fifo_empty,
    output wire         rx_fifo_full,
    output wire         rx_fifo_empty
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

// FIFO TX
wire        tx_fifo_full;
wire        tx_fifo_empty;
wire [7:0]  tx_fifo_data_out;
wire        tx_fifo_wr_en;
wire        tx_fifo_rd_en;

// Frame Transmission interface
wire [3:0]  frame_tx_state;
wire [2:0]  frame_tx_byte_count;
wire [31:0] frame_tx_crc_out;

// CRC (TX)
wire [31:0] crc_tx_out;
wire        crc_tx_done;

// CRC (RX)
wire [31:0] crc_rx_out;
wire        crc_rx_done;

// -----------------------------------------------------------------------------
// Assignments
// -----------------------------------------------------------------------------
assign rx_fifo_wr_en       = rx_en & rx_data_valid;
assign rx_fifo_rd_en       = rx_en & ~rx_fifo_empty;     // simple read when enabled
assign rx_frame_data_valid = ~rx_fifo_empty & rx_en;

// Assignments for TX path
assign tx_fifo_wr_en       = app_tx_data_valid & ~tx_fifo_full;
assign tx_fifo_rd_en       = (frame_tx_state == 4'b0110) & ~tx_fifo_empty; // Read when in PAYLOAD state
assign tx_data_valid       = tx_en;
assign tx_data             = tx_fifo_data_out;

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
// CRC Generator for RX (CRC checking/validation)
crc_generator u_crc_rx (
    .clk        (clk),
    .rst_n      (rst_n),
    .data_in    (rx_fifo_data_out),
    .data_valid (rx_frame_data_valid),
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

// Instantiate CRC Generator for TX (debug)
// CRC is driven by frame_transmission tx_out signal
crc_generator u_crc_tx (
    .clk        (clk),
    .rst_n      (rst_n),
    .data_in    (tx_fifo_data_out),
    .data_valid (tx_fifo_rd_en),
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
    .dest_addr  (app_tx_dest_mac),           // Application-provided destination MAC
    .src_addr   (app_tx_src_mac),            // Application-provided source MAC
    .eth_type   (app_tx_eth_type),           // Application-provided Ethernet type
    .data_in    (tx_fifo_data_out),          // Data from TX FIFO
    .start      (app_tx_start),              // Start transmission
    .tx_out     (tx_data),                   // Output to PHY
    .tx_done    (tx_done),                   // Transmission complete
    .tx_en      (tx_en),                     // Transmission enable output
    .state      (frame_tx_state),            // Debug: current state
    .next_state (),                          // Debug: next state (optional)
    .crc_done   (crc_tx_done),               // CRC completion signal
    .byte_count (frame_tx_byte_count),       // Debug: byte counter
    .crc__out   (frame_tx_crc_out)           // Debug: CRC output
);

endmodule
