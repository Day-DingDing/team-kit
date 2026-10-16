---
description: 팀 키트 A 방식(에이전트 팀: PM 세션 하나가 팀원을 만든다)을 지정한 폴더에 설치한다
argument-hint: <설치할 폴더> [--prd <PRD 파일>] [--no-github] [--repo <GitHub 저장소 이름>]
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run-install.sh:*)
disable-model-invocation: true
---
## 설치 실행 결과
!`${CLAUDE_PLUGIN_ROOT}/scripts/run-install.sh a $ARGUMENTS`

위는 팀 키트 설치 스크립트를 실행한 결과다. 사용자에게 한국어 평서문 존댓말로 짧게 보고한다.
- 종료 코드가 0이면: 설치된 폴더, git 커밋, GitHub 저장소(만들었으면 주소)를 알리고, 출력의 "다음 순서"를 그대로 안내한다.
- 0이 아니면: 출력에 나온 이유를 그대로 전하고 해결 방법을 한 줄로 안내한다. 폴더 인자가 없어서 사용법이 나온 경우에는 `/team-kit:a <설치할 폴더>` 형태를 예로 보여 준다.
- 설치를 다시 실행하거나, 실패를 우회하려고 파일을 직접 고치거나, 다른 작업을 이어서 하지 않는다.
