# RLDX-1 RoboCasa Kitchen Reproduction

Independent reproduction of the released [RLDX-1](https://www.rlwrld.ai/en/rldx-1) checkpoint on the RoboCasa Kitchen evaluation. This repository reproduces evaluation of the released fine-tuned checkpoint; it does **not** reproduce RLDX-1 pretraining or fine-tuning.

[Watch the simulation demo](https://youtu.be/BxVT_L6nGoU) · [Per-task results](results/results_v2.csv) · [Environment and debugging notes](setup_notes.md)

## What was reproduced

| Item | This reproduction | Upstream report |
|---|---|---|
| Success rate | **67.8% (814/1,200)** | 70.6% |
| Evaluation size | 24 tasks × 50 episodes | 24 tasks × 50 episodes |
| Hardware | NVIDIA RTX 3090 | Not matched |

The reproduced score was 2.8 percentage points below the upstream report. This study did not include enough independent replications to identify the cause of that difference. The results are a checkpoint evaluation reproduction, not evidence of a new model or statistical equivalence to the upstream result.

## Evaluation configuration

- Released checkpoint: `RLWRLD/RLDX-1-FT-ROBOCASA`.
- Simulator: RoboCasa Kitchen, `robocasa_panda_omron/*_PandaOmron_Env`.
- 50 episodes per task, one environment, `--max-episode-steps 720`, `--n-action-steps 16`.
- Original upstream Git commit and Hugging Face checkpoint revision: **not recorded**. Exact historical reconstruction is therefore not guaranteed.
- Environment notes record Ubuntu 22.04, CUDA cu126, PyTorch 2.7.0 for inference and 2.5.1 for simulation; these are historical notes, not a validated lockfile.

Success counts were aggregated from the success marker in upstream-generated episode video filenames. The committed CSV is the historical summary; raw episode outputs and logs are not included here.

## Results by category

| Category | Success / episodes | Rate |
|---|---:|---:|
| Close | 144 / 150 | 96.0% |
| Coffee | 108 / 150 | 72.0% |
| Open | 103 / 150 | 68.7% |
| PnP | 197 / 400 | 49.2% |
| Turn | 262 / 350 | 74.9% |
| **Total** | **814 / 1,200** | **67.8%** |

Rates use Python's one-decimal rounding from counts (including 49.25% → 49.2%), not averages of category percentages.

## Latency measurement

Historical measurement on RTX 3090, TurnSinkSpout: 10 episodes and 145 samples after warm-up.

| Measurement boundary | Mean | Median | p10 / p90 |
|---|---:|---:|---:|
| Server round-trip (ZeroMQ receive → send) | 413.5 ms | 411.5 ms | 374 / 452 ms |
| Policy inference (`RLDXPolicy._get_action`) | 409.4 ms | 407.1 ms | 370 / 448 ms |

The upstream report gives 43.7 ms per inference on RTX 5090. The two latency measurements are not directly comparable because hardware, software stack, numerical precision, and measurement setup were not matched. No causal attribution is made for the difference.

Action chunk length divided by inference latency is **not** a measured closed-loop robot control frequency. No hardware extrapolation or real-time-control suitability claim is made.

## Engineering observations

- The recorded step cap was approximately 45 at `max_episode_steps=720` and `n_action_steps=16`. The relation `720/16=45` is an empirical observation; its source-code mechanism and the exact semantics of the reported step counter were not verified.
- Some longer tasks reached that cap. This suggests a possible horizon limitation, but does not isolate why they failed or predict results with a different horizon.
- Environment issues included NumPy/Numba compatibility, Transformers versions, missing dependencies, and FFmpeg text rendering. See [setup notes](setup_notes.md); these describe the historical environment rather than universal compatibility rules.

## Running the evaluation

Use an upstream RLDX-1 checkout and follow its setup instructions for the simulator and a running policy server serving the checkpoint above. This repository does not install upstream dependencies, launch that server, or download weights.

From this repository:

```bash
export RLDX_ROOT=/absolute/path/to/RLDX-1
export OUTPUT_ROOT=/absolute/path/to/new-or-empty-run-directory
# Optional overrides: N_EPISODES, MAX_EPISODE_STEPS, N_ACTION_STEPS,
# POLICY_HOST, POLICY_PORT, SIM_PYTHON (path to simulator Python).
bash scripts/run_full_reproduce_v2.sh

export RESULTS_CSV=/absolute/path/to/generated-results.csv
bash scripts/generate_results_v2.sh
```

The runner requires Bash and the configured simulator Python. It records the current upstream commit, working-tree status, GPU/driver (when available), parameters, and per-task exit status under `_logs/`. Record the actual policy server's checkpoint revision separately. It attempts all 24 tasks and exits with the number of failed tasks. A nonempty output directory is rejected to avoid mixing separate runs.

The aggregator uses Python 3's standard library. It expects raw episode `.mp4` files with the historical `success` filename marker and `simulation_results.csv` with simulator step counts in its fifth column. Do not include demo copies or renamed videos. It checks CSV/video counts, warns about missing results, and exits nonzero for an incomplete task set. Missing timing remains blank, not zero. Relative paths are resolved from the invocation directory; `RESULTS_CSV` must be outside `OUTPUT_ROOT`.

These scripts have not been validated against every upstream version. Verify the CSV schema and filename convention against your pinned checkout before interpreting a new run. A syntactic or fixture test is not a GPU benchmark rerun.

## Repository contents

- `results/results_v2.csv`: unchanged historical task counts and summary statistics. Its legacy `per_step_ms` field is all zeros and must not be treated as a latency measurement.
- `scripts/run_full_reproduce_v2.sh`: evaluation wrapper.
- `scripts/generate_results_v2.sh`: aggregation for new raw outputs; uses explicit `avg_sim_steps`, `max_sim_steps`, and `task_wall_time_sec` fields and omits the legacy latency field.
- `scripts/make_demo_video.py` and `scripts/make_youtube_chapters.py`: presentation helpers.
- `setup_notes.md`: historical setup, observations, and limitations.

## Limitations

No training reproduction, multiple independent seed replications, controlled hardware comparison, or new experiments are claimed. Original upstream/checkpoint revisions and full raw evidence are missing. Success aggregation relies on upstream video naming, and the horizon observations have not been independently established as simulator-step semantics. This artifact documents one reproduction and its limits.

## Attribution

Project: **Bohyun Park**, with AI coding agents used for implementation. This is not a claim of manually authoring the implementation or creating the upstream model. RLDX-1, the released checkpoint, and RoboCasa are upstream work, not models or simulators introduced by this repository. Consult their respective terms before downloading or using them. No upstream code or model weights are bundled here, and this documentation update does not assign a new license.
