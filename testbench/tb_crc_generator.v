module tb_crc_generator;

    // Testbench signals
    reg clk;                   // Clock signal
    reg rst_n;                 // Active low reset
    reg [31:0] data_in;        // Input data byte
    reg data_valid;            // Data valid signal
    reg crc_en;                // CRC enable signal
    wire [31:0] crc_out;       // CRC output
    wire crc_done;             // Signal indicating CRC calculation is done

    // Instantiate the CRC generator module
    crc_generator uut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_valid(data_valid),
        .crc_en(crc_en),        // Connect crc_en signal
        .crc_out(crc_out),
        .crc_done(crc_done)
    );

    // Clock generation: toggles every 10 time units
    always #10 clk = ~clk;

    // Test process
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        data_in = 32'b0;
        data_valid = 0;
        crc_en = 0;             // Initialize crc_en to 0
        
        // Release reset after 20 time units
        #20 rst_n = 1;

        // Apply the test input 1011_0110 (B6 in hexadecimal)
        #30 data_in = 32'hB6;   // Set input data
        data_valid = 1;         // Assert data valid signal
        crc_en = 1;             // Enable CRC calculation
        
        #20 data_valid = 0;     // Deassert data valid after data is sent
        crc_en = 0;             // Disable CRC computation after input
        
        // Wait for CRC calculation to finish
        #100;
        $display("CRC32 Result = %h", crc_out);  // Display the result in hex

        // End the simulation
        #40;
        $finish;
    end
endmodule
