. ./drive.sh
R='{"rules":[{"when":"Unattended automation","strongest_reasoning":true,"confidence_floor":0.3,"use":[{"harness":"codex","model":"gpt-5.5","effort":"xhigh"}]},{"when":"Simple fact reporting or reading","use":[{"harness":"codex","model":"gpt-5.5","effort":"low"}]}]}'
cfg rule_2 0.8 "$stakes_ok" 200 4; run "H4 (threaded server) stakes answer takes 4s -> live answer not delayed" "$R"
echo "records immediately after live exit: $(wc -l < "$HOME_DIR/state/dispatch-stakes-shadow.jsonl" 2>/dev/null || echo 0)"
cfg rule_2 0.8 '{"type":"choice","choice":"maybe","confidence":2}'; run "H5 (threaded server) invalid stakes answer -> routing unchanged" "$R"
cfg rule_2 0.8 "$stakes_ok" 200 8; run "H6 stakes hangs past the 5s curl bound -> live unaffected, recorded as transport error" "$R"
sleep 9
jq -c '{stakes:.stakes, live:.live}' "$HOME_DIR/state/dispatch-stakes-shadow.jsonl"
