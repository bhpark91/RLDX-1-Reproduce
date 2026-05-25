#!/bin/bash
cd /workspace/RLDX-1

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

echo "task,category,success,total,rate_pct,avg_steps,max_steps,task_time_sec,per_step_ms" > results_v2.csv

for TASK in "${TASKS[@]}"; do
    DIR=output_final/robocasa/reproduce_v2/$TASK
    CSV=$DIR/simulation_results.csv
    LOG=output_final/robocasa/reproduce_v2/_logs/${TASK}.log
    if [ ! -f "$CSV" ]; then continue; fi
    
    S=$(find "$DIR" -name "*success*" 2>/dev/null | wc -l)
    C=$(find "$DIR" -name "*.mp4" 2>/dev/null | wc -l)
    [ $C -eq 0 ] && continue
    RATE=$((S * 100 / C))
    
    if [[ $TASK == Turn* ]]; then CAT="Turn"
    elif [[ $TASK == PnP* ]]; then CAT="PnP"
    elif [[ $TASK == Open* ]]; then CAT="Open"
    elif [[ $TASK == Close* ]]; then CAT="Close"
    elif [[ $TASK == Coffee* ]]; then CAT="Coffee"
    else CAT="Other"; fi
    
    AVG_STEPS=$(awk -F, 'NR>1 {sum+=$5; n++} END {if(n>0) printf "%.1f", sum/n}' "$CSV")
    MAX_STEPS=$(awk -F, 'NR>1 {if($5>max)max=$5} END {print max}' "$CSV")
    
    # task 전체 시간 추출 (log에서 "Collecting X episodes took Y seconds")
    TASK_TIME=$(grep -oP 'took \K[0-9.]+' "$LOG" 2>/dev/null | tail -1)
    [ -z "$TASK_TIME" ] && TASK_TIME=0
    
    # per-step time 계산 (전체 시간 / 총 step 수)
    if (( $(echo "$TASK_TIME > 0" | bc -l) )); then
        TOTAL_STEPS=$(awk -F, 'NR>1 {sum+=$5} END {print sum}' "$CSV")
        PER_STEP_MS=$(echo "scale=1; $TASK_TIME * 1000 / $TOTAL_STEPS" | bc -l)
    else
        PER_STEP_MS=0
    fi
    
    echo "$TASK,$CAT,$S,$C,$RATE,$AVG_STEPS,$MAX_STEPS,$TASK_TIME,$PER_STEP_MS" >> results_v2.csv
done

echo "=============================================="
echo "  RLDX-1 RoboCasa Reproduce v2 — Results"
echo "  Setup: RTX 3090, --n-action-steps 16 --max-episode-steps 720"
echo "=============================================="
echo ""
echo "===== Task별 결과 ====="
column -s, -t results_v2.csv | head -25
echo ""

echo "===== 카테고리별 ====="
awk -F, 'NR>1 {sum[$2]+=$3; tot[$2]+=$4} 
         END {for (c in sum) printf "  %-8s %4d/%4d  %3d%%\n", c, sum[c], tot[c], sum[c]*100/tot[c]}' \
    results_v2.csv | sort

echo ""
echo "===== 전체 ====="
awk -F, 'NR>1 {s+=$3; t+=$4} END {printf "  v2:                %d / %d = %.1f%%\n", s, t, s*100/t}' results_v2.csv
echo "  v1 (이전):         749 / 1200 = 62.4%"
echo "  RLWRLD 보고치:                  70.6%"

echo ""
echo "===== Latency 추정 (full pipeline: inference + sim + render) ====="
awk -F, 'NR>1 && $9>0 {sum+=$9; n++} END {if(n>0) printf "  평균 per-step time: %.1f ms (n=%d tasks)\n", sum/n, n}' results_v2.csv
echo "  비교: 보고서 §6-1 RTX 5090 (pure inference): 43.7 ms/step"
