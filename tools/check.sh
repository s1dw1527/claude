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
exit $fail
