module frame_transmission (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [47:0] dest_addr,
    input  wire [47:0] src_addr,
    input  wire [15:0] eth_type,
    input  wire [7:0]  payload_data,
    input  wire        payload_valid,
    input  wire [15:0] payload_length,
    input  wire        start,

    output reg  [7:0]  tx_data,
    output reg         tx_en,
    output reg         tx_done,

    output wire [31:0] crc_out,
    output wire        crc_done,
    
    // Debug outputs
    output wire [3:0]  state
);

localparam IDLE         = 4'd0;
localparam PREAMBLE     = 4'd1;
localparam SFD          = 4'd2;
localparam DEST_ADDR    = 4'd3;
localparam SRC_ADDR     = 4'd4;
localparam ETH_TYPE     = 4'd5;
localparam PAYLOAD      = 4'd6;
localparam FINALIZE_CRC = 4'd7;
localparam CRC_TX       = 4'd8;

reg [3:0] state_reg, next_state_reg;

reg [7:0]  byte_count;
reg [15:0] payload_count;

reg crc_en;

wire crc_done_internal;

crc_generator crc_gen_inst (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(tx_data),
    .data_valid(tx_en),
    .crc_en(crc_en),
    .crc_out(crc_out),
    .crc_done(crc_done_internal),
    .crc_valid()
);

assign crc_done = crc_done_internal;

// ============================================================================
// Debug output: expose internal state for monitoring
// ============================================================================
assign state = state_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        tx_data <= 0;
        tx_en <= 0;
        tx_done <= 0;
        byte_count <= 0;
        payload_count <= 0;
        crc_en <= 0;
    end
    else begin
        state_reg <= next_state_reg;

        if (state_reg != next_state_reg)
            byte_count <= 0;
        else
            byte_count <= byte_count + 1;

        if (state_reg == PAYLOAD && tx_en)
            payload_count <= payload_count + 1;
        else if (state_reg != PAYLOAD)
            payload_count <= 0;
    end
end

always @(*) begin

    next_state_reg = state_reg;
    tx_en = 0;
    tx_done = 0;
    crc_en = 0;
    tx_data = 8'h00;

    case (state_reg)

    IDLE: begin
        if (start)
            next_state_reg = PREAMBLE;
    end

    PREAMBLE: begin
        tx_en = 1;
        tx_data = 8'hAA;

        if (byte_count == 6)
            next_state_reg = SFD;
    end

    SFD: begin
        tx_en = 1;
        tx_data = 8'hAB;
        next_state_reg = DEST_ADDR;
    end

    DEST_ADDR: begin
        tx_en = 1;
        crc_en = 1;
        tx_data = dest_addr[47 - byte_count*8 -: 8];

        if (byte_count == 5)
            next_state_reg = SRC_ADDR;
    end

    SRC_ADDR: begin
        tx_en = 1;
        crc_en = 1;
        tx_data = src_addr[47 - byte_count*8 -: 8];

        if (byte_count == 5)
            next_state_reg = ETH_TYPE;
    end

    ETH_TYPE: begin
        tx_en = 1;
        crc_en = 1;
        tx_data = eth_type[15 - byte_count*8 -: 8];

        if (byte_count == 1)
            next_state_reg = PAYLOAD;
    end

    PAYLOAD: begin
        if (payload_valid) begin
            tx_en = 1;
            crc_en = 1;
            tx_data = payload_data;

            if (payload_count == payload_length - 1)
                next_state_reg = FINALIZE_CRC;
        end
    end

    FINALIZE_CRC: begin
        if (crc_done_internal)
            next_state_reg = CRC_TX;
    end

    CRC_TX: begin
        tx_en = 1;
        tx_data = crc_out[31 - byte_count*8 -: 8];

        if (byte_count == 3) begin
            tx_done = 1;
            next_state_reg = IDLE;
        end
    end

    default: next_state_reg = IDLE;

    endcase
end

endmodule