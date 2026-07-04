# AMBA-APB-Master-Slave-RTL-Verification
A complete RTL implementation of the AMBA APB protocol in Verilog, featuring APB Master, multiple Slave peripherals (RAM &amp; ROM), address decoding, wait-state support, error handling, and a self-checking verification environment with simulation waveforms.


## Project Overview

This project implements and verifies a complete **AMBA APB (Advanced Peripheral Bus)** Master-Slave system in Verilog. The design covers the full RTL development and functional verification cycle, including a self-checking testbench suite validated on EDA Playground.

The system consists of one APB Master, an Interconnect/Decoder, and three peripheral slaves (RAM, Register File, ROM), verified through a structured four-file testbench architecture with a built-in protocol checker and software scoreboard.

---

## Directory Structure

```
project_root/
│
├─ design/                    # RTL design files
│   ├─ apb_top.v              # Top-level structural wrapper
│   ├─ apb_master.v           # 4-state FSM APB Master
│   ├─ apb_interconnect.v     # Address decoder + response MUX
│   ├─ apb_slave_ram.v        # RAM slave (N=4 wait states)
│   ├─ apb_slave_reg.v        # Register file slave (N=0 wait states)
│   └─ apb_slave_rom.v        # ROM slave (N=2 wait states, read-only)
│
├─ tb/                        # Testbench files
│   ├─ tb_top.v               # Top-level testbench module
│   ├─ tb_tasks.v             # Shared tasks, signals, scoreboard
│   ├─ test_scenarios.v       # Individual test task definitions
│   └─ apb_protocol_checker.v # Passive APB protocol monitor
│
├─ design_doc/                # Project documents
│   ├─ APB_Testplan.xlsx      # Test plan (21 test cases, coverage, assertions)
│   └─ APB_Verification_Plan.docx
│
└─ sim/                       # Simulation outputs
    └─ apb_top.vcd            # Waveform dump (GTKWave compatible)
```

---

## Design Parameters

| Parameter    | Value                              |
|--------------|------------------------------------|
| `ADDR_WIDTH` | 8 bits                             |
| `DATA_WIDTH` | 8 bits                             |
| `MEM_DEPTH`  | 8 locations per slave              |
| Clock        | 100 MHz (10 ns period)             |
| Protocol     | AMBA APB3                          |

---

## Address Map

| Address Range | Slave          | Wait States |
|---------------|----------------|-------------|
| `0x00 – 0x0F` | RAM (Slave 0)  | N = 4       |
| `0x10 – 0x1F` | Register File (Slave 1) | N = 0 |
| `0x20 – 0x2F` | ROM (Slave 2)  | N = 2       |
| `0x30 – 0xFF` | Unmapped — error terminator fires | — |

---

## Module Summary

**`apb_master.v`** — 4-state FSM (`IDLE → SETUP → ACCESS → DONE`). Drives all APB control signals and exposes a simple `cmd_*` interface to the testbench.

**`apb_interconnect.v`** — Decodes `PADDR[7:4]` to select the appropriate slave, fans out control signals, MUXes slave responses back to the master, and asserts `PREADY=1, PSLVERR=1` for unmapped addresses.

**`apb_slave_ram.v`** — 8-deep byte-addressable RAM with N=4 configurable wait states. Asserts `PSLVERR` on out-of-range addresses.

**`apb_slave_reg.v`** — 8-entry register file with N=0 wait states (immediate `PREADY`).

**`apb_slave_rom.v`** — 8-entry read-only memory, pre-loaded with pattern `rom[i] = i × 0x11`. Rejects all write attempts with `PSLVERR=1`.

---

## Testbench Architecture

The testbench uses a four-file architecture where `tb_tasks.v` and `test_scenarios.v` are `include`-d into `tb_top.v` at compile time:

```
tb_top.v
  ├─ `include "tb_tasks.v"        ← signals, transactions, scoreboard
  ├─ `include "test_scenarios.v"  ← test1 … test8 task definitions
  ├─ apb_top (DUT instance)
  └─ apb_protocol_checker (passive monitor)
```

**`tb_tasks.v`** — Declares the `cmd_*` interface signals, software scoreboard arrays (`expected_ram/reg/rom[0:7]`), pass/fail counters, and core transaction tasks (`apb_write`, `apb_read`, `apb_transaction`, `check_result`, `print_summary`).

**`test_scenarios.v`** — Individual test tasks (`test1_ram_basic` through `test8_random`), each encapsulating stimulus generation and self-checking against the scoreboard.

**`apb_protocol_checker.v`** — Passive bus monitor that samples the APB bus on every `posedge PCLK` and flags protocol violations (PENABLE timing, signal stability during wait states, PSLVERR validity).

---

## List of Test Cases

| TC No. | Test Name                         | Description                                  |
|--------|-----------------------------------|----------------------------------------------|
| TC00   | APB General Test                  | Write + read across all three slaves         |
| TC01   | Reset Assertion                   | Verify all APB outputs deassert on reset     |
| TC02   | Post-Reset Ready                  | `cmd_ready` asserts within 1 cycle of reset  |
| TC03   | RAM Basic Write                   | Write `0xAA` to `RAM[0x02]`, N=4 wait       |
| TC04   | RAM Basic Read                    | Read back `RAM[0x02]`, verify `0xAA`         |
| TC05   | RAM Boundary Low                  | Write/read `RAM[0x00]`                        |
| TC06   | RAM Boundary High                 | Write/read `RAM[0x07]`                        |
| TC07   | RAM Out-of-Range                  | Address `0x08` — `PSLVERR` expected          |
| TC08   | Register Basic Write              | Write `0x55` to `REG[0x12]`, N=0 wait       |
| TC09   | Register Basic Read               | Read back `REG[0x12]`, verify `0x55`         |
| TC10   | Register Back-to-Back             | Three consecutive register writes, no idle   |
| TC11   | ROM Valid Read                    | Verify pre-loaded `i × 0x11` pattern         |
| TC12   | ROM Write Rejected                | Write attempt returns `PSLVERR=1`            |
| TC13   | ROM Integrity Check               | ROM data unchanged after write attempt       |
| TC14   | Unmapped Address Write            | Address `0x35` — error terminator fires      |
| TC15   | Unmapped Address Read             | Address `0x3F` — error terminator fires      |
| TC16   | Master FSM State Check            | Verify `IDLE→SETUP→ACCESS` waveform sequence |
| TC17   | Cross-Slave Back-to-Back          | RAM write then REG write, read both back     |
| TC18   | Reset During Transaction          | Assert reset mid-ACCESS, verify bus clears   |
| TC19   | PSLVERR Timing Check              | Protocol checker: PSLVERR only with PREADY   |
| TC20   | Signal Stability During Wait      | Protocol checker: PADDR/PWRITE stable in wait|
| TC21   | Random Stimulus (20 cycles)       | Random addr/data/rw vs software scoreboard   |

---

## Running the Simulation

### On EDA Playground (Icarus Verilog)

1. Upload all files from `design/` and `tb/` to the EDA Playground workspace.
2. Set the top module to `tb_top`.
3. Enable **VCD dump** in simulation settings.
4. Click **Run** — the simulation log will print `[PASS]` / `[FAIL]` for each check and a final summary.

### Locally (Icarus Verilog)

```bash
# Compile
iverilog -g2012 -o sim_out \
    design/apb_top.v \
    design/apb_master.v \
    design/apb_interconnect.v \
    design/apb_slave_ram.v \
    design/apb_slave_reg.v \
    design/apb_slave_rom.v \
    tb/apb_protocol_checker.v \
    tb/tb_top.v

# Run
vvp sim_out

# View waveform (requires GTKWave)
gtkwave sim/apb_top.vcd
```

> **Note:** `tb_tasks.v` and `test_scenarios.v` are `include`-d inside `tb_top.v` — do not pass them as separate compilation targets.

---

## Test Result Meaning

| Result | Meaning |
|--------|---------|
| `[PASS]` | The check condition evaluated true — DUT output matched expected value |
| `[FAIL]` | The check condition evaluated false — mismatch logged with test number and description |

The final `print_summary()` call prints total tests run, passed, failed, and success percentage.

---

## Protocol Assertions

The `apb_protocol_checker.v` monitors these rules on every clock edge:

| ID  | Property                    | Rule                                              |
|-----|-----------------------------|---------------------------------------------------|
| A01 | `penable_requires_psel`     | PENABLE may only assert if PSEL was high last cycle |
| A02 | `addr_stable_during_wait`   | PADDR must not change during ACCESS wait states   |
| A03 | `pwrite_stable_during_wait` | PWRITE must not change during ACCESS wait states  |
| A04 | `pslverr_valid_with_pready` | PSLVERR is only valid when PREADY is simultaneously high |
| A05 | `prdata_stable_during_wait` | PRDATA must not change during a read ACCESS wait  |

Violations are reported via `$display` and registered error flag outputs.

---

## Known RTL Bugs Found During Verification

Four bugs were discovered and fixed during the verification cycle:

1. **Master ACCESS state** — `PSEL` was not explicitly driven high in the ACCESS state `always` block; fixed by adding `PSEL <= 1`.
2. **Interconnect response MUX** — missing `!m_PSEL` guard caused spurious `PREADY=1` on an idle bus; fixed with an idle check.
3. **ROM Slave FSM** — `wait_counter` increment did not hold the `ACCESS` state; fixed by adding `state <= ACCESS` in the wait branch.
4. **ROM Slave write path** — write was silently modifying `rom[]`; fixed by returning `PSLVERR=1` and removing the write.

---

## Requirements

- Icarus Verilog `>= 10.0` 
- GTKWave (optional, for waveform viewing)
- No UVM or SystemVerilog extensions required — pure Verilog-2012

---

## Author

**Raghav**
Internship Project — VLSI / Digital Design
Date: 2026-06-30
