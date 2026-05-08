#!/usr/bin/env sh
set -eu

INTERVAL_SECONDS="${AUTOSAVE_INTERVAL_SECONDS:-1800}"
START_DELAY_SECONDS="${AUTOSAVE_START_DELAY_SECONDS:-0}"
REPO_DIR="${AUTOSAVE_REPO_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
PID_FILE="${AUTOSAVE_PID_FILE:-/tmp/minecraft-autosave.pid}"
LOG_FILE="${AUTOSAVE_LOG_FILE:-$REPO_DIR/.minecraft-autosave.log}"

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

run_rcon() {
  if command -v rcon-cli >/dev/null 2>&1; then
    rcon-cli "$@"
    return $?
  fi

  if command -v docker >/dev/null 2>&1; then
    docker compose exec -T mc rcon-cli "$@"
    return $?
  fi

  log "WARN: rcon-cli/docker not found; skipping Minecraft flush"
  return 1
}

ensure_git_identity() {
  if ! git config user.name >/dev/null 2>&1; then
    git config user.name "Minecraft Autosave"
  fi

  if ! git config user.email >/dev/null 2>&1; then
    git config user.email "minecraft-autosave@users.noreply.github.com"
  fi
}

autosave_once() {
  cd "$REPO_DIR"

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "ERROR: $REPO_DIR is not a git repository"
    return 1
  fi

  log "Flushing Minecraft world to disk"
  run_rcon "save-all flush" >/dev/null 2>&1 || log "WARN: could not run save-all flush"

  git add -A data

  if git diff --cached --quiet -- data; then
    log "No data changes to commit"
    return 0
  fi

  ensure_git_identity

  commit_message="Auto-save Minecraft world $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  git commit -m "$commit_message"

  if git push; then
    log "Pushed auto-save commit"
  else
    log "WARN: git push failed; commit is local and can be pushed later"
    return 1
  fi
}

loop() {
  if [ "$START_DELAY_SECONDS" -gt 0 ]; then
    log "Waiting ${START_DELAY_SECONDS}s before first auto-save"
    sleep "$START_DELAY_SECONDS"
  fi

  while true; do
    autosave_once || true
    log "Waiting ${INTERVAL_SECONDS}s until next auto-save"
    sleep "$INTERVAL_SECONDS"
  done
}

start() {
  if [ -f "$PID_FILE" ]; then
    old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      log "Auto-save already running with PID $old_pid"
      return 0
    fi
  fi

  if command -v setsid >/dev/null 2>&1; then
    setsid "$0" loop >> "$LOG_FILE" 2>&1 < /dev/null &
  else
    nohup "$0" loop >> "$LOG_FILE" 2>&1 < /dev/null &
  fi
  new_pid="$!"
  printf '%s\n' "$new_pid" > "$PID_FILE"
  log "Started auto-save with PID $new_pid; log: $LOG_FILE"
}

stop() {
  if [ ! -f "$PID_FILE" ]; then
    log "Auto-save is not running"
    return 0
  fi

  old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
    kill "$old_pid"
    log "Stopped auto-save with PID $old_pid"
  else
    log "Auto-save PID file existed, but process was not running"
  fi

  rm -f "$PID_FILE"
}

status() {
  if [ -f "$PID_FILE" ]; then
    old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      log "Auto-save is running with PID $old_pid"
      return 0
    fi
  fi

  log "Auto-save is not running"
}

case "${1:-once}" in
  once)
    autosave_once
    ;;
  loop)
    loop
    ;;
  start)
    start
    ;;
  stop)
    stop
    ;;
  status)
    status
    ;;
  *)
    echo "Usage: $0 [once|loop|start|stop|status]" >&2
    exit 2
    ;;
esac
