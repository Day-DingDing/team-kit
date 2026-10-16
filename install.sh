#!/usr/bin/env bash
# 팀 키트를 원하는 폴더에 설치한다. 보통은 setup.sh 가 만든 명령 prd-team-a / prd-team-b 로 부른다.
#   install.sh --mode a|b <폴더> [--prd <PRD 파일>] [--no-github] [--repo <GitHub 저장소 이름>]
#   --mode a : 에이전트 팀 — PM(리드) 세션 하나가 팀원을 만들어 진행
#   --mode b : 세션 연결 — 역할마다 독립 세션(roles/<역할>)을 session-link로 연결
#   <폴더>   : 없으면 만든다. 이미 있으면 키트 파일과 겹치는 파일이 없을 때만 설치한다 (기존 git 저장소면 그대로 쓴다).
#   --prd    : PRD 파일을 docs/prd/ 에 넣는다 (md, txt, pdf, docx 등 아무 형식)
#   --no-github : GitHub 저장소를 만들지 않는다. 없으면 폴더 이름(또는 --repo)으로 개인 GitHub **비공개** 저장소를 만든다.
#                 폴더에 이미 origin 원격이 있으면 저장소를 만들지 않는다.
set -euo pipefail
KIT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
target=""; github=1; mode=""; prd=""; repo=""
usage() { sed -n '3,9p' "$KIT/install.sh" | sed 's/^# \{0,1\}//' >&2; exit 1; }
while [ $# -gt 0 ]; do
  case "$1" in
    --no-github) github=0 ;;
    --mode) mode="${2:-}"; shift ;;
    --prd) prd="${2:-}"; shift ;;
    --repo) repo="${2:-}"; shift ;;
    -h|--help) usage ;;
    -*) echo "모르는 옵션: $1" >&2; usage ;;
    *) [ -z "$target" ] && target="$1" || { echo "폴더는 하나만 지정합니다: $1" >&2; exit 1; } ;;
  esac
  shift
done
[ -z "$target" ] && usage
[[ "$mode" == a || "$mode" == b ]] || { echo "--mode 는 a 또는 b" >&2; exit 1; }
[ -n "$prd" ] && [ ! -f "$prd" ] && { echo "PRD 파일이 없습니다: $prd" >&2; exit 1; }
[ -n "$prd" ] && prd="$(readlink -f "$prd")"
target="$(readlink -m "$target")"
name="$(basename "$target")"
[[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || { echo "폴더 이름은 영문·숫자·하이픈·밑줄만 씁니다 (tmux 세션·연결 그룹 이름으로 쓰임): $name" >&2; exit 1; }
repo="${repo:-$name}"

# ── 사전 점검: 빠진 것을 모두 모아 한 번에 알려 주고 멈춘다 ──
miss=()
for c in git python3 tmux claude; do command -v "$c" >/dev/null || miss+=("$c 가 설치되어 있지 않습니다"); done
has_origin=0
[ -d "$target/.git" ] && git -C "$target" remote get-url origin >/dev/null 2>&1 && has_origin=1
if [ "$github" = 1 ] && [ "$has_origin" = 0 ]; then
  if ! command -v gh >/dev/null; then miss+=("gh(GitHub CLI)가 없습니다. 설치하거나 --no-github 로 실행하세요")
  elif ! gh auth status >/dev/null 2>&1; then miss+=("gh 로그인이 안 되어 있습니다: gh auth login (또는 --no-github)")
  fi
fi
if [ "$mode" = b ] && command -v claude >/dev/null; then
  claude plugin list 2>/dev/null | grep -A4 "session-link@" | grep -q "enabled" ||
    miss+=("B 방식에 필요한 session-link 플러그인이 없습니다. Claude Code에서 /plugin install session-link@prd-team (또는 키트 폴더에서 ./setup.sh)")
fi
if [ -d "$target/.git" ] && [ -n "$(git -C "$target" diff --cached --name-only 2>/dev/null)" ]; then
  miss+=("$target 저장소에 스테이징된 변경이 있습니다. 먼저 커밋하거나 내려 주세요 (키트 커밋에 섞이지 않게)")
fi
if [ ${#miss[@]} -gt 0 ]; then
  echo "시작 전에 준비가 필요합니다:" >&2; printf '  - %s\n' "${miss[@]}" >&2; exit 1
fi

if [ "$github" = 1 ] && [ "$has_origin" = 0 ]; then
  login=$(gh api user --jq .login); uid=$(gh api user --jq .id)
  gh repo view "$login/$repo" >/dev/null 2>&1 && { echo "GitHub 에 이미 $login/$repo 저장소가 있습니다. --repo 로 다른 이름을 주세요." >&2; exit 1; }
  author_name="$login"; author_email="${uid}+${login}@users.noreply.github.com"
else
  # GitHub 없이: git 전역 설정 → 없으면 gh 로그인 정보 → 없으면 로컬 전용 이름
  author_name=$(git config --global user.name || true); author_email=$(git config --global user.email || true)
  if [ -z "$author_name" ] && command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
    login=$(gh api user --jq .login); uid=$(gh api user --jq .id)
    author_name="$login"; author_email="${uid}+${login}@users.noreply.github.com"
  fi
  author_name=${author_name:-prd-team}; author_email=${author_email:-prd-team@localhost}
fi

# ── 임시 폴더에 설치할 내용을 먼저 만든다 (경로는 최종 위치 기준) ──
stage="$(mktemp -d)"; trap 'rm -rf "$stage"' EXIT
cp -r "$KIT/project/." "$stage/"
[ -n "$prd" ] && cp "$prd" "$stage/docs/prd/"
if [ "$mode" = a ]; then
  cp -r "$KIT/a/." "$stage/"
else
  cp "$KIT/b/CLAUDE.md" "$KIT/b/start.sh" "$stage/"
  cp "$KIT/b/tools/add-role.sh" "$stage/tools/"
  python3 - "$KIT" "$stage" "$target" "$name" <<'PY'
import json, os, re, sys
kit, out, root, name = sys.argv[1:]
team = json.load(open(f"{out}/team.json", encoding="utf-8"))
# 역할 공통 문구: B 세션 공통 + 문서 작성 공통 (add-role.sh 도 이 파일을 쓴다)
infra = open(f"{kit}/a/.claude/agents/infra.md", encoding="utf-8").read()
doc_common = infra[infra.index("## 문서 작성 (모든 역할 공통"):].replace("infra.md", "{id}.md").replace("[인프라]", "[{prefix}]")
doc_common = doc_common.replace("총괄에게 보낼 때 주소는 `team-lead`.", "총괄에게 보낼 때 주소는 `pm`.")
common = open(f"{kit}/b/role-common.md", encoding="utf-8").read() + "\n" + doc_common
os.makedirs(f"{out}/roles", exist_ok=True)
open(f"{out}/roles/_common.md", "w", encoding="utf-8").write(common)
peers = []
def write_role(rid, prefix, body, model, desc, aliases):
    d = f"{out}/roles/{rid}"
    os.makedirs(f"{d}/.claude", exist_ok=True)
    tail = common.replace("{id}", rid).replace("{prefix}", prefix).replace("{root}", root)
    if "## 문서 작성 (모든 역할 공통" in body:   # 역할 파일에 이미 있는 공통 절은 한 번만
        tail = tail[:tail.index("## 문서 작성 (모든 역할 공통")]
    open(f"{d}/CLAUDE.md", "w", encoding="utf-8").write(body.rstrip() + "\n" + tail)
    open(f"{d}/.model", "w").write(model + "\n")
    json.dump({"permissions": {"additionalDirectories": [root]},
               "hooks": {"PreToolUse": [{"matcher": "Edit|Write|Bash",
                         "hooks": [{"type": "command", "command": f"{root}/.claude/hooks/guard.sh"}]}]}},
              open(f"{d}/.claude/settings.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    peers.append({"id": rid, "label": prefix, "dir": f"roles/{rid}", "aliases": aliases, "role": desc})
for r in team["roles"]:
    if r["id"] == "lead":
        write_role("pm", r["prefix"], open(f"{kit}/b/pm.md", encoding="utf-8").read(), r.get("model", "opus"),
                   "PM(총괄): 사용자 소통, 요구사항 확정, 회의·결정, 출시 판정", r.get("aliases", []))
        continue
    src = open(f"{kit}/a/.claude/agents/{r['id']}.md", encoding="utf-8").read()
    fm, body = re.match(r"^---\n(.*?)\n---\n(.*)$", src, re.S).groups()
    desc = re.search(r"^description:\s*(.+)$", fm, re.M).group(1)
    body = body.replace("총괄에게 보낼 때 주소는 `team-lead`.", "총괄에게 보낼 때 주소는 `pm`.")
    write_role(r["id"], r["prefix"], f"# B 역할 세션: {r['id']}\n\n" + body, r.get("model", "sonnet"), desc, r.get("aliases", []))
json.dump({"group": name, "peers": peers}, open(f"{out}/session-link.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
fi

# ── 기존 폴더와 겹치는지 확인 (.gitignore 는 합친다) ──
mapfile -t files < <(cd "$stage" && find . -type f ! -name .gitignore | sed 's#^\./##' | sort)
if [ -d "$target" ]; then
  conflict=()
  for f in "${files[@]}"; do [[ "$f" == */.gitkeep ]] && continue; [ -e "$target/$f" ] && conflict+=("$f"); done
  if [ ${#conflict[@]} -gt 0 ]; then
    echo "$target 에 키트와 같은 이름의 파일이 있어 설치하지 않았습니다:" >&2
    printf '  - %s\n' "${conflict[@]:0:20}" >&2; [ ${#conflict[@]} -gt 20 ] && echo "  … 외 $(( ${#conflict[@]} - 20 ))개" >&2
    exit 1
  fi
fi
mkdir -p "$target"
(cd "$stage" && find . -type f ! -name .gitignore -print0 | while IFS= read -r -d '' f; do
  mkdir -p "$target/$(dirname "$f")"; [ -e "$target/$f" ] || cp -p "$f" "$target/$f"; done)
touch "$target/.gitignore"
while IFS= read -r line; do grep -qxF -- "$line" "$target/.gitignore" || echo "$line" >> "$target/.gitignore"; done < "$stage/.gitignore"
chmod +x "$target"/start.sh "$target"/githooks/commit-msg "$target"/.claude/hooks/guard.sh "$target"/tools/*

# ── git: 새 폴더면 init, 기존 저장소면 그대로 쓰고 키트 파일만 커밋 ──
cd "$target"
if [ ! -d .git ]; then
  git init -q -b main
  git config user.name "$author_name"; git config user.email "$author_email"
else
  git config user.name >/dev/null || git config user.name "$author_name"
  git config user.email >/dev/null || git config user.email "$author_email"
  old_hooks=$(git config core.hooksPath || true)
  [ -n "$old_hooks" ] && [ "$old_hooks" != githooks ] && echo "알림: 기존 core.hooksPath($old_hooks)를 githooks 로 바꿨습니다." >&2
fi
git config core.hooksPath githooks
git add -- .gitignore "${files[@]}"
git commit -q -m "[총괄] 팀 키트(${mode^^} 방식) 설치"
echo "로컬 저장소: $target ($(git log --oneline | head -1))"

if [ "$github" = 1 ] && [ "$has_origin" = 0 ]; then
  gh repo create "$repo" --private --source . --remote origin --push >/dev/null
  echo "GitHub 비공개 저장소: https://github.com/$login/$repo"
elif [ "$has_origin" = 1 ]; then
  echo "기존 원격(origin)이 있어 GitHub 저장소는 만들지 않았습니다. 올리려면: git push"
fi
pm_where=$([ "$mode" = a ] && echo "총괄 세션" || echo "tmux 창 0(pm)")
cat <<MSG

다음 순서 (${mode^^} 방식):
  1) PRD를 docs/prd/ 에 넣는다 (--prd 로 넣었으면 생략)
  2) $target/start.sh 실행 (처음 여는 폴더는 칸마다 "신뢰" 확인)
  3) ${pm_where}에 입력: docs/prd 의 PRD로 프로젝트를 시작해
     → PM이 요구사항 문서를 만들고 확인 질문을 하면 답한 뒤 "확정"이라고 답한다
MSG
