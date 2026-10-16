#!/usr/bin/env bash
# 슬래시 명령(/team-kit:a, /team-kit:b)이 부르는 진입점. 출력과 종료 코드를 한 번에 돌려준다.
#   run-install.sh a|b <폴더> [옵션...]
mode="${1:-}"; shift || true
"$(dirname "$(readlink -f "$0")")/../install.sh" --mode "$mode" "$@" 2>&1
echo "(종료 코드 $?)"
