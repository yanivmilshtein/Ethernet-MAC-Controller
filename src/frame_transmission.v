module frame_transmission (
    input wire clk,
    input wire rst_n,
    input wire [31:0] data_in,   // Payload data
    input wire tx_en,            // Enable transmission
    output reg [7:0] tx_out,     // Serialized frame output
    output reg tx_done           // Transmission done signal
);

    // State encoding
    reg [2:0] state;
    reg [31:0] crc_reg;
    reg [7:0] preamble = 8'h55;            // Preamble value
    reg [7:0] sfd = 8'hD5;                 // Start frame delimiter
    reg [47:0] dest_addr = 48'hFF_FF_FF_FF_FF_FF; // Broadcast address for example
    reg [47:0] src_addr = 48'hAA_BB_CC_DD_EE_FF;  // Source MAC address
    reg [15:0] eth_type = 16'h0800;        // EtherType for IPv4

    reg [15:0] byte_count;

    // Define states
    localparam IDLE = 3'b000;
    localparam PREAMBLE = 3'b001;
    localparam SFD = 3'b010;
    localparam DEST_ADDR = 3'b011;
    localparam SRC_ADDR = 3'b100;
    localparam ETH_TYPE = 3'b101;
    localparam PAYLOAD = 3'b110;
    localparam CRC = 3'b111;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tx_out <= 0;
            tx_done <= 0;
            byte_count <= 0;
            crc_reg <= 32'hFFFFFFFF;  // Initial CRC value
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
                    byte_count <= 0;
                end
                DEST_ADDR: begin
                    tx_out <= dest_addr[47 - (byte_count * 8) +: 8];  // Send one byte at a time
                    byte_count <= byte_count + 1;
                    if (byte_count == 5) begin
                        state <= SRC_ADDR;
                        byte_count <= 0;
                    end
                end
                SRC_ADDR: begin
                    tx_out <= src_addr[47 - (byte_count * 8) +: 8];
                    byte_count <= byte_count + 1;
                    if (byte_count == 5) begin
                        state <= ETH_TYPE;
                        byte_count <= 0;
                    end
                end
                ETH_TYPE: begin
                    tx_out <= eth_type[15 - (byte_count * 8) +: 8];
                    byte_count <= byte_count + 1;
                    if (byte_count == 1) begin
                        state <= PAYLOAD;
                        byte_count <= 0;
                    end
                end
                PAYLOAD: begin
                    tx_out <= data_in[31 - (byte_count * 8) +: 8];
                    crc_reg <= (crc_reg << 8) ^ data_in[31 - (byte_count * 8) +: 8];  // Update CRC with byte
                    byte_count <= byte_count + 1;
                    if (byte_count == 3) begin
                        state <= CRC;
                        byte_count <= 0;
                    end
                end
                CRC: begin
                    tx_out <= crc_reg[31 - (byte_count * 8) +: 8];
                    byte_count <= byte_count + 1;
                    if (byte_count == 3) begin
                        state <= IDLE;
                        tx_done <= 1;
                    end
                end
            endcase
        end
    end
endmodule
