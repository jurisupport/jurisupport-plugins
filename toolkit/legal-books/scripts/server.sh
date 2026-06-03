#!/usr/bin/env bash
# Manage legal-books search server (port 8766)

set -euo pipefail

ROOT="$HOME/legal-books"
VENV="$ROOT/.venv/bin/activate"
PIDFILE="$ROOT/logs/server.pid"
LOGFILE="$ROOT/logs/server.log"
HEALTH_URL="http://localhost:8766/health"

start() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Server already running (PID $(cat "$PIDFILE"))"
    return
  fi
  rm -f "$PIDFILE"
  # shellcheck disable=SC1090
  source "$VENV"
  nohup python "$ROOT/server/server.py" >> "$LOGFILE" 2>&1 &
  echo $! > "$PIDFILE"
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sf "$HEALTH_URL" >/dev/null; then
      echo "Server started (PID $!). Log: $LOGFILE"
      curl -s "$HEALTH_URL"
      echo ""
      return
    fi
    if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      break
    fi
    sleep 0.5
  done
  echo "Server failed to start. Log: $LOGFILE" >&2
  tail -40 "$LOGFILE" >&2 || true
  rm -f "$PIDFILE"
  exit 1
}

stop() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill "$(cat "$PIDFILE")"
    rm -f "$PIDFILE"
    echo "Server stopped"
  else
    rm -f "$PIDFILE"
    echo "Server not running"
  fi
}

status() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Running (PID $(cat "$PIDFILE"))"
    curl -s "$HEALTH_URL" || true
  else
    rm -f "$PIDFILE"
    echo "Not running"
  fi
}

case "${1:-status}" in
  start)   start ;;
  stop)    stop ;;
  restart) stop; sleep 1; start ;;
  status)  status ;;
  *) echo "Usage: $0 {start|stop|restart|status}"; exit 1 ;;
esac
