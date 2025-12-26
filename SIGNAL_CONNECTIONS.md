# MAC Controller - Signal Connection Map

## Complete Signal Flow Diagram

```
╔════════════════════════════════════════════════════════════════════════════╗
║                          PHY LAYER (Below)                                 ║
║                                                                             ║
║  rx_en ─────────────────────────────────────────────────────────────────┐ ║
║  rx_data[7:0] ──────────────────────────────────────────────────────────┤ ║
║  rx_data_valid ──────────────────────────────────────────────────────────┤ ║
║                                                                          │ ║
║  ◄─ tx_en ◄─────────────────────────────────────────────────────────────┤ ║
║  ◄─ tx_data[7:0] ◄──────────────────────────────────────────────────────┤ ║
║  ◄─ tx_data_valid ◄────────────────────────────────────────────────────┘ ║
║                                                                             ║
╚════════════════════════════════════════════════════════════════════════════╝
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                      MAC CONTROLLER (Top-Level)                            │
│                                                                            │
│  ┌─────────────────────────── RX PATH ────────────────────────────┐      │
│  │                                                                 │      │
│  │  rx_data[7:0], rx_data_valid, rx_en                           │      │
│  │         │                                                      │      │
│  │         ▼                                                      │      │
│  │    ┌─────────────┐                                            │      │
│  │    │  fifo_rx    │  (8-byte circular FIFO)                    │      │
│  │    │  (Buffering)│                                            │      │
│  │    └─────────────┘                                            │      │
│  │         │ rx_fifo_data_out[7:0]                              │      │
│  │         │ rx_frame_data_valid                                │      │
│  │         ▼                                                      │      │
│  │    ┌──────────────────┐        ┌──────────────────┐           │      │
│  │    │ frame_reception  │        │  crc_generator   │           │      │
│  │    │  (RX FSM)        │◄──────►│  (RX instance)   │           │      │
│  │    │                  │        │  (Validation)    │           │      │
│  │    │ Parses:          │        └──────────────────┘           │      │
│  │    │ - Preamble       │               │                       │      │
│  │    │ - SFD            │               │ crc_rx_out[31:0]      │      │
│  │    │ - Dest MAC       │               │ crc_rx_done           │      │
│  │    │ - Src MAC        │               ▼                       │      │
│  │    │ - Eth Type       │        (CRC Check Internal)           │      │
│  │    │ - Payload        │               │                       │      │
│  │    └──────────────────┘               │                       │      │
│  │         │                             │                       │      │
│  │ Outputs:│                             │                       │      │
│  │ ├─ dest_mac[47:0]   ◄─────────────────┘                       │      │
│  │ ├─ src_mac[47:0]                                              │      │
│  │ ├─ eth_type[15:0]                                             │      │
│  │ ├─ frame_valid (from CRC comparison)                          │      │
│  │ └─ rx_done                                                    │      │
│  │                                                                │      │
│  └────────────────────────────────────────────────────────────────┘      │
│                                                                            │
│  ┌─────────────────────────── TX PATH ────────────────────────────┐      │
│  │                                                                 │      │
│  │  app_tx_data[7:0], app_tx_data_valid, app_tx_start            │      │
│  │  app_tx_dest_mac[47:0], app_tx_src_mac[47:0]                 │      │
│  │  app_tx_eth_type[15:0]                                        │      │
│  │         │                                                      │      │
│  │         ▼                                                      │      │
│  │    ┌─────────────┐                                            │      │
│  │    │  fifo_tx    │  (16-byte circular FIFO)                   │      │
│  │    │  (Buffering)│                                            │      │
│  │    └─────────────┘                                            │      │
│  │         │ tx_fifo_data_out[7:0]                              │      │
│  │         │ tx_fifo_rd_en ◄─────────┐                           │      │
│  │         ▼                         │                           │      │
│  │    ┌────────────────────────┐    │                           │      │
│  │    │ frame_transmission     │    │                           │      │
│  │    │  (TX FSM)              │    │                           │      │
│  │    │                        │    │                           │      │
│  │    │ Generates:             │    │                           │      │
│  │    │ - Preamble (0xAA×7)    │    │                           │      │
│  │    │ - SFD (0xAB)           │    │                           │      │
│  │    │ - Dest MAC             │    │                           │      │
│  │    │ - Src MAC              │    │                           │      │
│  │    │ - Eth Type             │    │                           │      │
│  │    │ - Payload (from FIFO)  │    │                           │      │
│  │    │ - CRC (4 bytes)        │    │                           │      │
│  │    │                        │◄───┘ (gated by PAYLOAD state)   │      │
│  │    └────────────────────────┘                                 │      │
│  │         │ tx_out[7:0]       ┌──────────────────┐              │      │
│  │         │ tx_en             │  crc_generator   │              │      │
│  │         └────────────────►  │  (TX instance)   │              │      │
│  │                             │  (Generation)    │              │      │
│  │                             └──────────────────┘              │      │
│  │                                   │                           │      │
│  │                                   │ crc_tx_out[31:0]         │      │
│  │                                   │ crc_tx_done              │      │
│  │                                   ▼                           │      │
│  │                          (CRC Computation)                    │      │
│  │         │                                                      │      │
│  │         └─► Outputs ─────────────────────────────────────────┐ │      │
│  │               tx_data[7:0]                                  │ │      │
│  │               tx_data_valid                                │ │      │
│  │               tx_en                                        │ │      │
│  │               tx_done                                      │ │      │
│  │                                                                │      │
│  └────────────────────────────────────────────────────────────────┘      │
│                                                                            │
│  ┌─────────────────────── DEBUG OUTPUTS ─────────────────────────┐       │
│  │                                                                 │       │
│  │  ├─ tx_state[3:0] ◄──────► frame_transmission.state           │       │
│  │  ├─ tx_fifo_full ◄────────► fifo_tx.full                      │       │
│  │  ├─ tx_fifo_empty ◄───────► fifo_tx.empty                     │       │
│  │  ├─ rx_fifo_full ◄────────► fifo_rx.full_flag                 │       │
│  │  └─ rx_fifo_empty ◄───────► fifo_rx.empty_flag                │       │
│  │                                                                 │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
╔════════════════════════════════════════════════════════════════════════════╗
║                    APPLICATION LAYER (Above)                              ║
║                                                                             ║
║  ◄─ dest_mac[47:0]           ◄─ tx_done                                    ║
║  ◄─ src_mac[47:0]            ◄─ tx_data_valid                              ║
║  ◄─ eth_type[15:0]           ◄─ tx_en                                      ║
║  ◄─ frame_valid                                                            ║
║  ◄─ rx_done                                                                ║
║                                                                             ║
║  app_tx_data[7:0] ──────────────────────────────────────────────────────► ║
║  app_tx_data_valid ─────────────────────────────────────────────────────► ║
║  app_tx_start ──────────────────────────────────────────────────────────► ║
║  app_tx_dest_mac[47:0] ─────────────────────────────────────────────────► ║
║  app_tx_src_mac[47:0] ──────────────────────────────────────────────────► ║
║  app_tx_eth_type[15:0] ─────────────────────────────────────────────────► ║
║                                                                             ║
╚════════════════════════════════════════════════════════════════════════════╝
```

## Signal Direction Convention
```
─────►  = Input to MAC Controller
◄─────  = Output from MAC Controller
◄────►  = Bidirectional / Internal
```

## Control Flow Summary

### Reception Control Flow
```
PHY Layer sends rx_en + rx_data
    │
    ▼
FIFO_RX buffers the data
    │
    ▼
Frame_Reception parses byte-by-byte
    │
    ├─► CRC_Generator accumulates checksum
    │
    ▼
Extract headers (dest_mac, src_mac, eth_type)
    │
    ▼
CRC_Generator finalizes and compares
    │
    ▼
Output frame_valid when CRC matches
    │
    ▼
Application receives complete frame info
```

### Transmission Control Flow
```
Application provides payload + MAC info
    │
    ├─ app_tx_dest_mac[47:0]
    ├─ app_tx_src_mac[47:0]
    ├─ app_tx_eth_type[15:0]
    └─ app_tx_data[7:0] + app_tx_data_valid
    │
    ▼
FIFO_TX buffers payload
    │
    ▼
Frame_Transmission builds frame on demand
    │
    ├─ Preamble (0xAA × 7)
    ├─ SFD (0xAB)
    ├─ Destination MAC (6 bytes)
    ├─ Source MAC (6 bytes)
    ├─ Ethernet Type (2 bytes)
    ├─ Payload (from FIFO_TX)
    │   (CRC_Generator accumulates)
    └─ CRC (4 bytes)
    │
    ▼
Outputs to PHY layer
    │
    ├─ tx_en (transmission active)
    ├─ tx_data[7:0] (byte to transmit)
    └─ tx_data_valid (byte is valid)
    │
    ▼
tx_done asserted when frame complete
```

## Key Internal Signals Reference

| Signal | Width | Source | Destination | Logic |
|--------|-------|--------|-------------|-------|
| `rx_fifo_wr_en` | 1 | MAC | FIFO_RX | `rx_en & rx_data_valid` |
| `rx_fifo_rd_en` | 1 | MAC | FIFO_RX | `rx_en & ~rx_fifo_empty` |
| `rx_frame_data_valid` | 1 | FIFO_RX | Frame_RX, CRC_RX | `~rx_fifo_empty & rx_en` |
| `tx_fifo_wr_en` | 1 | MAC | FIFO_TX | `app_tx_data_valid & ~tx_fifo_full` |
| `tx_fifo_rd_en` | 1 | MAC | FIFO_TX | `(frame_tx_state==PAYLOAD) & ~tx_fifo_empty` |
| `frame_tx_state[3:0]` | 4 | Frame_TX | MAC, FIFO control | FSM output (0-9) |
| `crc_rx_out[31:0]` | 32 | CRC_RX | Frame_RX | Calculated RX CRC |
| `crc_rx_done` | 1 | CRC_RX | Frame_RX | CRC ready signal |
| `crc_tx_out[31:0]` | 32 | CRC_TX | Frame_TX | Calculated TX CRC |
| `crc_tx_done` | 1 | CRC_TX | Frame_TX | CRC ready signal |

## Frame Structure (as built by frame_transmission)

```
Byte Offset  |  Field           |  Value/Source         |  Bytes
─────────────┼──────────────────┼──────────────────────┼────────
0-6          |  Preamble        |  0xAA                 |  7
7            |  SFD             |  0xAB                 |  1
8-13         |  Dest MAC        |  app_tx_dest_mac      |  6
14-19        |  Src MAC         |  app_tx_src_mac       |  6
20-21        |  Ethernet Type   |  app_tx_eth_type      |  2
22-N         |  Payload         |  app_tx_data (FIFO)   |  Variable
N+1-N+4      |  CRC-32          |  crc_generator        |  4
─────────────┴──────────────────┴──────────────────────┴────────
             Total Frame: 15 + Payload Size + 4 bytes
```

## Timing Example: Receiving a Frame

```
Clock Cycle  |  rx_data  |  rx_data_valid  |  rx_fifo_empty  |  Action
──────────────┼───────────┼─────────────────┼─────────────────┼──────────────────
0            |  0xAA     |  1              |  0              |  Preamble byte 1
1            |  0xAA     |  1              |  0              |  Preamble byte 2
...
6            |  0xAB     |  1              |  0              |  SFD
7            |  0xXX     |  1              |  0              |  Dest MAC byte 1
...
12           |  0xXX     |  1              |  0              |  Src MAC byte 1
...
19           |  0xXX     |  1              |  0              |  Eth Type byte 1
20           |  0xXX     |  1              |  0              |  Payload byte 1
...
N            |  0xXX     |  1              |  0              |  CRC byte 1
N+1          |  0xXX     |  1              |  0              |  CRC byte 2
N+2          |  0xXX     |  1              |  0              |  CRC byte 3
N+3          |  0xXX     |  1              |  0              |  CRC byte 4
N+4          |  ----     |  0              |  1              |  frame_valid asserted
```

## TX State Encoding Reference

```
State Code | State Name       | Description
───────────┼──────────────────┼─────────────────────────────────
4'b0000    | IDLE             | Waiting for app_tx_start
4'b0001    | PREAMBLE         | Sending 7 bytes of 0xAA
4'b0010    | SFD              | Sending Start Frame Delimiter 0xAB
4'b0011    | DEST_ADDR        | Sending destination MAC (6 bytes)
4'b0100    | SRC_ADDR         | Sending source MAC (6 bytes)
4'b0101    | ETH_TYPE         | Sending Ethernet type (2 bytes)
4'b0110    | PAYLOAD          | Sending payload from FIFO_TX
4'b0111    | FINALIZE_CRC     | Finalizing CRC computation
4'b1000    | CRC              | Sending CRC-32 (4 bytes)
4'b1001    | DONE             | Transmission complete, tx_done=1
```
