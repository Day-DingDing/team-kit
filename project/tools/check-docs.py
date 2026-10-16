#!/usr/bin/env python3
"""완료 판정 전에 문서·기록·테스트 결과가 다 있는지 점검한다. 총괄이 9단계에서 실행한다.

사용법: python3 tools/check-docs.py        (실패 항목이 있으면 종료 코드 1)

점검 내용
- 산출물: 계획서에서 "필요"로 표시한 역할의 산출물이 있고, 메타 표(버전·작성자·상태)·변경 이력이 있으며,
  양식의 빈칸 표시 {{ }} 가 남아 있지 않고, 상태가 "확정"인지
- 회의록: 참석자로 적힌 역할마다 자기 의견 절이 비어 있지 않은지
- 결정 기록: D-번호 항목마다 근거·채택하지 않은 의견이 있는지
- 작업 기록: 커밋한 역할마다 docs/worklogs/<역할>.md 에 항목이 1개 이상 있는지
- 테스트 원본: reports/test/unit/ 에 결과 파일이 있는지 (junit xml 등)
- 커밋: 모든 커밋 첫 줄에 [역할] 접두어가 있는지
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
import json

_TEAM = json.loads((ROOT / "team.json").read_text(encoding="utf-8"))
# 역할 접두어 → 작업 기록 파일 이름 / 필수 산출물 (team.json 에서 읽음)
ROLES = {r["prefix"]: r["id"] for r in _TEAM["roles"]}
DELIVERABLES = {r["prefix"]: r.get("deliverables", []) for r in _TEAM["roles"]}
LEAD = next(r["prefix"] for r in _TEAM["roles"] if r["id"] == "lead")
PREFIX_RE = "|".join(re.escape(p) for p in ROLES)
results = []


def check(ok, what, detail=""):
    results.append((ok, what, detail))


def active_roles():
    """계획서 팀 구성 표에서 '필요'로 적힌 역할. 계획서가 없으면 전체."""
    plan = DOCS / "01-plan" / "plan.md"
    if not plan.exists():
        return list(ROLES)
    roles = [LEAD]
    for line in plan.read_text(encoding="utf-8").splitlines():
        m = re.match(rf"\|\s*({PREFIX_RE})\s*\|\s*([^|]+)\|", line)
        if m and "불필요" not in m.group(2) and "필요" in m.group(2):
            roles.append(m.group(1))
    return roles


def check_deliverable(rel):
    p = DOCS / rel
    if not p.exists():
        check(False, f"산출물 {rel}", "파일 없음")
        return
    if p.suffix != ".md" or p.name == "findings.md":  # 항목 모음 문서는 메타 표 없이 내용만 본다
        t = p.read_text(encoding="utf-8") if p.suffix == ".md" else ""
        check("{{" not in t, f"산출물 {rel}", "채우지 않은 칸 남음" if "{{" in t else "")
        return
        check(True, f"산출물 {rel}")
        return
    t = p.read_text(encoding="utf-8")
    problems = []
    for field in ("| 버전 |", "| 작성자 |", "| 상태 |"):
        if field not in t:
            problems.append(f"메타 표 '{field.strip('| ')}' 없음")
    if "## 변경 이력" not in t:
        problems.append("변경 이력 없음")
    if "{{" in t:
        problems.append(f"채우지 않은 칸 {t.count('{{')}개")
    m = re.search(r"\| 상태 \|\s*([^|]+)\|", t)
    if m and "확정" not in m.group(1):
        problems.append(f"상태가 '{m.group(1).strip()}' (확정 아님)")
    check(not problems, f"산출물 {rel}", ", ".join(problems))


def filled(text, label):
    """'- 의견: 내용' 처럼 라벨 뒤에 실제 내용이 있는지"""
    return [x for x in re.findall(rf"^- {label}:[ \t]*(\S.*)$", text, re.M) if "{{" not in x]


def check_meetings():
    """docs/meetings/NN-주제/_main.md (총괄) + <역할 id>.md (참석자 각자)"""
    dirs = sorted(d for d in (DOCS / "meetings").iterdir() if d.is_dir()) if (DOCS / "meetings").exists() else []
    check(len(dirs) >= 3, "회의 3회 이상 (meetings/NN-주제/)", f"{len(dirs)}회")
    for d in dirs:
        main = d / "_main.md"
        if not main.exists():
            check(False, f"회의 {d.name}", "_main.md 없음")
            continue
        t = main.read_text(encoding="utf-8")
        m = re.search(r"\| 참석 \|([^|]+)\|", t)
        attendees = re.findall(rf"\[({PREFIX_RE})\]", m.group(1)) if m else []
        missing = []
        for a in attendees:
            f = d / f"{ROLES[a]}.md"
            if not f.exists() or not filled(f.read_text(encoding="utf-8"), "의견"):
                missing.append(f"{ROLES[a]}.md")
        if "{{" in t:
            missing.append("_main.md 빈칸 남음")
        check(attendees and not missing, f"회의 {d.name} 참석자별 의견 파일",
              "참석자 표기 없음" if not attendees else ", ".join(missing))


def check_retro(roles):
    """09-release/retro/<역할 id>.md 를 역할마다 각자 작성"""
    missing = []
    for r in roles:
        f = DOCS / "09-release" / "retro" / f"{ROLES[r]}.md"
        if not f.exists() or not filled(f.read_text(encoding="utf-8"), "잘된 점"):
            missing.append(f"{ROLES[r]}.md")
    check(not missing, "역할별 회고 파일 (09-release/retro/)", ", ".join(missing))


def check_decisions():
    p = DOCS / "decisions.md"
    t = p.read_text(encoding="utf-8") if p.exists() else ""
    entries = re.split(r"\n(?=## D-)", t)[1:]
    check(len(entries) >= 1, "결정 기록 1건 이상", f"{len(entries)}건")
    bad = [e.splitlines()[0] for e in entries if "근거" not in e or "채택하지 않은" not in e]
    check(not bad, "결정 기록마다 근거·채택하지 않은 의견", "; ".join(bad))


def check_verdicts(roles):
    for role, rel in (("보안", "06-security/security-review.md"), ("준법", "07-compliance/compliance-review.md")):
        p = DOCS / rel
        if role not in roles or not p.exists():
            continue
        t = p.read_text(encoding="utf-8")
        sec = t.split("## 7. 판정", 1)[-1].split("## 변경 이력", 1)[0]
        first = next((ln.strip(" -*>#") for ln in sec.splitlines() if ln.strip()), "")
        ok = first.startswith(("출시 가능", "조건부"))
        check(ok, f"{role} 판정이 출시 가능 또는 조건부 (판정 절 첫 줄)", first[:80] or "판정 없음")


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True).stdout


def check_worklogs_and_commits():
    subjects = git("log", "--format=%s").splitlines()
    bad = [s for s in subjects if not re.match(rf"^\[({PREFIX_RE})\] ", s)]
    check(not bad, "모든 커밋에 [역할] 접두어", f"어긋난 커밋 {len(bad)}건: {bad[:3]}" if bad else "")
    committed = {re.match(r"^\[([^\]]+)\]", s).group(1) for s in subjects if re.match(r"^\[([^\]]+)\]", s)}
    for role in sorted(committed & set(ROLES)):
        p = DOCS / "worklogs" / f"{ROLES[role]}.md"
        n = len(re.findall(r"^## \d{4}-\d{2}-\d{2}", p.read_text(encoding="utf-8"), re.M)) if p.exists() else 0
        check(n >= 1, f"작업 기록 worklogs/{ROLES[role]}.md ([{role}])", f"항목 {n}개" if n else "없음")


def check_test_outputs():
    unit = [f for f in (ROOT / "reports" / "test" / "unit").glob("*") if f.is_file()] if (ROOT / "reports/test/unit").exists() else []
    check(bool(unit), "단위 테스트 원본 결과 reports/test/unit/", "" if unit else "결과 파일 없음")
    other = [f for f in (ROOT / "reports" / "test").rglob("*") if f.is_file() and "unit" not in f.parts and f.name != ".gitkeep"]
    check(bool(other), "통합·화면·탐색 테스트 원본 결과 reports/test/", "" if other else "결과 파일 없음")


def check_requirements():
    p = DOCS / "00-requirements.md"
    check_deliverable("00-requirements.md")
    if p.exists():
        m = re.search(r"\| 사용자 확인 \|\s*([^|]*)\|", p.read_text(encoding="utf-8"))
        val = m.group(1).strip() if m else ""
        check(bool(val) and "{{" not in val, "요구사항 사용자 확인 기록", val[:60] or "비어 있음")


def main():
    roles = active_roles()
    check_requirements()
    for r in roles:
        for rel in DELIVERABLES.get(r, []):
            check_deliverable(rel)
    check_meetings()
    check_retro(roles)
    check_decisions()
    check_worklogs_and_commits()
    check_test_outputs()
    check_verdicts(roles)
    fails = [r for r in results if not r[0]]
    print(f"문서 점검: {len(results)}항목 중 통과 {len(results) - len(fails)}, 실패 {len(fails)} (대상 역할: {' '.join(roles)})")
    for ok, what, detail in results:
        print(f"  {'✔' if ok else '✘'} {what}" + (f" — {detail}" if detail else ""))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
