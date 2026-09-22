. ./drive.sh
R='{"rules":[{"when":"A","confidence_floor":0.8,"use":[{"harness":"codex","model":"gpt-5.5","effort":"low"}]}]}'
one() { jq -n --argjson conf "$1" --argjson s "$stakes_ok" '{rule:{type:"choice",choice:"rule_1",confidence:$conf,probabilities:{rule_1:0.9,default:0.1}},stakes:{answer:$s}}' > "$LAB/server.json"; }
one 0.7; run "C6 raised floor 0.8 without declaration -> legal; 0.7 refused by the raised floor" "$R"
one 0.85; run "C6' raised floor 0.8, confidence 0.85 -> clear" "$R"
