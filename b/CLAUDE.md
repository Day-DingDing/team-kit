# 팀 프로젝트 B — 공통 안내 (모든 역할 세션에 로드됨)

이 저장소는 **역할마다 독립된 Claude Code 세션**이 session-link로 협업하는 방식(B)이다.
- 각 세션은 `roles/<주소>/` 폴더에서 실행되고, 그 폴더의 `CLAUDE.md`가 자기 역할이다.
- 작업 공간(코드·문서)은 이 저장소 루트다. 문서 경로는 모두 루트 기준이다.
- 공통 규칙: `docs/conventions.md`. 양식: `docs/templates/`. 작업판: `docs/board.md`.
- 세션 주소: `session-link.json`의 peers (기본 pm, planner, designer, architect, developer, qa, security, compliance, infra. 진행 중 추가될 수 있음).
- 사용자는 pm 세션하고만 대화한다. 다른 세션은 pm과 동료 세션의 메시지로 일한다.
