module tb_frame_transmission;

    // Inputs
    reg clk;
    reg rst_n;
    reg start;
    reg [47:0] dest_addr;
    reg [47:0] src_addr;
    reg [15:0] eth_type;
    reg [31:0] data_in;

    // Outputs
    wire [7:0] tx_out;
    wire tx_done;
    wire tx_en;
    wire [3:0] state;
    wire [3:0] next_state;
    wire crc_done;
    wire [2:0] byte_count;
    wire [31:0] crc__out;
    // Instantiate the frame_transmission module
    frame_transmission uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .dest_addr(dest_addr),
        .src_addr(src_addr),
        .eth_type(eth_type),
        .data_in(data_in),
        .tx_out(tx_out),
        .tx_done(tx_done),
        .tx_en(tx_en),
        .state(state),
        .next_state(next_state),
        .crc_done(crc_done),
        .byte_count(byte_count),
        .crc__out(crc__out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10 time units clock period
    end

    // Testbench stimulus
    initial begin
        // Initialize inputs
        rst_n = 0; // Assert reset
        start = 0;
        dest_addr = 48'h123456789ABC;
        src_addr = 48'hABCDEF123456;
        eth_type = 16'h0800;
        data_in = 32'hDEADBEEF;

        // Apply reset
        #20 rst_n = 1; // Release reset after 20 time units

        // Start frame transmission
        #10 start = 1; // Assert start signal
        #10 start = 0; // Deassert start signal

        // Wait for transmission to complete
        wait (tx_done); // Wait until tx_done is asserted
        $display("Transmission complete. Waiting for FSM to return to IDLE...");

        // Wait for FSM to return to IDLE
        wait (state == 4'b0000); // Assuming IDLE state is encoded as 3'b000
        $display("FSM returned to IDLE state.");

        // End the simulation
        #50 $finish;
    end

    // Monitor tx_out to observe the serialized output
    initial begin
        $monitor("Time: %0d, tx_out: %h, tx_en: %b, tx_done: %b, crc_done: %b, state: %b, next_state: %b",
          $time, tx_out, tx_en, tx_done,crc_done, state, next_state);

    end

endmodule