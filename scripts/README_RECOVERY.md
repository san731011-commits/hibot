If I (the assistant) crash or the agent process is stopped, here are the steps to recover and what to run first:

1) Start OpenClaw gateway service
   - Check status: sudo systemctl status openclaw-gateway
   - Start if stopped: sudo systemctl start openclaw-gateway

2) If Docker containers need restarting
   - List containers: /usr/bin/docker ps -a
   - Start containers: /usr/bin/docker-compose up -d (run from workspace where docker-compose.yml is)

3) Restore latest git snapshot (local)
   - cd /home/san/.openclaw/workspace
   - git tag --list "healthcheck/*" | tail -n 1  # shows latest tag
   - git checkout <tag-or-commit>

4) If configuration needs restoring from backups
   - cd /home/san/.openclaw/workspace/backups
   - ls -1t
   - tar xzf backup-config-YYYYMMDD-HHMMSS.tar.gz -C /home/san/.openclaw/workspace

5) Reconnect Discord bot (if tokens/secrets changed)
   - openclaw status --deep
   - If channel shows token missing, reconfigure via environment or config file and restart gateway

6) Logs and debugging
   - openclaw logs --follow
   - journalctl -u openclaw-gateway -f

Notes:
- Do NOT run destructive commands (rm -rf, mkfs) unless explicitly authorized.
- If remote push is needed, ensure SSH keys/remote creds are available before git push.
- For any step that modifies system services, require manual approval.
