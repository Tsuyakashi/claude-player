#!/usr/bin/env bash
# bot.sh start|stop|restart|status [N] [name]
set -euo pipefail

V="${HORIZON_DIR:-$HOME/horizon-current}"
ROOT="${BOTS_DIR:-$HOME/bots}"
RUN="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SERVER="${HORIZON_SERVER:-127.0.0.1:25565}"
export DISPLAY="${DISPLAY:-:0}"
export MESA_VK_DEVICE_SELECT="${MESA_VK_DEVICE_SELECT:-10de:11e0!}"

usage() { echo "usage: $0 start|stop|restart N [name] | status [N]" >&2; exit 1; }

alive() { [[ -f "$ROOT/bot$1/pid" ]] && kill -0 "$(cat "$ROOT/bot$1/pid")" 2>/dev/null; }

start() {
  local n=$1 name=${2:-claude_bot$1} d="$ROOT/bot$1"
  alive "$n" && { echo "bot$n already running (pid $(cat "$d/pid"))"; return 0; }
  [[ -S /tmp/.X11-unix/X${DISPLAY#:} ]] || { echo "no X on $DISPLAY" >&2; return 1; }
  mkdir -p "$d/game" "$d/home"
  touch "$d/game/options.txt"
  set_opt() { grep -q "^$1:" "$d/game/options.txt" && sed -i "s/^$1:.*/$1:$2/" "$d/game/options.txt" || echo "$1:$2" >> "$d/game/options.txt"; }
  set_opt enableVsync false
  set_opt maxFps 10
  rm -f "$RUN/horizon-bot$n.sock"
  setsid "$V/horizon-client" \
    --resources "$V/.local/horizon-client/26.3" \
    --control --control-socket "$RUN/horizon-bot$n.sock" \
    --name "$name" --server "$SERVER" \
    --game-dir "$d/game" --home "$d/home" \
    --render-distance 2 --width 640 --height 360 \
    >"$d/client.log" 2>&1 < /dev/null &
  echo $! > "$d/pid"
  echo "bot$n ($name) started, pid $!, log $d/client.log"
}

stop() {
  local n=$1 d="$ROOT/bot$1"
  alive "$n" || { echo "bot$n not running"; rm -f "$d/pid"; return 0; }
  local p; p=$(cat "$d/pid")
  kill "$p"
  for _ in $(seq 20); do kill -0 "$p" 2>/dev/null || break; sleep 0.5; done
  kill -0 "$p" 2>/dev/null && kill -9 "$p"
  rm -f "$d/pid" "$RUN/horizon-bot$n.sock"
  echo "bot$n stopped"
}

status() {
  local list
  if [[ -n ${1:-} ]]; then list=$1; else list=$(ls -d "$ROOT"/bot* 2>/dev/null | sed 's/.*bot//' | sort -n); fi
  for n in $list; do
    if alive "$n"; then
      local p; p=$(cat "$ROOT/bot$n/pid")
      printf 'bot%-3s running  pid %-7s rss %4d MB  socket %s\n' "$n" "$p" \
        $(( $(ps -o rss= -p "$p") / 1024 )) \
        "$([[ -S $RUN/horizon-bot$n.sock ]] && echo ok || echo missing)"
    else
      printf 'bot%-3s stopped\n' "$n"
    fi
  done
}

case "${1:-}" in
  start)   [[ -n ${2:-} ]] || usage; start "$2" "${3:-}" ;;
  stop)    [[ -n ${2:-} ]] || usage; stop "$2" ;;
  restart) [[ -n ${2:-} ]] || usage; stop "$2"; start "$2" "${3:-}" ;;
  status)  status "${2:-}" ;;
  *) usage ;;
esac
