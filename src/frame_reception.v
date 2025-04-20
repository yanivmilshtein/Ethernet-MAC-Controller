module frame_reception(
    input wire clk, // Clock signal
    input wire rst_n, // Active low reset signal
    input wire rx_en, // Trigger signal to start frame reception
    input wire [7:0] rx_data, // Incoming byte from MAC/PHY
    input wire rx_data_valid, // High when rx_data is valid

    output reg  [47:0] dest_mac,      // Destination MAC address
    output reg  [47:0] src_mac,       // Source MAC address
    output reg  [15:0] eth_type,      // Ethernet type
    output reg         frame_valid,   // High when frame is received and CRC is good
    output reg         rx_done        // Indicates frame reception is done   
);

// Internal registers
reg [3:0] state; // Current state of the FSM
reg [3:0] next_state; // Next state of the FSM
reg [5:0] byte_count; // Number of bytes received up to 59 

 // CRC engine interface
reg        crc_en;
reg        data_valid;
wire       crc_done;
wire [31:0] crc_out;

// Payload buffer for 48 bytes of data
reg [31:0] paylod_buffer:

// crc checking
reg [31:0] received_crc; // Received CRC value from the frame

// state encoding (4-bit)
parameter IDLE        = 4'b0000;
parameter PREAMBLE    = 4'b0001;    
parameter SFD         = 4'b0010;
parameter DEST_ADDR   = 4'b0011;    
parameter SRC_ADDR    = 4'b0100;
parameter ETH_TYPE    = 4'b0101;    
parameter PAYLOAD     = 4'b0110;
parameter CRC_CAPTURE = 4'b0111;
parameter CRC_COMPARE = 4'b1000;


crc_generator crc_gen_inst (
        .clk(clk),
        .data_in(rx_data),
        .data_valid(data_valid),
        .crc_en(crc_en),
        .crc_out(crc_out),
        .crc_done(crc_done)
    );
// fsm sequential logic
always @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        // enter reset values for all registers
    end else begin
         state <= next_state;
    end
end

// FSM combinational logic
always @(posedge clk) begin
        // Default values
    next_state = state;

    case (state)
        IDLE: begin
            // Wait for frame start (rx_en or similar)
            byte_count = 0;
            crc_en = 0;
            data_valid = 0;
            rx_done = 0;
            frame_valid = 0;

            // clear all temporary registers
            paylod_buffer = 0;
            dest_mac = 0;
            src_mac = 0;
            eth_type = 0;
            if (rx_en) begin
                next_state = PREAMBLE;
            end else begin
                next_state = IDLE; // Wait for rx_en
            end
        end

        PREAMBLE: begin
            // Check 7 bytes of 0xAA
            if(rx_data == 8'hAA) begin
                if (byte_count == 6) begin
                    next_state = SFD;
                    byte_count = 0; // Reset byte count for SFD
                end else begin
                    byte_count = byte_count + 1; // Increment byte count
                end
            end else begin
                next_state = IDLE; // Fail-safe
                byte_count = 0; // Reset byte count
            end
        end

        SFD: begin
            // Check byte == 0xAB
            if (rx_en) begin
                if (rx_data == 8'hAB) begin
                    next_state = DEST_ADDR;
                    byte_count = 0; // Reset byte count for destination address
                end else begin
                next_state = IDLE; // Fail-safe
            end
        end
            
         end

        DEST_ADDR: begin
            if (rx_en) begin
                dest_mac[47 - (byte_count * 8) -: 8] = rx_data;
                byte_count = byte_count + 1;
        
                if (byte_count == 5) begin
                    next_state = SRC_ADDR;
                    byte_count = 0;
                end
            end
        end


        SRC_ADDR: begin
            if (rx_en) begin
                src_mac[47 - (byte_count * 8) -: 8] = rx_data;
                byte_count = byte_count + 1;

                if (byte_count == 5) begin
                    next_state = ETH_TYPE;
                    byte_count = 0;
                end
            end
        end

        ETH_TYPE: begin
            if (rx_en) begin
                eth_type[15 - (byte_count * 8) -: 8] = rx_data;
                byte_count = byte_count + 1;

                if (byte_count == 1) begin
                    next_state = PAYLOAD;
                    byte_count = 0;
                end
            end
        end


        PAYLOAD: begin
            if (rx_en) begin
                data_in    = rx_data;
                crc_en     = 1;
                data_valid = 1;

                // Optional: store payload
                payload_data[31 - (byte_count * 8) -: 8] = rx_data;

                byte_count = byte_count + 1;

                if (byte_count == 3) begin
                    next_state = CRC_VERIFY;
                    byte_count = 0;
                    crc_en     = 0; // Tell CRC module to finalize internally
                end
            end else begin
                data_valid = 0;
            end
        end


        CRC_CAPTURE: begin
            received_crc[31 - (byte_count * 8) -: 8] = rx_data;
    
            if (byte_count == 3) begin
                byte_count = 0;
                next_state = CRC_COMPARE;
            end else begin
                byte_count = byte_count + 1;
            end
        end


        CRC_COMPARE: begin
            if (rx_crc == crc_out) begin
                frame_valid <= 1;       // Mark frame as valid
                $display(">> CRC PASS at time %0t", $time);
            end else begin
                frame_valid <= 0;       // Mark frame as invalid
                $display(">> CRC FAIL at time %0t", $time);
            end

            next_state <= IDLE;         // Reset FSM for next frame
        end


        default: begin
            next_state     <= IDLE;
            byte_count     <= 0;
            rx_crc         <= 32'b0;
            dest_mac       <= 48'b0;
            src_mac        <= 48'b0;
            eth_type       <= 16'b0;
            payload        <= 32'b0;
            frame_valid    <= 0;
            crc_en         <= 0;
            data_valid     <= 0;
            $display(">> DEFAULT STATE TRIGGERED at time %0t", $time);
        end

    endcase
end
endmodule
    
