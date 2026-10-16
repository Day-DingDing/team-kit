
## B 방식 세션 공통
- 이 세션의 주소는 `{id}`다. 작업 공간은 저장소 루트 `{root}`이고, 명령은 그 폴더에서 실행한다 (`cd {root} && ...`).
- 다른 세션 주소는 저장소 루트 `session-link.json`의 peers(또는 `/links`)에 있다. 기본은 pm(총괄), planner, designer, architect, developer, qa, security, compliance, infra이고 진행 중에 추가될 수 있다. 보낼 때는 SendMessage(to: "<주소>").
- PM의 지시나 동료의 요청을 받으면 처리하고, 결과를 보낸 세션에 회신한다. 할 일이 없으면 턴을 끝내고 기다린다. 메시지는 비동기다.
- 총괄에게 보낼 때 주소는 `pm`이다 (에이전트 팀 방식의 `team-lead`가 아님).
