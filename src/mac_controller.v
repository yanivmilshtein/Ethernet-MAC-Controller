// ============================================================================
// Top-level MAC Controller - Integrates RX and TX pipelines
// ============================================================================
// RX Path:
//   PHY → RX FIFO → Frame_Reception → Application
//
// TX Path:
//   Application → Payload FIFO → Frame_Transmission → TX FIFO → PHY
// ============================================================================

module mac_controller (

    // Clock / Reset
    input  wire        clk,
    input  wire        rst_n,

    // ==============================
    // PHY RX Interface
    // ==============================
    input  wire        rx_en,
    input  wire [7:0]  rx_data,
    input  wire        rx_data_valid,

    // ==============================
    // PHY TX Interface
    // ==============================
    output wire        tx_en,
    output wire [7:0]  tx_data,
    output wire        tx_data_valid,

    // ==============================
    // RX outputs to application
    // ==============================
    output wire [47:0] dest_mac,
    output wire [47:0] src_mac,
    output wire [15:0] eth_type,
    output wire        frame_valid,
    output wire        rx_done,

    // ==============================
    // TX inputs from application
    // ==============================
    input  wire [7:0]  app_tx_data,
    input  wire        app_tx_data_valid,
    input  wire        app_tx_start,
    input  wire [47:0] app_tx_dest_mac,
    input  wire [47:0] app_tx_src_mac,
    input  wire [15:0] app_tx_eth_type,

    // ==============================
    // Status
    // ==============================
    output wire        tx_done,

    // Debug
    output wire [3:0]  tx_state,
    output wire        tx_fifo_full,
    output wire        tx_fifo_empty,
    output wire        rx_fifo_full,
    output wire        rx_fifo_empty
);

    // ==========================================================
    // RX FIFO signals
    // ==========================================================

    wire [7:0] rx_fifo_data_out;
    wire       rx_fifo_wr_en;
    wire       rx_fifo_rd_en;

    assign rx_fifo_wr_en = rx_en & rx_data_valid;

    // FIXED: read whenever data exists (do not tie to rx_en)
    assign rx_fifo_rd_en = ~rx_fifo_empty;

    wire rx_fifo_data_valid = ~rx_fifo_empty;

    // ==========================================================
    // TX FIFO signals
    // ==========================================================

    wire [7:0] tx_fifo_data_out;
    wire       tx_fifo_wr_en;
    wire       tx_fifo_rd_en;

    // ==========================================================
    // Frame transmission outputs
    // ==========================================================

    wire [7:0] frame_tx_data;
    wire       frame_tx_en;
    wire [3:0] frame_tx_state;

    assign tx_state = frame_tx_state;

    // ==========================================================
    // Payload FIFO signals
    // ==========================================================

    wire [7:0] payload_fifo_data_out;
    wire       payload_fifo_empty;
    wire       payload_fifo_full;
    wire       payload_fifo_wr_en;
    wire       payload_fifo_rd_en;

    assign payload_fifo_wr_en = app_tx_data_valid;

    // ==========================================================
    // TX control logic
    // ==========================================================

    assign tx_fifo_wr_en = frame_tx_en;

    // FIXED: PHY drains FIFO whenever data exists
    assign tx_fifo_rd_en = ~tx_fifo_empty;

    assign tx_en         = ~tx_fifo_empty;
    assign tx_data       = tx_fifo_data_out;
    assign tx_data_valid = ~tx_fifo_empty;

    // ==========================================================
    // Payload FIFO read only during PAYLOAD state
    // ==========================================================

    localparam PAYLOAD = 4'd6;

    assign payload_fifo_rd_en =
        (frame_tx_state == PAYLOAD);

    // ==========================================================
    // RX FIFO
    // ==========================================================

    fifo_rx u_fifo_rx (
        .clk          (clk),
        .rst_n        (rst_n),
        .data_in      (rx_data),
        .write_enable (rx_fifo_wr_en),
        .read_enable  (rx_fifo_rd_en),
        .data_out     (rx_fifo_data_out),
        .full_flag    (rx_fifo_full),
        .empty_flag   (rx_fifo_empty)
    );

    // ==========================================================
    // Frame Reception
    // ==========================================================

    frame_reception u_frame_reception (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx_en         (rx_en),
        .rx_data       (rx_fifo_data_out),
        .rx_data_valid (rx_fifo_data_valid),
        .dest_mac      (dest_mac),
        .src_mac       (src_mac),
        .eth_type      (eth_type),
        .payload       (),
        .payload_valid (),
        .frame_valid   (frame_valid),
        .rx_done       (rx_done)
    );

    // ==========================================================
    // TX FIFO
    // ==========================================================

    fifo_tx #(
        .DATA_WIDTH (8),
        .FIFO_DEPTH (16)
    ) u_fifo_tx (
        .clk      (clk),
        .rst_n    (rst_n),
        .write_en (tx_fifo_wr_en),
        .read_en  (tx_fifo_rd_en),
        .data_in  (frame_tx_data),
        .data_out (tx_fifo_data_out),
        .full     (tx_fifo_full),
        .empty    (tx_fifo_empty)
    );

    // ==========================================================
    // Payload FIFO
    // ==========================================================

    fifo_tx #(
        .DATA_WIDTH (8),
        .FIFO_DEPTH (256)
    ) u_payload_fifo (
        .clk      (clk),
        .rst_n    (rst_n),
        .write_en (payload_fifo_wr_en),
        .read_en  (payload_fifo_rd_en),
        .data_in  (app_tx_data),
        .data_out (payload_fifo_data_out),
        .full     (payload_fifo_full),
        .empty    (payload_fifo_empty)
    );

    // ==========================================================
    // Frame Transmission
    // ==========================================================

    frame_transmission u_frame_transmission (
        .clk            (clk),
        .rst_n          (rst_n),
        .dest_addr      (app_tx_dest_mac),
        .src_addr       (app_tx_src_mac),
        .eth_type       (app_tx_eth_type),
        .payload_data   (payload_fifo_data_out),
        .payload_valid  (~payload_fifo_empty),
        .payload_length (16'd46),
        .start          (app_tx_start),
        .tx_data        (frame_tx_data),
        .tx_en          (frame_tx_en),
        .tx_done        (tx_done),
        .crc_out        (),
        .crc_done       (),
        .state          (frame_tx_state)
    );

endmodule