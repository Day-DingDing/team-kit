#!/usr/bin/env bash
# 키트를 받은 뒤 한 번 실행한다 (다시 실행해도 된다).
#   ./setup.sh               명령 team-kit-a, team-kit-b 등록 + B 방식용 session-link 플러그인 설치
#   ./setup.sh --no-plugin   명령만 등록 (A 방식만 쓸 때)
# 명령은 ~/.local/bin 에 이 폴더를 가리키는 링크로 만든다. 키트 폴더를 옮기면 다시 실행한다.
set -euo pipefail
KIT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
plugin=1; [ "${1:-}" = "--no-plugin" ] && plugin=0

for c in git python3 tmux claude gh; do command -v "$c" >/dev/null || echo "알림: $c 가 없습니다 (gh 는 GitHub 저장소를 만들 때만 필요)"; done

bin="$HOME/.local/bin"; mkdir -p "$bin"
chmod +x "$KIT"/install.sh "$KIT"/bin/* "$KIT"/a/start.sh "$KIT"/b/start.sh "$KIT"/b/tools/*.sh
for m in a b; do ln -sfn "$KIT/bin/team-kit-$m" "$bin/team-kit-$m"; done
echo "명령 등록: $bin/team-kit-a, $bin/team-kit-b"
case ":$PATH:" in *":$bin:"*) ;; *) echo "알림: $bin 이 PATH 에 없습니다. ~/.bashrc 에 추가하세요: export PATH=\"\$HOME/.local/bin:\$PATH\"";; esac

if [ "$plugin" = 1 ]; then
  if ! command -v claude >/dev/null; then echo "claude 가 없어 플러그인 설치를 건너뜁니다."; exit 0; fi
  if claude plugin list 2>/dev/null | grep -A4 "session-link@" | grep -q enabled; then
    echo "session-link 플러그인이 이미 켜져 있습니다. 설치를 건너뜁니다."
  else
    claude plugin marketplace list 2>/dev/null | grep -q "team-kit" || claude plugin marketplace add "$KIT"
    claude plugin install session-link@team-kit
    echo "session-link 설치 완료. 이미 열려 있는 Claude Code 세션은 /reload-plugins 를 실행하거나 다시 여세요."
  fi
fi
