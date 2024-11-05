module frame_transmission (
    input wire clk,
    input wire rst_n,
    input wire [7:0] fifo_data, // data from the fifo_tx
    input wire fifo_empty, // fifo empty flag
    input wire start_tx, // sign to start transimission
    input wire [31:0] crc_out, // crc from crc module
    output reg [7:0] tx_data, // transmitted data
    output reg tx_valid, // flag if the data valid for transmission
    output reg tx_done //flag that transmission done
);

reg [3:0] state; //state machine
reg [31:0] crc_reg; //hold crc value
reg [7:0] byte_counter; // counting transmitted bytes

// fsm states
localparam IDLE = 4'b0001,
SEND_DATA = 4'b0010,
SEND_CRC = 4'b0100,
DONE = 4'b1000;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        tx_valid <= 0;
        tx_done <= 0;
        byte_counter <= 0;
        crc_reg <= 32'hFFFFFFFF;
    end else begin
        case (state)
            IDLE:begin
                tx_valid <= 0;
                tx_done <= 0;
                byte_counter <= 0;
                if (start_tx && !fifo_empty) begin
                    state <= SEND_DATA;
                end 
            end

            SEND_DATA: begin
                if (!fifo_empty) begin
                    tx_data <= fifo_data;
                    tx_valid <= 1;
                    byte_counter <= byte_counter + 1;
                    if (byte_counter == 11) begin // assumtion 12 bit for example
                        state <= SEND_CRC;
                        crc_reg <= crc_out; // capture crc after data
                    end
                end
            end

            SEND_CRC: begin
                //send scrc byte by byte
                case (byte_counter)
                    12: tx_data <= crc_reg[31:24];  // First CRC byte
                    13: tx_data <= crc_reg[23:16];  // Second CRC byte
                    14: tx_data <= crc_reg[15:8];   // Third CRC byte
                    15: tx_data <= crc_reg[7:0];    // Fourth CRC byte
                endcase
                tx_valid <= 1;
                byte_counter <= byte_counter + 1;
                if (byte_counter == 16) begin
                    state <= DONE;
                end
            end

            DONE: begin
                tx_valid <= 0;
                tx_done <= 1;
                state <= IDLE;
            end
        endcase
    end
end 
endmodule