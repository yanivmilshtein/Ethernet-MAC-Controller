module frame_transmission(
    input wire clk,
    input wire rst_n,
    input wire [47:0] dest_addr,
    input wire [47:0] src_addr,
    input wire [15:0] eth_type,
    input wire [31:0] data_in,
    input wire start,          // Signal to start frame transmission
    output reg [7:0] tx_out,
    output reg tx_done,
    output reg tx_en           // Transmission enable
);

    // State encoding
    parameter IDLE        = 3'b000;
    parameter PREAMBLE    = 3'b001;
    parameter SFD         = 3'b010;
    parameter DEST_ADDR   = 3'b011;
    parameter SRC_ADDR    = 3'b100;
    parameter ETH_TYPE    = 3'b101;
    parameter PAYLOAD     = 3'b110;
    parameter CRC         = 3'b111;

    reg [2:0] state, next_state;
    reg [2:0] byte_count;  // Count for bytes within each section

    // FSM sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            byte_count <= 0;
            tx_en <= 0;
            tx_done <= 0;
            tx_out <= 8'h00;
        end else begin
            state <= next_state;
        end
    end

    // FSM combinational logic
    always @* begin
        // Default values
        next_state = state;
        tx_en = 0;
        tx_done = 0;
        
        case (state)
            IDLE: begin
                tx_out = 8'h00;
                byte_count = 0;
                if (start) begin
                    next_state = PREAMBLE;
                    tx_en = 1;
                end
            end

            PREAMBLE: begin
                tx_out = 8'h55;
                tx_en = 1;
                if (byte_count == 6) begin
                    next_state = SFD;
                    byte_count = 0;
                end else begin
                    byte_count = byte_count + 1;
                end
            end

            SFD: begin
                tx_out = 8'hD5;
                tx_en = 1;
                next_state = DEST_ADDR;
                byte_count = 0;
            end

            DEST_ADDR: begin
                tx_out = dest_addr[47 - (byte_count * 8) -: 8];
                tx_en = 1;
                if (byte_count == 5) begin
                    next_state = SRC_ADDR;
                    byte_count = 0;
                end else begin
                    byte_count = byte_count + 1;
                end
            end

            SRC_ADDR: begin
                tx_out = src_addr[47 - (byte_count * 8) -: 8];
                tx_en = 1;
                if (byte_count == 5) begin
                    next_state = ETH_TYPE;
                    byte_count = 0;
                end else begin
                    byte_count = byte_count + 1;
                end
            end

            ETH_TYPE: begin
                tx_out = eth_type[15 - (byte_count * 8) -: 8];
                tx_en = 1;
                if (byte_count == 1) begin
                    next_state = PAYLOAD;
                    byte_count = 0;
                end else begin
                    byte_count = byte_count + 1;
                end
            end

            PAYLOAD: begin
                tx_out = data_in[31 - (byte_count * 8) -: 8];
                tx_en = 1;
                if (byte_count == 3) begin
                    next_state = CRC;
                    byte_count = 0;
                end else begin
                    byte_count = byte_count + 1;
                end
            end

            CRC: begin
                tx_out = 8'hFF;  // Placeholder for CRC byte
                tx_en = 1;
                tx_done = 1;      // Indicate transmission is complete
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
                tx_out = 8'h00;
                tx_en = 0;
                tx_done = 0;
            end
        endcase
    end
endmodule
