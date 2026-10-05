#!/bin/bash
# Syntax-compile every script and run the Roblox-aware type checker, hiding style-only noise.
T=${LUAU_TOOLS:-/tmp/claude-0/-home-user-claude/8ab8267c-f21d-5159-b6c6-de5701660394/scratchpad/tools}
DIR=${1:-src}
fail=0
for f in $(find "$DIR" -name '*.lua'); do
  if ! out=$($T/luau-compile --null "$f" 2>&1); then echo "COMPILE FAIL $f: $out"; fail=1; fi
done
$T/luau-lsp analyze --definitions=$T/globalTypes.d.luau --platform=roblox "$DIR" 2>&1 \
  | grep -v -E "SameLineStatement|LocalUnused|LocalShadow|FunctionUnused|ImportUnused|not found in table|MultiLineStatement|TableOperations|ImplicitReturn" \
  | grep -v "^$" || true
# v10: reading a global the script never defined (e.g. a local table used inside its own constructor) is a bug
ROBLOX='task|Enum|Color3|UDim2|UDim|CFrame|Vector3|Vector2|TweenInfo|Instance|game|workspace|Ray|RaycastParams|NumberSequence|NumberSequenceKeypoint|NumberRange|ColorSequence|ColorSequenceKeypoint|PhysicalProperties|Random|typeof|tick|utf8|warn|BrickColor|Rect|OverlapParams|Font|DateTime|Region3|PathWaypoint|Faces|Axes|script|delay|spawn|wait|shared|settings|elapsedTime|time|SharedTable|buffer'
globals=$($T/luau-analyze --mode=nonstrict $(find "$DIR" -name '*.lua') 2>&1 | grep "Unknown global" | grep -v -E "Unknown global '($ROBLOX)'")
if [ -n "$globals" ]; then echo "UNKNOWN GLOBALS:"; echo "$globals"; fail=1; fi
exit $fail
