# Simulation Results

The following values are transcribed from the EDA Playground simulation logs supplied for this case study.

## Golden and derived tests

| Test | BUG_MODE | Transactions checked | Functional coverage | Scoreboard errors | UVM errors | UVM fatals |
|---|---:|---:|---:|---:|---:|---:|
| `apb_test` | 0 | 135 | 100.00% | 0 | 0 | 0 |
| `apb_rw_test` | 0 | 11 | 61.07% | 0 | 0 | 0 |
| `apb_error_test` | 0 | 7 | 71.99% | 0 | 0 | 0 |
| `apb_random_test` | 0 | 103 | 93.75% | 0 | 0 | 0 |

The focused tests have lower functional coverage because they exercise only part of the full feature space.

## Mutation testing

| BUG_MODE | Injected defect | Detection evidence | Scoreboard errors |
|---:|---|---|---:|
| 1 | SCRATCH address decode defect | `PSLVERR` mismatch at address `0x0C` | 30 |
| 2 | STATUS RO protection defect | `PSLVERR` mismatch at address `0x04` | 10 |
| 3 | W1C polarity defect | `INT_STATUS` readback expected `0x0000000A`, got `0x00000005` | 2 |

All three injected mutations were detected by the scoreboard.

## SVA evidence

The SVA-enabled golden run compiled and completed without reported assertion failures. The testbench contains three properties:
1. `PENABLE` implies `PSEL`.
2. APB controls and payload remain stable during ACCESS wait states.
3. SETUP progresses to ACCESS on the next sampled clock.

The SVA cover messages were observed for the scenarios. A numeric assertion-coverage report was not provided.

## Coverage limitations

- Functional coverage: 100.00% in the full golden run.
- RTL statement coverage: not measured.
- RTL branch coverage: not measured.
- Toggle/FSM coverage: not measured.
- Only `WAIT_STATES=2` was exercised in the recorded run.

These results describe the supplied simulation evidence and should not be interpreted as formal proof or full RTL code coverage.
