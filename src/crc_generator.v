module crc_generator (
    input wire clk,
    input wire rst_n,
    input wire [7:0] data_in,       // Accept 1 byte per cycle
    input wire data_valid,          // Asserted when a valid byte is present
    input wire crc_en,              // Enables CRC accumulation
    output reg [31:0] crc_out,      // Final CRC value (inverted for transmission)
    output reg crc_done,            // Asserted for one cycle when CRC is ready
    output reg crc_valid            // Asserted if CRC verification passes (residue match)
);

    localparam CRC_RESIDUE = 32'hC704DD7B;  // Ethernet standard magic residue
    localparam CRC_POLY    = 32'h04C11DB7;  // CRC-32 polynomial

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
            polynomial  <= CRC_POLY;
            crc_done    <= 1'b0;
            crc_valid   <= 1'b0;
            crc_active  <= 1'b0;
        end else begin
            crc_done  <= 1'b0;  // Default unless CRC completes
            crc_valid <= 1'b0;  // Default unless verification passes

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
                
                // Check if CRC verification passes (for received frames)
                if (crc_reg == CRC_RESIDUE) begin
                    crc_valid <= 1'b1;  // Valid frame - residue matches
                    $display(">> CRC VERIFICATION PASSED: Residue matches 0x%h", CRC_RESIDUE);
                end else begin
                    crc_valid <= 1'b0;  // Invalid frame
                    $display(">> CRC VERIFICATION FAILED: Residue is 0x%h (expected 0x%h)", crc_reg, CRC_RESIDUE);
                end

                crc_out    <= ~crc_reg;           // Final CRC result (inverted for transmission)
                crc_done   <= 1'b1;               // Signal done
                crc_reg    <= 32'hFFFFFFFF;       // Prepare for next frame
                crc_active <= 1'b0;
                $display(">> CRC FINAL OUT: %h at time %0t", ~crc_reg, $time); 
            end
        end
    end
endmodule
