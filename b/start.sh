#!/usr/bin/env bash
# B 방식: tmux 세션 하나에 창 두 개를 띄운다.
#   창 0 "pm"   : PM(총괄) 세션 — 사용자는 여기서만 대화한다
#   창 1 "team" : 역할 세션 7개 (planner designer developer qa security compliance infra)
# 처음 여는 폴더는 칸마다 "신뢰" 확인을 한 번 눌러야 한다. --detach 를 주면 띄우기만 하고 붙지 않는다.
cd "$(dirname "$0")" || exit 1
ROOT="$PWD"; name=$(basename "$ROOT")
perm=$(python3 -c 'import json;print(json.load(open("team.json")).get("permission_mode","default"))' 2>/dev/null || echo default)
if tmux has-session -t "$name" 2>/dev/null; then [ "${1:-}" = "--detach" ] && exit 0; exec tmux attach -t "$name"; fi
model() { cat "$ROOT/roles/$1/.model" 2>/dev/null || echo opus; }
tmux new-session -d -s "$name" -n pm -x 240 -y 60 -c "$ROOT/roles/pm" "claude --permission-mode $perm --model $(model pm)"
first=1
for r in $(ls "$ROOT/roles" | grep -v "^pm$\|^_"); do
  [ -d "$ROOT/roles/$r" ] || continue
  if [ $first = 1 ]; then tmux new-window -t "$name" -n team -c "$ROOT/roles/$r" "claude --permission-mode $perm --model $(model $r)"; first=0
  else tmux split-window -t "$name:team" -c "$ROOT/roles/$r" "claude --permission-mode $perm --model $(model $r)"; tmux select-layout -t "$name:team" tiled >/dev/null; fi
done
tmux select-window -t "$name:pm"
[ "${1:-}" = "--detach" ] || exec tmux attach -t "$name"
