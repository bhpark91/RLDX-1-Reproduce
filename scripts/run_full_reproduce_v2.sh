#!/usr/bin/env bash
set -euo pipefail
export MUJOCO_GL="${MUJOCO_GL:-egl}"
export PYOPENGL_PLATFORM="${PYOPENGL_PLATFORM:-egl}"

: "${RLDX_ROOT:?Set RLDX_ROOT to your upstream RLDX-1 checkout}"
RLDX_ROOT=$(cd "$RLDX_ROOT" && pwd)
[[ -f "$RLDX_ROOT/rldx/eval/rollout_policy.py" ]] || { echo "Missing upstream rollout_policy.py" >&2; exit 2; }
OUTPUT_ROOT="${OUTPUT_ROOT:-$RLDX_ROOT/output_final/robocasa/reproduce_v2}"
[[ "$OUTPUT_ROOT" = /* ]] || OUTPUT_ROOT="$PWD/$OUTPUT_ROOT"
SIM_PYTHON="${SIM_PYTHON:-$RLDX_ROOT/rldx/eval/sim/robocasa/robocasa_uv/.venv/bin/python}"
[[ "$SIM_PYTHON" = /* ]] || SIM_PYTHON="$PWD/$SIM_PYTHON"
[[ -x "$SIM_PYTHON" ]] || { echo "Simulator Python is not executable: $SIM_PYTHON" >&2; exit 2; }
N_EPISODES="${N_EPISODES:-50}"
MAX_EPISODE_STEPS="${MAX_EPISODE_STEPS:-720}"
N_ACTION_STEPS="${N_ACTION_STEPS:-16}"
POLICY_HOST="${POLICY_HOST:-127.0.0.1}"
POLICY_PORT="${POLICY_PORT:-5555}"
for value in "$N_EPISODES" "$MAX_EPISODE_STEPS" "$N_ACTION_STEPS" "$POLICY_PORT"; do
    [[ "$value" =~ ^[1-9][0-9]*$ ]] || { echo "Episode, step and port values must be positive integers" >&2; exit 2; }
done
# Avoid mixing videos, CSVs, or logs from separate runs.
if [[ -e "$OUTPUT_ROOT" && ( ! -d "$OUTPUT_ROOT" || -n "$(find "$OUTPUT_ROOT" -mindepth 1 -print -quit)" ) ]]; then
    echo "OUTPUT_ROOT must be new or empty: $OUTPUT_ROOT" >&2
    exit 2
fi
LOG_DIR="$OUTPUT_ROOT/_logs"
mkdir -p "$LOG_DIR"
cd "$RLDX_ROOT"
{
    printf 'started_utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'upstream_commit=%s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
    printf 'upstream_worktree_status:\n'
    git status --porcelain 2>/dev/null || true
    printf 'checkpoint=RLWRLD/RLDX-1-FT-ROBOCASA (expected; verify running server)\n'
    printf 'checkpoint_revision=not automatically captured; record server revision separately\n'
    printf 'n_episodes=%s\nmax_episode_steps=%s\nn_action_steps=%s\n' "$N_EPISODES" "$MAX_EPISODE_STEPS" "$N_ACTION_STEPS"
    printf 'sim_python=%s\npolicy_host=%s\npolicy_port=%s\n' "$SIM_PYTHON" "$POLICY_HOST" "$POLICY_PORT"
    "$SIM_PYTHON" --version 2>&1
    if command -v nvidia-smi >/dev/null; then
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader || true
    else
        printf 'GPU/driver unavailable: nvidia-smi not found\n'
    fi
} > "$LOG_DIR/run_metadata.txt"

TASKS=(
    "TurnSinkSpout" "TurnOnStove" "TurnOnSinkFaucet" "TurnOnMicrowave"
    "TurnOffStove" "TurnOffSinkFaucet" "TurnOffMicrowave"
    "PnPStoveToCounter" "PnPSinkToCounter" "PnPMicrowaveToCounter"
    "PnPCounterToStove" "PnPCounterToSink" "PnPCounterToMicrowave"
    "PnPCounterToCab" "PnPCabToCounter"
    "OpenSingleDoor" "OpenDrawer" "OpenDoubleDoor"
    "CoffeeSetupMug" "CoffeeServeMug" "CoffeePressButton"
    "CloseSingleDoor" "CloseDrawer" "CloseDoubleDoor"
)

FAILED_TASKS=0
for TASK in "${TASKS[@]}"; do
    echo "===== $TASK starting at $(date -u +%FT%TZ) ====="
    # Temporarily disable errexit so every task is attempted and both pipeline statuses are captured.
    set +e
    "$SIM_PYTHON" rldx/eval/rollout_policy.py \
        --n-episodes "$N_EPISODES" \
        --policy-client-host "$POLICY_HOST" --policy-client-port "$POLICY_PORT" \
        --max-episode-steps "$MAX_EPISODE_STEPS" \
        --env-name "robocasa_panda_omron/${TASK}_PandaOmron_Env" \
        --n-action-steps "$N_ACTION_STEPS" --n-envs 1 \
        --video-dir "$OUTPUT_ROOT/$TASK" 2>&1 | tee "$LOG_DIR/$TASK.log"
    STATUS=("${PIPESTATUS[@]}")
    set -e
    if (( STATUS[0] != 0 || STATUS[1] != 0 )); then
        FAILED_TASKS=$((FAILED_TASKS + 1))
        printf '%s: FAILED rollout_exit=%s log_exit=%s\n' "$TASK" "${STATUS[0]}" "${STATUS[1]}" | tee -a "$LOG_DIR/_status.log"
    else
        printf '%s: OK\n' "$TASK" | tee -a "$LOG_DIR/_status.log"
    fi
done
printf 'Processed %s tasks; %s failed.\n' "${#TASKS[@]}" "$FAILED_TASKS"
exit "$FAILED_TASKS"
