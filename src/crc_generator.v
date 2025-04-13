module crc_generator (
    input wire clk,
    input wire rst_n,
    input wire [7:0] data_in,
    input wire data_valid,
    input wire crc_en,
    output reg [31:0] crc_out,
    output reg crc_done
);

    reg [31:0] crc_reg;
    reg [31:0] polynomial;
    reg crc_active;

    integer i;
    reg [7:0] data_byte;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc_reg <= 32'hFFFFFFFF;
            crc_out <= 32'd0;
            polynomial <= 32'h04C11DB7;
            crc_done <= 1'b0;
            crc_active <= 1'b0;
        end else begin
            if (crc_en) begin
                crc_done <= 1'b0;
                crc_active <= 1'b1;

                if (data_valid) begin
                    data_byte = data_in;
                    crc_reg = crc_reg ^ (data_byte << 24); // align byte to MSB

                    for (i = 0; i < 8; i = i + 1) begin
                        if (crc_reg[31])
                            crc_reg = (crc_reg << 1) ^ polynomial;
                        else
                            crc_reg = crc_reg << 1;
                    end
                end
            end else if (crc_active) begin
                // CRC finished
                crc_out <= ~crc_reg;
                crc_done <= 1'b1;
                crc_active <= 1'b0;
                crc_reg <= 32'hFFFFFFFF;  // reset for next frame
            end else begin
                crc_done <= 1'b0;
            end
        end
    end
endmodule
