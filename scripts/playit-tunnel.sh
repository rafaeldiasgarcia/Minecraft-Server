#!/usr/bin/env sh
set -eu

REPO_DIR="${PLAYIT_REPO_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
PID_FILE="${PLAYIT_WATCHDOG_PID_FILE:-$REPO_DIR/.playit-watchdog.pid}"
LOG_FILE="${PLAYIT_WATCHDOG_LOG_FILE:-$REPO_DIR/.playit-watchdog.log}"
WATCH_INTERVAL_SECONDS="${PLAYIT_WATCH_INTERVAL_SECONDS:-20}"

cd "$REPO_DIR"

has_secret() {
  if [ -n "${PLAYIT_SECRET_KEY:-}" ]; then
    return 0
  fi

  if [ -f .env ] && grep -Eq '^PLAYIT_SECRET_KEY=.+$' .env; then
    return 0
  fi

  return 1
}

start() {
  if ! has_secret; then
    cat >&2 <<'EOF'
PLAYIT_SECRET_KEY is not configured.

Create a playit.gg Docker agent, then add the secret key to .env:

  cp .env.example .env
  # edit .env and replace your-playit-secret-key-here

Then run:

  scripts/playit-tunnel.sh start
EOF
    exit 1
  fi

  docker compose --profile public-tunnel up -d playit
}

restart_playit() {
  docker compose --profile public-tunnel up -d --force-recreate playit
}

mc_container_id() {
  docker compose ps -q mc 2>/dev/null || true
}

playit_running() {
  container_id="$(docker compose --profile public-tunnel ps -q playit 2>/dev/null || true)"

  if [ -z "$container_id" ]; then
    return 1
  fi

  [ "$(docker inspect -f '{{.State.Running}}' "$container_id" 2>/dev/null || echo false)" = "true" ]
}

watch_loop() {
  if ! has_secret; then
    echo "PLAYIT_SECRET_KEY not configured; watchdog exiting"
    exit 0
  fi

  start
  last_mc_id="$(mc_container_id)"
  echo "playit watchdog started; mc=$last_mc_id"

  while :; do
    sleep "$WATCH_INTERVAL_SECONDS"
    current_mc_id="$(mc_container_id)"

    if [ -z "$current_mc_id" ]; then
      echo "$(date -Is) mc container not found; waiting"
      continue
    fi

    if [ "$current_mc_id" != "$last_mc_id" ]; then
      echo "$(date -Is) mc container changed; recreating playit tunnel"
      restart_playit
      last_mc_id="$current_mc_id"
      continue
    fi

    if ! playit_running; then
      echo "$(date -Is) playit is not running; starting tunnel"
      restart_playit
    fi
  done
}

watch_start() {
  if [ -f "$PID_FILE" ]; then
    old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      echo "playit watchdog already running with PID $old_pid"
      return 0
    fi
  fi

  nohup sh "$REPO_DIR/scripts/playit-tunnel.sh" watch-loop >> "$LOG_FILE" 2>&1 < /dev/null &
  echo "$!" > "$PID_FILE"
  echo "playit watchdog started with PID $!"
}

watch_stop() {
  if [ ! -f "$PID_FILE" ]; then
    echo "playit watchdog is not running"
    return 0
  fi

  old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
    kill "$old_pid"
    echo "playit watchdog stopped"
  else
    echo "playit watchdog was not running"
  fi

  rm -f "$PID_FILE"
}

watch_status() {
  if [ -f "$PID_FILE" ]; then
    old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      echo "playit watchdog running with PID $old_pid"
      return 0
    fi
  fi

  echo "playit watchdog is not running"
  return 1
}

case "${1:-status}" in
  auto-start)
    if has_secret; then
      start
      watch_start
    else
      echo "PLAYIT_SECRET_KEY not configured; public tunnel not started"
    fi
    ;;
  start)
    start
    ;;
  stop)
    docker compose --profile public-tunnel stop playit
    ;;
  restart)
    restart_playit
    ;;
  logs)
    docker compose --profile public-tunnel logs -f playit
    ;;
  watch-start)
    watch_start
    ;;
  watch-stop)
    watch_stop
    ;;
  watch-status)
    watch_status
    ;;
  watch-loop)
    watch_loop
    ;;
  status)
    docker compose --profile public-tunnel ps playit
    watch_status || true
    ;;
  *)
    echo "Usage: $0 [auto-start|start|stop|restart|logs|watch-start|watch-stop|watch-status|watch-loop|status]" >&2
    exit 2
    ;;
esac
