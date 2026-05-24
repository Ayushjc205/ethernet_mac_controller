`timescale 1ns / 1ps

module mac_tx_tb;

    reg clk;
    reg reset;
    reg start_tx;

    wire [7:0] tx;

    reg rx_valid;
    reg [7:0] rx_data;

    wire sfd_detected;
    wire frame_valid;
    wire frame_error;

    // Error injection control
    reg inject_error;

    reg [7:0] rx_data_int;

    MAC_top dut (

        .clk          (clk),
        .reset        (reset),
        .start_tx     (start_tx),

        .tx           (tx),

        .rx_valid     (rx_valid),
        .rx_data      (rx_data),

        .sfd_detected (sfd_detected),
        .frame_valid  (frame_valid),
        .frame_error  (frame_error)
    );

    // 25 MHz Clock
    // Clock period = 40 ns
    initial
        clk = 0;

    always #20 clk = ~clk;

    
    always @(*) begin

        // Inject 1-bit error into received byte
        rx_data_int =
            inject_error ? (tx ^ 8'h01) : tx;

        rx_data  = rx_data_int;

        // Always valid in loopback setup
        rx_valid = 1'b1;
    end

    initial begin

        reset        = 1;
        start_tx     = 0;
        inject_error = 0;

        #100;

        reset = 0;

        // 1 : Clean frame
        #100;

        start_tx = 1;

        #40;

        // One clock pulse
        start_tx = 0;

        // Wait for full frame transmission
        #4000;

        //2 : Inject 1-bit error
        inject_error = 1;

        #100;

        inject_error = 0;

        #3000;

        // Final report
        $monitor(
            "Error injected = %b | frame_valid = %b | frame_error = %b",
            inject_error,
            frame_valid,
            frame_error
        );

        $finish;
    end

    // Per-cycle display for waveform/debug cross-check
    always @(posedge clk) begin

        $display(
            "Time = %0t | tx = 0x%02h",
            $time,
            tx
        );
    end

endmodule