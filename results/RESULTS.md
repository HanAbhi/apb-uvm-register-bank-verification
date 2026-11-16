# Simulation Results

The values below are transcribed from the available EDA Playground logs for this case study.

## Golden DUT tests

| Test | BUG_MODE | Transactions checked | Functional coverage | Scoreboard errors | UVM errors | UVM fatals |
|---|---:|---:|---:|---:|---:|---:|
| `apb_test` | 0 | 135 | 100.00% | 0 | 0 | 0 |
| `apb_error_test` | 0 | 7 | 71.99% | 0 | 0 | 0 |
| `apb_random_test` | 0 | 103 | 93.75% | 0 | 0 | 0 |

The focused tests exercise smaller portions of the feature space, so their functional coverage is lower than the full baseline.

A result row for `apb_rw_test` is intentionally omitted because a verified run log and its metrics were not available for this report.

## Mutation testing

Each mutation was run with `apb_test`. The scoreboard reported the following mismatches:

| BUG_MODE | Injected defect | Detection evidence | Scoreboard errors |
|---:|---|---|---:|
| 1 | SCRATCH address decode defect | `PSLVERR` mismatch at address `0x0C` | 30 |
| 2 | STATUS read-only protection defect | `PSLVERR` mismatch at address `0x04` | 10 |
| 3 | W1C polarity defect | `INT_STATUS` readback expected `0x0000000A`, got `0x00000005` | 2 |

All three injected mutations were detected by the scoreboard.

## SystemVerilog Assertions

The testbench contains protocol properties for:
1. `PENABLE` implying `PSEL`.
2. APB control and payload stability during ACCESS wait states.
3. SETUP progressing to ACCESS on the next sampled clock.

SVA was enabled for the golden baseline run. The available log does not provide an assertion execution count or a numeric assertion-coverage result, so no assertion-coverage percentage is claimed here.

## Coverage scope and limitations

- Full golden-run functional coverage: **100.00%** for the implemented reachable-bin model.
- RTL statement coverage: not measured.
- RTL branch coverage: not measured.
- Toggle and FSM coverage: not measured.
- Recorded baseline configuration: `WAIT_STATES=2`.

These simulation results are evidence from the recorded test runs; they are not formal proof of correctness or a substitute for RTL code-coverage analysis.
