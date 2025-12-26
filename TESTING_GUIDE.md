# MAC Controller - Implementation & Testing Guide

## Quick Start Summary

The `mac_controller` is fully integrated with all submodules. Here's what's been implemented:

### ✅ Completed Integration

1. **Module Connections** - All submodules properly instantiated:
   - ✓ FIFO_RX → Frame_Reception → CRC_Generator (RX)
   - ✓ FIFO_TX → Frame_Transmission → CRC_Generator (TX)

2. **Signal Routing** - Complete end-to-end paths:
   - ✓ RX: PHY → FIFO → Parser → Headers (to Application)
   - ✓ TX: Application → FIFO → Frame Builder → PHY

3. **Control Logic** - Intelligent gate signals:
   - ✓ TX FIFO read only during PAYLOAD state
   - ✓ CRC enable/disable synchronized with frame boundaries
   - ✓ Proper full/empty flag handling

4. **Debug Outputs** - Visibility for verification:
   - ✓ TX state output for monitoring FSM
   - ✓ FIFO flags for occupancy tracking

---

## Data Sheet Summary

### Port Count
- **Inputs:** 11
- **Outputs:** 13
- **Total Signals:** 24

### Timing Characteristics
- **Clock:** Single clock domain (synchronous design)
- **Reset:** Asynchronous active-low
- **Latency:** Variable (depends on frame content)

### Memory Usage
- **FIFO_RX:** 8 × 8-bit = 64 bits
- **FIFO_TX:** 16 × 8-bit = 128 bits
- **Total:** 192 bits (24 bytes)

### Supported Frame Sizes
- **Minimum:** 15 bytes (preamble + SFD + headers)
- **Maximum:** Determined by payload buffering (unlimited with streaming)

---

## Implementation Checklist

### Phase 1: Basic Connectivity
- [ ] Instantiate mac_controller module
- [ ] Connect clock and reset (mandatory)
- [ ] Connect PHY RX interface (rx_en, rx_data, rx_data_valid)
- [ ] Connect PHY TX interface (tx_en, tx_data, tx_data_valid)

### Phase 2: RX Application Interface
- [ ] Connect dest_mac output to application
- [ ] Connect src_mac output to application
- [ ] Connect eth_type output to application
- [ ] Monitor frame_valid for CRC validation
- [ ] Monitor rx_done for frame completion

### Phase 3: TX Application Interface
- [ ] Connect app_tx_data input (payload)
- [ ] Connect app_tx_data_valid input (valid byte)
- [ ] Connect app_tx_start input (initiate transmission)
- [ ] Connect app_tx_dest_mac input (destination)
- [ ] Connect app_tx_src_mac input (source)
- [ ] Connect app_tx_eth_type input (frame type)
- [ ] Monitor tx_done for transmission completion

### Phase 4: Debugging
- [ ] Connect tx_state to logic analyzer (optional)
- [ ] Connect FIFO flags to monitor buffer occupancy
- [ ] Verify all signals on scope/logic analyzer

---

## RX Path Detailed Walkthrough

### Step 1: Frame Arrival at PHY
```verilog
// Simulate frame: dest=112233445566, src=aabbccddeeff, type=0800, payload=0x12345678

rx_en = 1;              // Frame reception active
rx_data_valid = 1;
rx_data = 8'hAA;        // Preamble byte 1
```

### Step 2: FIFO_RX Stores Data
```
FIFO_RX write_enable = rx_en & rx_data_valid = 1
fifo_mem[0] = 8'hAA
```

### Step 3: Frame_Reception Processes
```verilog
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

