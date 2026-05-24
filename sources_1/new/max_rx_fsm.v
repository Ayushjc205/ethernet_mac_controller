`timescale 1ns / 1ps

module mac_rx_fsm (

    input clk,
    input reset,

    input rx_valid,          // byte available from PHY
    input [7:0] rx_data,

    output reg sfd_detected, // high while in DEST state

    output reg [47:0] dest_mac,      // captured destination MAC
    output reg [47:0] src_mac,       // captured source MAC
    output reg [15:0] length_field,  // captured length/type
    output reg [31:0] crc_mac,       // captured received CRC/FCS

    output reg frame_valid,  // CRC match + address match
    output reg frame_error,  // CRC fail or wrong destination

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

    // Device MAC address
    // Also accepts broadcast address
    parameter MY_MAC = 48'hAABBCCDDEEFF;

    // Internal counters and state registers
    reg [2:0] preamble_count;
    reg [2:0] dest_count;
    reg [2:0] src_count;
    reg [1:0] len_count;

    reg [12:0] payload_count;
    reg [5:0]  pad_count;
    reg [1:0]  crc_count;

    reg [9:0] state, next_state;

    // Payload storage memory
    reg [7:0] payload_mem [0:1500];

    // CRC engine signals
    wire [31:0] crc_calc;
    wire crc_en;
    wire crc_init;

    reg [7:0] rx_data_d;

    // Pipeline rx_data by one cycle
    always @(posedge clk)
        rx_data_d <= rx_data;

    // CRC Engine Instance
    crc32 rx_crc_unit (
        .clk      (clk),
        .reset    (reset),
        .crc_init (crc_init),
        .crc_en   (crc_en),
        .data_in  (rx_data_d),
        .crc_out  (crc_calc)
    );

    // CRC covers:
    // DEST + SRC + LEN + PAYLOAD + PAD
    assign crc_en =
           (state == DEST)    ||
           (state == SRC)     ||
           (state == LEN)     ||
           (state == PAYLOAD) ||
           (state == PAD);

    // Reset CRC after SFD detection
    assign crc_init =
           (next_state == DEST &&
            rx_valid &&
            rx_data == 8'hD5 &&
            preamble_count == 6);

    // Final IEEE CRC inversion
    wire [31:0] crc_final_rx;

    assign crc_final_rx = crc_calc ^ 32'hFFFFFFFF;

    // Address filtering
    wire address_match;

    assign address_match =
           (dest_mac == MY_MAC) ||
           (dest_mac == 48'hFFFFFFFFFFFF);

    // State register
    always @(posedge clk or posedge reset) begin

        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Preamble counter
    // Expects 7 bytes of 0x55
    always @(posedge clk or posedge reset) begin

        if (reset)
            preamble_count <= 0;

        else if (state == IDLE)
            preamble_count <= 0;

        else if (state == PREAMBLE &&
                 rx_valid &&
                 rx_data == 8'h55)

            preamble_count <= preamble_count + 1;
    end

    // Destination counter
    always @(posedge clk or posedge reset) begin

        if (reset)
            dest_count <= 0;

        else if (next_state == DEST && state != DEST)
            dest_count <= 0;

        else if (state == DEST && rx_valid)
            dest_count <= dest_count + 1;
    end

    // Source counter
    always @(posedge clk or posedge reset) begin

        if (reset)
            src_count <= 0;

        else if (next_state == SRC && state != SRC)
            src_count <= 0;

        else if (state == SRC && rx_valid)
            src_count <= src_count + 1;
    end

    // Length counter
    always @(posedge clk or posedge reset) begin

        if (reset)
            len_count <= 0;

        else if (next_state == LEN && state != LEN)
            len_count <= 0;

        else if (state == LEN && rx_valid)
            len_count <= len_count + 1;
    end

    // Payload counter
    always @(posedge clk or posedge reset) begin

        if (reset)
            payload_count <= 0;

        else if (next_state == PAYLOAD && state != PAYLOAD)
            payload_count <= 0;

        else if (state == PAYLOAD && rx_valid)
            payload_count <= payload_count + 1;
    end

    // Padding counter
    always @(posedge clk or posedge reset) begin

        if (reset)
            pad_count <= 0;

        else if (next_state == PAD && state != PAD)
            pad_count <= 0;

        else if (state == PAD && rx_valid)
            pad_count <= pad_count + 1;
    end

    // CRC counter
    always @(posedge clk or posedge reset) begin

        if (reset)
            crc_count <= 0;

        else if (next_state == CRC && state != CRC)
            crc_count <= 0;

        else if (state == CRC && rx_valid)
            crc_count <= crc_count + 1;
    end

    // Next-state logic
    always @(*) begin

        next_state = state;

        case (state)

            // Wait for preamble
            IDLE: begin

                if (rx_valid && rx_data == 8'h55)
                    next_state = PREAMBLE;
            end

            // Receive preamble and detect SFD
            PREAMBLE: begin

                if (rx_valid && rx_data == 8'h55)
                    next_state = PREAMBLE;

                else if (rx_valid &&
                         rx_data == 8'hD5 &&
                         preamble_count == 6)

                    next_state = DEST;

                else
                    next_state = IDLE;
            end

            // Destination MAC
            DEST: begin

                if (rx_valid && dest_count == 5)
                    next_state = SRC;
            end

            // Source MAC
            SRC: begin

                if (rx_valid && src_count == 5)
                    next_state = LEN;
            end

            // Length field
            LEN: begin

                if (rx_valid && len_count == 1)
                    next_state = PAYLOAD;
            end

            // Payload reception
            PAYLOAD: begin

                if (rx_valid &&
                    payload_count == (length_field - 1))

                    next_state =
                        (length_field < 16'd46) ?
                        PAD : CRC;
            end

            // Padding bytes
            PAD: begin

                if (rx_valid &&
                    pad_count == (16'd45 - length_field))

                    next_state = CRC;
            end

            // CRC reception
            CRC: begin

                if (rx_valid && crc_count == 3)
                    next_state = IFG;
            end

            // Inter-frame gap
            IFG:
                next_state = IDLE;

            default:
                next_state = IDLE;
        endcase
    end

    // Capture Destination MAC
    always @(posedge clk or posedge reset) begin

        if (reset)
            dest_mac <= 0;

        else if (rx_valid && state == DEST)

            case (dest_count)

                0: dest_mac[47:40] <= rx_data;
                1: dest_mac[39:32] <= rx_data;
                2: dest_mac[31:24] <= rx_data;
                3: dest_mac[23:16] <= rx_data;
                4: dest_mac[15:8]  <= rx_data;
                5: dest_mac[7:0]   <= rx_data;

            endcase
    end

    // Capture Source MAC
    always @(posedge clk or posedge reset) begin

        if (reset)
            src_mac <= 0;

        else if (rx_valid && state == SRC)

            case (src_count)

                0: src_mac[47:40] <= rx_data;
                1: src_mac[39:32] <= rx_data;
                2: src_mac[31:24] <= rx_data;
                3: src_mac[23:16] <= rx_data;
                4: src_mac[15:8]  <= rx_data;
                5: src_mac[7:0]   <= rx_data;

            endcase
    end

    // Capture Length field
    always @(posedge clk or posedge reset) begin

        if (reset)
            length_field <= 0;

        else if (rx_valid && state == LEN)

            case (len_count)

                0: length_field[15:8] <= rx_data;
                1: length_field[7:0]  <= rx_data;

            endcase
    end

   // Store payload bytes
    always @(posedge clk or posedge reset) begin

    if (reset) begin
        // optional reset logic
    end

    else if (state == PAYLOAD && rx_valid) begin
        payload_mem[payload_count] <= rx_data;
    end

end

    // Capture received CRC/FCS bytes
    always @(posedge clk or posedge reset) begin

        if (reset)
            crc_mac <= 0;

        else if (rx_valid && state == CRC)

            case (crc_count)

                0: crc_mac[7:0]   <= rx_data;
                1: crc_mac[15:8]  <= rx_data;
                2: crc_mac[23:16] <= rx_data;
                3: crc_mac[31:24] <= rx_data;

            endcase
    end

    // Frame validation
    always @(posedge clk or posedge reset) begin

        if (reset) begin

            frame_valid <= 0;
            frame_error <= 0;
        end

        else if (state == IFG) begin

            if (crc_mac == crc_final_rx &&
                address_match) begin

                frame_valid <= 1;
                frame_error <= 0;

            end
            else begin

                frame_valid <= 0;
                frame_error <= 1;
            end
        end

        else begin

            frame_valid <= 0;
            frame_error <= 0;
        end
    end

    // SFD detected indication
    always @(*) begin

        sfd_detected =
            (state == DEST) ? 1'b1 : 1'b0;
    end

endmodule