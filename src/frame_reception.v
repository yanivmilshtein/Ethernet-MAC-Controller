`timescale 1ns/1ps

module frame_reception (
    input wire clk,
    input wire rst_n,
    input wire rx_en,
    input wire [7:0] rx_data,
    input wire rx_data_valid,
    
    output reg [47:0] dest_mac,
    output reg [47:0] src_mac,
    output reg [15:0] eth_type,
    output wire [7:0] payload,
    output wire payload_valid,
    output reg frame_valid,
    output reg rx_done
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
    localparam MIN_PAYLOAD         = 46;
    localparam CRC_LEN             = 4;

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
        .crc_out(),
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

            // default outputs (pulses)
            frame_valid <= 1'b0;
            rx_done     <= 1'b0;

            case (state)

                // ================= IDLE =================
                STATE_IDLE: begin
                    dest_mac       <= 48'd0;
                    src_mac        <= 48'd0;
                    eth_type       <= 16'd0;
                    preamble_count <= 4'd0;
                    byte_count     <= 4'd0;
                    payload_count  <= 16'd0;
                    received_crc   <= 32'd0;
                    crc_en         <= 1'b0;

                    if (rx_en && rx_data_valid && rx_data == PREAMBLE_BYTE) begin
                        state <= STATE_PREAMBLE;
                        preamble_count <= 4'd1;
                    end
                end

                // ================= PREAMBLE =================
                STATE_PREAMBLE: begin
                    if (rx_data_valid) begin
                        if (preamble_count < 4'd7) begin
                            if (rx_data == PREAMBLE_BYTE)
                                preamble_count <= preamble_count + 1'b1;
                            else
                                state <= STATE_IDLE;
                        end
                        else begin
                            if (rx_data == SFD_BYTE) begin
                                state <= STATE_DEST_MAC;
                                byte_count <= 4'd0;
                                crc_en <= 1'b1;
                            end
                            else
                                state <= STATE_IDLE;
                        end
                    end
                end

                // ================= DEST MAC =================
                STATE_DEST_MAC: begin
                    if (rx_data_valid) begin
                        dest_mac <= {dest_mac[39:0], rx_data};

                        if (byte_count == 4'd5) begin
                            state <= STATE_SRC_MAC;
                            byte_count <= 4'd0;
                        end
                        else
                            byte_count <= byte_count + 1'b1;
                    end
                end

                // ================= SRC MAC =================
                STATE_SRC_MAC: begin
                    if (rx_data_valid) begin
                        src_mac <= {src_mac[39:0], rx_data};

                        if (byte_count == 4'd5) begin
                            state <= STATE_ETH_TYPE;
                            byte_count <= 4'd0;
                        end
                        else
                            byte_count <= byte_count + 1'b1;
                    end
                end

                // ================= ETH TYPE =================
                STATE_ETH_TYPE: begin
                    if (rx_data_valid) begin
                        eth_type <= {eth_type[7:0], rx_data};

                        if (byte_count == 4'd1) begin
                            state <= STATE_PAYLOAD;
                            byte_count <= 4'd0;
                            payload_count <= 16'd0;
                        end
                        else
                            byte_count <= byte_count + 1'b1;
                    end
                end

                // ================= PAYLOAD =================
                STATE_PAYLOAD: begin
                    if (rx_data_valid) begin
                        payload_count <= payload_count + 1'b1;

                        if (payload_count >= MIN_PAYLOAD)
                            received_crc <= {received_crc[23:0], rx_data};
                    end

                    if (!rx_en) begin
                        crc_en <= 1'b0;
                        state <= STATE_CRC;

                        $display("\n>> FRAME_RX: rx_en dropped at time %0t", $time);
                        $display(">> FRAME_RX: Payload count = %0d bytes", payload_count);
                        $display(">> FRAME_RX: Deasserted crc_en, moving to STATE_CRC");
                    end
                end

                // ================= CRC WAIT =================
                STATE_CRC: begin
                    if (crc_done) begin
                        state <= STATE_FINALIZE;
                    end
                end

                // ================= FINALIZE =================
                STATE_FINALIZE: begin
                    frame_valid <= 1'b1;   // pulse if CRC correct
                    rx_done     <= 1'b1;        // reception finished
                    state       <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;

            endcase
        end
    end

endmodule