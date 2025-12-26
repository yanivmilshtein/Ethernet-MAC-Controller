module crc_generator (
    input wire clk,
    input wire rst_n,
    input wire [7:0] data_in,       // Accept 1 byte per cycle
    input wire data_valid,          // Asserted when a valid byte is present
    input wire crc_en,              // Enables CRC accumulation
    output reg [31:0] crc_out,      // Final CRC value
    output reg crc_done             // Asserted for one cycle when CRC is ready
);

    reg [31:0] crc_reg;
    reg [31:0] polynomial;
    reg [31:0] temp_crc;           // Temporary variable for CRC calculation
    reg crc_active;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc_reg     <= 32'hFFFFFFFF;
            temp_crc    <= 32'd0;
            crc_out     <= 32'd0;
            polynomial  <= 32'h04C11DB7;
            crc_done    <= 1'b0;
            crc_active  <= 1'b0;
        end else begin
            crc_done <= 1'b0;  // Default unless CRC completes

            if (crc_en) begin
                crc_active <= 1'b1;

                if (data_valid) begin
                    temp_crc = crc_reg ^ (data_in << 24);

                    // Process 8 bits of input
                    for (i = 0; i < 8; i = i + 1) begin
                        if (temp_crc[31])
                            temp_crc = (temp_crc << 1) ^ polynomial;
                        else
                            temp_crc = temp_crc << 1;
                    end

                    crc_reg <= temp_crc;

                    $display(">> CRC INPUT BYTE: %h at time %0t", data_in, $time);
                    $display(">> CRC REG: %h at time %0t", temp_crc, $time);
                    $display(">> CRC data_valid: %h at time %0t", data_valid, $time);
                end
            end else if (crc_active) begin
                // Finalize CRC once crc_en is deasserted
                crc_out    <= ~crc_reg;           // Final CRC result (inverted)
                crc_done   <= 1'b1;               // Signal done
                crc_reg    <= 32'hFFFFFFFF;       // Prepare for next frame
                crc_active <= 1'b0;
                $display(">> CRC FINAL OUT: %h at time %0t", ~crc_reg, $time); 
            end
        end
    end
endmodule
