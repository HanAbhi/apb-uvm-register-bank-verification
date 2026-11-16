# Simulation Results

The values below are transcribed from the available EDA Playground logs for this case study.

## Golden and derived tests

| Test | BUG_MODE | Transactions checked | Functional coverage | Scoreboard errors | UVM errors | UVM fatals |
|---|---:|---:|---:|---:|---:|---:|
| `apb_test` | 0 | 135 | 100.00% | 0 | 0 | 0 |
| `apb_error_test` | 0 | 7 | 71.99% | 0 | 0 | 0 |
| `apb_random_test` | 0 | 103 | 93.75% | 0 | 0 | 0 |

A confirmed simulation log for `apb_rw_test` was not available when this results file was prepared, so its numerical results are intentionally omitted.

## Mutation testing

| BUG_MODE | Injected defect | Detection evidence | Scoreboard errors |
|---:|---|---|---:|
| 1 | SCRATCH address decode defect | `PSLVERR` mismatch at address `0x0C` | 30 |
| 2 | STATUS read-only protection defect | `PSLVERR` mismatch at address `0x04` | 10 |
| 3 | W1C polarity defect | `INT_STATUS` readback expected `0x0000000A`, got `0x00000005` | 2 |

All three injected mutations were detected by the scoreboard.

## SVA evidence

The SVA-enabled golden run compiled and completed without reported errors. The testbench contains three protocol properties:
1. `PENABLE` implies `PSEL`.
2. APB controls and payload remain stable during ACCESS wait states.
3. SETUP progresses to ACCESS on the next sampled clock.

Associated cover properties are present in the testbench. The available run log does not provide a numeric assertion-coverage result, so none is claimed here.

## Coverage limitations

- Functional coverage: 100.00% in the full golden run.
- RTL statement coverage: not measured.
- RTL branch coverage: not measured.
- Toggle/FSM coverage: not measured.
- Only `WAIT_STATES=2` was exercised in the recorded baseline.

These results describe the supplied simulation evidence and should not be interpreted as formal proof or full RTL code coverage.
