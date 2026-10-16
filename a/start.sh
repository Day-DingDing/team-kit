#!/usr/bin/env bash
# A 방식: PM(리드) 세션을 tmux 안에서 연다. 팀원이 생기면 창이 나뉜다.
# 처음 실행할 때 PM 세션 번호를 .claude/pm-session-id 에 저장하고, 다음부터는 그 번호로 PM 대화를 다시 연다
# (claude -c 는 "가장 최근 대화"를 열기 때문에 팀원 대화가 열릴 수 있다).
#   ./start.sh            PM 열기 (이어서)
#   ./start.sh --detach   띄우기만 하고 붙지 않기
cd "$(dirname "$0")" || exit 1
name=$(basename "$PWD"); id_file=.claude/pm-session-id
perm=$(python3 -c 'import json;print(json.load(open("team.json")).get("permission_mode","default"))' 2>/dev/null || echo default)
if tmux has-session -t "$name" 2>/dev/null; then [ "${1:-}" = "--detach" ] && exit 0; exec tmux attach -t "$name"; fi
if [ -s "$id_file" ]; then cmd="claude --permission-mode $perm --resume $(cat "$id_file")"
else id=$(python3 -c 'import uuid; print(uuid.uuid4())'); echo "$id" > "$id_file"; cmd="claude --permission-mode $perm --session-id $id"; fi
tmux new-session -d -s "$name" -x 230 -y 60 "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 $cmd"
[ "${1:-}" = "--detach" ] || exec tmux attach -t "$name"
