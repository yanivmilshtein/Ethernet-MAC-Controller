`timescale 1ns/1ps

module frame_reception (
    input wire clk,
    input wire rst_n,
    input wire rx_en,              // Frame reception active
    input wire [7:0] rx_data,      // Received data byte
    input wire rx_data_valid,      // Data valid pulse
    
    output reg [47:0] dest_mac,    // Destination MAC address
    output reg [47:0] src_mac,     // Source MAC address
    output reg [15:0] eth_type,    // Ethernet type/length
    output wire [7:0] payload,     // Current payload byte
    output wire payload_valid,     // Payload byte is valid
    output reg frame_valid,        // Frame CRC valid
    output reg rx_done             // Frame reception complete
);

    // ================= STATE DEFINITIONS =================
    localparam STATE_IDLE          = 4'd0;
    localparam STATE_PREAMBLE      = 4'd1;
    localparam STATE_SFD           = 4'd2;
    localparam STATE_DEST_MAC      = 4'd3;
    localparam STATE_SRC_MAC       = 4'd4;
    localparam STATE_ETH_TYPE      = 4'd5;
    localparam STATE_PAYLOAD       = 4'd6;
    localparam STATE_CRC           = 4'd7;
    localparam STATE_FINALIZE      = 4'd8;

    // ================= CONSTANTS =================
    localparam PREAMBLE_BYTE       = 8'hAA;
    localparam SFD_BYTE            = 8'hAB;
    localparam MIN_PAYLOAD         = 46;   // Minimum Ethernet payload (46 bytes)
    localparam CRC_LEN             = 4;    // CRC is 4 bytes

    // ================= INTERNAL REGISTERS =================
    reg [3:0] state;
    reg [3:0] preamble_count;
    reg [3:0] byte_count;
    reg [15:0] payload_count;
    reg [31:0] received_crc;
    reg crc_en;

    // ================= CRC INTERFACE =================
    wire crc_done;
    wire crc_valid;

    crc_generator crc_gen (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(rx_data),
        .data_valid(rx_data_valid & crc_en),
        .crc_en(crc_en),
        .crc_out(),        // Not used in reception mode
        .crc_done(crc_done),
        .crc_valid(crc_valid)
    );

    // ================= OUTPUT ASSIGNMENTS =================
    assign payload = rx_data;
    assign payload_valid = rx_data_valid && (state == STATE_PAYLOAD);

    // ================= STATE MACHINE =================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= STATE_IDLE;
            dest_mac       <= 48'd0;
            src_mac        <= 48'd0;
            eth_type       <= 16'd0;
            frame_valid    <= 1'b0;
            rx_done        <= 1'b0;
            preamble_count <= 4'd0;
            byte_count     <= 4'd0;
            payload_count  <= 16'd0;
            received_crc   <= 32'd0;
            crc_en         <= 1'b0;
        end else begin
            // Default: rx_done is a pulse
            rx_done <= 1'b0;

            case (state)

                // IDLE: Wait for frame reception to start
                STATE_IDLE: begin
                    frame_valid <= 1'b0;
                    dest_mac    <= 48'd0;
                    src_mac     <= 48'd0;
                    eth_type    <= 16'd0;
                    preamble_count <= 4'd0;
                    byte_count     <= 4'd0;
                    payload_count  <= 16'd0;
                    received_crc   <= 32'd0;
                    crc_en         <= 1'b0;

                    // Start frame reception on first valid preamble byte
                    if (rx_en && rx_data_valid) begin
                        if (rx_data == PREAMBLE_BYTE) begin
                            state <= STATE_PREAMBLE;
                            preamble_count <= 4'd1;
                            crc_en <= 1'b0;  // Don't enable CRC yet - wait for SFD
                        end
                    end
                end

                // PREAMBLE: Validate 7 bytes of 0xAA
                STATE_PREAMBLE: begin
                    if (rx_data_valid) begin
                        if (preamble_count < 4'd7) begin
                            if (rx_data == PREAMBLE_BYTE) begin
                                preamble_count <= preamble_count + 1'b1;
                            end else begin
                                // Invalid preamble byte
                                state <= STATE_IDLE;
                                crc_en <= 1'b0;
                            end
                        end else begin
                            // After 7 preamble bytes, expect SFD
                            if (rx_data == SFD_BYTE) begin
                                state <= STATE_DEST_MAC;
                                byte_count <= 4'd0;
                                crc_en <= 1'b1;  // Enable CRC AFTER SFD validation
                            end else begin
                                // Invalid SFD
                                state <= STATE_IDLE;
                                crc_en <= 1'b0;
                            end
                        end
                    end
                end

                // DEST_MAC: Capture 6 bytes of destination MAC address
                STATE_DEST_MAC: begin
                    if (rx_data_valid) begin
                        dest_mac <= {dest_mac[39:0], rx_data};
                        
                        if (byte_count == 4'd5) begin
                            state <= STATE_SRC_MAC;
                            byte_count <= 4'd0;
                        end else begin
                            byte_count <= byte_count + 1'b1;
                        end
                    end
                end

                // SRC_MAC: Capture 6 bytes of source MAC address
                STATE_SRC_MAC: begin
                    if (rx_data_valid) begin
                        src_mac <= {src_mac[39:0], rx_data};
                        
                        if (byte_count == 4'd5) begin
                            state <= STATE_ETH_TYPE;
                            byte_count <= 4'd0;
                        end else begin
                            byte_count <= byte_count + 1'b1;
                        end
                    end
                end

                // ETH_TYPE: Capture 2 bytes of EtherType/Length field
                STATE_ETH_TYPE: begin
                    if (rx_data_valid) begin
                        eth_type <= {eth_type[7:0], rx_data};
                        
                        if (byte_count == 4'd1) begin
                            state <= STATE_PAYLOAD;
                            byte_count <= 4'd0;
                            payload_count <= 16'd0;
                        end else begin
                            byte_count <= byte_count + 1'b1;
                        end
                    end
                end

                // PAYLOAD: Capture payload and CRC bytes
                STATE_PAYLOAD: begin
                    if (rx_data_valid) begin
                        // Feed to CRC only for the first 46 payload bytes (MIN_PAYLOAD)
                        // Do NOT include the 4 CRC bytes in the CRC calculation
                        if (payload_count < MIN_PAYLOAD) begin
                            // This byte is still part of the payload - will be included in CRC
                            payload_count <= payload_count + 1'b1;
                        end else begin
                            // We've reached the CRC bytes - stop feeding to CRC
                            crc_en <= 1'b0;
                            payload_count <= payload_count + 1'b1;
                        end
                        
                        // Store last 4 bytes as received CRC
                        if (payload_count >= MIN_PAYLOAD) begin
                            received_crc <= {received_crc[23:0], rx_data};
                        end
                    end
                    
                    // Check if frame reception is ending
                    if (!rx_en) begin
                        // Frame complete - stop CRC calculation and verify
                        crc_en <= 1'b0;
                        state <= STATE_CRC;
                    end
                end

                // CRC: Wait for CRC validation to complete
                STATE_CRC: begin
                    if (crc_done) begin
                        frame_valid <= crc_valid;
                        state <= STATE_FINALIZE;
                    end
                end

                // FINALIZE: Signal completion
                STATE_FINALIZE: begin
                    rx_done <= 1'b1;
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase

            // Safety: return to IDLE if rx_en drops unexpectedly
            if (!rx_en && state != STATE_IDLE && state != STATE_CRC && state != STATE_FINALIZE) begin
                state <= STATE_IDLE;
                crc_en <= 1'b0;
            end
        end
    end

endmodule