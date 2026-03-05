# MAC Controller - Quick Reference Card

## System Overview

```
┌──────────────────────────────────────────────────────────┐
│      Ethernet MAC Controller - Top Level Module          │
│                                                            │
│   IEEE 802.3 Compliant | Full-Duplex | CRC-32         │
│   100 MHz Clock | 24 Signals | 72-byte frames          │
│                                                            │
└──────────────────────────────────────────────────────────┘
```

---

## Data Paths (One-Page View)

```
RX PATH                          TX PATH
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PHY Layer                        Application
(rx_en, rx_data, rx_data_valid)  (app_tx_data, app_tx_dest_mac, ...)
         │                                  │
         ▼                                  ▼
  ┌────────────┐                 ┌────────────┐
  │ FIFO_RX    │                 │ FIFO_TX    │
  │ (8 bytes)  │                 │ (16 bytes) │
  └────────────┘                 └────────────┘
         │                                  │
         ▼                                  ▼
  ┌────────────────────┐          ┌────────────────────┐
  │ Frame_Reception    │          │ Frame_Transmission │
  │ (Parse headers)    │          │ (Build frame)      │
  │ ┌──────────────┐   │          │ ┌──────────────┐   │
  │ │ crc_validate │   │          │ │ crc_generate │   │
  │ └──────────────┘   │          │ └──────────────┘   │
  └────────────────────┘          └────────────────────┘
         │                                  │
         ▼                                  ▼
  Application                        PHY Layer
  (dest_mac, src_mac,               (tx_en, tx_data,
   eth_type, frame_valid)            tx_data_valid)
```

---

## Port Summary (24 Signals Total)

### Category 1: Clock & Reset (2)
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `clk` | 1 | Input | System clock (100 MHz) |
| `rst_n` | 1 | Input | Asynchronous active-low reset |

### Category 2: RX from PHY (3)
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `rx_en` | 1 | Input | Frame reception enabled |
| `rx_data` | 8 | Input | Incoming frame byte |
| `rx_data_valid` | 1 | Input | Byte is valid |

### Category 3: RX to Application (5)
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `dest_mac` | 48 | Output | Parsed destination MAC address |
| `src_mac` | 48 | Output | Parsed source MAC address |
| `eth_type` | 16 | Output | Parsed EtherType/Length field |
| `frame_valid` | 1 | Output | CRC validation result (1=pass) |
| `rx_done` | 1 | Output | Frame reception complete |

### Category 4: TX from Application (6)
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `app_tx_data` | 8 | Input | Payload byte |
| `app_tx_data_valid` | 1 | Input | Payload byte is valid |
| `app_tx_start` | 1 | Input | Initiate transmission (pulse) |
| `app_tx_dest_mac` | 48 | Input | Destination MAC address |
| `app_tx_src_mac` | 48 | Input | Source MAC address |
| `app_tx_eth_type` | 16 | Input | EtherType field (e.g., 0x0800) |

### Category 5: TX to PHY (3)
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `tx_en` | 1 | Output | Transmission active |
| `tx_data` | 8 | Output | Outgoing frame byte |
| `tx_data_valid` | 1 | Output | Byte is valid |

### Category 6: Completion Flags (1)
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `tx_done` | 1 | Output | Transmission complete |

### Category 7: Debug Outputs (4)
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `tx_state` | 4 | Output | TX FSM state (IDLE=0, PREAMBLE=1, ...) |
| `tx_fifo_full` | 1 | Output | TX FIFO full flag |
| `tx_fifo_empty` | 1 | Output | TX FIFO empty flag |
| `rx_fifo_full` | 1 | Output | RX FIFO full flag |
| `rx_fifo_empty` | 1 | Output | RX FIFO empty flag |

---

## Frame Structure Quick Reference

```
Byte     Content               Example
────────────────────────────────────────────
0-6      Preamble              0xAA (7 bytes)
7        SFD                   0xAB
8-13     Destination MAC       0x00:11:22:33:44:55
14-19    Source MAC            0xAA:BB:CC:DD:EE:FF
20-21    EtherType             0x0800 (IPv4)
22-67    Payload               46 bytes minimum
68-71    CRC-32                4 bytes
────────────────────────────────────────────
TOTAL    Frame Size            72 bytes (minimum)
```

---

## Typical Usage Sequence

### TX Example
```verilog
// Step 1: Setup frame parameters
app_tx_dest_mac  = 48'h001122334455;
app_tx_src_mac   = 48'hAABBCCDDEEFF;
app_tx_eth_type  = 16'h0800;

// Step 2: Fill payload (46 bytes minimum)
for (i = 0; i < 46; i = i + 1) begin
    @(posedge clk);
    app_tx_data = payload_byte[i];
    app_tx_data_valid = 1'b1;
end
app_tx_data_valid = 1'b0;

// Step 3: Pulse start signal
@(posedge clk);
app_tx_start = 1'b1;
@(posedge clk);
app_tx_start = 1'b0;

// Step 4: Wait for completion
wait (tx_done == 1'b1);
```

### RX Example
```verilog
// Step 1: Inject frame bytes
for (i = 0; i < frame_size; i = i + 1) begin
    @(posedge clk);
    rx_data = frame[i];
    rx_data_valid = 1'b1;
    rx_en = 1'b1;
end
rx_data_valid = 1'b0;
rx_en = 1'b0;

// Step 2: Wait for parsing (300+ cycles)
wait_cycles(300);

// Step 3: Check results
if (frame_valid && rx_done) begin
    $display("Dest: %012h", dest_mac);
    $display("Src:  %012h", src_mac);
    $display("Type: %04h", eth_type);
end
```

---

## TX FSM States

| State | Code | Sequence | Description |
|-------|------|----------|-------------|
| IDLE | 0x0 | → | Waiting for app_tx_start pulse |
| PREAMBLE | 0x1 | → | Transmit 7 × 0xAA bytes |
| SFD | 0x2 | → | Transmit 1 × 0xAB byte |
| DEST_ADDR | 0x3 | → | Transmit 6 destination MAC bytes |
| SRC_ADDR | 0x4 | → | Transmit 6 source MAC bytes |
| ETH_TYPE | 0x5 | → | Transmit 2 EtherType bytes |
| PAYLOAD | 0x6 | → | Transmit 46+ payload bytes from FIFO |
| FINALIZE_CRC | 0x7 | → | Compute CRC-32 checksum |
| CRC_TX | 0x8 | → | Transmit 4 CRC bytes, then IDLE |

---

## Key Design Features

| Feature | Value | Benefit |
|---------|-------|---------|
| **Clock Frequency** | 100 MHz (10 ns) | High-speed operation |
| **Full Duplex** | Simultaneous RX/TX | Bidirectional communication |
| **CRC Validation** | IEEE 802.3 CRC-32 | Error detection |
| **RX Buffer Size** | 8 bytes | Handles PHY burst rates |
| **TX Buffer Size** | 16 bytes | Decouples app timing |
| **Preamble** | 7 × 0xAA | Standard Ethernet sync |
| **Min Frame Size** | 72 bytes | IEEE 802.3 compliance |
| **Max Frame Size** | Unlimited | With streaming payload |

---

## Common Signal States

### RX Reception Complete
```
Condition: rx_done == 1
├─ dest_mac: valid (stable)
├─ src_mac: valid (stable)
├─ eth_type: valid (stable)
├─ frame_valid: 1 = CRC OK, 0 = CRC failed
└─ rx_fifo: should be empty
```

### TX Transmission Complete
```
Condition: tx_done == 1
├─ tx_en: 0 (not transmitting)
├─ tx_data_valid: 0
├─ tx_fifo_empty: 1 (FIFO depleted)
└─ tx_state: IDLE (0x0)
```

---

## Debugging Checklist

- [ ] Clock period is 10 ns (100 MHz)
- [ ] Reset (rst_n) is properly released
- [ ] app_tx_start is a one-cycle pulse
- [ ] app_tx_dest_mac/src_mac/eth_type set before transmission
- [ ] Payload FIFO filled before app_tx_start pulse
- [ ] For RX: Wait ≥300 cycles after injecting complete frame
- [ ] Check tx_state progression (0→1→2→3→4→5→6→7→8→0)
- [ ] Monitor rx_fifo_empty/full for data flow issues
- [ ] Verify CRC in frame matches expected residue
- [ ] Confirm frame_valid = 1 when RX completes

---

## Reference Links

- [README.md](README.md) - Project overview & architecture
- [TESTING_GUIDE.md](TESTING_GUIDE.md) - Detailed test procedures
- [SIGNAL_CONNECTIONS.md](SIGNAL_CONNECTIONS.md) - Complete signal reference
- [MAC_CONTROLLER_DESIGN.md](MAC_CONTROLLER_DESIGN.md) - Detailed design documentation

---

## Test Output Summary

The `tb_mac_controller.v` testbench produces:

**Test 1 Output:** 72-byte frame with byte-by-byte display showing:
```
[Byte] [Value] [ASCII] [Frame Structure]
[  0] 0xAA  '«'    [Preamble byte 0]
...
[ 71] 0xXX  'x'    [CRC byte 3]
Total frame size: 72 bytes
```

**Test 2 Output:** Extracted headers with verification:
```
Destination MAC: 0x001122334455 (Expected: 0x001122334455, Match: ✓ YES)
Source MAC: 0xAABBCCDDEEFF (Expected: 0xAABBCCDDEEFF, Match: ✓ YES)
EtherType: 0x0800 (Expected: 0x0800, Match: ✓ YES)
Frame Valid: 1
RX Done: 1
```

### RX Control Signals (Internal)
```
rx_fifo_wr_en       = rx_en & rx_data_valid          // Write to RX FIFO
rx_fifo_rd_en       = rx_en & ~rx_fifo_empty         // Read from RX FIFO
rx_frame_data_valid = ~rx_fifo_empty & rx_en         // Valid data available
```

### TX Control Signals (Internal)
```
tx_fifo_wr_en = app_tx_data_valid & ~tx_fifo_full              // Write to TX FIFO
tx_fifo_rd_en = (frame_tx_state == 4'b0110) & ~tx_fifo_empty  // Read during PAYLOAD
```

### Frame_Transmission States
```
4'b0000 = IDLE          (Waiting)
4'b0001 = PREAMBLE      (7 × 0xAA)
4'b0010 = SFD           (0xAB)
4'b0011 = DEST_ADDR     (6 bytes)
4'b0100 = SRC_ADDR      (6 bytes)
4'b0101 = ETH_TYPE      (2 bytes)
4'b0110 = PAYLOAD       (Variable, from FIFO)
4'b0111 = FINALIZE_CRC  (Finalize calculation)
4'b1000 = CRC           (4 bytes)
4'b1001 = DONE          (Complete)
```

---

## TX Frame Structure

```
Byte Offset │ Field          │ Value
────────────┼────────────────┼──────────────────
0-6         │ Preamble       │ 0xAA (7 bytes)
7           │ SFD            │ 0xAB
8-13        │ Dest MAC       │ app_tx_dest_mac
14-19       │ Src MAC        │ app_tx_src_mac
20-21       │ Ethernet Type  │ app_tx_eth_type
22-N        │ Payload        │ app_tx_data (FIFO)
N+1-N+4     │ CRC-32         │ computed
────────────┴────────────────┴──────────────────
```

---

## Essential Concepts

### 1. Full-Duplex Operation
- RX and TX can happen **simultaneously**
- Use separate FIFOs to avoid conflicts
- Independent FSMs don't interfere

### 2. FIFO Gating Strategy
**RX:** Simple read when enable & not empty
```
rx_fifo_rd_en = rx_en & ~rx_fifo_empty
```

**TX:** Complex read only during PAYLOAD state
```
tx_fifo_rd_en = (frame_tx_state == PAYLOAD) & ~tx_fifo_empty
```

### 3. CRC Role
**RX:** Validates received frames
```
if (received_crc == crc_out) frame_valid = 1;
```

**TX:** Protects transmitted frames
```
crc_tx_done → frame appends CRC bytes
```

### 4. Application Integration
- Application provides **payload + MAC info** for TX
- Application receives **parsed headers** from RX
- Decoupled by FIFOs (asynchronous timing)

---

## Common Tasks

### Task 1: Receive a Frame
```verilog
// Drive PHY interface
rx_en = 1;
rx_data_valid = 1;
rx_data = frame_byte;  // One byte per cycle

// Monitor output
wait(frame_valid == 1);
dest = dest_mac;
src = src_mac;
type = eth_type;
```

### Task 2: Transmit a Frame
```verilog
// Load application parameters
app_tx_dest_mac = 48'hFFFFFFFFFFFF;
app_tx_src_mac = 48'h001122334455;
app_tx_eth_type = 16'h0800;
app_tx_start = 1;

// Provide payload
app_tx_data = payload_byte;
app_tx_data_valid = 1;

// Monitor completion
wait(tx_done == 1);
```

### Task 3: Handle Full FIFO
```verilog
// Check FIFO status before writing
if (!tx_fifo_full) begin
    app_tx_data = next_byte;
    app_tx_data_valid = 1;
end else begin
    // Stall application
    wait(!tx_fifo_full);
end
```

### Task 4: Monitor FSM State
```verilog
// Use debug output for state tracking
case(tx_state)
    4'b0110: $display("In PAYLOAD state");
    4'b0111: $display("CRC finalizing");
    4'b1000: $display("Transmitting CRC");
    default: $display("Other state");
endcase
```

---

## Performance Numbers

| Metric | Value |
|--------|-------|
| **Clock Frequency** | Configurable (typically 50-125 MHz) |
| **Max Data Rate** | 1 byte/cycle (8-125 Mbps depending on clock) |
| **Min Frame Size** | 15 bytes (headers only, no payload) |
| **Max Frame Size** | Limited by payload buffering (16B FIFO) |
| **RX Processing Latency** | ~20 cycles (FIFO + FSM) |
| **TX Build Latency** | ~50 cycles (preamble + headers + payload) |
| **CRC Compute Time** | ~1 cycle/byte |

---

## Common Issues & Solutions

### Issue: `frame_valid` never asserts
**Check:**
- Is `crc_done` from RX CRC generator asserted?
- Are received CRC bytes captured correctly?
- Is frame_reception reaching CRC_COMPARE state?

### Issue: TX frame doesn't start
**Check:**
- Is `app_tx_start` being held long enough?
- Is frame_tx_state changing from IDLE?
- Check `tx_fifo_empty` is not blocking

### Issue: FIFO overflow
**Check:**
- Is `tx_fifo_full` being monitored?
- Is `tx_fifo_wr_en` being gated with full flag?
- Can reduce write rate or increase FIFO depth

### Issue: CRC mismatch
**Check:**
- Are all data bytes being included in CRC?
- Is polynomial correct (0x04C11DB7)?
- Are CRC bytes in correct order?

---

## Debugging Tips

### Add Signal Taps
```verilog
// Monitor RX path
output wire [31:0] debug_crc_rx = crc_rx_out;
output wire debug_crc_done_rx = crc_rx_done;

// Monitor TX path
output wire [3:0] debug_tx_state = frame_tx_state;
output wire debug_tx_fifo_rd = tx_fifo_rd_en;
```

### Use Simulation $monitor
```verilog
$monitor($time, " RX: state=%0d crc_done=%b | TX: state=%0d tx_en=%b",
         state_rx, crc_done_rx, tx_state, tx_en);
```

### Trace Frame Content
```verilog
if (rx_frame_data_valid) 
    $display("[%0d] RX byte: %02X", $time, rx_fifo_data_out);
if (tx_en) 
    $display("[%0d] TX byte: %02X", $time, tx_out);
```

---

## Reset Sequence

```verilog
// Apply reset
rst_n = 0;
repeat(5) @(posedge clk);

// Release reset
rst_n = 1;
repeat(5) @(posedge clk);  // Let FSMs settle

// Now ready for operation
```

---

## Integration Checklist

- [ ] Connect clk, rst_n
- [ ] Connect PHY RX signals (rx_en, rx_data, rx_data_valid)
- [ ] Connect PHY TX signals (tx_en, tx_data, tx_data_valid)
- [ ] Connect RX app outputs (dest_mac, src_mac, eth_type, frame_valid, rx_done)
- [ ] Connect TX app inputs (app_tx_data*, app_tx_dest_mac, app_tx_src_mac, app_tx_eth_type)
- [ ] Monitor tx_done for TX completion
- [ ] (Optional) Connect debug signals for monitoring

---

## File References

| Document | Contents |
|----------|----------|
| **README.md** | This folder overview |
| **MAC_CONTROLLER_DESIGN.md** | Full architecture documentation |
| **SIGNAL_CONNECTIONS.md** | Detailed signal flows & timing |
| **TESTING_GUIDE.md** | Test cases & debug strategies |
| **src/mac_controller.v** | Implementation source code |

---

## Module Dependencies

```
mac_controller (Top Level)
├── fifo_rx.v
│   └── Circular buffer (8×8-bit)
├── frame_reception.v
│   └── FSM parser for RX
├── crc_generator.v (RX instance)
│   └── CRC-32 validator
├── fifo_tx.v
│   └── Circular buffer (16×8-bit)
├── frame_transmission.v
│   └── FSM builder for TX
└── crc_generator.v (TX instance)
    └── CRC-32 calculator
```

---

**Quick Ref Version:** 1.0 | Last Updated: Dec 24, 2024

