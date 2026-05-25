#!/bin/bash
export MUJOCO_GL=egl
export PYOPENGL_PLATFORM=egl

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

N_EPISODES=50
MAX_STEPS=720
N_ACTION_STEPS=16

LOG_DIR=output_final/robocasa/reproduce_v2/_logs
mkdir -p ${LOG_DIR}

cd /workspace/RLDX-1
START_TIME=$(date +%s)

for i in "${!TASKS[@]}"; do
    TASK="${TASKS[$i]}"
    PROGRESS="[$((i+1))/${#TASKS[@]}]"
    
    echo ""
    echo "==========================================="
    echo "===== ${PROGRESS} ${TASK} starting at $(date '+%H:%M:%S') ====="
    echo "===== n_action_steps=${N_ACTION_STEPS}, max_steps=${MAX_STEPS} ====="
    echo "==========================================="
    
    rldx/eval/sim/robocasa/robocasa_uv/.venv/bin/python \
        rldx/eval/rollout_policy.py \
            --n-episodes ${N_EPISODES} \
            --policy-client-host 127.0.0.1 --policy-client-port 5555 \
            --max-episode-steps ${MAX_STEPS} \
            --env-name "robocasa_panda_omron/${TASK}_PandaOmron_Env" \
            --n-action-steps ${N_ACTION_STEPS} --n-envs 1 \
            --video-dir output_final/robocasa/reproduce_v2/${TASK} \
        2>&1 | tee -a ${LOG_DIR}/${TASK}.log
    
    EXIT_CODE=${PIPESTATUS[0]}
    ELAPSED=$(($(date +%s) - START_TIME))
    HOURS=$((ELAPSED / 3600))
    MINUTES=$(((ELAPSED % 3600) / 60))
    
    if [ ${EXIT_CODE} -ne 0 ]; then
        echo "===== ${PROGRESS} ${TASK} FAILED (exit ${EXIT_CODE}), continuing ====="
        echo "${TASK}: FAILED exit=${EXIT_CODE}" >> ${LOG_DIR}/_status.log
    else
        echo "===== ${PROGRESS} ${TASK} done at $(date '+%H:%M:%S') (total: ${HOURS}h ${MINUTES}m) ====="
        echo "${TASK}: OK" >> ${LOG_DIR}/_status.log
    fi
done

echo ""
echo "===== ALL 24 TASKS PROCESSED at $(date) ====="
