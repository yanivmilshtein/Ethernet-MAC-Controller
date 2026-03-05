# MAC Controller - Testing Guide

## Quick Start

Run the 2-test focused testbench in ModelSim:

```bash
cd Ethernet-MAC-Controller
vsim -do run.do
```

**Expected Output:** Two sequential tests (TX then RX) with detailed FIFO status and frame structure logging.

---

## Testbench Architecture

**File:** `testbench/tb_mac_controller.v`

The testbench contains exactly **2 focused tests**:

```
┌──────────────────────────────────────────────────────────────┐
│                     Main Test Sequence                        │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  TEST 1: TX PATH (Frame Transmission)                        │
│  ├─ Fill payload FIFO with 46 bytes                         │
│  ├─ Initiate frame transmission                              │
│  ├─ Capture frame output byte-by-byte                        │
│  └─ Display frame structure with annotations                │
│                                                               │
│  [IDLE: 10 cycles]                                           │
│                                                               │
│  TEST 2: RX PATH (Frame Reception)                           │
│  ├─ Inject captured frame from Test 1                        │
│  ├─ Feed bytes into RX FIFO                                  │
│  ├─ Wait for Frame_Reception parsing                         │
│  └─ Verify extracted headers match original                 │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

---

## Test 1: TX Path (Frame Transmission)

### Purpose
Validate that the MAC controller correctly transmits an Ethernet frame from application layer to PHY layer.

### Test Sequence

**Step 1: Setup Frame Parameters**
```verilog
app_tx_dest_mac  = 48'h001122334455;   // Destination: 00:11:22:33:44:55
app_tx_src_mac   = 48'hAABBCCDDEEFF;   // Source:      AA:BB:CC:DD:EE:FF
app_tx_eth_type  = 16'h0800;           // EtherType:   IPv4
```

**Step 2: Fill Payload FIFO**
```verilog
for (i = 0; i < 46; i = i + 1) begin   // Minimum payload: 46 bytes
    @(posedge clk);
    app_tx_data = i + 8'h41;            // Pattern: 0x41, 0x42, 0x43, ...
    app_tx_data_valid = 1'b1;           // Mark byte as valid
end
app_tx_data_valid = 1'b0;               // Done writing
```

FIFO status displayed after every 10 bytes:
```
[10-19] bytes written, FIFO Full: 0, Empty: 0
[20-29] bytes written, FIFO Full: 0, Empty: 0
[30-39] bytes written, FIFO Full: 0, Empty: 0
[40-45] bytes written, FIFO Full: 0, Empty: 0
```

**Step 3: Initiate Transmission**
```verilog
wait_cycles(5);                          // Wait 5 clock cycles
app_tx_start = 1'b1;
@(posedge clk);
app_tx_start = 1'b0;                     // Pulse the start signal
```

**Step 4: Capture Frame Output**
Frame is transmitted byte-by-byte with structure annotations:

```
  [Byte] [Value] [ASCII] [Frame Structure]
  ─────────────────────────────────────────
  [  0] 0xAA  '«'    [Preamble byte 0]
  [  1] 0xAA  '«'    [Preamble byte 1]
  [  2] 0xAA  '«'    [Preamble byte 2]
  [  3] 0xAA  '«'    [Preamble byte 3]
  [  4] 0xAA  '«'    [Preamble byte 4]
  [  5] 0xAA  '«'    [Preamble byte 5]
  [  6] 0xAA  '«'    [Preamble byte 6]
  [  7] 0xAB  '«'    [SFD (Start Frame Delimiter)]
  [  8] 0x00        [Destination MAC byte 0]
  [  9] 0x11        [Destination MAC byte 1]
  [ 10] 0x22        [Destination MAC byte 2]
  [ 11] 0x33        [Destination MAC byte 3]
  [ 12] 0x44        [Destination MAC byte 4]
  [ 13] 0x55        [Destination MAC byte 5]
  [ 14] 0xAA        [Source MAC byte 0]
  [ 15] 0xBB        [Source MAC byte 1]
  [ 16] 0xCC        [Source MAC byte 2]
  [ 17] 0xDD        [Source MAC byte 3]
  [ 18] 0xEE        [Source MAC byte 4]
  [ 19] 0xFF        [Source MAC byte 5]
  [ 20] 0x08        [EtherType byte 0]
  [ 21] 0x00        [EtherType byte 1]
  [ 22-67] 0xAA-0xAE [Payload bytes 0-45]
  [ 68-71] 0xXX...  [CRC bytes 0-3]
  ─────────────────────────────────────────
  └─ Total frame size: 72 bytes
```

### Expected Results

✓ Frame starts with 7 bytes of 0xAA preamble
✓ Byte 7 is 0xAB (SFD)
✓ Bytes 8-13 match destination MAC (0x001122334455)
✓ Bytes 14-19 match source MAC (0xAABBCCDDEEFF)
✓ Bytes 20-21 match EtherType (0x0800)
✓ Bytes 22-67 match payload pattern (0x41-0xAE)
✓ Bytes 68-71 are CRC-32 value
✓ Total frame: 72 bytes

---

## Test 2: RX Path (Frame Reception)

### Purpose
Validate that the MAC controller correctly receives and parses an Ethernet frame from PHY layer to application layer.

### Test Sequence

**Step 1: Prepare Frame for Injection**
```verilog
// Use frame captured in Test 1
$display("Frame size: %d bytes", tx_frame_count);
```

**Step 2: Inject Frame into RX FIFO**
```verilog
rx_en = 1'b1;                              // Enable RX

for (i = 0; i < tx_frame_count; i = i + 1) begin
    @(posedge clk);
    rx_data = captured_tx_frame[i];         // Feed captured bytes
    rx_data_valid = 1'b1;                   // Mark as valid
end

@(posedge clk);
rx_data_valid = 1'b0;
rx_en = 1'b0;                               // Done injecting
```

FIFO status displayed for each byte:
```
  [Byte] [Value] [ASCII] [FIFO Status]
  ──────────────────────────────────────
  [  0] 0xAA  '«'    Full: 0, Empty: 0
  [  1] 0xAA  '«'    Full: 0, Empty: 0
  ...
  [ 71] 0xXX  'x'    Full: 0, Empty: 0
  ──────────────────────────────────────
```

**Step 3: Wait for Frame Processing**
```verilog
wait_cycles(300);  // Wait for Frame_Reception to parse entire frame
```

Frame_Reception FSM processes:
- Preamble detection
- SFD detection
- Destination MAC extraction
- Source MAC extraction
- EtherType extraction
- Payload processing
- CRC verification

**Step 4: Display Parsed Frame Information**

```
  ┌─ Destination MAC Address
  │   0x001122334455
  │   Expected: 0x001122334455
  │   Match: ✓ YES
  ├─ Source MAC Address
  │   0xAABBCCDDEEFF
  │   Expected: 0xAABBCCDDEEFF
  │   Match: ✓ YES
  ├─ EtherType/Length
  │   0x0800
  │   Expected: 0x0800
  │   Match: ✓ YES
  ├─ Frame Valid (CRC Check)
  │   1
  └─ RX Done Flag
      1
```

### Expected Results

✓ Destination MAC: 0x001122334455 (matches Test 1)
✓ Source MAC: 0xAABBCCDDEEFF (matches Test 1)
✓ EtherType: 0x0800 (matches Test 1)
✓ Frame Valid: 1 (CRC verification passed)
✓ RX Done: 1 (frame reception complete)

---

## Frame Structure Reference

Ethernet frame format (IEEE 802.3):

```
┌─────────────────────────────────────────────────────────────────┐
│ Preamble │ SFD │ Dest MAC │ Src MAC │ EtherType │ Payload │ CRC │
│ (7 bytes)│(1B) │ (6 bytes)│(6 bytes)│  (2 bytes) │(46-1500)│(4B) │
├─────────────────────────────────────────────────────────────────┤
│ 0x00-0x06│ 0x07│ 0x08-0x0D│0x0E-0x13│  0x14-0x15 │0x16-... │Last │
└─────────────────────────────────────────────────────────────────┘
```

**Frame Details:**
- Preamble: 7 bytes of 0xAA (synchronization)
- SFD: 1 byte of 0xAB (frame delimiter)
- Destination MAC: 6 bytes
- Source MAC: 6 bytes
- EtherType: 2 bytes (0x0800 = IPv4)
- Payload: 46-1500 bytes
- CRC: 4 bytes (CRC-32)
- Minimum total: 64 bytes
- Test frame: 72 bytes (7+1+6+6+2+46+4)

---

## Key Signals During Testing

### TX Path Monitoring
| Signal | Purpose | Expected during TX |
|--------|---------|-------------------|
| `tx_en` | Frame transmission active | 1 for 72 cycles |
| `tx_data[7:0]` | Current frame byte | Frame bytes (0xAA...0xXX) |
| `tx_data_valid` | Byte is valid | 1 during transmission |
| `tx_done` | Transmission complete | 1 at end, 0 otherwise |
| `tx_fifo_empty` | TX FIFO depleted | Transition 0→1 at end |
| `tx_state[3:0]` | TX FSM state | IDLE→PREAMBLE→...→IDLE |

### RX Path Monitoring
| Signal | Purpose | Expected during RX |
|--------|---------|-------------------|
| `rx_en` | Frame reception enabled | 1 during injection |
| `rx_data[7:0]` | Current frame byte | Frame bytes from Test 1 |
| `rx_data_valid` | Byte is valid | 1 during injection |
| `frame_valid` | CRC check passed | 1 after parsing |
| `rx_done` | Reception complete | 1 after 300 cycles |
| `dest_mac[47:0]` | Parsed destination | 0x001122334455 |

---

## Debugging Tips

### If Test 1 Fails (TX Path)
1. Check that `app_tx_data_valid` pulses correctly
2. Verify `tx_en` goes high and stays high for 72 cycles
3. Monitor `tx_state` output to see FSM progression
4. Check FIFO read enable timing
5. Capture frame to waveform and inspect byte sequence

### If Test 2 Fails (RX Path)
1. Verify frame bytes are correctly stored in `captured_tx_frame[]`
2. Check that `rx_data_valid` is asserted for each byte
3. Monitor RX FIFO level during injection
4. Verify Frame_Reception FSM reaches PARSE state
5. Check CRC computation result

### General Debug Strategy
1. Run single test at a time (comment out other test)
2. Add `$monitor` statements for signal tracking
3. Increase `wait_cycles()` between tests
4. Use waveform viewer to inspect signals frame-by-frame
5. Verify clock period (should be 10ns = 100MHz)
// FSM reads from FIFO
rx_fifo_data_out = 8'hAA    // FIFO output
rx_frame_data_valid = ~rx_fifo_empty & rx_en = 1

// Frame_Reception state machine:
case (state)
    IDLE: if (rx_en) next_state = PREAMBLE;
    PREAMBLE: if (rx_data==0xAA) count++;
              if (count==6) next_state = SFD;
    SFD: if (rx_data==0xAB) next_state = DEST_ADDR;
    DEST_ADDR: dest_mac[47-cnt*8 -: 8] = rx_data;
               if (cnt==5) next_state = SRC_ADDR;
    SRC_ADDR: src_mac[47-cnt*8 -: 8] = rx_data;
              if (cnt==5) next_state = ETH_TYPE;
    ETH_TYPE: eth_type[15-cnt*8 -: 8] = rx_data;
              if (cnt==1) next_state = PAYLOAD;
    PAYLOAD: crc_en = 1; payload_data[31-cnt*8 -: 8] = rx_data;
             if (cnt==3) next_state = CRC_CAPTURE;
    CRC_CAPTURE: received_crc[31-cnt*8 -: 8] = rx_data;
                 if (cnt==3) next_state = CRC_COMPARE;
    CRC_COMPARE: if (received_crc == crc_out) frame_valid = 1;
                 next_state = IDLE;
endcase
```

### Step 4: CRC_Generator Validates
```verilog
crc_en = rx_en = 1;
data_valid = rx_frame_data_valid = 1;
data_in = rx_fifo_data_out;

// Internal CRC computation (Ethernet CRC-32)
// As each byte arrives, CRC register updated:
crc_reg <= temp_crc;  // Updated with each byte

// After frame ends, crc_done asserted:
crc_out <= ~crc_reg;  // Final CRC (bit-reversed and inverted)
crc_done <= 1;
```

### Step 5: Application Reads Results
```verilog
// After frame_valid asserted:
received_dest = dest_mac;      // 48'h112233445566
received_src = src_mac;        // 48'haabbccddeeff
received_type = eth_type;      // 16'h0800
frame_is_valid = frame_valid;  // 1 = CRC OK, 0 = CRC ERROR
```

---

## TX Path Detailed Walkthrough

### Step 1: Application Initiates TX
```verilog
app_tx_start = 1;
app_tx_dest_mac = 48'hffffffffffff;  // Broadcast
app_tx_src_mac = 48'h001122334455;
app_tx_eth_type = 16'h0800;           // IPv4
app_tx_data = 8'h45;                  // Payload byte
app_tx_data_valid = 1;
```

### Step 2: TX FIFO Captures Payload
```verilog
tx_fifo_wr_en = app_tx_data_valid & ~tx_fifo_full = 1
fifo_mem[0] = app_tx_data = 8'h45

// FIFO ready to be read
tx_fifo_empty = 0
```

### Step 3: Frame_Transmission Builds Frame
```verilog
// Frame_Transmission FSM processes:

case (state)
    IDLE: 
        if (app_tx_start) next_state = PREAMBLE;
    
    PREAMBLE:
        tx_out = 8'hAA;          // Output preamble
        tx_en = 1;               // Enable transmission
        byte_count++;
        if (byte_count == 6) next_state = SFD;
    
    SFD:
        tx_out = 8'hAB;
        tx_en = 1;
        next_state = DEST_ADDR;
    
    DEST_ADDR:
        tx_out = app_tx_dest_mac[47-(byte_count*8) -: 8];
        tx_en = 1;
        byte_count++;
        if (byte_count == 5) next_state = SRC_ADDR;
    
    SRC_ADDR:
        tx_out = app_tx_src_mac[47-(byte_count*8) -: 8];
        tx_en = 1;
        byte_count++;
        if (byte_count == 5) next_state = ETH_TYPE;
    
    ETH_TYPE:
        tx_out = app_tx_eth_type[15-(byte_count*8) -: 8];
        tx_en = 1;
        byte_count++;
        if (byte_count == 1) next_state = PAYLOAD;
    
    PAYLOAD:
        crc_en = 1;                    // Enable CRC accumulation
        tx_out = tx_fifo_data_out;     // Output from FIFO
        tx_en = 1;                     // Valid output
        byte_count++;
        if (byte_count == 3) next_state = FINALIZE_CRC;
    
    FINALIZE_CRC:
        crc_en = 0;                    // Disable CRC, let it finalize
        tx_en = 0;                     // Stop transmission
        if (crc_done) next_state = CRC;
    
    CRC:
        tx_out = crc_out[31-(byte_count*8) -: 8];
        tx_en = 1;
        byte_count++;
        if (byte_count == 3) begin
            tx_done = 1;
            next_state = IDLE;
        end
endcase
```

### Step 4: CRC_Generator Accumulates
```verilog
// During PAYLOAD state:
crc_en = 1;
data_valid = tx_fifo_rd_en = (frame_tx_state == PAYLOAD) & ~tx_fifo_empty;
data_in = tx_fifo_data_out;

// CRC computed as each payload byte appears:
temp_crc = crc_reg ^ (data_in << 24);
for (i=0; i<8; i++) begin
    if (temp_crc[31])
        temp_crc = (temp_crc << 1) ^ polynomial;
    else
        temp_crc = temp_crc << 1;
end
crc_reg <= temp_crc;

// After payload complete (crc_en = 0):
crc_out <= ~crc_reg;    // Final CRC
crc_done <= 1;          // Signal ready
```

### Step 5: TX FIFO Read Control
```verilog
// MAC_Controller intelligently gates FIFO reads:
tx_fifo_rd_en = (frame_tx_state == PAYLOAD) & ~tx_fifo_empty;

// Frame_Transmission can only read during PAYLOAD state
// This prevents stale data from being transmitted
```

### Step 6: PHY Receives Frame
```verilog
// On each clock cycle while tx_en=1:
phy_tx_en = tx_en;
phy_tx_data = tx_data;          // Output byte
phy_tx_valid = tx_data_valid;   // Valid indicator
```

### Step 7: Transmission Complete
```verilog
// After CRC bytes sent:
tx_done = 1;    // Frame transmission complete

// Application can initiate next transmission after this
```

---

## State Machine Flow Diagrams

### RX State Transitions
```
                ┌─────────────────────────┐
                │        IDLE             │◄──────────┐
                │ (Waiting for frame)     │           │
                └────────────┬────────────┘           │
                             │rx_en=1                 │
                             ▼                        │
                ┌─────────────────────────┐           │
                │      PREAMBLE           │           │
                │ (Check 7×0xAA)          │           │
                └────────────┬────────────┘           │
                             │(count==6)             │
                             ▼                        │
                ┌─────────────────────────┐           │
                │        SFD              │           │
                │ (Expect 0xAB)           │           │
                └────────────┬────────────┘           │
                             │(RX==0xAB)             │
                             ▼                        │
                ┌─────────────────────────┐           │
                │     DEST_ADDR           │           │
                │ (6 bytes)               │           │
                └────────────┬────────────┘           │
                             │(count==5)             │
                             ▼                        │
                ┌─────────────────────────┐           │
                │      SRC_ADDR           │           │
                │ (6 bytes)               │           │
                └────────────┬────────────┘           │
                             │(count==5)             │
                             ▼                        │
                ┌─────────────────────────┐           │
                │      ETH_TYPE           │           │
                │ (2 bytes)               │           │
                └────────────┬────────────┘           │
                             │(count==1)             │
                             ▼                        │
                ┌─────────────────────────┐           │
                │      PAYLOAD            │           │
                │ (Variable bytes)        │           │
                │ crc_en=1                │           │
                └────────────┬────────────┘           │
                             │(count==3)             │
                             ▼                        │
                ┌─────────────────────────┐           │
                │    CRC_CAPTURE          │           │
                │ (4 bytes)               │           │
                └────────────┬────────────┘           │
                             │(count==3)             │
                             ▼                        │
                ┌─────────────────────────┐           │
                │    CRC_COMPARE          │           │
                │ (Check CRC validity)    │           │
                │ frame_valid asserted    │           │
                └────────────┬────────────┘           │
                             │                       │
                             └───────────────────────┘
```

### TX State Transitions
```
                ┌─────────────────────────┐
                │        IDLE             │◄──────────┐
                │ (Waiting for start)     │           │
                └────────────┬────────────┘           │
                             │app_tx_start=1         │
                             ▼                        │
                ┌─────────────────────────┐           │
                │      PREAMBLE           │           │
                │ (7 bytes of 0xAA)       │           │
                └────────────┬────────────┘           │
                             │(count==6)             │
                             ▼                        │
                ┌─────────────────────────┐           │
                │        SFD              │           │
                │ (1 byte 0xAB)           │           │
                └────────────┬────────────┘           │
                             │                       │
                             ▼                        │
                ┌─────────────────────────┐           │
                │     DEST_ADDR           │           │
                │ (6 bytes)               │           │
                └────────────┬────────────┘           │
                             │(count==5)             │
                             ▼                        │
                ┌─────────────────────────┐           │
                │      SRC_ADDR           │           │
                │ (6 bytes)               │           │
                └────────────┬────────────┘           │
                             │(count==5)             │
                             ▼                        │
                ┌─────────────────────────┐           │
                │      ETH_TYPE           │           │
                │ (2 bytes)               │           │
                └────────────┬────────────┘           │
                             │(count==1)             │
                             ▼                        │
                ┌─────────────────────────┐           │
                │      PAYLOAD            │           │
                │ (Variable bytes)        │           │
                │ tx_fifo_rd_en active    │           │
                │ crc_en=1                │           │
                └────────────┬────────────┘           │
                             │(count==3)             │
                             ▼                        │
                ┌─────────────────────────┐           │
                │   FINALIZE_CRC          │           │
                │ crc_en=0 (finalize)     │           │
                │ Wait for crc_done       │           │
                └────────────┬────────────┘           │
                             │crc_done=1             │
                             ▼                        │
                ┌─────────────────────────┐           │
                │        CRC              │           │
                │ (4 CRC bytes)           │           │
                │ tx_data_valid=1         │           │
                └────────────┬────────────┘           │
                             │(count==3)             │
                             ▼                        │
                ┌─────────────────────────┐           │
                │        DONE             │           │
                │ tx_done=1               │           │
                │ (Frame complete)        │           │
                └────────────┬────────────┘           │
                             │                       │
                             └───────────────────────┘
```

---

## Verification Test Cases

### Test 1: Simple RX Frame
**Objective:** Verify frame reception and parsing

```verilog
// Input sequence:
rx_en = 1;
// Preamble (7 bytes)
repeat(7) begin
    rx_data = 8'hAA;
    rx_data_valid = 1;
    @(posedge clk);
end

// SFD
rx_data = 8'hAB;
@(posedge clk);

// Dest MAC: 11:22:33:44:55:66
rx_data = 8'h11; @(posedge clk);
rx_data = 8'h22; @(posedge clk);
rx_data = 8'h33; @(posedge clk);
rx_data = 8'h44; @(posedge clk);
rx_data = 8'h55; @(posedge clk);
rx_data = 8'h66; @(posedge clk);

// Src MAC: aa:bb:cc:dd:ee:ff
repeat(6) begin
    rx_data = {4'ha, 4'hb} + more_bytes;
    @(posedge clk);
end

// Ethernet Type: 0x0800 (IPv4)
rx_data = 8'h08; @(posedge clk);
rx_data = 8'h00; @(posedge clk);

// Payload: 4 bytes
rx_data = 8'h12; @(posedge clk);
rx_data = 8'h34; @(posedge clk);
rx_data = 8'h56; @(posedge clk);
rx_data = 8'h78; @(posedge clk);

// CRC: Assume calculated as 0xDEADBEEF
rx_data = 8'hDE; @(posedge clk);
rx_data = 8'hAD; @(posedge clk);
rx_data = 8'hBE; @(posedge clk);
rx_data = 8'hEF; @(posedge clk);

rx_en = 0;

// Verify outputs:
assert(dest_mac == 48'h112233445566);
assert(src_mac == 48'haabbccddeeff);
assert(eth_type == 16'h0800);
assert(frame_valid == 1);  // If CRC calculated correctly
assert(rx_done == 1);
```

### Test 2: Simple TX Frame
**Objective:** Verify frame transmission construction

```verilog
// Setup:
app_tx_dest_mac = 48'hffffffffffff;
app_tx_src_mac = 48'h001122334455;
app_tx_eth_type = 16'h0800;
app_tx_start = 1;

// Load payload into FIFO:
app_tx_data = 8'h45;
app_tx_data_valid = 1;
@(posedge clk);
app_tx_data = 8'h00;
@(posedge clk);
app_tx_data = 8'h00;
@(posedge clk);
app_tx_data = 8'h3c;
@(posedge clk);
app_tx_data_valid = 0;

// Wait for transmission to complete
wait(tx_done == 1);
@(posedge clk);

// Verify tx_done was pulsed
assert(tx_done == 1);
```

### Test 3: Full Duplex Operation
**Objective:** Verify simultaneous RX and TX

```verilog
// Start RX frame reception
rx_en = 1;
rx_data_valid = 1;
rx_data = 8'hAA;  // Preamble starts

// Simultaneously start TX frame transmission
app_tx_start = 1;
app_tx_data = 8'h12;
app_tx_data_valid = 1;
@(posedge clk);

// Continue both paths independently
// Frame_reception should complete RX independently of TX
// frame_transmission should complete TX independently of RX

wait(rx_done == 1 && tx_done == 1);
```

### Test 4: FIFO Overflow Prevention
**Objective:** Verify FIFO full flag prevents data loss

```verilog
// Fill TX FIFO to capacity (16 bytes)
repeat(16) begin
    app_tx_data = 8'hAA;
    app_tx_data_valid = 1;
    @(posedge clk);
end

// Next write should be prevented
assert(tx_fifo_full == 1);
app_tx_data = 8'hBB;
app_tx_data_valid = 1;
@(posedge clk);
// Data should NOT be written (tx_fifo_wr_en = 0)
```

### Test 5: CRC Validation
**Objective:** Verify CRC checking

```verilog
// Test Case 5a: Correct CRC
// (Send frame with valid CRC)
// Expected: frame_valid = 1

// Test Case 5b: Incorrect CRC
// (Send frame with corrupted CRC)
// Expected: frame_valid = 0
```

---

## Debug Tips

### Issue: frame_valid never asserts after RX
**Diagnosis:**
- Check if crc_done from crc_generator is asserted
- Verify crc_out matches received_crc in frame_reception
- Check frame reception is reaching CRC_COMPARE state

**Solution:**
```verilog
// Add debug outputs:
output wire crc_done_dbg = crc_done;
output wire [31:0] crc_out_dbg = crc_out;
// Monitor these in simulation
```

### Issue: TX frame doesn't start transmitting
**Diagnosis:**
- Check if app_tx_start pulse is being recognized
- Verify frame_tx_state is transitioning from IDLE
- Check if tx_data is changing on each clock

**Solution:**
```verilog
// Monitor frame_tx_state:
// Should see IDLE → PREAMBLE → SFD → ...
// If stuck in IDLE, app_tx_start signal issue
```

### Issue: FIFO_TX doesn't provide data to frame_transmission
**Diagnosis:**
- Check tx_fifo_rd_en is asserted when frame_tx_state == PAYLOAD
- Verify FIFO has data (!tx_fifo_empty)
- Check tx_fifo_data_out is valid

**Solution:**
```verilog
// Gate signals must combine properly:
// tx_fifo_rd_en = (frame_tx_state == 4'b0110) & ~tx_fifo_empty
```

### Issue: CRC mismatch in RX
**Diagnosis:**
- Verify input data bytes are correct
- Check CRC polynomial (0x04C11DB7)
- Verify received_crc is capturing all 4 bytes correctly

**Solution:**
- Use known test vector frames with precalculated CRC values
- Trace CRC calculation byte-by-byte

---

## Performance Metrics

### Throughput
- **Maximum:** 1 byte per clock cycle (8 bits/cycle)
- **Practical:** Depends on application interface timing

### Latency
- **RX:** Frame_size + CRC_calculation_time
- **TX:** Header_time + Payload_time + CRC_finalize_time

### Resource Utilization
- **Registers:** ~150 (FSMs + counters + buffers)
- **Memory:** 192 bits (FIFOs)
- **Combinational Logic:** ~500 gates equivalent

---

## Next Steps

1. **Simulation:** Run all test cases in ModelSim/VCS
2. **Synthesis:** Check timing constraints are met
3. **Integration:** Connect to PHY and application layers
4. **Validation:** Run real frame traffic
5. **Optimization:** Profile and optimize critical paths

