#!/usr/bin/env sh
set -eu

REPO_DIR="${PLAYIT_REPO_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"

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

case "${1:-status}" in
  auto-start)
    if has_secret; then
      start
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
    docker compose --profile public-tunnel restart playit
    ;;
  logs)
    docker compose --profile public-tunnel logs -f playit
    ;;
  status)
    docker compose --profile public-tunnel ps playit
    ;;
  *)
    echo "Usage: $0 [auto-start|start|stop|restart|logs|status]" >&2
    exit 2
    ;;
esac
