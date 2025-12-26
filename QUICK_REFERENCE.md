# MAC Controller - Quick Reference Card

## At a Glance

```
┌─────────────────────────────────────────────────┐
│     Ethernet MAC Controller (Top Level)         │
│                                                   │
│  Single Clock Domain | Full Duplex | CRC Ready  │
│                                                   │
│  24 Signals | 128 bits | ~2-5K gates            │
└─────────────────────────────────────────────────┘
```

## RX Path (4 stages)
```
PHY Data
   ↓
FIFO_RX (buffer 8B)
   ↓
Frame_Reception (parse headers)
   ↓
CRC_Generator (validate)
   ↓
Application (dest_mac, src_mac, eth_type, frame_valid)
```

## TX Path (4 stages)
```
Application (payload + MAC headers)
   ↓
FIFO_TX (buffer 16B)
   ↓
Frame_Transmission (construct frame)
   ↓
CRC_Generator (compute checksum)
   ↓
PHY (complete Ethernet frame)
```

---

## Port Quick Reference

### Clock & Reset (2 signals)
| Port | Direction | Width | Purpose |
|------|-----------|-------|---------|
| `clk` | Input | 1 | System clock |
| `rst_n` | Input | 1 | Active-low reset |

### PHY RX Interface (3 signals) → MAC
| Port | Direction | Width | Purpose |
|------|-----------|-------|---------|
| `rx_en` | Input | 1 | Frame reception enable |
| `rx_data` | Input | 8 | Incoming byte |
| `rx_data_valid` | Input | 1 | Byte is valid |

### MAC RX Outputs (5 signals) → Application
| Port | Direction | Width | Purpose |
|------|-----------|-------|---------|
| `dest_mac` | Output | 48 | Destination MAC address |
| `src_mac` | Output | 48 | Source MAC address |
| `eth_type` | Output | 16 | Ethernet type/length |
| `frame_valid` | Output | 1 | CRC validation passed |
| `rx_done` | Output | 1 | Frame reception complete |

### MAC TX Inputs (6 signals) ← Application
| Port | Direction | Width | Purpose |
|------|-----------|-------|---------|
| `app_tx_data` | Input | 8 | Payload byte |
| `app_tx_data_valid` | Input | 1 | Byte is valid |
| `app_tx_start` | Input | 1 | Initiate transmission |
| `app_tx_dest_mac` | Input | 48 | Destination MAC |
| `app_tx_src_mac` | Input | 48 | Source MAC |
| `app_tx_eth_type` | Input | 16 | Ethernet type |

### PHY TX Interface (3 signals) MAC →
| Port | Direction | Width | Purpose |
|------|-----------|-------|---------|
| `tx_en` | Output | 1 | Transmission enable |
| `tx_data` | Output | 8 | Outgoing byte |
| `tx_data_valid` | Output | 1 | Byte is valid |

### Completion Flags (1 signal)
| Port | Direction | Width | Purpose |
|------|-----------|-------|---------|
| `tx_done` | Output | 1 | Transmission complete |

### Debug Outputs (5 signals - optional)
| Port | Direction | Width | Purpose |
|------|-----------|-------|---------|
| `tx_state` | Output | 4 | TX FSM state |
| `tx_fifo_full` | Output | 1 | TX buffer full |
| `tx_fifo_empty` | Output | 1 | TX buffer empty |
| `rx_fifo_full` | Output | 1 | RX buffer full |
| `rx_fifo_empty` | Output | 1 | RX buffer empty |

---

## Signal Meanings

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

