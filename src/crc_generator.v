module crc_generator(
    input wire clk,
    input wire rst_n,
    input wire [31:0] data_in,
    input wire data_valid,
    input wire crc_en,
    output reg [31:0] crc_out,
    output reg crc_done
);

    integer i;  // Declare the loop variable outside the always block
    reg [31:0] crc_reg;
    reg [31:0] polynomial = 32'h04C11DB7;  // CRC-32 polynomial

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc_reg <= 32'hFFFFFFFF;  // Initialize CRC register with all 1s
            crc_done <= 0;            // Initialize CRC done signal
        end else if (crc_en && data_valid) begin
            crc_reg <= crc_reg ^ data_in;  // XOR initial step with input data
            
            // Perform the polynomial division (CRC calculation)
            for (i = 0; i < 32; i = i + 1) begin
                if (crc_reg[31])               // Check the MSB (most significant bit)
                    crc_reg <= (crc_reg << 1) ^ polynomial;  // Shift left and XOR
                else
                    crc_reg <= crc_reg << 1;   // Shift left only
            end

            crc_done <= 1; // Set done flag when calculation completes
        end else begin
            crc_done <= 0; // Reset done flag when not enabled
        end

        crc_out <= crc_reg; // Output the CRC result
    end

endmodule
