#!/usr/bin/env python3
"""팀원(역할)들의 Claude Code 대화 기록을 조회한다. PM이 "QA가 뭘 했는지 보여줘" 같은 질문에 답할 때 쓴다.

사용법:
  python3 tools/team-history.py                 역할별 대화 목록 (기간, 메시지 수)
  python3 tools/team-history.py --role qa       qa의 대화를 시간순으로 (사람이 읽는 글과 도구 이름)
  python3 tools/team-history.py --role qa --grep 버그     qa 대화 중 '버그'가 들어간 부분만
  python3 tools/team-history.py --grep B-3      모든 역할에서 검색

기록 위치: ~/.claude/projects/<폴더 경로를 '-'로 바꾼 이름>/*.jsonl
- A 방식: 프로젝트 폴더 하나에 리드와 팀원 파일이 섞여 있고, 팀원 줄에는 agentName 이 있다.
- B 방식: roles/<역할> 폴더마다 기록 폴더가 따로 있다.
이 도구는 읽기만 한다.
"""
import argparse
import json
import re
import subprocess
from datetime import datetime
from pathlib import Path

PROJECTS = Path.home() / ".claude" / "projects"


def root():
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True,
                         cwd=Path.cwd()).stdout.strip()
    return Path(out or Path(__file__).resolve().parent.parent)


def proj_dir(path):
    return PROJECTS / re.sub(r"[^A-Za-z0-9]", "-", str(path))


def sources(r):
    """(기본 역할 이름, jsonl 파일) 목록"""
    out = [("pm", f) for f in proj_dir(r).glob("*.jsonl")]
    roles = r / "roles"
    if roles.is_dir():
        for d in sorted(roles.iterdir()):
            out += [(d.name, f) for f in proj_dir(d).glob("*.jsonl")]
    return out


def entries(default_role, f):
    for line in f.open(encoding="utf-8", errors="ignore"):
        try:
            o = json.loads(line)
        except json.JSONDecodeError:
            continue
        if o.get("type") not in ("user", "assistant"):
            continue
        role = o.get("agentName") or default_role
        ts = o.get("timestamp", "")
        content = (o.get("message") or {}).get("content")
        parts = []
        if isinstance(content, str):
            parts.append(content)
        else:
            for b in content or []:
                if not isinstance(b, dict):
                    continue
                if b.get("type") == "text":
                    parts.append(b["text"])
                elif b.get("type") == "tool_use":
                    inp = b.get("input") or {}
                    hint = inp.get("file_path") or inp.get("command") or inp.get("to") or ""
                    parts.append(f"[도구 {b['name']}] {str(hint)[:120]}")
        text = "\n".join(p for p in parts if p).strip()
        if text:
            yield role, ts, o["type"], text


def local(ts):
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone().strftime("%m-%d %H:%M")
    except ValueError:
        return ts[:16]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--role")
    ap.add_argument("--grep")
    ap.add_argument("--limit", type=int, default=200, help="출력할 최대 항목 수 (최근 것부터 자름)")
    a = ap.parse_args()
    rows = []
    for default_role, f in sources(root()):
        rows += list(entries(default_role, f))
    rows.sort(key=lambda x: x[1])
    if not a.role and not a.grep:
        summary = {}
        for role, ts, _, _ in rows:
            s = summary.setdefault(role, [ts, ts, 0])
            s[1] = ts
            s[2] += 1
        print("| 역할 | 처음 | 마지막 | 메시지 수 |\n|---|---|---|---|")
        for role, (t0, t1, n) in sorted(summary.items(), key=lambda x: x[1][0]):
            print(f"| {role} | {local(t0)} | {local(t1)} | {n} |")
        return
    sel = [x for x in rows if (not a.role or x[0] == a.role) and (not a.grep or a.grep in x[3])]
    for role, ts, kind, text in sel[-a.limit:]:
        who = role if kind == "assistant" else f"{role}←받음"
        print(f"── {local(ts)} {who}\n{text[:1500]}\n")
    print(f"({len(sel)}건 중 {min(len(sel), a.limit)}건 표시)")


if __name__ == "__main__":
    main()
