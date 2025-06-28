module tb_frame_reception;

    // Inputs
    reg clk;
    reg rst_n;
    reg rx_en;
    reg [7:0] rx_data;
    reg rx_data_valid;

    // Outputs
    wire [47:0] dest_mac;
    wire [47:0] src_mac;
    wire [15:0] eth_type;
    wire frame_valid;
    wire rx_done;

    integer i;

    // Instantiate the frame_reception module
    frame_reception uut (
        .clk(clk),
        .rst_n(rst_n),
        .rx_en(rx_en),
        .rx_data(rx_data),
        .rx_data_valid(rx_data_valid),
        .dest_mac(dest_mac),
        .src_mac(src_mac),
        .eth_type(eth_type),
        .frame_valid(frame_valid),
        .rx_done(rx_done)
    );

    // Clock generation
    always begin
        #5 clk = ~clk;  // 100 MHz clock
    end

    // Test procedure
    initial begin
        

        // Initial values
        clk = 0;
        rst_n = 0;
        rx_en = 0;
        rx_data = 0;
        rx_data_valid = 0;

        // Reset the system
        #10 rst_n = 1;  // Release reset after 10 time units

        // Start sending frame
        #10 rx_en = 1;  // Enable reception

        // Preamble (7 bytes of 0xAA)
        for (i = 0; i < 7; i = i + 1)
            send_frame(8'hAA);

        // SFD (0xAB)
        send_frame(8'hAB);

        // Destination MAC (6 bytes)
        send_frame(8'h01);
        send_frame(8'h23);
        send_frame(8'h45);
        send_frame(8'h67);
        send_frame(8'h89);
        send_frame(8'hAB);

        // Source MAC (6 bytes)
        send_frame(8'hCD);
        send_frame(8'hEF);
        send_frame(8'h01);
        send_frame(8'h23);
        send_frame(8'h45);
        send_frame(8'h67);

        // Ethernet Type (2 bytes)
        send_frame(8'h08);
        send_frame(8'h00);

        // Payload (46 bytes)
        for (i = 0; i < 46; i = i + 1)
            send_frame(8'hFF);

        // CRC (4 bytes, placeholder)
        send_frame(8'hDE);
        send_frame(8'hAD);
        send_frame(8'hBE);
        send_frame(8'hEF);

        // Complete frame transmission
        #10 rx_en = 0;

        // Wait for FSM to process the frame
        #20;

        // Check if the frame is valid
        if (frame_valid) begin
            $display(" Frame sent successfully at time %0t", $time);
        end else begin
            $display(" Frame failed at time %0t", $time);
        end

        // Finish simulation
        #10 $finish;
    end

    // Task to send a byte of data to the frame reception module
    task send_frame(input [7:0] byte_data);
        begin
            rx_data = byte_data;
            rx_data_valid = 1;
            #10;
            rx_data_valid = 0;
            #10;  // Optional: one extra cycle of idle
        end
    endtask

endmodule
