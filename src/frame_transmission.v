module frame_transmission (
    input wire clk,
    input wire rst_n,
    input wire [31:0] data_in,
    input wire tx_en,
    output reg [7:0] tx_out,
    output reg tx_done,
    output wire data_en
);

    // Frame state and byte counter
    reg [2:0] state;
    reg [3:0] byte_count;
    reg [7:0] preamble = 8'h55;
    reg [7:0] sfd = 8'hD5;
    reg [47:0] dest_addr = 48'hFF_FF_FF_FF_FF_FF;
    reg [47:0] src_addr = 48'hAA_BB_CC_DD_EE_FF;
    reg [15:0] eth_type = 16'h0800;
    reg [31:0] crc_reg;

    // Frame states
    localparam IDLE = 3'b000, PREAMBLE = 3'b001, SFD = 3'b010, DEST_ADDR = 3'b011,
               SRC_ADDR = 3'b100, ETH_TYPE = 3'b101, PAYLOAD = 3'b110, CRC = 3'b111;

    assign data_en = (state != IDLE && state != CRC) || (state == CRC && crc_reg != 0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tx_out <= 0;
            tx_done <= 0;
            byte_count <= 0;
            crc_reg <= 32'hFFFFFFFF;
        end else begin
            case (state)
                IDLE: begin
                    tx_done <= 0;
                    if (tx_en) begin
                        state <= PREAMBLE;
                        byte_count <= 0;
                    end
                end
                PREAMBLE: begin
                    tx_out <= preamble;
                    byte_count <= byte_count + 1;
                    if (byte_count == 7) begin
                        state <= SFD;
                        byte_count <= 0;
                    end
                end
                SFD: begin
                    tx_out <= sfd;
                    state <= DEST_ADDR;
                end
                DEST_ADDR: begin
                    tx_out <= dest_addr[47 - byte_count*8 -: 8];
                    byte_count <= byte_count + 1;
                    if (byte_count == 6) begin
                        state <= SRC_ADDR;
                        byte_count <= 0;
                    end
                end
                SRC_ADDR: begin
                    tx_out <= src_addr[47 - byte_count*8 -: 8];
                    byte_count <= byte_count + 1;
                    if (byte_count == 6) begin
                        state <= ETH_TYPE;
                        byte_count <= 0;
                    end
                end
                ETH_TYPE: begin
                    tx_out <= eth_type[15 - byte_count*8 -: 8];
                    byte_count <= byte_count + 1;
                    if (byte_count == 2) begin
                        state <= PAYLOAD;
                        byte_count <= 0;
                    end
                end
                PAYLOAD: begin
                    tx_out <= data_in[31 - byte_count*8 -: 8];
                    byte_count <= byte_count + 1;
                    if (byte_count == 4) begin
                        state <= CRC;
                        byte_count <= 0;
                    end
                end
                CRC: begin
                    tx_out <= crc_reg[31 - byte_count*8 -: 8];
                    byte_count <= byte_count + 1;
                    if (byte_count == 4) begin
                        state <= IDLE;
                        tx_done <= 1;
                    end
                end
            endcase
        end
    end
endmodule
