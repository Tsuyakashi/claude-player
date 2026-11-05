#!/usr/bin/env bash
# gen-hands.sh COUNT — агенты hands-1..COUNT, MCP horizon-bot-1..COUNT и horizon-server
set -euo pipefail
COUNT=${1:?usage: gen-hands.sh COUNT}
DIR=$(cd "$(dirname "$0")" && pwd)
V=${HORIZON_DIR:-$HOME/horizon-current}
RUN=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
TPL="$DIR/.claude/hands.md.tmpl"
OUT="$DIR/.claude/agents"

reg() { claude mcp remove -s user "$1" >/dev/null 2>&1 || true
        claude mcp add -s user "$1" -- "${@:2}" >/dev/null; }

mkdir -p "$OUT"
rm -f "$OUT"/hands-*.md
reg horizon-server "$V/horizon-server" --dir "$HOME/servers/coop" mcp

for n in $(seq 1 "$COUNT"); do
  nick=$([ "$n" = 1 ] && echo claude_bot || echo "claude_bot$n")
  sed -e "s/{{N}}/$n/g" -e "s/{{NICK}}/$nick/g" "$TPL" > "$OUT/hands-$n.md"
  reg "horizon-bot-$n" "$V/horizon-ctl" --socket "$RUN/horizon-bot$n.sock" mcp
done

for s in $(claude mcp list 2>/dev/null | grep -oE '^horizon-bot-[0-9]+'); do
  n=${s#horizon-bot-}
  [ "$n" -gt "$COUNT" ] && claude mcp remove -s user "$s" >/dev/null || true
done
echo "ok: hands-1..$COUNT, horizon-bot-1..$COUNT, horizon-server"
