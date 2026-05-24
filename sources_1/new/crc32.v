`timescale 1ns / 1ps

// CRC-32 engine : byte-serial LFSR using the reflected polynomial
// 0xEDB88320.

module crc32 (
    input clk,
    input reset,

    input crc_init,      // synchronous init to 0xFFFFFFFF
    input crc_en,        // enable: process data_in this cycle

    input [7:0] data_in,

    output [31:0] crc_out   // current CRC register (not finalised)
);

    // Reflected CRC-32 polynomial (Ethernet standard)
    parameter POLY = 32'hEDB88320;

    reg [31:0] crc_reg;
    reg [31:0] crc_next;

    integer i;
    
    
    // Sequential Logic : Update CRC Register
    always @(posedge clk or posedge reset) begin

        if (reset)
            crc_reg <= 32'hFFFFFFFF;

        // Start of frame initialization
        else if (crc_init)
            crc_reg <= 32'hFFFFFFFF;

        // Shift in next byte
        else if (crc_en)
            crc_reg <= crc_next;
    end

    // Combinational Logic : Compute Next CRC Value
    always @(*) begin

        // XOR incoming byte into LSB of CRC register
        crc_next = crc_reg ^ {24'h0, data_in};

        // Process 8 bits serially
        for (i = 0; i < 8; i = i + 1) begin

            // If LSB is 1, apply feedback polynomial
            if (crc_next[0])
                crc_next = (crc_next >> 1) ^ POLY;

            // Otherwise just shift
            else
                crc_next = crc_next >> 1;
        end
    end

    // Current CRC value
    assign crc_out = crc_reg;

endmodule