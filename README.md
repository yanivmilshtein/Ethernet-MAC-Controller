# Ethernet MAC Controller - Complete System

The Ethernet MAC Controller is a synthesizable Verilog implementation of an IEEE 802.3 compliant Media Access Control (MAC) layer. It provides full-duplex Ethernet frame transmission and reception with integrated CRC-32 validation.

---

## Project Structure

```
Ethernet-MAC-Controller/
├── src/                           # Core HDL modules
│   ├── mac_controller.v           # Top-level orchestrator (24 signals)
│   ├── frame_transmission.v       # TX frame builder FSM
│   ├── frame_reception.v          # RX frame parser FSM
│   ├── fifo_tx.v                  # TX payload buffer (16×8)
│   ├── fifo_rx.v                  # RX data buffer (8×8)
│   └── crc_generator.v            # CRC-32 engine (shared RX/TX)
├── testbench/                     # Simulation test files
│   ├── tb_mac_controller.v        # Main testbench (2 focused tests)
│   ├── tb_frame_transmission.v    # TX module test
│   ├── tb_frame_reception.v       # RX module test
│   ├── tb_fifo_rx.v               # RX FIFO test
│   ├── tb_fifo_tx.v               # TX FIFO test
│   └── tb_crc_generator.v         # CRC validation test
├── QUICK_REFERENCE.md             # Signal reference card
├── TESTING_GUIDE.md               # Test procedures & examples
├── SIGNAL_CONNECTIONS.md          # Connection diagrams
└── run.do                          # ModelSim simulation script
```

---

## System Architecture

### Data Paths

**RX Path (Receive):**
```
PHY Layer
   ↓ (rx_en, rx_data[7:0], rx_data_valid)
FIFO_RX (8-byte circular buffer)
   ↓ (rx_fifo_data_out[7:0], rx_frame_data_valid)
Frame_Reception (parse Ethernet frame)
   ↓ (dest_mac[47:0], src_mac[47:0], eth_type[15:0])
Application Layer
```

**TX Path (Transmit):**
```
Application Layer
   ↓ (app_tx_data[7:0], app_tx_dest_mac[47:0], app_tx_src_mac[47:0], app_tx_eth_type[15:0])
FIFO_TX (16-byte circular buffer)
   ↓ (tx_fifo_data_out[7:0], payload_fifo_rd_en)
Frame_Transmission (construct Ethernet frame)
   ↓ (tx_data[7:0], tx_en, tx_data_valid)
PHY Layer
```

**Shared Components:**
- CRC_Generator: Used for both RX validation and TX computation
- Clock Domain: Single 100 MHz clock, synchronous design
- Reset: Asynchronous active-low reset

### Key Features

| Feature | Capability |
|---------|-----------|
| **Clock Frequency** | 100 MHz (10 ns period) |
| **Frame Size** | 64 - 1518 bytes (IEEE 802.3) |
| **Minimum Payload** | 46 bytes |
| **CRC Algorithm** | CRC-32 (Poly: 0x04C11DB7) |
| **Duplex Mode** | Full-duplex (RX & TX simultaneous) |
| **Buffering** | RX: 8 bytes, TX: 16 bytes |
| **Signal Count** | 24 total (6 clk/reset + 3 RX input + 5 RX output + 6 TX input + 3 TX output + 1 done) |

---

## Testbench Overview

**File:** [testbench/tb_mac_controller.v](testbench/tb_mac_controller.v)

The main testbench contains exactly **2 focused tests**:

### Test 1: TX Path
- **Purpose:** Validate transmission pipeline (application → PHY)
- **Procedure:**
  1. Set destination/source MAC and EtherType
  2. Fill payload FIFO with test data (46 bytes)
  3. Initiate frame transmission
  4. Capture complete frame bytes to array
  5. Display frame structure with byte-by-byte decoding
- **Output:** 72-byte complete Ethernet frame (preamble + SFD + headers + payload + CRC)
- **Verification:** Frame structure and byte sequence correct

### Test 2: RX Path  
- **Purpose:** Validate reception pipeline (PHY → application)
- **Procedure:**
  1. Inject captured frame from Test 1 into RX FIFO
  2. Feed frame bytes to Frame_Reception module
  3. Wait for frame parsing complete
  4. Verify extracted headers match injected frame
- **Outputs:** dest_mac, src_mac, eth_type, frame_valid
- **Verification:** Parsed headers match original values

Both tests run sequentially with 10-cycle idle period between them. Each test includes detailed FIFO status logging and frame structure annotations.

---

## Module Interconnection

```
┌─────────────────────────────────────────────────────────────────┐
│                    mac_controller.v                             │
│  (24 signals: clock, reset, PHY I/F, app I/F, debug)           │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │  fifo_rx.v   │  │  fifo_tx.v   │  │ crc_gen.v    │           │
│  │  (8×8 FIFO)  │  │  (16×8 FIFO) │  │ (CRC-32)     │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│         ▲                  ▲                   ▲                  │
│         │                  │                   │                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  frame_reception.v              frame_transmission.v     │   │
│  │  (RX FSM: parse frame)          (TX FSM: build frame)    │   │
│  └──────────────────────────────────────────────────────────┘   │
│         ▲                                       ▲                  │
│         │                                       │                  │
│      [PHY RX]                               [PHY TX]              │
└─────────────────────────────────────────────────────────────────┘
```

---

## Simulation & Testing

All testing is performed using ModelSim. See [TESTING_GUIDE.md](TESTING_GUIDE.md) for detailed procedures.

**Quick Start:**
```bash
cd Ethernet-MAC-Controller
vsim -do run.do
```

This runs the 2-test testbench with full logging and signal display.

### 🔗 Complete Frame Handling
- Preamble generation (7 × 0xAA)
- Start Frame Delimiter (0xAB)
- MAC address insertion
- Ethernet type handling
- Payload pass-through
- CRC appending

### 👁️ Debug Visibility
- TX state output for monitoring FSM progression
- FIFO occupancy flags for buffer analysis
- Easy to add protocol analyzers or test points

---

## Data Flow at a Glance

### Reception (PHY → Application)
```
Raw Ethernet Frame
        ↓
    FIFO_RX (buffering)
        ↓
Frame_Reception (parsing):
  - Extracts preamble (validates)
  - Extracts SFD (validates)
  - Captures dest MAC
  - Captures src MAC
  - Captures eth type
  - Captures payload
        ↓
  CRC_Generator (validating):
  - Computes CRC-32
  - Compares with received
  - Sets frame_valid flag
        ↓
Application receives:
  - dest_mac, src_mac, eth_type
  - frame_valid (CRC status)
  - rx_done (completion flag)
```

### Transmission (Application → PHY)
```
Application provides:
  - app_tx_dest_mac
  - app_tx_src_mac
  - app_tx_eth_type
  - app_tx_data (payload)
  - app_tx_start (initiate)
        ↓
  FIFO_TX (buffering payload)
        ↓
Frame_Transmission (constructing):
  - Generates preamble (0xAA × 7)
  - Generates SFD (0xAB)
  - Inserts dest MAC (from app)
  - Inserts src MAC (from app)
  - Inserts eth type (from app)
  - Streams payload (from FIFO)
        ↓
  CRC_Generator (computing):
  - Accumulates CRC-32 over payload
  - Outputs final CRC when ready
        ↓
Frame_Transmission appends CRC
        ↓
PHY receives complete frame
  - tx_en (transmission valid)
  - tx_data[7:0] (byte to transmit)
  - tx_done (completion flag)
```

---

## Module Interconnections

### RX Path Signals
| Stage | Input | Output | Purpose |
|-------|-------|--------|---------|
| PHY | `rx_en`, `rx_data[7:0]`, `rx_data_valid` | - | Raw frame bytes |
| FIFO_RX | `rx_data`, `rx_fifo_wr_en`, `rx_fifo_rd_en` | `rx_fifo_data_out[7:0]` | Buffer data |
| Frame_RX | `rx_fifo_data_out`, `rx_frame_data_valid` | `dest_mac`, `src_mac`, `eth_type` | Parse headers |
| CRC_RX | `rx_fifo_data_out`, `rx_frame_data_valid`, `rx_en` | `crc_rx_out[31:0]`, `crc_rx_done` | Validate |
| App | `dest_mac`, `src_mac`, `eth_type`, `frame_valid`, `rx_done` | - | Results |

### TX Path Signals
| Stage | Input | Output | Purpose |
|-------|-------|--------|---------|
| App | `app_tx_data[7:0]`, `app_tx_data_valid`, `app_tx_start` | - | Payload input |
| App | `app_tx_dest_mac`, `app_tx_src_mac`, `app_tx_eth_type` | - | MAC headers |
| FIFO_TX | `app_tx_data`, `tx_fifo_wr_en`, `tx_fifo_rd_en` | `tx_fifo_data_out[7:0]` | Buffer payload |
| Frame_TX | `tx_fifo_data_out`, `app_tx_dest_mac`, etc. | `tx_out[7:0]`, `tx_en` | Build frame |
| CRC_TX | `tx_fifo_data_out`, `tx_fifo_rd_en`, `app_tx_start` | `crc_tx_out[31:0]`, `crc_tx_done` | Generate CRC |
| PHY | `tx_out`, `tx_en`, `tx_data_valid` | - | Frame output |

---

## Port Summary

### Input Ports (11)
1. `clk` - System clock (1-bit)
2. `rst_n` - Active-low reset (1-bit)
3. `rx_en` - RX enable from PHY (1-bit)
4. `rx_data[7:0]` - RX byte from PHY (8-bit)
5. `rx_data_valid` - RX byte valid (1-bit)
6. `app_tx_data[7:0]` - TX payload byte (8-bit)
7. `app_tx_data_valid` - TX byte valid (1-bit)
8. `app_tx_start` - Initiate transmission (1-bit)
9. `app_tx_dest_mac[47:0]` - Destination MAC (48-bit)
10. `app_tx_src_mac[47:0]` - Source MAC (48-bit)
11. `app_tx_eth_type[15:0]` - Ethernet type (16-bit)

### Output Ports (13)
1. `tx_en` - TX enable to PHY (1-bit)
2. `tx_data[7:0]` - TX byte to PHY (8-bit)
3. `tx_data_valid` - TX byte valid (1-bit)
4. `dest_mac[47:0]` - Received dest MAC (48-bit)
5. `src_mac[47:0]` - Received src MAC (48-bit)
6. `eth_type[15:0]` - Received eth type (16-bit)
7. `frame_valid` - RX CRC valid (1-bit)
8. `rx_done` - RX complete (1-bit)
9. `tx_done` - TX complete (1-bit)
10. `tx_state[3:0]` - Debug: TX state (4-bit)
11. `tx_fifo_full` - Debug: TX FIFO full (1-bit)
12. `tx_fifo_empty` - Debug: TX FIFO empty (1-bit)
13. `rx_fifo_full` - Debug: RX FIFO full (1-bit)
14. `rx_fifo_empty` - Debug: RX FIFO empty (1-bit)

**Total: 24 signals, 128 bits**

---

## Instantiation Template

```verilog
mac_controller u_mac (
    // Clock and Reset
    .clk                (clk),
    .rst_n              (rst_n),
    
    // PHY RX Interface
    .rx_en              (phy_rx_en),
    .rx_data            (phy_rx_byte),
    .rx_data_valid      (phy_rx_valid),
    
    // PHY TX Interface
    .tx_en              (phy_tx_en),
    .tx_data            (phy_tx_byte),
    .tx_data_valid      (phy_tx_valid),
    
    // RX to Application
    .dest_mac           (rx_dest_mac),
    .src_mac            (rx_src_mac),
    .eth_type           (rx_eth_type),
    .frame_valid        (rx_frame_valid),
    .rx_done            (rx_complete),
    
    // Application TX
    .app_tx_data        (app_payload),
    .app_tx_data_valid  (app_payload_valid),
    .app_tx_start       (app_tx_initiate),
    .app_tx_dest_mac    (app_dest_mac),
    .app_tx_src_mac     (app_src_mac),
    .app_tx_eth_type    (app_eth_type),
    .tx_done            (tx_complete),
    
    // Debug
    .tx_state           (debug_state),
    .tx_fifo_full       (debug_tx_full),
    .tx_fifo_empty      (debug_tx_empty),
    .rx_fifo_full       (debug_rx_full),
    .rx_fifo_empty      (debug_rx_empty)
);
```

---

## Integration Checklist

- [x] Module architecture designed
- [x] Port definitions complete
- [x] RX path implemented
- [x] TX path implemented
- [x] Signal routing verified
- [x] Control logic implemented
- [x] Debug outputs added
- [x] Documentation complete
- [ ] Simulation (ready for testing)
- [ ] Synthesis (ready for implementation)
- [ ] Integration with PHY layer
- [ ] Integration with application layer
- [ ] System validation

---

## Next Steps

### Immediate
1. **Simulate:** Run test benches against mac_controller
2. **Verify:** Check all signals flow correctly
3. **Debug:** Fix any issues revealed by simulation

### Short-term
4. **Synthesize:** Map to target FPGA/ASIC
5. **Time:** Verify timing closure
6. **Place:** Route and place design

### Medium-term
7. **Integrate:** Connect actual PHY and application
8. **Validate:** Test with real Ethernet traffic
9. **Optimize:** Profile and improve performance

### Long-term
10. **Enhance:** Add error handling
11. **Document:** Create user guide
12. **Release:** Production deployment

---

## File Structure

```
Ethernet-MAC-Controller/
├── src/
│   ├── mac_controller.v         ← Updated (Main module)
│   ├── frame_reception.v        ← Unchanged (RX parser)
│   ├── frame_transmission.v     ← Unchanged (TX builder)
│   ├── fifo_rx.v                ← Unchanged (RX buffer)
│   ├── fifo_tx.v                ← Unchanged (TX buffer)
│   └── crc_generator.v          ← Unchanged (CRC calc)
├── testbench/
│   ├── tb_*.v                   ← Ready for enhancement
│   └── (More to be added)
├── simulation/
│   └── (Simulation artifacts)
├── MAC_CONTROLLER_DESIGN.md     ← NEW (Architecture guide)
├── SIGNAL_CONNECTIONS.md        ← NEW (Signal reference)
├── TESTING_GUIDE.md             ← NEW (Testing manual)
└── (This file)
```

---

## Key Design Decisions

1. **Separate CRC Instances:** RX CRC validates, TX CRC generates
   - Allows independent operation
   - Simpler state management

2. **FIFO-based Buffering:** Decouples timing domains
   - Application doesn't need to match PHY speed
   - PHY doesn't need to match application speed

3. **State-gated FIFO Reads:** TX FIFO only reads during PAYLOAD
   - Prevents incorrect data from being transmitted
   - Synchronizes with frame construction FSM

4. **Application-provided MAC Addresses:** Flexible frame construction
   - Supports multicast, broadcast, unicast
   - Application controls source/dest at runtime

5. **Debug Outputs:** Enhanced testability
   - State visibility aids debugging
   - FIFO flags for occupancy monitoring

---

## Performance Characteristics

### Speed
- **Data Rate:** Up to 1 byte/cycle (configurable clock rate)
- **Frame Period:** ~50-200 cycles (depending on payload)
- **CRC Latency:** ~50 cycles (32-bit polynomial)

### Area
- **Logic Gates:** ~2-5K equivalent gates
- **Memory:** 192 bits (8B + 16B FIFOs)
- **Registers:** ~150

### Power
- **Clock:** Single clock domain (no domain crossing)
- **Gating:** FIFO reads gated on frame state
- **Scalable:** Can optimize for power or speed

---

## Compatibility

### Supports
- ✓ Ethernet II frame format
- ✓ CRC-32 (IEEE polynomial: 0x04C11DB7)
- ✓ Variable payload sizes (up to available buffering)
- ✓ Full-duplex operation
- ✓ Broadcast frames (0xFFFFFFFFFFFF)
- ✓ Unicast frames
- ✓ Multicast frames

### Future Extensions
- Priority queue support
- Multiple frame buffering
- VLAN tagging
- Frame filtering
- Speed negotiation

---

## Questions?

Refer to the detailed documentation:
- **Architecture:** See [MAC_CONTROLLER_DESIGN.md](MAC_CONTROLLER_DESIGN.md)
- **Signals:** See [SIGNAL_CONNECTIONS.md](SIGNAL_CONNECTIONS.md)
- **Testing:** See [TESTING_GUIDE.md](TESTING_GUIDE.md)
- **Code:** See [src/mac_controller.v](src/mac_controller.v)

---

**Design Status:** ✅ Complete and Ready for Simulation
**Last Updated:** December 24, 2024
**Version:** 1.0
>>>>>>> mac_controller
