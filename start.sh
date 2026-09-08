#!/usr/bin/env bash
set -euo pipefail

mkdir -p /app/data/openhands/agent-canvas/conversations \
  /app/data/openhands/agent-canvas/bash_events \
  /app/data/openhands/automation \
  /app/data/workspaces \
  /app/data/storage
chown -R openhands:openhands /app/data

exec gosu openhands:openhands /opt/agent-canvas/entrypoint.sh

