#!/usr/bin/env python3
"""Parse OpenClaw/Discord commands and call Codex HTTP bridge."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request
from typing import Any


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


def load_config(repo_path: pathlib.Path, env_file: str) -> dict[str, str]:
    config = dict(os.environ)
    config_from_file = parse_env_file((repo_path / env_file).resolve())
    for k, v in config_from_file.items():
        config.setdefault(k, v)
    return config


class BridgeClient:
    def __init__(self, base_url: str, token: str, timeout_sec: int):
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.timeout_sec = timeout_sec

    def _request(self, method: str, path: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
        url = f"{self.base_url}{path}"
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "openclaw-http-bridge",
        }
        data = None
        if payload is not None:
            data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        req = urllib.request.Request(url=url, method=method, headers=headers, data=data)

        try:
            with urllib.request.urlopen(req, timeout=self.timeout_sec) as resp:
                raw = resp.read().decode("utf-8")
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as err:
            detail = err.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"HTTP {err.code}: {detail}") from err
        except urllib.error.URLError as err:
            raise RuntimeError(f"Bridge request failed: {err}") from err

    def create_job(self, prompt: str) -> dict[str, Any]:
        return self._request("POST", "/jobs", {"prompt": prompt})

    def get_job(self, job_id: str) -> dict[str, Any]:
        return self._request("GET", f"/jobs/{job_id}")

    def health(self) -> dict[str, Any]:
        # /health does not require auth, but sending it is harmless.
        return self._request("GET", "/health")


def truncate(text: str, max_len: int = 1000) -> str:
    text = (text or "").strip()
    if len(text) <= max_len:
        return text
    return text[:max_len] + "\n...[truncated]..."


def extract_job_id(text: str) -> str:
    # Accept UUID-like values from /status command
    m = re.search(r"([0-9a-fA-F-]{16,})", text)
    if not m:
        raise ValueError("job_id를 찾지 못했습니다. 예: /status <job_id>")
    return m.group(1)


def handle_task(client: BridgeClient, msg: str) -> str:
    prompt = msg[len("/task") :].strip()
    if not prompt:
        raise ValueError("형식: /task <Codex에 전달할 프롬프트>")
    created = client.create_job(prompt)
    job_id = created.get("job_id", "")
    return (
        "작업 접수 완료\n"
        f"- job_id: `{job_id}`\n"
        f"- 상태확인: `/status {job_id}`"
    )


def format_job_status(job: dict[str, Any]) -> str:
    status = job.get("status", "unknown")
    lines = [
        f"job_id: `{job.get('id', '-')}`",
        f"status: `{status}`",
        f"created_at: `{job.get('created_at', '-')}`",
    ]

    if status in {"queued", "running"}:
        return "작업 진행 중\n- " + "\n- ".join(lines)

    lines.append(f"return_code: `{job.get('return_code')}`")
    stdout = truncate(job.get("stdout", ""))
    stderr = truncate(job.get("stderr", ""))
    error = truncate(job.get("error", ""))
    if stdout:
        lines.append(f"stdout:\n```text\n{stdout}\n```")
    if stderr:
        lines.append(f"stderr:\n```text\n{stderr}\n```")
    if error:
        lines.append(f"error: `{error}`")
    return "작업 완료 상태\n- " + "\n- ".join(lines)


def wait_until_done(client: BridgeClient, job_id: str, wait_sec: int, poll_sec: float) -> dict[str, Any]:
    deadline = time.time() + wait_sec
    last: dict[str, Any] | None = None
    while time.time() < deadline:
        last = client.get_job(job_id)
        if last.get("status") in {"succeeded", "failed"}:
            return last
        time.sleep(poll_sec)
    return last or client.get_job(job_id)


def handle_command(client: BridgeClient, message: str, wait_sec: int, poll_sec: float) -> str:
    msg = message.strip()
    if msg.startswith("/task "):
        return handle_task(client, msg)
    if msg.startswith("/status "):
        job_id = extract_job_id(msg)
        return format_job_status(client.get_job(job_id))
    if msg.startswith("/taskwait "):
        prompt = msg[len("/taskwait") :].strip()
        if not prompt:
            raise ValueError("형식: /taskwait <프롬프트>")
        created = client.create_job(prompt)
        job_id = created.get("job_id", "")
        result = wait_until_done(client, job_id, wait_sec=wait_sec, poll_sec=poll_sec)
        return f"동기 실행 결과 (job_id `{job_id}`)\n" + format_job_status(result)
    if msg == "/health":
        health = client.health()
        return (
            "브리지 상태\n"
            f"- ok: `{health.get('ok')}`\n"
            f"- queued: `{health.get('queued')}`\n"
            f"- running: `{health.get('running')}`\n"
            f"- time: `{health.get('time')}`"
        )
    return (
        "지원 명령\n"
        "- /task <프롬프트>\n"
        "- /status <job_id>\n"
        "- /taskwait <프롬프트>\n"
        "- /health"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="OpenClaw command bridge to Codex HTTP")
    parser.add_argument("message", help="Command message text")
    parser.add_argument("--repo-path", default=".", help="Repository path for env file lookup")
    parser.add_argument("--env-file", default=".worker.env", help="Environment file name")
    parser.add_argument("--wait-sec", type=int, default=90, help="Timeout for /taskwait")
    parser.add_argument("--poll-sec", type=float, default=2.0, help="Polling interval for /taskwait")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_path = pathlib.Path(args.repo_path).resolve()
    config = load_config(repo_path, args.env_file)

    base_url = config.get("BRIDGE_BASE_URL", "http://127.0.0.1:8787").strip()
    token = config.get("BRIDGE_TOKEN", "").strip()
    timeout_sec = int(config.get("BRIDGE_HTTP_TIMEOUT_SEC", "20"))

    if not token:
        print("BRIDGE_TOKEN is not set.", file=sys.stderr)
        return 1

    client = BridgeClient(base_url=base_url, token=token, timeout_sec=timeout_sec)
    try:
        response = handle_command(client, args.message, wait_sec=args.wait_sec, poll_sec=args.poll_sec)
    except Exception as exc:  # noqa: BLE001
        print(f"명령 처리 실패: {exc}", file=sys.stderr)
        return 1
    print(response)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
