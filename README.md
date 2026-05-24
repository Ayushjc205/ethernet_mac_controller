# ethernet_mac_controller

Hardware Implementation of Ethernet MAC Layer 


<img width="1834" height="690" alt="image" src="https://github.com/user-attachments/assets/a686b309-f290-470b-bcf8-a1e258f65022" />

A modular Ethernet MAC (Media Access Control) design implementing
the IEEE 802.3 standard frame protocol. Designed for a 25 MHz
system clock, featuring a 10-state one-hot FSM transmitter, a data-
driven receiver, a hardware CRC-32 engine using reflected polynomial
0xEDB88320, and a loopback testbench with error injection


Transmitter Path: 10-state one-hot FSM + Datapath + CRC32 engine
Receiver Path: Data-driven FSM + CRC32 verification + frame validation
Top-level wrapper (MAC top) integrating both paths with loopback
Self-checking testbench with single-bit error injection


<img width="765" height="381" alt="image" src="https://github.com/user-attachments/assets/bcc91fb7-8f96-4e71-866f-fec4a87c6600" />
