# Ethernet MAC Controller - Top-Level Design

## Overview
The `mac_controller` is the top-level integration module that manages both RX (receive) and TX (transmit) paths for Ethernet frame handling. It acts as an interface between:
- **PHY Layer** (below) - Raw Ethernet frames
- **Application Layer** (above) - Payload data and MAC/Ethernet parameters

---

## Architecture

### Block Diagram
```
┌─────────────────────────────────────────────────────────────────┐
│                      MAC CONTROLLER                              │
│                                                                   │
│  ┌─────────────────── RX PATH ────────────────────┐            │
│  │                                                  │            │
│  │  PHY Raw Data → FIFO_RX → Frame_Reception     │            │
│  │                                ↓                │            │
│  │                          CRC Validation        │            │
│  │                                ↓                │            │
│  │                     Parsed MAC Headers          │            │
│  │                  (dest_mac, src_mac, type)     │            │
│  │                          ↓                      │            │
│  │                    To Application Layer         │            │
│  └──────────────────────────────────────────────────┘            │
│                                                                   │
│  ┌─────────────────── TX PATH ────────────────────┐            │
│  │                                                  │            │
│  │  Application Data → FIFO_TX → Frame_Transmission            │
│  │  (with MAC headers)        ↓                    │            │
│  │                        CRC Generation           │            │
│  │                             ↓                   │            │
│  │                      Complete Frame             │            │
│  │                             ↓                   │            │
│  │                      To PHY Layer                │            │
│  └──────────────────────────────────────────────────┘            │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## RX Path (Reception)

### Data Flow: PHY → Application

1. **Input:** Raw Ethernet frame bytes from PHY layer
   - `rx_en`: Frame reception enable
   - `rx_data[7:0]`: Incoming byte
   - `rx_data_valid`: Valid byte indicator

2. **FIFO_RX:** Buffers incoming PHY data
   - Absorbs PHY timing variations
   - 8-byte depth allows buffering bursts
   - Provides synchronized data to frame_reception

3. **Frame Reception:** Parses Ethernet frame structure
   - Extracts: Preamble (7×0xAA) → SFD (0xAB) → Destination MAC (6B) → Source MAC (6B) → Ethernet Type (2B) → Payload
   - Passes each byte to CRC validator
   - Outputs parsed headers

4. **CRC Generator (RX):** Validates frame integrity
   - Accumulates CRC over all frame bytes
   - Compares received CRC with calculated value
   - Asserts `frame_valid` if CRC matches

5. **Output to Application:**
   - `dest_mac[47:0]`: Destination MAC address
   - `src_mac[47:0]`: Source MAC address
   - `eth_type[15:0]`: Ethernet type/length
   - `frame_valid`: Frame passed CRC validation
   - `rx_done`: Reception completed

### Key Signals
| Signal | Width | Source | Destination | Purpose |
|--------|-------|--------|-------------|---------|
| `rx_en` | 1 | PHY | FIFO_RX, Frame_RX | Enable frame reception |
| `rx_data` | 8 | PHY | FIFO_RX | Raw byte input |
| `rx_data_valid` | 1 | PHY | FIFO_RX | Byte validity |
| `rx_frame_data_valid` | 1 | FIFO_RX | Frame_RX, CRC_RX | FIFO has data |
| `dest_mac` | 48 | Frame_RX | App | Destination MAC |
| `src_mac` | 48 | Frame_RX | App | Source MAC |
| `frame_valid` | 1 | Frame_RX | App | CRC validated |

---

## TX Path (Transmission)

### Data Flow: Application → PHY

1. **Input from Application:**
   - `app_tx_data[7:0]`: Payload bytes
   - `app_tx_data_valid`: Valid payload byte
   - `app_tx_start`: Initiate transmission
   - `app_tx_dest_mac[47:0]`: Destination MAC
   - `app_tx_src_mac[47:0]`: Source MAC
   - `app_tx_eth_type[15:0]`: Ethernet type

2. **FIFO_TX:** Buffers application payload data
   - Decouples application timing from transmission
   - 16-byte depth provides buffering
   - Filled while `app_tx_data_valid` is asserted
   - Read enable gated by `frame_tx_state == PAYLOAD`

3. **Frame Transmission:** Constructs complete Ethernet frame
   - **IDLE:** Wait for `start` signal
   - **PREAMBLE:** Output 7 bytes of 0xAA
   - **SFD:** Output 0xAB (Start Frame Delimiter)
   - **DEST_ADDR:** Output destination MAC from application input
   - **SRC_ADDR:** Output source MAC from application input
   - **ETH_TYPE:** Output Ethernet type from application input
   - **PAYLOAD:** Read data from FIFO_TX, output bytes sequentially
   - **FINALIZE_CRC:** Finalize CRC computation
   - **CRC:** Output 4 CRC bytes
   - **DONE:** Assert `tx_done`, return to IDLE

4. **CRC Generator (TX):** Calculates frame checksum
   - Enabled during frame construction (`crc_en = app_tx_start`)
   - Accumulates CRC from payload data read from FIFO
   - Disabled when payload complete
   - CRC appended at end of frame

5. **Output to PHY:**
   - `tx_data[7:0]`: Byte to transmit
   - `tx_en`: Transmission enable (byte valid)
   - `tx_data_valid`: Valid byte indicator
   - `tx_done`: Frame transmission complete

### TX State Machine
```
IDLE → PREAMBLE → SFD → DEST_ADDR → SRC_ADDR → ETH_TYPE → PAYLOAD → FINALIZE_CRC → CRC → DONE → IDLE
 ↑                                                                                           │
 └───────────────────────────────────────────────────────────────────────────────────────────┘
```

### Key Control Signals
| Signal | Width | Logic | Purpose |
|--------|-------|-------|---------|
| `tx_fifo_wr_en` | 1 | `app_tx_data_valid & ~tx_fifo_full` | Write payload to FIFO |
| `tx_fifo_rd_en` | 1 | `(frame_tx_state == PAYLOAD) & ~tx_fifo_empty` | Read from FIFO during payload state |
| `frame_tx_state` | 4 | Output from frame_transmission | Current transmission state |
| `crc_tx_done` | 1 | Output from crc_generator | CRC calculation complete |

---

## Detailed Signal Description

### Inputs
| Name | Width | Direction | Description |
|------|-------|-----------|-------------|
| `clk` | 1 | Input | System clock |
| `rst_n` | 1 | Input | Active-low asynchronous reset |
| **RX Physical Interface** | | | |
| `rx_en` | 1 | Input | PHY frame reception active |
| `rx_data` | 8 | Input | Incoming byte from PHY |
| `rx_data_valid` | 1 | Input | PHY byte valid indicator |
| **TX Application Interface** | | | |
| `app_tx_data` | 8 | Input | Payload byte from application |
| `app_tx_data_valid` | 1 | Input | Payload byte valid |
| `app_tx_start` | 1 | Input | Initiate frame transmission |
| `app_tx_dest_mac` | 48 | Input | Destination MAC address |
| `app_tx_src_mac` | 48 | Input | Source MAC address |
| `app_tx_eth_type` | 16 | Input | Ethernet type/length field |

### Outputs
| Name | Width | Direction | Description |
|------|-------|-----------|-------------|
| **RX Application Interface** | | | |
| `dest_mac` | 48 | Output | Received destination MAC |
| `src_mac` | 48 | Output | Received source MAC |
| `eth_type` | 16 | Output | Received Ethernet type |
| `frame_valid` | 1 | Output | Frame passed CRC check |
| `rx_done` | 1 | Output | Frame reception complete |
| **TX Physical Interface** | | | |
| `tx_en` | 1 | Output | PHY transmission active |
| `tx_data` | 8 | Output | Byte to transmit to PHY |
| `tx_data_valid` | 1 | Output | Transmitted byte valid |
| `tx_done` | 1 | Output | Frame transmission complete |
| **Debug Outputs** | | | |
| `tx_state` | 4 | Output | Current TX frame state |
| `tx_fifo_full` | 1 | Output | TX FIFO full flag |
| `tx_fifo_empty` | 1 | Output | TX FIFO empty flag |
| `rx_fifo_full` | 1 | Output | RX FIFO full flag |
| `rx_fifo_empty` | 1 | Output | RX FIFO empty flag |

---

## Internal Module Integration

### RX Path Modules
1. **fifo_rx** (8-byte circular FIFO)
   - Buffers raw PHY data
   - Synchronizes PHY and MAC timing domains

2. **frame_reception** (FSM-based parser)
   - Parses Ethernet frame headers
   - Extracts MAC addresses and type
   - Passes to CRC validator

3. **crc_generator** (RX instance)
   - Validates frame checksum
   - Produces `frame_valid` status

### TX Path Modules
1. **fifo_tx** (16-byte circular FIFO)
   - Buffers application payload
   - Decouples application and transmission timing

2. **frame_transmission** (FSM-based constructor)
   - Builds complete frame structure
   - Manages header insertion
   - Controls CRC finalization

3. **crc_generator** (TX instance)
   - Calculates payload checksum
   - CRC appended to frame

---

## Data Flow Examples

### Example 1: Receiving a Frame
```
1. PHY provides rx_en=1, rx_data=0xAA (preamble byte)
2. MAC_CONTROLLER writes to FIFO_RX
3. FIFO_RX outputs byte to frame_reception
4. frame_reception checks preamble byte
5. frame_reception passes byte to crc_generator for CRC accumulation
6. After frame, crc_generator compares received CRC with calculated
7. frame_valid asserted if match
8. Application reads: dest_mac, src_mac, eth_type, frame_valid
```

### Example 2: Transmitting a Frame
```
1. Application sets:
   - app_tx_dest_mac = 48'hFFFFFFFFFFFF (broadcast)
   - app_tx_src_mac = 48'hAABBCCDDEEFF
   - app_tx_eth_type = 16'h0800 (IPv4)
   - Provides payload via app_tx_data[7:0]

2. Application asserts app_tx_start=1
3. frame_transmission enters PREAMBLE state
4. frame_transmission outputs preamble bytes (0xAA)
5. frame_transmission transitions through SFD, addresses, type
6. frame_transmission enters PAYLOAD state
7. MAC_CONTROLLER reads from FIFO_TX (tx_fifo_rd_en asserted)
8. frame_transmission outputs payload bytes
9. crc_generator accumulates CRC
10. frame_transmission enters CRC state, outputs 4 CRC bytes
11. frame_transmission asserts tx_done
12. Frame complete on PHY interface
```

---

## Key Design Features

### 1. **Buffering & Decoupling**
   - FIFOs decouple timing domains between application, MAC, and PHY
   - Allows asynchronous operation

### 2. **State Management**
   - Frame_transmission state machine controls TX sequencing
   - Frame_reception state machine controls RX parsing
   - MAC_Controller gates FIFO reads based on transmission state

### 3. **CRC Integration**
   - Separate CRC instances for RX (validation) and TX (generation)
   - CRC enabled/disabled based on frame boundaries

### 4. **Debug Visibility**
   - Output FIFO flags for monitoring occupancy
   - Output TX state for timing verification
   - Easy to add protocol analyzer connections

### 5. **Robustness**
   - Simultaneous RX and TX operation possible (full-duplex)
   - FIFO full/empty flags prevent data loss
   - Active-low asynchronous reset for safe power-on

---

## Timing Considerations

### RX Path Timing
- PHY provides data at PHY clock rate
- FIFO_RX absorbs jitter up to 8 bytes
- Frame_reception processes one byte per cycle
- CRC calculation synchronized with frame reception

### TX Path Timing
- Application loads FIFO_TX at application clock rate
- frame_transmission reads FIFO at MAC clock rate
- CRC accumulates as payload is transmitted
- tx_done asserted after CRC bytes sent

---

## Example Instantiation

```verilog
mac_controller mac_inst (
    .clk                (sys_clk),
    .rst_n              (sys_rst_n),
    
    // RX from PHY
    .rx_en              (phy_rx_en),
    .rx_data            (phy_rx_data),
    .rx_data_valid      (phy_rx_valid),
    
    // TX to PHY
    .tx_en              (phy_tx_en),
    .tx_data            (phy_tx_data),
    .tx_data_valid      (phy_tx_valid),
    
    // RX outputs to application
    .dest_mac           (app_dest_mac),
    .src_mac            (app_src_mac),
    .eth_type           (app_eth_type),
    .frame_valid        (app_frame_valid),
    .rx_done            (app_rx_done),
    
    // TX inputs from application
    .app_tx_data        (app_payload_data),
    .app_tx_data_valid  (app_payload_valid),
    .app_tx_start       (app_tx_start),
    .app_tx_dest_mac    (app_dest_mac_tx),
    .app_tx_src_mac     (app_src_mac_tx),
    .app_tx_eth_type    (app_eth_type_tx),
    .tx_done            (app_tx_done),
    
    // Debug outputs
    .tx_state           (debug_tx_state),
    .tx_fifo_full       (debug_tx_fifo_full),
    .tx_fifo_empty      (debug_tx_fifo_empty),
    .rx_fifo_full       (debug_rx_fifo_full),
    .rx_fifo_empty      (debug_rx_fifo_empty)
);
```

---

## Testing Strategy

1. **RX Path Testing:**
   - Inject known frame with valid/invalid CRC
   - Verify header extraction
   - Verify frame_valid assertion

2. **TX Path Testing:**
   - Load FIFO with payload
   - Verify frame construction
   - Verify CRC calculation
   - Verify tx_done timing

3. **Integration Testing:**
   - Simultaneous RX and TX
   - Back-to-back frames
   - FIFO overflow/underflow scenarios

---

## Future Enhancements

1. **Multiple Frame Support:**
   - Larger FIFOs for multiple frame buffering
   - Frame-level synchronization signals

2. **Error Handling:**
   - Overflow/underflow detection
   - Frame error signals

3. **Performance Optimization:**
   - Parallel CRC computation
   - Pipelined header processing

4. **Configuration:**
   - Programmable MAC addresses
   - Configurable frame types
