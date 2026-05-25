# Environment Setup + Debugging History

## Pod Environment

- **GPU**: NVIDIA RTX 3090 (sm_86, 24GB)
- **Cost**: $0.46/hr (RunPod)
- **OS**: Ubuntu 22.04, CUDA cu126
- **PyTorch**: 2.7.0 (server), 2.5.1 (sim env)

## Two Separate venvs

- `.venv` (training/inference): transformers 4.57.0, flash-attn 2.7.4
- `rldx/eval/sim/robocasa/robocasa_uv/.venv` (sim): robocasa 0.2.0, mujoco 3.2.6, robosuite 1.5.2

## Debugging History

### 1) Blackwell sm_120 incompatibility
- Initially tried RTX PRO 4500 (sm_120) — PyTorch 2.7 binaries incompatible
- Solution: Switched to RTX 3090 (sm_86)

### 2) numpy / numba ABI conflict
- robocasa setup script installs numpy 2.x — conflicts with numba 0.56.4
- Solution: `pip install numpy==1.23.3 --force-reinstall`

### 3) transformers version mismatch
- sim venv had transformers 4.51.3 — masking_utils import error
- Solution: `pip install transformers==4.57.0 --upgrade`

### 4) Missing packages
- rldx was installed with `--no-deps`, leaving 13+ runtime deps uninstalled
- Added: tyro, dm-tree, omegaconf, and others

### 5) Episode horizon cap observation
- First attempt (`--max-episode-steps 500 --n-action-steps 16`): all episodes terminated at 32 steps
- Analysis: docs example specifies 720, but I arbitrarily used 500. Even 500 was not applied directly — actual cap was only 32.
- After switching to 720, cap expanded to ~45 sim steps
- Empirical formula: `actual_cap ≈ max_episode_steps / n_action_steps`
  - 500 / 16 = 31.25 ≈ 32 ✓
  - 720 / 16 = 45 ✓
  - 720 / 8 = 90 ✓
- Exact source-code mechanism not investigated

### 6) ffmpeg drawtext % handling
- Default `expansion=normal` interprets `%` as strftime expansion — silent drawtext failure
- Solution: Added `expansion=none` to all drawtext filters

## Results

- First attempt (max=500, cap 32): 62.4%
- **Final (max=720, fair condition, cap 45): 67.8%** vs RLWRLD reported 70.6%

## Inference Latency Estimate

- Full pipeline (inference + sim + render + serialize): ~1800 ms/step on RTX 3090
- Reference (paper §6-1): RTX 5090 achieves 43.7 ms/step (pure inference only)
- In real robot deployment, sim/render overhead drops out, so actual inference latency should be substantially lower
