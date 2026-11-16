# APB Slave with Register Bank — UVM Verification

**Course:** VT3003-1 VLSI Testing and Verification  
**DUT:** #11 — APB Slave with Register Bank  
**Team:** Team 01, VLSI Design and Technology, Semester 7

This repository contains the RTL DUT, SystemVerilog UVM testbench, EDA Playground run instructions, waveform screenshots, and recorded verification results.

## Team

| Team member | Contribution |
|---|---:|
| Abhijna Laxmi | 20% |
| Anirudh Pai | 20% |
| Neetha Nayak | 20% |
| Suha Fathima | 20% |
| Vaishnavi Kudva | 20% |

## Repository structure

```text
.
├── rtl/
│   └── apb_regbank.sv
├── tb/
│   └── apb_uvm_testbench.sv
├── docs/
│   ├── figures/
│   │   └── uvm_testbench_architecture.png
│   └── waveforms/
│       ├── apb_waveform_wide.png
│       └── apb_waveform_zoom.png
├── results/
│   └── RESULTS.md
├── .gitignore
└── README.md
```

## DUT overview

The DUT is a 32-bit APB register bank with four byte strobes and a configurable wait-state count.

| Address | Register | Access | Reset / read value |
|---|---|---|---|
| `0x00` | CTRL | RW | `0x00000000` |
| `0x04` | STATUS | RO | `0x00000001` |
| `0x08` | INT_STATUS | W1C | `0x0000000F` |
| `0x0C` | SCRATCH | RW | `0x00000000` |
| Other | Unmapped | Invalid | `PSLVERR` asserted |

The register map and reset values are taken from the reference RTL used in this case study. Check them against the instructor-approved DUT specification before treating them as an independent specification.

## UVM testbench

The testbench includes:
- APB interface and transaction class
- Sequencer, driver and monitor
- UVM agent and environment
- Reference model and scoreboard
- Functional coverage subscriber
- Three SystemVerilog Assertion (SVA) protocol properties and associated cover properties
- Base test and three derived tests

### Tests

| Test | Purpose |
|---|---|
| `apb_test` | Full directed and random baseline |
| `apb_rw_test` | Reset and read/write register behaviour |
| `apb_error_test` | Read-only write protection and invalid-address errors |
| `apb_random_test` | W1C and constrained-random traffic |

## Run in EDA Playground

1. Open [EDA Playground](https://www.edaplayground.com/).
2. Select **SystemVerilog** for the testbench and design.
3. Select **UVM 1.2**.
4. Select **Siemens Questa 2025.2** (or a compatible Questa version).
5. Paste `rtl/apb_regbank.sv` into the **Design** pane.
6. Paste `tb/apb_uvm_testbench.sv` into the **Testbench** pane.
7. Set compile options:

   ```text
   -timescale 1ns/1ns +define+ENABLE_SVA
   ```

8. Set run options:

   ```text
   -voptargs=+acc+npr
   ```

9. Run the simulation.

The testbench top module has two local parameters:

```systemverilog
localparam int BUG_MODE = 0;
localparam string TEST_NAME = "apb_test";
```

Change `TEST_NAME` to run one of the derived tests. Keep `BUG_MODE=0` for the golden DUT.

### Mutation testing

To activate the injected RTL defects, change `BUG_MODE` in the testbench top module and run `apb_test`:

| BUG_MODE | Injected defect |
|---:|---|
| `0` | Correct reference DUT |
| `1` | SCRATCH address decode defect |
| `2` | STATUS read-only protection defect |
| `3` | W1C polarity defect |

Restore `BUG_MODE=0` after mutation testing.

## Simulation results

See [`results/RESULTS.md`](results/RESULTS.md) for the recorded test outcomes and mutation-detection evidence. Only results supported by the available simulation logs are included.

## Waveform evidence

The screenshots in `docs/waveforms/` were captured from EPWave and show APB clock, reset, select/enable, ready/error, address, data, strobes and transfer direction.

## Verification notes

- The **100% value refers to functional coverage** for the implemented reachable-bin model in the full golden run. It is not RTL statement, branch, toggle or FSM coverage.
- RTL statement and branch coverage were not measured in the supplied simulation evidence.
- `WAIT_STATES=2` was used for the recorded baseline.
- The SVA-enabled baseline compiled and ran without reported errors; the available log does not provide a numeric assertion-coverage result.
- The full case-study report is maintained separately as an Overleaf project. This repository focuses on source code and verification evidence.
