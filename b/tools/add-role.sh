#!/usr/bin/env bash
# B 방식: 역할 세션을 추가한다 (진행 중에도 가능).
#   ./tools/add-role.sh <id> <커밋 접두어> <model> "<하는 일>" [산출물 경로(docs 기준)...]
#   예) ./tools/add-role.sh writer 문서 sonnet "사용자 설명서와 API 문서 작성" 10-docs/user-guide.md
# 하는 일: team.json·session-link.json 에 추가, roles/<id>/ (CLAUDE.md, 설정, 모델) 생성,
#          tmux 가 떠 있으면 team 창에 새 칸을 연다 (처음 한 번 "신뢰" 확인 필요).
set -euo pipefail
cd "$(dirname "$0")/.."; ROOT="$PWD"; name=$(basename "$ROOT")
perm=$(python3 -c 'import json;print(json.load(open("team.json")).get("permission_mode","default"))' 2>/dev/null || echo default)
[ $# -lt 4 ] && { sed -n '2,6p' "$0"; exit 1; }
id="$1"; prefix="$2"; model="$3"; desc="$4"; shift 4
[[ "$id" =~ ^[a-z][a-z0-9-]*$ ]] || { echo "id는 영문 소문자로 시작" >&2; exit 1; }
[ -e "roles/$id" ] && { echo "이미 있는 역할: $id" >&2; exit 1; }
python3 - "$ROOT" "$id" "$prefix" "$model" "$desc" "$@" <<'PY'
import json, os, sys
root, rid, prefix, model, desc, *deliv = sys.argv[1:]
team = json.load(open(f"{root}/team.json", encoding="utf-8"))
if any(r["prefix"] == prefix for r in team["roles"]):
    sys.exit(f"이미 쓰는 접두어: {prefix}")
team["roles"].append({"id": rid, "prefix": prefix, "model": model, "aliases": [prefix], "deliverables": deliv})
json.dump(team, open(f"{root}/team.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
sl = json.load(open(f"{root}/session-link.json", encoding="utf-8"))
sl["peers"].append({"id": rid, "label": prefix, "dir": f"roles/{rid}", "aliases": [prefix], "role": desc})
json.dump(sl, open(f"{root}/session-link.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
d = f"{root}/roles/{rid}"; os.makedirs(f"{d}/.claude")
common = open(f"{root}/roles/_common.md", encoding="utf-8").read()
out = "\n".join(f"- `docs/{x}`" for x in deliv) or "- (총괄과 정한다)"
body = f"""# B 역할 세션: {rid}

너는 이 프로젝트의 {prefix} 담당이다. 커밋 접두어는 `[{prefix}]`.
하는 일: {desc}
산출물:
{out}
- 양식이 `docs/templates/`에 없으면 다른 산출물 양식(메타 표 + 변경 이력)을 본떠 만든다.
"""
open(f"{d}/CLAUDE.md", "w", encoding="utf-8").write(body + "\n" + common.replace("{id}", rid).replace("{prefix}", prefix).replace("{root}", root))
open(f"{d}/.model", "w").write(model + "\n")
json.dump({"permissions": {"additionalDirectories": [root]},
           "hooks": {"PreToolUse": [{"matcher": "Edit|Write|Bash", "hooks": [{"type": "command", "command": f"{root}/.claude/hooks/guard.sh"}]}]}},
          open(f"{d}/.claude/settings.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(f"역할 추가: {rid} [{prefix}] ({model})")
PY
if tmux has-session -t "$name" 2>/dev/null; then
  tmux split-window -t "$name:team" -c "$ROOT/roles/$id" "claude --permission-mode $perm --model $model"; tmux select-layout -t "$name:team" tiled >/dev/null
  echo "tmux $name:team 창에 새 칸을 열었습니다. 그 칸에서 \"신뢰\" 확인을 한 번 눌러 주세요."
fi
echo "다음: git add team.json session-link.json roles/$id && git commit -m \"[총괄] 역할 추가: $id\" (PM이 커밋)"
