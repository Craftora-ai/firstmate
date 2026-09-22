. ./drive.sh
cfg rule_1 0.95 "$stakes_ok"
run "C1 below-default floor (0.3) WITHOUT strongest_reasoning -> refused as malformed" '{"rules":[{"when":"Fact reporting","confidence_floor":0.3,"use":[{"harness":"codex","model":"gpt-5.5","effort":"low"}]}]}'
run "C2 two strongest_reasoning rules naming DIFFERENT profile sets -> refused" '{"rules":[{"when":"A","strongest_reasoning":true,"confidence_floor":0.3,"use":[{"harness":"claude","model":"opus"}]},{"when":"B","strongest_reasoning":true,"confidence_floor":0.3,"use":[{"harness":"codex","model":"gpt-5.5","effort":"low"}]}]}'
run "C3 two strongest_reasoning rules naming the SAME set -> accepted" '{"rules":[{"when":"A","strongest_reasoning":true,"confidence_floor":0.3,"use":[{"harness":"codex","model":"gpt-5.5","effort":"xhigh"}]},{"when":"B","strongest_reasoning":true,"use":[{"harness":"codex","model":"gpt-5.5","effort":"xhigh"}]}]}'
run "C4 strongest_reasoning as string -> refused" '{"rules":[{"when":"A","strongest_reasoning":"true","confidence_floor":0.3,"use":[{"harness":"codex","model":"gpt-5.5"}]}]}'
run "C5 confidence_floor as numeric string -> refused" '{"rules":[{"when":"A","confidence_floor":"0.7","use":[{"harness":"codex","model":"gpt-5.5"}]}]}'
run "C6 raised floor 0.8 without declaration -> legal" '{"rules":[{"when":"A","confidence_floor":0.8,"use":[{"harness":"codex","model":"gpt-5.5","effort":"low"}]}]}'
echo "shadow records written by refused configs: $(cat "$HOME_DIR/state/dispatch-stakes-shadow.jsonl" 2>/dev/null | wc -l)"
