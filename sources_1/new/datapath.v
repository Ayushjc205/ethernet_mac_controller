`timescale 1ns / 1ps

module datapath (
    input clk,
    input reset,

    input [2:0] dest_count,
    input [2:0] src_count,
    input [1:0] len_count,

    input [3:0] byte_sel,
    input [3:0] payload_count,
    input [5:0] pad_count,

    input [31:0] crc_out,
    input [1:0] crc_count,
    input [3:0] ifg_count,

    output reg [7:0] tx
);

    // Standard Ethernet values
    parameter PREAMBLE_VAL = 8'h55;
    parameter SFD_VAL      = 8'hD5;

    // Fixed addresses for demo
    // Extend using registers/configuration in production
    parameter DEST_MAC = 48'hAABBCCDDEEFF;
    parameter SRC_MAC  = 48'hAB00CD00EFAB;

    // 4-byte payload length
    parameter LEN_VAL  = 16'h0004;

    // Payload memory
    reg [7:0] payload_mem [0:7];

    // Final CRC value after IEEE 802.3 inversion
    wire [31:0] crc_final;

    assign crc_final = crc_out ^ 32'hFFFFFFFF;

    // Payload initialization
    initial begin
        payload_mem[0] = 8'h11;
        payload_mem[1] = 8'h22;
        payload_mem[2] = 8'h33;
        payload_mem[3] = 8'h44;
        payload_mem[4] = 8'h55;
        payload_mem[5] = 8'h66;
        payload_mem[6] = 8'h77;
        payload_mem[7] = 8'h88;
    end

    // TX byte generation logic
    always @(posedge clk or posedge reset) begin

        // Idle / Reset
        if (reset || byte_sel == 4'd0) begin
            tx <= 8'h00;
        end

        // Preamble : 7 bytes of 0x55
        else if (byte_sel == 4'd1) begin
            tx <= PREAMBLE_VAL;
        end
        
        // Start Frame Delimiter
        else if (byte_sel == 4'd2) begin
            tx <= SFD_VAL;
        end

        // Destination MAC Address (MSB first)
        else if (byte_sel == 4'd3) begin
            case (dest_count)

                3'd0: tx <= DEST_MAC[47:40];
                3'd1: tx <= DEST_MAC[39:32];
                3'd2: tx <= DEST_MAC[31:24];
                3'd3: tx <= DEST_MAC[23:16];
                3'd4: tx <= DEST_MAC[15:8];
                3'd5: tx <= DEST_MAC[7:0];

                default: tx <= 8'h00;
            endcase
        end

        // Source MAC Address (MSB first)
        else if (byte_sel == 4'd4) begin
            case (src_count)

                3'd0: tx <= SRC_MAC[47:40];
                3'd1: tx <= SRC_MAC[39:32];
                3'd2: tx <= SRC_MAC[31:24];
                3'd3: tx <= SRC_MAC[23:16];
                3'd4: tx <= SRC_MAC[15:8];
                3'd5: tx <= SRC_MAC[7:0];

                default: tx <= 8'h00;
            endcase
        end

        // Length / Type Field (Big-endian)
        else if (byte_sel == 4'd5) begin
            case (len_count)

                2'd0: tx <= LEN_VAL[15:8];
                2'd1: tx <= LEN_VAL[7:0];

                default: tx <= 8'h00;
            endcase
        end

        // Payload bytes
        else if (byte_sel == 4'd6) begin
            tx <= payload_mem[payload_count];
        end

        // Padding bytes
        else if (byte_sel == 4'd7) begin
            tx <= 8'h00;
        end

        // CRC / FCS field
        // IEEE 802.3 sends CRC LSB first
        else if (byte_sel == 4'd8) begin
            case (crc_count)

                2'd0: tx <= crc_final[7:0];
                2'd1: tx <= crc_final[15:8];
                2'd2: tx <= crc_final[23:16];
                2'd3: tx <= crc_final[31:24];

                default: tx <= 8'h00;
            endcase
        end

        // Inter Frame Gap
        else if (byte_sel == 4'd9) begin
            tx <= 8'h00;
        end

    end

endmodule