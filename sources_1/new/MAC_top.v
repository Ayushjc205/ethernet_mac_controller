`timescale 1ns / 1ps

module MAC_top (

    input clk,
    input reset,

    input start_tx,     // pulse high to begin transmission

    output [7:0] tx,    // serialized byte output to PHY

    input rx_valid,     // PHY asserts when rx_data is valid
    input [7:0] rx_data,

    output sfd_detected, // high when RX reaches DEST state
    output frame_valid,  // frame passed CRC + address check
    output frame_error   // frame failed CRC or address check
);

    // Internal wires : TX control signals from FSM
    wire [3:0] byte_sel;

    wire [2:0] dest_count;
    wire [2:0] src_count;

    wire [1:0] len_count;

    wire [3:0] payload_count;
    wire [5:0] pad_count;

    wire [1:0] crc_count;
    wire [3:0] ifg_count;

    // Internal wires : CRC engine
    wire [31:0] crc_out;

    wire crc_en;
    wire crc_init;

    // TX FSM
    // Generates:
    //   - byte_sel
    //   - field counters
    mac_tx_fsm TX_FSM (

        .clk           (clk),
        .reset         (reset),
        .start_tx      (start_tx),

        .dest_count    (dest_count),
        .src_count     (src_count),
        .len_count     (len_count),

        .payload_count (payload_count),
        .pad_count     (pad_count),

        .crc_count     (crc_count),
        .ifg_count     (ifg_count),

        .byte_sel      (byte_sel)
    );

    // TX Datapath
    // Drives tx[7:0] according to byte_sel
    datapath TX_DATA (

        .clk           (clk),
        .reset         (reset),

        .dest_count    (dest_count),
        .src_count     (src_count),
        .len_count     (len_count),

        .byte_sel      (byte_sel),

        .payload_count (payload_count),
        .pad_count     (pad_count),

        .crc_out       (crc_out),
        .crc_count     (crc_count),

        .ifg_count     (ifg_count),

        .tx            (tx)
    );

    // CRC Enable
    // CRC is calculated over:
    //   DEST + SRC + LEN + PAYLOAD + PAD
    assign crc_en =
           (byte_sel == 4'd3) ||   // DEST
           (byte_sel == 4'd4) ||   // SRC
           (byte_sel == 4'd5) ||   // LEN
           (byte_sel == 4'd6) ||   // PAYLOAD
           (byte_sel == 4'd7);     // PAD

    // CRC Initialization
    // Reset CRC register at SFD
    assign crc_init = (byte_sel == 4'd2);

    // TX CRC Engine
    // Computes Ethernet FCS for outgoing frame
    crc32 TX_CRC (

        .clk      (clk),
        .reset    (reset),

        .crc_init (crc_init),
        .crc_en   (crc_en),

        .data_in  (tx),

        .crc_out  (crc_out)
    );

    // RX FSM
    // Receives and validates incoming frame
    mac_rx_fsm RX_FSM (

        .clk          (clk),
        .reset        (reset),

        .rx_valid     (rx_valid),
        .rx_data      (rx_data),

        .sfd_detected (sfd_detected),

        .frame_valid  (frame_valid),
        .frame_error  (frame_error),

        .byte_sel     ()   // unused externally
    );

endmodule