module tb_frame_transmission();
    reg clk;
    reg rst_n;
    reg [31:0] data_in;
    reg tx_en;
    wire [7:0] tx_out;
    wire tx_done;
    wire data_en;

    frame_transmission uut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .tx_en(tx_en),
        .tx_out(tx_out),
        .tx_done(tx_done),
        .data_en(data_en)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        tx_en = 0;
        data_in = 32'hDEADBEEF;
        #15 rst_n = 1;
        #10 tx_en = 1;  // Begin transmission
        #100 tx_en = 0; // Disable after initial transmission

        wait (tx_done);
        #20 $finish;
    end

    // Monitor tx_out to observe the serialized output
    initial begin
        $monitor("Time: %0d, tx_out: %h, state: %b, data_en: %b", 
                  $time, tx_out, uut.state, data_en);
    end
endmodule
