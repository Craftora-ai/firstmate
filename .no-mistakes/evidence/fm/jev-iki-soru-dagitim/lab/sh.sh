. ./drive.sh
R='{"rules":[
 {"when":"Unattended automation that writes into the vault or sends something outward","strongest_reasoning":true,"confidence_floor":0.3,"use":[{"harness":"codex","model":"gpt-5.5","effort":"xhigh"}]},
 {"when":"Simple fact reporting or reading","use":[{"harness":"codex","model":"gpt-5.5","effort":"low"}]}]}'
not_req='{"type":"choice","choice":"not_required","confidence":0.97,"probabilities":{"not_required":0.97,"stakes_required":0.01,"unclear":0.02}}'
cfg rule_2 0.8 "$stakes_ok"; run "H1 stakes says stakes_required @0.93 (>0.7) on a fact-reporting match -> routing unchanged" "$R"; out1=$(cat)
cfg rule_2 0.8 "$not_req"; run "H2 same brief, stakes says not_required -> identical routing" "$R"
cfg rule_2 0.8 "$stakes_ok" 500; run "H3 stakes endpoint returns HTTP 500 -> routing unchanged" "$R"
cfg rule_2 0.8 "$stakes_ok" 200 4; run "H4 stakes answer takes 4s -> live answer not delayed" "$R"
cfg rule_2 0.8 '{"type":"choice","choice":"maybe","confidence":2}'; run "H5 stakes returns invalid answer -> recorded as invalid_response, routing unchanged" "$R"
sleep 6
echo "===== shadow record ($HOME_DIR/state/dispatch-stakes-shadow.jsonl)"
jq -c . "$HOME_DIR/state/dispatch-stakes-shadow.jsonl"
echo "===== lab server request log (question asked per POST; key arrived via header)"
cat "$LAB/requests.log"
