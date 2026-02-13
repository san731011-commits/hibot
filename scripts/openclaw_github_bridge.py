#!/usr/bin/env python3
"""Parse OpenClaw/Discord style commands and map to GitHub operations."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.request
from typing import Any


DEFAULT_OWNER = "san731011-commits"
DEFAULT_REPO = "band-ai-dashboard"


def parse_env_file(path: pathlib.Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        values[k.strip()] = v.strip().strip('"').strip("'")
    return values


class GitHubClient:
    def __init__(self, owner: str, repo: str, token: str):
        self.owner = owner
        self.repo = repo
        self.token = token
        self.base = f"https://api.github.com/repos/{owner}/{repo}"

    def request(self, method: str, path: str, payload: dict[str, Any] | None = None) -> Any:
        url = f"{self.base}{path}"
        data = None
        headers = {
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {self.token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "openclaw-github-bridge",
        }
        if payload is not None:
            data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            headers["Content-Type"] = "application/json"

        req = urllib.request.Request(url=url, method=method, data=data, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                text = resp.read().decode("utf-8")
                return json.loads(text) if text else None
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"GitHub API error {e.code}: {detail}") from e

    def create_issue(self, title: str, objective: str, priority: str) -> dict[str, Any]:
        body = (
            "## 작업 목표\n"
            f"- {objective}\n\n"
            "## 완료 기준\n"
            "- [ ] 요구사항 충족\n"
            "- [ ] 테스트/검증 완료\n"
            "- [ ] PR 생성 및 리뷰 가능 상태\n\n"
            "## 우선순위\n"
            f"{priority}\n"
        )
        return self.request(
            "POST",
            "/issues",
            {
                "title": f"[Task] {title}",
                "body": body,
                "labels": ["task"],
            },
        )

    def get_issue(self, number: int) -> dict[str, Any]:
        return self.request("GET", f"/issues/{number}")

    def update_issue(self, number: int, payload: dict[str, Any]) -> dict[str, Any]:
        return self.request("PATCH", f"/issues/{number}", payload)

    def add_comment(self, number: int, body: str) -> None:
        self.request("POST", f"/issues/{number}/comments", {"body": body})


def load_config(repo_path: pathlib.Path, env_file: str) -> dict[str, str]:
    config = dict(os.environ)
    config_from_file = parse_env_file((repo_path / env_file).resolve())
    for k, v in config_from_file.items():
        config.setdefault(k, v)
    return config


def parse_issue_number(text: str) -> int:
    m = re.search(r"#?(\d+)", text)
    if not m:
        raise ValueError("이슈 번호를 찾지 못했습니다. 예: /status #12")
    return int(m.group(1))


def parse_task_cmd(message: str) -> tuple[str, str, str]:
    # /task 제목 | 목표 | 우선순위(선택)
    payload = message[len("/task") :].strip()
    parts = [x.strip() for x in payload.split("|")]
    if len(parts) < 2:
        raise ValueError("형식: /task <제목> | <목표> | <우선순위(선택)>")
    title = parts[0]
    objective = parts[1]
    priority = parts[2] if len(parts) >= 3 and parts[2] else "P1 - 높음"
    return title, objective, priority


def handle_command(gh: GitHubClient, message: str) -> str:
    msg = message.strip()
    if msg.startswith("/task "):
        title, objective, priority = parse_task_cmd(msg)
        issue = gh.create_issue(title, objective, priority)
        return f"작업 이슈 생성 완료: #{issue['number']} {issue['html_url']}"

    if msg.startswith("/status "):
        issue_no = parse_issue_number(msg)
        issue = gh.get_issue(issue_no)
        labels = ", ".join([x["name"] for x in issue.get("labels", [])]) or "-"
        return (
            f"이슈 #{issue_no} 상태: {issue['state']}\n"
            f"제목: {issue['title']}\n"
            f"라벨: {labels}\n"
            f"링크: {issue['html_url']}"
        )

    if msg.startswith("/cancel "):
        issue_no = parse_issue_number(msg)
        issue = gh.get_issue(issue_no)
        labels = sorted(set([x["name"] for x in issue.get("labels", [])] + ["canceled"]))
        gh.update_issue(issue_no, {"state": "closed", "labels": labels})
        gh.add_comment(issue_no, "Canceled by OpenClaw command.")
        return f"이슈 #{issue_no}를 취소(Closed) 처리했습니다."

    return (
        "지원 명령:\n"
        "- /task <제목> | <목표> | <우선순위(선택)>\n"
        "- /status #<이슈번호>\n"
        "- /cancel #<이슈번호>"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="OpenClaw command bridge to GitHub")
    parser.add_argument("message", help="Command message text")
    parser.add_argument("--repo-path", default=".", help="Repository path for .worker.env lookup")
    parser.add_argument("--env-file", default=".worker.env", help="Environment file name")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_path = pathlib.Path(args.repo_path).resolve()
    config = load_config(repo_path, args.env_file)

    token = config.get("GITHUB_TOKEN", "").strip()
    if not token:
        print("GITHUB_TOKEN is not set.", file=sys.stderr)
        return 1

    owner = config.get("GITHUB_OWNER", DEFAULT_OWNER)
    repo = config.get("GITHUB_REPO", DEFAULT_REPO)
    gh = GitHubClient(owner=owner, repo=repo, token=token)

    try:
        response = handle_command(gh, args.message)
    except Exception as exc:  # noqa: BLE001
        print(f"명령 처리 실패: {exc}", file=sys.stderr)
        return 1

    print(response)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
