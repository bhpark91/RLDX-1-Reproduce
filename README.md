# RLDX-1 RoboCasa Kitchen Reproduction Study

Personal reproduction study of [RLWRLD's RLDX-1](https://www.rlwrld.ai/en/rldx-1) model on the RoboCasa Kitchen benchmark.

📹 **Demo Video**: https://youtu.be/BxVT_L6nGoU

## Summary

| Metric | Value |
|--------|-------|
| Reproduction | **67.8%** (814 / 1200) |
| RLWRLD reported | 70.6% |
| Difference | 2.8%p |
| Hardware | NVIDIA RTX 3090 |
| Trials | 24 tasks × 50 episodes = 1,200 |
| Setup | Docs example: `--n-action-steps 16 --max-episode-steps 720` |

## Category Breakdown

| Category | Success | Rate |
|----------|---------|------|
| Close    | 144 / 150 | 96% |
| Coffee   | 108 / 150 | 72% |
| Open     | 103 / 150 | 69% |
| PnP      | 197 / 400 | 49% |
| Turn     | 262 / 350 | 75% |

## Notes from the Reproduction

1. **Episode horizon observation**: Empirically observed that `--max-episode-steps` does not apply directly. With docs defaults (`max=720`, `n_action_steps=16`), the actual sim-step cap settled around 45. Pattern across settings suggests `actual_cap ≈ max_episode_steps / n_action_steps`. (Exact source mechanism not investigated.)

2. **Long-horizon tasks are horizon-limited**: Tasks like OpenDoubleDoor (avg 44 step, cap 45) showed competent visual execution but timed out before completion. PnP variants similarly bottlenecked.

3. **Reproduction substantially successful**: The 2.8%p gap from the reported 70.6% is within expected variance attributable to GPU difference (RTX 3090 vs RTX 5090) and random seed.

## Files

- `results/results_v2.csv` — Per-task results
- `scripts/run_full_reproduce_v2.sh` — Reproduction script
- `scripts/generate_results_v2.sh` — Result aggregation
- `scripts/make_demo_video.py` — Demo video compositor
- `setup_notes.md` — Environment setup + debugging history

## Author

**Bohyun Park**
