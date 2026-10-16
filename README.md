# team-kit — PRD 하나로 시작하는 팀 프로젝트 키트 (A·B 두 방식)

PRD(요구사항 초안) 파일 하나를 넣으면 총괄(PM)이 이를 분석해 요구사항 문서를 만들고, 사용자에게 확인을 받습니다. 그다음 팀을 꾸려 기획, 디자인, 설계, 구현, 테스트, 보안·준법 점검, 배포 준비, 출시 판정까지 진행합니다.
사용자는 **PM하고만** 대화합니다. 결과물은 개인 GitHub **비공개** 저장소에 `[역할]` 접두어를 붙인 커밋으로 쌓이고, 회의록·결정·작업 기록·테스트 결과는 모두 문서로 남습니다.

작성일: 2026-10-15 / 기준: Claude Code 2.1.300

---

## 빠른 시작 (Claude Code 안에서)
PC마다 한 번 플러그인을 설치합니다.
```
/plugin install team-kit --marketplace Day-DingDing/team-kit
/plugin install session-link@team-kit          ← B 방식을 쓸 때만
```
그다음 원하는 폴더를 지정해 설치합니다. 폴더는 지금 세션의 폴더 기준 상대 경로나 절대 경로로 씁니다.
```
/team-kit:a ~/work/my-app --prd ~/my-prd.md     ← A 방식 (에이전트 팀)
/team-kit:b ~/work/my-app2 --prd ~/my-prd.md    ← B 방식 (세션 연결)
```
설치가 끝나면 터미널에서 `~/work/my-app/start.sh`로 엽니다. 그다음 PM에게 **"docs/prd 의 PRD로 프로젝트를 시작해"**라고 입력합니다.

- 명령은 반드시 `team-kit:` 이름공간을 붙여서 씁니다. 시험해 보니 `/a`나 `/team-kit-a`처럼 이름공간 없이 입력하면 명령으로 인식되지 않았습니다.
- 저장소가 비공개라서 GitHub 인증이 필요합니다. `gh auth login`과 `gh auth setup-git`을 해 두면 됩니다.
- 이미 열려 있는 세션에는 설치한 플러그인이 바로 적용되지 않습니다. `/reload-plugins`를 실행하거나 세션을 다시 엽니다.
- 키트를 최신으로 받으려면 `/plugin marketplace update team-kit`을 실행한 뒤 `/reload-plugins`를 실행합니다.

## 시작하기

### 0단계. (다른 방법) 셸 명령으로 쓰기
Claude Code 밖의 터미널에서 쓰려면 저장소를 받아 `setup.sh`를 실행합니다.
```bash
git clone https://github.com/Day-DingDing/team-kit.git <받을 폴더>
<받을 폴더>/setup.sh               # 명령 등록 + B용 session-link 설치
<받을 폴더>/setup.sh --no-plugin   # 명령만 등록 (A 방식만 쓸 때)
team-kit-a ~/work/my-app --prd ~/my-prd.md
```
- `setup.sh`는 `~/.local/bin`에 `team-kit-a`, `team-kit-b` 명령을 만듭니다. 받은 폴더를 가리키는 링크입니다.
  - `~/.local/bin`이 PATH에 없으면 추가할 줄을 알려 줍니다.
  - 키트 폴더를 옮겼다면 다시 실행합니다.
- 이미 켜져 있는 session-link가 있으면 플러그인 설치는 건너뜁니다.
- 슬래시 명령(`/team-kit:a`)과 셸 명령(`team-kit-a`)은 같은 `install.sh`를 실행합니다. 옵션도 같습니다.

### 1단계. 준비물 점검
설치 명령(`/team-kit:a`, `/team-kit:b`, `team-kit-a`, `team-kit-b`)은 시작할 때 아래 항목을 점검합니다. 빠진 것이 있으면 목록을 보여 주고 멈춥니다.

| 준비물 | 필요한 경우 | 확인 방법 |
|---|---|---|
| Claude Code (2.1.300 이상), claude.ai 로그인 | 항상 | `claude --version` |
| git, python3, tmux | 항상 | `command -v tmux` |
| gh (GitHub CLI) 로그인 | GitHub 저장소를 만들 때 (`--no-github`이면 필요 없음) | `gh auth status` |
| session-link 플러그인 | **B 방식일 때만** (`/plugin install session-link@team-kit` 또는 `setup.sh`) | `claude plugin list`에 `session-link@…`이 `enabled`로 보이는지 |
| Claude Design 사용 권한 | 화면이 있는 프로젝트 (디자인 담당이 시안을 만들 때) | claude.ai 계정에서 Design 유형을 쓸 수 있는지 |

B 방식을 쓰려면 session-link를 설치해야 합니다. 방법은 `/plugin install session-link@team-kit` 또는 `setup.sh`입니다. 설치한 뒤 이미 열려 있는 Claude Code 세션에는 바로 적용되지 않습니다. 그 세션에서 `/reload-plugins`를 실행하거나 세션을 다시 여세요.

### 2단계. 권한 설정 이해하기 (중요)
팀원들은 확인을 기다리지 않고 진행해야 합니다. 그래서 생성되는 프로젝트의 `team.json`에 아래 값을 넣어 두었습니다.
```json
"permission_mode": "bypassPermissions"
```
`start.sh`와 `tools/add-role.sh`는 이 값을 읽어 `claude --permission-mode bypassPermissions`로 세션을 엽니다.
이 값이 없으면 칸마다 "이 명령을 실행할까요?" 확인 창이 떠서 진행이 멈춥니다. B 방식은 최대 9개 칸이 동시에 멈춥니다.

> `.claude/settings.json`에 `"defaultMode": "bypassPermissions"`를 넣는 방법은 쓰지 않습니다. Claude Code는 공유 프로젝트 설정에 들어 있는 이 값을 오류 없이 무시합니다(공식 문서 permission-modes). 그래서 실행 옵션으로 넘깁니다.

이 설정의 의미는 다음과 같습니다.
- `start.sh`로 연 세션은 파일 수정과 명령 실행을 **묻지 않고** 진행합니다.
- 키트의 가드 훅(`.claude/hooks/guard.sh`)은 계속 동작합니다. 가드 훅이 막는 것:
  - `.env`·키 파일
  - 양식 수정
  - 기존 문서 덮어쓰기
  - 강제 push, `reset --hard`, 원격 저장소 변경
- 권한 확인 생략 모드를 처음 켤 때 경고 확인 창이 한 번 나옵니다. 수락하면 사용자 설정에 기록되어 다음부터는 나오지 않습니다. 폴더마다 "이 폴더를 신뢰합니까?" 확인도 처음 한 번 나옵니다.
- B 방식에서 역할 칸을 직접 다시 열 때는 옵션을 붙입니다: `cd roles/qa && claude -c --permission-mode bypassPermissions`
- 확인을 받으면서 진행하려면 `team.json`의 값을 `"default"`로 바꿉니다. 이때는 사람이 각 칸을 지켜보며 승인해야 합니다.
- **믿을 수 없는 PRD나 외부 코드를 넣은 프로젝트에서는 쓰지 마세요.** 문서 속 지시가 확인 없이 실행될 수 있습니다.

### 3단계. A와 B 중 고르기
| | **A 방식 (에이전트 팀)** | **B 방식 (세션 연결)** |
|---|---|---|
| 구조 | PM 세션 하나가 팀원을 만든다 (Claude Code 실험 기능 Agent Teams) | 역할마다 독립 세션(`roles/<역할>/`)을 띄우고 session-link로 연결한다 |
| 화면 | tmux 한 창. 팀원이 생기면 칸이 나뉜다 | tmux 창 0 = PM, 창 1 = 역할 칸 여러 개 |
| 추가 준비 | 없음 | session-link 플러그인 |
| 다시 열기 | `./start.sh` (저장해 둔 PM 대화가 열림). 팀원은 복원되지 않아 PM이 다시 만든다 | 역할마다 자기 대화가 그대로 이어진다 (`roles/<역할>`에서 `claude -c`) |
| 팀원 기록 조회 | PM에게 물으면 `tools/team-history.py`로 찾아 준다 | 같은 도구 + 역할 세션에 직접 들어가 물을 수 있다 |
| 진행 중 역할 추가 | PM에게 말하면 팀원을 만든다 | PM이 `tools/add-role.sh`로 칸을 추가한다 (새 칸에 신뢰 확인 1회) |
| 실험 결과 (회의실 예약, 9역할) | 85분, 출력 토큰 약 87만 | 76분, 출력 토큰 약 100만 |
| 실험 결과 (비품 대여, 3역할) | 27분 | 20분 |
| 맞는 경우 | 처음 써 볼 때, 한 번에 끝낼 프로젝트, 준비를 줄이고 싶을 때 | 여러 날에 걸친 프로젝트, 역할별 대화를 나중에 직접 이어 가야 할 때 |

두 방식의 문서 품질과 점검 결과(check-docs 전 항목 통과)는 실험에서 같았습니다. 잘 모르겠으면 **A**로 시작하세요.

### 4단계. 설치하고 실행
```bash
/team-kit:a ~/work/my-app --prd ~/my-prd.md      # A 방식 + GitHub 비공개 저장소 my-app
/team-kit:b ~/work/my-app --prd ~/my-prd.md      # B 방식
/team-kit:a ./my-app --no-github                 # GitHub 없이 로컬만
/team-kit:a ~/work/my-app --repo my-app-2026     # GitHub 저장소 이름을 따로 지정
# 셸에서는 같은 인자로 team-kit-a / team-kit-b
```
- **폴더**
  - 없으면 새로 만듭니다.
  - 이미 있는 폴더에도 설치합니다. 단, 키트와 같은 이름의 파일(`CLAUDE.md`, `docs/…` 등)이 하나라도 있으면 목록을 보여 주고 멈춥니다. `.gitignore`는 내용을 합칩니다.
  - 그 폴더가 이미 git 저장소이면 저장소를 그대로 쓰고 **키트 파일만** 커밋합니다. 스테이징된 변경이 있으면 섞이지 않도록 멈춥니다.
  - 이미 `origin` 원격이 있으면 GitHub 저장소를 새로 만들지 않습니다.
- **폴더 이름**은 영문·숫자·하이픈·밑줄만 씁니다. tmux 세션 이름과 B 방식의 연결 그룹 이름으로 쓰이기 때문입니다.
- **PRD 형식**은 md, txt, pdf, docx 무엇이든 됩니다. `--prd`를 빼면 나중에 `docs/prd/`에 넣으면 됩니다.
- 명령을 등록하지 않았다면 키트 폴더에서 `./install.sh --mode a <폴더> …`로 같은 일을 할 수 있습니다.

1. `<프로젝트>/start.sh`를 실행합니다. 처음에는 칸마다 "신뢰" 확인을 누릅니다.
2. PM(A는 그 창, B는 창 0 `pm`)에게 입력합니다: **`docs/prd 의 PRD로 프로젝트를 시작해`**
3. PM이 요구사항 초안(`docs/00-requirements.md`)과 확인 질문을 한 번에 보여 줍니다. 질문마다 기본값이 붙어 있습니다. 바꿀 것만 답하고 **"확정"**이라고 하면 팀 작업이 시작됩니다.
4. 이후에는 단계마다 PM의 짧은 보고가 올라옵니다. 디자인 단계에서는 Claude Design 시안 링크가 나옵니다.
5. 중간에 요구 변경, 역할 추가, 진행 상황 질문은 모두 PM에게 하면 됩니다.
6. 끝나면 PM이 출시 판정, 최종 보고서, 회고를 정리합니다. 완료 조건은 QA·보안·준법 판정이 모두 "출시 가능" 또는 "조건부"이고, `tools/check-docs.py` 실패가 0건인 것입니다.

중단했다가 다시 열 때도 `./start.sh`를 실행합니다.

---

## 키트 구성
```
team-kit/
├── .claude-plugin/       플러그인(team-kit)과 마켓플레이스(team-kit: team-kit, session-link) 정의
├── commands/a.md, b.md   슬래시 명령 /team-kit:a, /team-kit:b → install.sh 실행
├── setup.sh              (셸에서 쓸 때) team-kit-a/b 명령 등록, session-link 플러그인 설치
├── bin/team-kit-a, team-kit-b   → install.sh --mode a|b
├── install.sh            설치: 사전 점검 → 겹침 확인 → 복사 → git (init 또는 기존 저장소) → (GitHub 비공개 저장소)
├── plugins/session-link/ B 방식용 세션 연결 플러그인 (프로젝트의 session-link.json 을 읽음)
├── project/              A·B 공통으로 복사되는 것
│   ├── team.json         역할 목록(id, 접두어, 모델, 산출물), 수용 기준 상한(ac_max), 권한 모드(permission_mode)
│   ├── githooks/commit-msg   첫 줄 [역할] 접두어 강제, Claude 표기 줄 거부
│   ├── .claude/hooks/guard.sh  비밀 파일·양식·기존 문서 덮어쓰기·강제 push 등 차단
│   ├── tools/check-docs.py     완료 전 문서·기록·테스트 결과 점검 (실패 0이어야 완료)
│   ├── tools/team-history.py   팀원 대화 기록 조회 (읽기 전용)
│   ├── reports/          테스트 원본 결과 (junit xml, 로그, 스크린샷)
│   └── docs/
│       ├── prd/          사용자가 넣는 PRD
│       ├── 00-requirements.md   PM이 PRD로 작성, 사용자가 확정
│       ├── conventions.md       공통 규칙 (응답 형식, 실행 환경, 수용 기준 상한)
│       ├── templates/    산출물 양식 19종
│       ├── 01-plan/ … 09-release/   단계별 산출물
│       └── meetings/ worklogs/ board.md decisions.md bugs.md
├── a/                    A 방식에만 추가
│   ├── CLAUDE.md         PM(리드) 진행 규칙
│   ├── .claude/agents/   planner·designer·architect·developer·qa·security·compliance·infra
│   ├── .claude/settings.json  Agent Teams 켬, 가드 훅
│   └── start.sh          PM 세션 열기 (세션 번호 저장 후 재개)
└── b/                    B 방식에만 추가
    ├── CLAUDE.md, pm.md, role-common.md   → 생성 시 roles/<역할>/CLAUDE.md 로 조립
    ├── start.sh          tmux 창 0=pm, 창 1=역할 칸
    └── tools/add-role.sh 진행 중 역할 추가
```

## 산출물 양식과 작성자
| 양식 (`docs/templates/`) | 산출물 위치 | 작성자 |
|---|---|---|
| (PM 작성, 양식 내장) | 00-requirements.md | [총괄] — 사용자 확정 |
| plan.md | 01-plan/plan.md | [총괄] |
| requirements-spec.md | 02-requirements/requirements-spec.md | [기획] |
| design-spec.md (+ tokens.css) | 03-design/ | [디자인] |
| architecture.md | 04-architecture/architecture.md | [설계] |
| test-plan.md, test-report.md | 05-test/ | [QA] |
| unit-test-report.md | 05-test/unit-test-report.md | [개발] |
| security-review.md, security-finding.md | 06-security/ | [보안] |
| compliance-review.md | 07-compliance/ | [준법] |
| deploy-guide.md | 08-deploy/deploy-guide.md | [인프라] |
| final-report.md | 09-release/final-report.md | [총괄] |
| retro.md / retro-role.md | 09-release/retro.md (종합) / 09-release/retro/<역할>.md | [총괄] / 각 역할 |
| meeting.md / meeting-opinion.md | meetings/NN-주제/_main.md / meetings/NN-주제/<역할>.md | [총괄] / 참석자 각자 |
| decision-entry.md | decisions.md 항목 | 결정 [총괄], 제안자 표기 |
| bug-entry.md | bugs.md 항목 | 보고·재검증 [QA], 수정 [개발] |
| worklog.md | worklogs/<역할>.md | 각자 |

- 모든 산출물 머리에 메타 표가 있습니다. 항목은 버전, 작성자, 상태(작성 중 → 검토 중 → 확정 → 변경됨), 최종 수정, 관련 결정입니다. 끝에는 **변경 이력**이 있습니다.
- 수정이 생기면 Edit로 고치고 버전을 올린 뒤, 변경 이력에 이유와 D-번호를 남깁니다. Write로 덮어쓰면 훅이 막습니다.
- 마무리 단계에는 **단위 테스트 결과서**(개발)와 **테스트 결과 보고서**(QA: 통합·화면·탐색)가 있어야 합니다. 원본 결과는 `reports/`에 함께 커밋합니다.

## 역할과 커밋 접두어
| 역할 | id | 접두어 | 모델 | 담당 |
|---|---|---|---|---|
| 총괄 | lead (B: pm) | `[총괄]` | opus | 사용자 소통, 요구사항 확정, 계획, 회의·결정, 출시 판정, 회고 종합, push |
| 기획 | planner | `[기획]` | opus | 요구사항 명세, 수용 기준, 화면 목록, 빈 값·시간 규칙 |
| 디자인 | designer | `[디자인]` | sonnet | Claude Design 시안, tokens.css, 화면 명세 |
| 설계 | architect | `[설계]` | opus | 설계서 (구성, ERD, 테이블 정의서, 인덱스, 개인정보·파기, 로그·오류 출력) |
| 개발 | developer | `[개발]` | sonnet | 구현, 단위 테스트, 단위 테스트 결과서 |
| QA | qa | `[QA]` | sonnet | 수용 기준 테스트, 원문 기준 탐색 테스트, 화면 확인 |
| 보안 | security | `[보안]` | opus | 위협 분석, 공격 입력 시험, 비밀값·의존성·컨테이너 점검, 보안 판정 |
| 준법 | compliance | `[준법]` | opus | 개인정보, 라이선스, 고지 문서, 준법 판정 (법률 자문 아님) |
| 인프라 | infra | `[인프라]` | sonnet | Containerfile(podman), GitHub Actions CI, 배포 가이드 |

- 화면이 없는 프로젝트는 디자인 역할을, 배포 대상이 없는 프로젝트는 인프라 역할을 PM이 만들지 않습니다.
- 외부에 띄우는 프로젝트는 보안·준법 역할을 항상 둡니다.
- 역할을 추가하거나 제거하려면 PM에게 말합니다. 직접 바꾸려면 `team.json`을 고칩니다. B 방식은 `tools/add-role.sh`를 씁니다.

---

# 테스트 결과
키트로 실제 팀을 구성해 프로젝트를 끝까지 진행한 시험의 결과입니다. 모두 2026-10-15, Claude Code 2.1.300에서 사용자 개입 없이 진행했습니다. 단, 0-2단계의 "확정" 답과 요구 변경 지시는 사람이 입력했습니다.

## 팀 실행 시험
| 시험 | 방식 | 팀 | 소요 | 문서 점검 (check-docs) | 테스트 | 커밋 규칙 |
|---|---|---|---|---|---|---|
| 북마크 웹앱 | A | 6역할 | 39분 | (점검 도구 도입 전) | 62건 통과, CI 성공, QA 버그 3건 수정·재검증 | 42건 모두 접두어 |
| 세미나 신청 웹앱 (개인정보 수집) | A | 8역할 (보안·준법 포함) | 59분 | 33/33 통과 | 단위 107 + 통합 29 통과, CI 성공 | 109건 모두 접두어 |
| 회의실 예약 웹앱 | A | 9역할 | 85분 | 35/35 통과 | 단위 78 + 통합 98 통과, CI 성공 | 위반 0건 |
| 회의실 예약 웹앱 | B | 9역할 | 76분 | 35/35 통과 | 단위 149 + 통합 86 통과, CI 성공 | 위반 0건 |
| 비품 대여 API (가벼운 시험) | A | 3역할 + 진행 중 1역할 추가 | 27분 | 24/24 통과 | 단위 통과, 통합 73/73, QA 버그 2건 수정·재검증 | 위반 0건 |
| 비품 대여 API (가벼운 시험) | B | 3역할 + 진행 중 1역할 추가 | 20분 | 24/24 통과 | 단위 통과 | 위반 0건 |

- 회의실 예약 시험의 출력 토큰은 A 약 87만, B 약 100만이었습니다.
- 커밋 규칙은 `[역할]` 접두어가 붙었는지, Claude 표기가 없는지를 셌습니다.
- 진행 중 변경도 시험했습니다(비품 대여).
  - 역할 추가(`[문서]`)는 A·B 모두 성공했습니다.
  - 요구사항 변경(대여 연장)도 A·B 모두 요구사항 개정부터 반영까지 성공했습니다.
- 다시 열기:
  - A는 `start.sh`로 PM 대화가 이어졌습니다.
  - B는 역할 폴더마다 각자 대화가 이어졌습니다.
  - PM이 `team-history.py`로 팀원 기록을 조회해 요약했습니다.
- 시험에서 나온 문제는 키트에 반영했습니다. 반영한 것은 다음과 같습니다.
  - 회의록·회고를 역할별 파일로 분리(같은 파일 동시 편집으로 내용이 사라지던 문제)
  - 메시지 도구를 불러오는 방법 안내
  - 운영 런타임 검증
  - 자기 프로세스만 종료

## 설치·도구 시험
| 항목 | 결과 |
|---|---|
| `/team-kit:a <폴더>` 슬래시 명령 (GitHub에서 플러그인 설치 후) | 설치·커밋·PRD 복사 성공. 폴더 인자가 없으면 사용법 안내 |
| `team-kit-a` / `team-kit-b` 셸 명령 (저장소 clone 후 `setup.sh`) | A·B 설치 성공, B는 역할 칸 9개 열림 |
| 이미 있는 폴더·저장소에 설치 | 기존 저장소를 그대로 쓰고 키트 파일만 커밋, 작업 중인 파일은 건드리지 않음 |
| 겹치는 파일 / 스테이징된 변경이 있을 때 | 아무것도 바꾸지 않고 멈춤 |
| 사전 점검 (tmux 없음, gh 미로그인, B에 session-link 없음) | 각각 안내 후 멈춤 |
| 권한 확인 생략 모드에서 가드 훅 | 기존 문서 덮어쓰기 차단 확인 |
| 가드 훅 / 커밋 메시지 훅 | 차단 7가지 / 4가지 경우 확인 |
| session-link 플러그인 | `claude plugin validate` 통과, 테스트 4/4 통과 |

## 확인하지 못한 것
- 사용자 설정에 권한 확인 생략이 없는 PC에서 A 팀원 칸이 리드의 권한 모드를 물려받는지
- A에서 공유 작업 목록 도구가 PM에게 보이지 않는 원인 (`docs/board.md`로 대신 관리)
- 대화형 화면에서 `team-kit:` 이름공간 없이 명령을 입력할 수 있는지 (`claude -p`에서는 인식되지 않았음)

## 키트를 고칠 때 (관리용)
- 키트를 고친 뒤 `.claude-plugin/plugin.json`의 `version`을 올리고 push합니다. 버전이 같으면 `/plugin marketplace update` 뒤에도 설치된 플러그인이 갱신되지 않습니다.
- `claude plugin validate .`로 플러그인과 마켓플레이스를 검증합니다. `claude plugin test plugins/session-link`로 session-link 테스트를 실행합니다.

## 라이선스
MIT — [LICENSE](LICENSE)
