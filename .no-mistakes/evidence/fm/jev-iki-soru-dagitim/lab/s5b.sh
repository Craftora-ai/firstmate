. ./drive.sh
R='{"rules":[
 {"when":"Unattended automation that writes into the vault or sends something outward","strongest_reasoning":true,"confidence_floor":0.3,"use":[{"harness":"codex","model":"gpt-5.5","effort":"xhigh"}]},
 {"when":"Simple fact reporting or reading","use":[{"harness":"codex","model":"gpt-5.5","effort":"low"}]}],
 "default":[{"harness":"codex","model":"gpt-5.5","effort":"low"}]}'
cfg rule_1 null "$stakes_ok"; run "S5b strongest rule (declared, floor 0.3) with NO confidence -> moves up (clear)" "$R"
cfg rule_2 null "$stakes_ok"; run "S6b weaker rule with NO confidence -> ambiguous" "$R"
R2='{"rules":[
 {"when":"Unattended automation","strongest_reasoning":true,"use":[{"harness":"codex","model":"gpt-5.5","effort":"xhigh"}]},
 {"when":"Simple fact reporting or reading","use":[{"harness":"codex","model":"gpt-5.5","effort":"low"}]}]}'
cfg rule_1 null "$stakes_ok"; run "S5c strongest declaration WITHOUT lowered floor + NO confidence -> no waiver" "$R2"
