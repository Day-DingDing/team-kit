#!/usr/bin/env bash
# PreToolUse 훅 (exit 2 = 차단)
#  Edit|Write: .env·키 파일 수정 차단, 양식(docs/templates) 수정 차단, 이미 있는 docs/*.md 통째 덮어쓰기 차단
#  Bash: 강제 push, 기록 지우기(reset --hard, push --delete), 원격 저장소 변경 차단
input=$(cat)
eval "$(printf '%s' "$input" | python3 -c '
import json, shlex, sys
d = json.load(sys.stdin); t = d.get("tool_input", {})
print("tool=" + shlex.quote(d.get("tool_name", "")))
print("file_path=" + shlex.quote(t.get("file_path", "")))
print("command=" + shlex.quote(t.get("command", "")))
' 2>/dev/null)"

if [[ "$tool" == "Edit" || "$tool" == "Write" ]]; then
  name=$(basename "$file_path")
  for p in ".env" ".env.*" "*.pem" "*.key"; do
    # shellcheck disable=SC2053
    [[ "$name" == $p && "$name" != ".env.example" ]] && { echo "차단됨: '$name' 은(는) 비밀 정보 파일입니다." >&2; exit 2; }
  done
  if [[ "$file_path" == */docs/templates/* ]]; then
    echo "차단됨: 양식(docs/templates)은 사용자만 고칩니다. 양식을 복사해 산출물 위치에 새로 만드세요." >&2; exit 2
  fi
  # 이미 있는 문서는 통째로 덮어쓰지 않는다: Edit로 고치고 버전·변경 이력을 남긴다 (작업판은 예외)
  if [[ "$tool" == "Write" && -e "$file_path" && "$file_path" == */docs/*.md && "$file_path" != */docs/board.md ]]; then
    echo "차단됨: '$name' 은(는) 이미 있는 문서입니다. Write로 덮어쓰지 말고 Edit로 고친 뒤, 버전을 올리고 변경 이력에 한 줄 남기세요." >&2; exit 2
  fi
fi

if [[ "$tool" == "Bash" ]]; then
  if printf '%s' "$command" | grep -qE 'git\s+push\s+.*(--force|-f\b|--delete|\+[A-Za-z])|git\s+reset\s+--hard|git\s+remote\s+(set-url|remove|rm|add)|gh\s+repo\s+(delete|edit\s+.*--visibility)'; then
    echo "차단됨: 강제 push·기록 삭제·원격 저장소 변경은 사용자가 직접 합니다. 필요하면 총괄이 사용자에게 요청하세요." >&2; exit 2
  fi
fi
exit 0
