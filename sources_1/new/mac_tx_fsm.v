`timescale 1ns / 1ps

module mac_tx_fsm (
    input clk,
    input reset,
    input start_tx,

    output reg [2:0] dest_count,
    output reg [2:0] src_count,
    output reg [1:0] len_count,
    output reg [3:0] payload_count,
    output reg [5:0] pad_count,
    output reg [1:0] crc_count,
    output reg [3:0] ifg_count,
    output reg [3:0] byte_sel
);

    // One-hot state encoding
    parameter IDLE      = 10'b0000000001,
              PREAMBLE = 10'b0000000010,
              SFD       = 10'b0000000100,
              DEST      = 10'b0000001000,
              SRC       = 10'b0000010000,
              LEN       = 10'b0000100000,
              PAYLOAD   = 10'b0001000000,
              PAD       = 10'b0010000000,
              CRC       = 10'b0100000000,
              IFG       = 10'b1000000000;

    // byte_sel constants matching datapath mux
    parameter BYTE_IDLE      = 4'd0,
              BYTE_PREAMBLE = 4'd1,
              BYTE_SFD      = 4'd2,
              BYTE_DEST     = 4'd3,
              BYTE_SRC      = 4'd4,
              BYTE_LEN      = 4'd5,
              BYTE_PAYLOAD  = 4'd6,
              BYTE_PAD      = 4'd7,
              BYTE_CRC      = 4'd8,
              BYTE_IFG      = 4'd9;

    // Demo payload length = 4 bytes
    parameter PAYLOAD_LEN = 4'd4;

    // Pad to 46-byte Ethernet minimum payload
    parameter PAD_LEN = 6'd46 - PAYLOAD_LEN;

    reg [2:0] preamble_count;
    reg [9:0] state, next_state;

    // State register
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Preamble counter : counts 0 to 6 (7 bytes)
    always @(posedge clk or posedge reset) begin
        if (reset)
            preamble_count <= 0;
        else if (state == IDLE)
            preamble_count <= 0;
        else if (state == PREAMBLE)
            preamble_count <= preamble_count + 1;
    end

    // Destination MAC counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            dest_count <= 0;
        else if (state == SFD)
            dest_count <= 0;
        else if (state == DEST)
            dest_count <= dest_count + 1;
    end

    // Source MAC counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            src_count <= 0;
        else if (state == DEST)
            src_count <= 0;
        else if (state == SRC)
            src_count <= src_count + 1;
    end

    // Length field counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            len_count <= 0;
        else if (state == SRC)
            len_count <= 0;
        else if (state == LEN)
            len_count <= len_count + 1;
    end

    // Payload counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            payload_count <= 0;
        else if (state == LEN)
            payload_count <= 0;
        else if (state == PAYLOAD)
            payload_count <= payload_count + 1;
    end

    // Padding counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            pad_count <= 0;
        else if (state == PAYLOAD)
            pad_count <= 0;
        else if (state == PAD)
            pad_count <= pad_count + 1;
    end

    // CRC counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            crc_count <= 0;
        else if (state == PAD)
            crc_count <= 0;
        else if (state == CRC)
            crc_count <= crc_count + 1;
    end

    // Inter Frame Gap counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            ifg_count <= 0;
        else if (state == CRC)
            ifg_count <= 0;
        else if (state == IFG)
            ifg_count <= ifg_count + 1;
    end

    // Next-state logic
    always @(*) begin
        case (state)

            IDLE:
                next_state = start_tx ? PREAMBLE : IDLE;

            PREAMBLE:
                next_state = (preamble_count < 6) ? PREAMBLE : SFD;

            SFD:
                next_state = DEST;

            DEST:
                next_state = (dest_count < 5) ? DEST : SRC;

            SRC:
                next_state = (src_count < 5) ? SRC : LEN;

            LEN:
                next_state = (len_count < 1) ? LEN : PAYLOAD;

            PAYLOAD:
                next_state = (payload_count < PAYLOAD_LEN - 1) ?
                             PAYLOAD : PAD;

            PAD:
                next_state = (pad_count < PAD_LEN - 1) ?
                             PAD : CRC;

            CRC:
                next_state = (crc_count < 3) ? CRC : IFG;

            IFG:
                next_state = (ifg_count < 11) ? IFG : IDLE;

            default:
                next_state = IDLE;
        endcase
    end

    // Output logic : byte_sel drives datapath mux
    always @(*) begin
        case (state)

            IDLE:      byte_sel = BYTE_IDLE;
            PREAMBLE:  byte_sel = BYTE_PREAMBLE;
            SFD:       byte_sel = BYTE_SFD;
            DEST:      byte_sel = BYTE_DEST;
            SRC:       byte_sel = BYTE_SRC;
            LEN:       byte_sel = BYTE_LEN;
            PAYLOAD:   byte_sel = BYTE_PAYLOAD;
            PAD:       byte_sel = BYTE_PAD;
            CRC:       byte_sel = BYTE_CRC;
            IFG:       byte_sel = BYTE_IFG;

            default:   byte_sel = BYTE_IDLE;
        endcase
    end

endmodule