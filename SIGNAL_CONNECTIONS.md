# MAC Controller - Signal Connection Reference

## Complete System Block Diagram

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          PHY LAYER (External)                              │
│                                                                             │
│  RX Inputs:  rx_en, rx_data[7:0], rx_data_valid                          │
│  TX Outputs: tx_en, tx_data[7:0], tx_data_valid                          │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                   MAC CONTROLLER TOP LEVEL (24 signals)                    │
│                                                                             │
│  ┌─────────────────────── RX DATA PATH ────────────────────────┐          │
│  │                                                               │          │
│  │  PHY RX: rx_en, rx_data[7:0], rx_data_valid                 │          │
│  │         (frame bytes arriving from network)                  │          │
│  │         ▼                                                     │          │
│  │    ┌─────────────────┐                                       │          │
│  │    │   fifo_rx.v     │  (8-byte circular buffer)             │          │
│  │    │ (Synchronization)                                       │          │
│  │    └─────────────────┘                                       │          │
│  │    wr_en: rx_fifo_wr_en ◄──── (controlled by PHY rx_en)    │          │
│  │    rd_en: rx_fifo_rd_en ◄──── (controlled by Frame_Reception)          │
│  │         ▼                                                     │          │
│  │    ┌────────────────────┐    ┌──────────────┐              │          │
│  │    │ frame_reception.v  │◄──►│ crc_gen.v    │              │          │
│  │    │ (RX State Machine) │    │ (CRC Verify) │              │          │
│  │    │                    │    └──────────────┘              │          │
│  │    │ Extracts:          │          │                        │          │
│  │    │ • Preamble         │          ├─ crc_rx_out[31:0]      │          │
│  │    │ • SFD              │          ├─ crc_rx_done           │          │
│  │    │ • Dest MAC         │          ├─ crc_rx_valid_residue  │          │
│  │    │ • Src MAC          │          └─ (validation check)    │          │
│  │    │ • EtherType        │               │                    │          │
│  │    │ • Payload          │               ├─► frame_valid      │          │
│  │    │ • CRC              │               └─► rx_done          │          │
│  │    └────────────────────┘                                   │          │
│  │         ▼                                                     │          │
│  │  APP RX: dest_mac[47:0], src_mac[47:0], eth_type[15:0]      │          │
│  │          frame_valid (CRC result), rx_done                   │          │
│  │                                                               │          │
│  └───────────────────────────────────────────────────────────────┘          │
│                                                                              │
│  ┌─────────────────────── TX DATA PATH ────────────────────────┐          │
│  │                                                               │          │
│  │  APP TX: app_tx_data[7:0], app_tx_data_valid                │          │
│  │          app_tx_dest_mac[47:0], app_tx_src_mac[47:0]        │          │
│  │          app_tx_eth_type[15:0], app_tx_start                │          │
│  │          (frame data and control from application)           │          │
│  │         ▼                                                     │          │
│  │    ┌──────────────────┐                                      │          │
│  │    │   fifo_tx.v      │  (16-byte circular buffer)           │          │
│  │    │ (Payload Storage) │                                      │          │
│  │    └──────────────────┘                                      │          │
│  │    wr_en: tx_fifo_wr_en ◄──── (controlled by app data_valid) │          │
│  │    rd_en: tx_fifo_rd_en ◄──── (gated by PAYLOAD state)       │          │
│  │         ▼                                                     │          │
│  │    ┌────────────────────┐    ┌──────────────┐              │          │
│  │    │ frame_transmission │◄──►│ crc_gen.v    │              │          │
│  │    │  (TX State Machine)│    │ (CRC Gen)    │              │          │
│  │    │                    │    └──────────────┘              │          │
│  │    │ Generates:         │          │                        │          │
│  │    │ • Preamble (0xAA×7)│          ├─ crc_tx_out[31:0]      │          │
│  │    │ • SFD (0xAB)       │          ├─ crc_tx_done           │          │
│  │    │ • Dest MAC (app)   │          └─ (CRC computation)     │          │
│  │    │ • Src MAC (app)    │               │                    │          │
│  │    │ • EtherType (app)  │               └─► [inserted before │          │
│  │    │ • Payload (FIFO)   │                    CRC output]    │          │
│  │    │ • CRC              │                                    │          │
│  │    └────────────────────┘                                   │          │
│  │         ▼                                                     │          │
│  │  PHY TX: tx_en, tx_data[7:0], tx_data_valid                 │          │
│  │          tx_done (completion flag)                           │          │
│  │          (complete Ethernet frame to network)                │          │
│  │                                                               │          │
│  └───────────────────────────────────────────────────────────────┘          │
│                                                                              │
│  ┌─────────────── CONTROL SIGNALS & STATUS ────────────────────┐          │
│  │                                                               │          │
│  │  clk (100 MHz, 10ns period)                                  │          │
│  │  rst_n (asynchronous active-low reset)                       │          │
│  │                                                               │          │
│  │  Debug/Status Outputs:                                       │          │
│  │  • tx_state[3:0] - TX FSM state (for monitoring)             │          │
│  │  • tx_fifo_full, tx_fifo_empty - TX FIFO status              │          │
│  │  • rx_fifo_full, rx_fifo_empty - RX FIFO status              │          │
│  │                                                               │          │
│  └───────────────────────────────────────────────────────────────┘          │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                       APPLICATION LAYER (External)                         │
│                                                                             │
│  RX Processing: Use dest_mac, src_mac, eth_type, frame_valid when rx_done  │
│  TX Processing: Provide payload via app_tx_data, assert app_tx_start      │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Signal Summary Table

### Inputs (11 signals)

| Port | Width | Source | Description |
|------|-------|--------|-------------|
| `clk` | 1 | System | 100 MHz clock |
| `rst_n` | 1 | System | Active-low reset |
| `rx_en` | 1 | PHY | Frame reception enable |
| `rx_data` | 8 | PHY | Incoming frame byte |
| `rx_data_valid` | 1 | PHY | Byte is valid |
| `app_tx_data` | 8 | App | Payload byte |
| `app_tx_data_valid` | 1 | App | Payload byte valid |
| `app_tx_start` | 1 | App | Initiate transmission |
| `app_tx_dest_mac` | 48 | App | Destination MAC |
| `app_tx_src_mac` | 48 | App | Source MAC |
| `app_tx_eth_type` | 16 | App | EtherType field |

### Outputs (13 signals)

| Port | Width | Destination | Description |
|------|-------|-------------|-------------|
| `tx_en` | 1 | PHY | Transmission active |
| `tx_data` | 8 | PHY | Outgoing frame byte |
| `tx_data_valid` | 1 | PHY | Byte is valid |
| `dest_mac` | 48 | App | Received destination MAC |
| `src_mac` | 48 | App | Received source MAC |
| `eth_type` | 16 | App | Received EtherType |
| `frame_valid` | 1 | App | CRC validation passed |
| `rx_done` | 1 | App | Frame reception complete |
| `tx_done` | 1 | App | Frame transmission complete |
| `tx_state` | 4 | Debug | TX FSM state (optional) |
| `tx_fifo_full` | 1 | Debug | TX FIFO full flag |
| `tx_fifo_empty` | 1 | Debug | TX FIFO empty flag |
| `rx_fifo_full` | 1 | Debug | RX FIFO full flag |
| `rx_fifo_empty` | 1 | Debug | RX FIFO empty flag |

---

## Control Flow

### RX Path Control Logic

```verilog
// Write to RX FIFO when PHY provides data
rx_fifo_wr_en = rx_en & rx_data_valid;

// Read from RX FIFO when Frame_Reception is active
rx_fifo_rd_en = (frame_rx_state != IDLE) & ~rx_fifo_empty;

// Signal to Frame_Reception that data is available
rx_frame_data_valid = ~rx_fifo_empty & frame_rx_state != IDLE;
```

### TX Path Control Logic

```verilog
// Write to TX FIFO when application provides payload
tx_fifo_wr_en = app_tx_data_valid & ~tx_fifo_full;

// Read from TX FIFO only during PAYLOAD state of TX FSM
// This prevents reading stale data at frame boundaries
tx_fifo_rd_en = (frame_tx_state == PAYLOAD) & ~tx_fifo_empty;
```

### MAC Address & EtherType Routing

```verilog
// Destination MAC: app → Frame_Transmission
frame_tx_dest_mac = app_tx_dest_mac;

// Source MAC: app → Frame_Transmission
frame_tx_src_mac = app_tx_src_mac;

// EtherType: app → Frame_Transmission
frame_tx_eth_type = app_tx_eth_type;
```

---

## Frame Structure

Complete Ethernet frame transmitted/received:

```
Byte Position │ Length │ Description
──────────────┼────────┼─────────────────────────────
0-6           │ 7      │ Preamble (0xAA × 7)
7             │ 1      │ SFD (Start Frame Delimiter 0xAB)
8-13          │ 6      │ Destination MAC Address
14-19         │ 6      │ Source MAC Address
20-21         │ 2      │ EtherType (e.g., 0x0800 for IPv4)
22-67         │ 46     │ Payload (variable, min 46 bytes)
68-71         │ 4      │ CRC-32 Checksum
──────────────┴────────┴─────────────────────────────
Total Frame   │ 72     │ bytes (minimum frame size)
```

---

## TX State Machine States

The `tx_state[3:0]` output reflects the current TX FSM state:

| State | Value | Description |
|-------|-------|-------------|
| IDLE | 4'h0 | Waiting for app_tx_start |
| PREAMBLE | 4'h1 | Transmitting preamble (7×0xAA) |
| SFD | 4'h2 | Transmitting SFD (0xAB) |
| DEST_ADDR | 4'h3 | Transmitting destination MAC |
| SRC_ADDR | 4'h4 | Transmitting source MAC |
| ETH_TYPE | 4'h5 | Transmitting EtherType |
| PAYLOAD | 4'h6 | Transmitting payload from FIFO |
| FINALIZE_CRC | 4'h7 | Computing CRC |
| CRC_TX | 4'h8 | Transmitting CRC bytes |

---

## Timing Examples

### Example 1: Single TX Frame (100 MHz clock)

```
Time    │ Signal          │ Value │ Notes
────────┼─────────────────┼───────┼──────────────────────
t=0ns   │ clk             │ 1→0   │ Reset released (rst_n=1)
t=10ns  │ clk             │ 0→1   │ First clock edge
        │ app_tx_start    │ 1     │ Application requests TX
t=20ns  │ clk             │ 1→0   │
        │ app_tx_start    │ 0     │ Pulse ends
        │ tx_state        │ PREAMBLE │ FSM transitions
t=30ns  │ clk             │ 0→1   │
        │ tx_en           │ 1     │ TX begins
        │ tx_data         │ 0xAA  │ Preamble byte 0
t=40-1800ns │ (sequential) │ 0xAA  │ Preamble bytes 1-6, SFD, headers
        │ tx_fifo_rd_en   │ 1     │ Reading payload from FIFO
        │ tx_state        │ PAYLOAD │ In payload state
t=1810ns│ clk             │ 0→1   │
        │ tx_data         │ 0xXX  │ Last CRC byte
t=1820ns│ clk             │ 1→0   │
        │ tx_en           │ 0     │ TX complete
        │ tx_done         │ 1     │ Transmission done flag
        │ tx_state        │ IDLE  │ FSM returns to idle
```

### Example 2: RX Frame Reception (100 MHz clock)

```
Time    │ Signal          │ Value │ Notes
────────┼─────────────────┼───────┼──────────────────────
t=0ns   │ clk             │ 1→0   │ Frame arriving from PHY
t=10ns  │ clk             │ 0→1   │
        │ rx_en           │ 1     │ RX enabled
        │ rx_data         │ 0xAA  │ Preamble byte 0
        │ rx_data_valid   │ 1     │ Valid data
        │ rx_fifo_wr_en   │ 1     │ FIFO accepting data
t=20ns+ │ (sequential)    │ 0xAA+ │ Bytes 1-71 received one per cycle
        │ rx_fifo_empty   │ 0     │ FIFO contains data
t=1790ns│ clk             │ 0→1   │
        │ rx_data         │ 0xXX  │ Last CRC byte
t=1800ns│ clk             │ 1→0   │
        │ rx_en           │ 0     │ RX stopped
        │ rx_data_valid   │ 0     │ No more data
t=300+ │ clk cycles      │ -     │ Frame_Reception parsing
t=3000ns│ clk             │ 0→1   │
        │ dest_mac        │ 0x0011223344555 │ (stable)
        │ src_mac         │ 0xAABBCCDDEEFF  │ (stable)
        │ eth_type        │ 0x0800          │ (stable)
        │ frame_valid     │ 1              │ CRC passed
        │ rx_done         │ 1              │ Reception complete
```

---

## Common Connection Errors

| Error | Cause | Fix |
|-------|-------|-----|
| Dest/Src MAC outputs are 0x00... | Not waiting long enough after rx_done | Increase wait cycles, check Frame_Reception latency |
| tx_en never goes high | app_tx_start not pulsed | Ensure one-cycle pulse on app_tx_start |
| TX FIFO remains full | payload_fifo_rd_en never asserted | Check if frame_tx_state reaches PAYLOAD |
| RX FIFO overflows | Reading slower than writing | Verify rx_fifo_rd_en is properly gated |
| CRC validation fails | FIFO timing corruption | Check full/empty flags, ensure proper synchronization |

---

## Useful Waveform Signals to Monitor

**For TX Testing:**
- `clk`, `rst_n` (timing reference)
- `app_tx_start`, `app_tx_data`, `app_tx_data_valid`
- `tx_en`, `tx_data`, `tx_data_valid`
- `tx_state` (see progression through PREAMBLE → PAYLOAD → CRC_TX → IDLE)
- `tx_fifo_empty`, `tx_fifo_full`

**For RX Testing:**
- `clk`, `rst_n` (timing reference)
- `rx_en`, `rx_data`, `rx_data_valid`
- `dest_mac`, `src_mac`, `eth_type` (should stabilize after rx_done)
- `frame_valid`, `rx_done`
- `rx_fifo_empty`, `rx_fifo_full`

**For Both:**
- `app_tx_*` (TX inputs)
- `rx_*` (RX inputs)
- `tx_*`, `dest_mac`, `src_mac`, `eth_type` (outputs)
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
