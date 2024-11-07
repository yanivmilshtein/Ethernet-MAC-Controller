module crc_generator (
    input wire clk,
    input wire rst_n,
    input wire [7:0] data_in,   // Process 8 bits at a time
    input wire data_valid,
    input wire crc_en,
    output reg [31:0] crc_out,
    output reg crc_done
);

    reg [31:0] crc_reg;
    reg [31:0] polynomial = 32'h04C11DB7;

    // Function to reflect the bits in a byte (for Ethernet CRC)
    function [7:0] reflect_byte(input [7:0] byte);
        integer j;
        begin
            reflect_byte = 0;
            for (j = 0; j < 8; j = j + 1) begin
                reflect_byte[j] = byte[7 - j];
            end
        end
    endfunction

    // Function to reflect the bits in a 32-bit word
    function [31:0] reflect_word(input [31:0] word);
        integer k;
        begin
            reflect_word = 0;
            for (k = 0; k < 32; k = k + 1) begin
                reflect_word[k] = word[31 - k];
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc_reg <= 32'hFFFFFFFF;  // Initialize CRC register with all 1s
            crc_done <= 0;
        end else if (crc_en && data_valid) begin
            crc_reg <= crc_reg ^ {reflect_byte(data_in), 24'b0};  // Reflect data byte before XOR

            // Perform polynomial division (CRC calculation)
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                if (crc_reg[31])          // Check MSB (most significant bit)
                    crc_reg <= (crc_reg << 1) ^ polynomial;
                else
                    crc_reg <= crc_reg << 1;
            end

            crc_done <= 1; // Set done flag when calculation completes
        end else begin
            crc_done <= 0; // Reset done flag when not enabled
        end

        // Reflect and XOR final CRC value for Ethernet CRC output
        crc_out <= reflect_word(crc_reg) ^ 32'hFFFFFFFF;
    end
endmodule
