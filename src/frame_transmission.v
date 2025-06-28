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
    output reg tx_en,           // Transmission enable
    output reg [3:0] state,
    output reg [3:0] next_state,
    output wire crc_done,
    output wire [2:0] byte_count,     // <- Now output as wire
    output wire [31:0] crc__out       // <- Output for observation in TB
);

    // State encoding (4-bit)
    parameter IDLE        = 4'b0000;
    parameter PREAMBLE    = 4'b0001;
    parameter SFD         = 4'b0010;
    parameter DEST_ADDR   = 4'b0011;
    parameter SRC_ADDR    = 4'b0100;
    parameter ETH_TYPE    = 4'b0101;
    parameter PAYLOAD     = 4'b0110;
    parameter FINALIZE_CRC = 4'b0111;
    parameter CRC         = 4'b1000;
    parameter DONE        = 4'b1001;

    // Internal registers
    reg [2:0] byte_count_internal;
    reg crc_en;
    reg data_valid;
    reg crc_done_reg;



    // Wires
    wire [31:0] crc_out;
    wire crc_done_internal;
    wire crc_en_internal;
    wire [7:0] crc_byte_0 = crc_out[31:24];
    wire [7:0] crc_byte_1 = crc_out[23:16];
    wire [7:0] crc_byte_2 = crc_out[15:8];
    wire [7:0] crc_byte_3 = crc_out[7:0];

    // Connect internal signals to output ports
    assign byte_count = byte_count_internal;
    assign crc__out = crc_out;
    assign crc_done = crc_done_internal;
    assign crc_en_internal = crc_en;

    // CRC generator instance
    crc_generator crc_gen_inst (
        .clk(clk),
        .data_in(tx_out),
        .data_valid(tx_en),
        .crc_en(crc_en_internal),
        .crc_out(crc_out),
        .crc_done(crc_done_internal)
    );





       // FSM sequential logic
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            byte_count_internal <= 0;
            tx_en <= 0;
            tx_done <= 0;
            tx_out <= 8'h00;
        end else begin
            state <= next_state;
        end
    end
        // STEP 3: Register crc_done
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n)
            crc_done_reg <= 0;
        else
            crc_done_reg <= crc_done;
    end


    // FSM combinational logic
    always @(posedge clk) begin
        // Default values
        next_state = state;
        tx_en = 0;
        tx_done = 0;
       
        
        case (state)
            IDLE: begin
                tx_out = 8'h00;
                data_valid = 0;
                byte_count_internal = 0;
                if (start) begin
                    next_state = PREAMBLE;
                    tx_en = 1;
                end
            end

            PREAMBLE: begin
                tx_out = 8'hAA;
                tx_en = 1;
                if (byte_count_internal == 6) begin
                    next_state = SFD;
                    byte_count_internal = 0;
                end else begin
                    byte_count_internal = byte_count_internal + 1;
                end
            end

            SFD: begin
                tx_out = 8'hAB;
                tx_en = 1;
                next_state = DEST_ADDR;
                byte_count_internal = 0;
            end

            DEST_ADDR: begin
                tx_out = dest_addr[47 - (byte_count_internal * 8) -: 8];
                tx_en = 1;
                if (byte_count_internal == 5) begin
                    next_state = SRC_ADDR;
                    byte_count_internal = 0;
                end else begin
                    byte_count_internal = byte_count_internal + 1;
                end
            end

            SRC_ADDR: begin
                tx_out = src_addr[47 - (byte_count_internal * 8) -: 8];
                tx_en = 1;
                if (byte_count_internal == 5) begin
                    next_state = ETH_TYPE;
                    byte_count_internal = 0;
                end else begin
                    byte_count_internal = byte_count_internal + 1;
                end
            end

            ETH_TYPE: begin
                tx_out = eth_type[15 - (byte_count_internal * 8) -: 8];
                tx_en = 1;
                if (byte_count_internal == 1) begin
                    next_state = PAYLOAD;
                    byte_count_internal = 0;
                end else begin
                    byte_count_internal = byte_count_internal + 1;
                end
            end

            PAYLOAD: begin
                crc_en = 1; // Enable CRC calculation
                data_valid = 1;
                 tx_en = 1;
                tx_out = data_in[31 - (byte_count_internal * 8) -: 8];
                $display(">> TX_OUT during PAYLOAD: %h at time %0t", tx_out, $time);
                $display(">> TX_EN during PAYLOAD: %b at time %0t", tx_en, $time);
                $display(">> CRC_EN during PAYLOAD: %b at time %0t", crc_en, $time);
               
                
                
                if (byte_count_internal == 3) begin
                    next_state = FINALIZE_CRC;  // Transition to FINALIZE_CRC state
                    byte_count_internal = 0;   // Reset byte count
                end else begin
                    byte_count_internal = byte_count_internal + 1;
                end
            end

            FINALIZE_CRC: begin
                crc_en = 0;             // Disable CRC to finalize
                data_valid = 0;
                tx_en = 0;
                $display(">> CRC_DONE in FINALIZE_CRC: %b at time %0t", crc_done, $time);
                if (crc_done_reg) begin

                    $display(">> CRC Computed: %h at time %0t", crc_out, $time); // Display computed CRC
                    next_state = CRC;  // Transition to CRC state to transmit the CRC bytes
                    byte_count_internal = 0;  // Reset byte count for CRC transmission
                end else begin
                    tx_out = 8'h00;    // Keep sending zeroes until CRC is done
                    tx_en = 0;
                end
            end

            CRC: begin
                tx_out = crc_out[31 - (byte_count_internal * 8) -: 8];
                tx_en = 1;
                $display(">> Transmitting CRC Byte: %h at time %0t", tx_out, $time); // Display transmitted CRC byte
                if (byte_count_internal == 3) begin
                    tx_done = 1;       // Indicate transmission is complete
                    next_state = IDLE; // Transition back to IDLE state
                    byte_count_internal = 0;  // Reset byte count
                end else begin
                    byte_count_internal = byte_count_internal + 1;
                end
            end

            default: begin
                next_state = IDLE;
                tx_out = 8'h00;
                tx_en = 0;
                tx_done = 0;
                byte_count_internal = 0;
            end
        endcase
    end
endmodule
