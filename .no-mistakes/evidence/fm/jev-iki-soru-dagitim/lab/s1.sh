. ./drive.sh
cfg rule_1 0.35 "$stakes_ok"; run "S1 strongest-class rule (declared, floor 0.3) matched at 0.35 -> moves UP" "$GOOD_RULES"
cfg rule_2 0.35 "$stakes_ok"; run "S2 weaker rule (no declaration, global floor) matched at 0.35 -> refused" "$GOOD_RULES"
cfg rule_2 0.59 "$stakes_ok"; run "S3 weaker rule at 0.59 (17-Sept case) -> refused" "$GOOD_RULES"
cfg rule_2 0.65 "$stakes_ok"; run "S4 weaker rule at 0.65 -> clears" "$GOOD_RULES"
cfg rule_1 null "$stakes_ok"; run "S5 strongest rule with NO confidence -> may move up" "$GOOD_RULES"
cfg rule_2 null "$stakes_ok"; run "S6 weaker rule with NO confidence -> never moves down" "$GOOD_RULES"
cfg default null "$stakes_ok"; run "S7 default match with NO confidence -> no waiver" "$GOOD_RULES"
cfg rule_1 0.29 "$stakes_ok"; run "S8 strongest rule below its own 0.3 floor -> refused" "$GOOD_RULES"
