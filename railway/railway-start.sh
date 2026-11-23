#!/bin/bash
# Railway wrapper for Qinglong. It
#  1. refuses to start without a JWT secret and a first-boot admin password,
#  2. creates the admin account on the very first boot (no open setup wizard),
#  3. runs the upstream entrypoint and exits non-zero if the panel dies,
#     so Railway's ON_FAILURE restart policy brings it back.
set -u
log() { printf '[railway] %s\n' "$*"; }

DATA=/ql/data
export QlPort="${PORT:-5700}"

if [ -z "${JWT_SECRET:-}" ] || [ "${JWT_SECRET}" = "whyour-secret" ]; then
  log "JWT_SECRET is empty or the public upstream default; refusing to start."; exit 1
fi

# CPU share for the task queues (see cpu-cap.cjs).
if [ -z "${QL_CPU_LIMIT:-}" ]; then
  QL_CPU_LIMIT=2
  if [ -r /sys/fs/cgroup/cpu.max ]; then
    read -r quota period < /sys/fs/cgroup/cpu.max || true
    if [ "${quota:-max}" != "max" ] && [ -n "${period:-}" ]; then
      QL_CPU_LIMIT=$(( (quota + period - 1) / period ))
    fi
  fi
  [ "$QL_CPU_LIMIT" -ge 1 ] 2>/dev/null || QL_CPU_LIMIT=2
fi
export QL_CPU_LIMIT

# First boot only: seed the admin account. Qinglong reads config/auth.json
# once, when its database has no login yet; afterwards the panel owns it.
mkdir -p "$DATA/config" "$DATA/db"
if [ ! -s "$DATA/db/database.sqlite" ]; then
  if [ -z "${QL_ADMIN_PASSWORD:-}" ] || [ "${QL_ADMIN_PASSWORD}" = "admin" ]; then
    log "QL_ADMIN_PASSWORD must be set (and not 'admin') for the first boot; refusing to start."; exit 1
  fi
  hash=$(node -e 'const c=require("crypto");const s=c.randomBytes(16).toString("hex");process.stdout.write("scrypt$"+s+"$"+c.scryptSync(process.env.QL_ADMIN_PASSWORD,s,64).toString("hex"))') || { log "could not hash the admin password"; exit 1; }
  jq -n --arg u "${QL_ADMIN_USERNAME:-admin}" --arg p "$hash" '{username:$u,password:$p}' > "$DATA/config/auth.json" || exit 1
  log "first boot: admin account '${QL_ADMIN_USERNAME:-admin}' prepared"
fi
unset QL_ADMIN_PASSWORD

child=0
stop() {
  log "stopping"
  pm2 kill >/dev/null 2>&1 || true
  [ "$child" -gt 0 ] && kill -TERM "$child" 2>/dev/null
  exit 143
}
trap stop TERM INT

/ql/docker/docker-entrypoint.sh &
child=$!

# Watchdog: the upstream entrypoint keeps running (crond) even after PM2
# gives up on the panel, so check the health endpoint ourselves.
url="http://127.0.0.1:${QlPort}/api/health"
grace=${QL_WATCHDOG_GRACE:-240}; fails=0; up=0; start=$(date +%s)
while :; do
  sleep 10 & wait $!
  if ! kill -0 "$child" 2>/dev/null; then
    wait "$child"; rc=$?
    log "upstream entrypoint exited (code $rc)"; exit $(( rc == 0 ? 1 : rc ))
  fi
  if curl -sf --noproxy '*' -o /dev/null -m 5 "$url"; then
    [ "$up" = 0 ] && log "panel healthy on port ${QlPort}"
    up=1; fails=0
  else
    fails=$((fails + 1))
    if [ "$up" = 0 ] && [ $(( $(date +%s) - start )) -gt "$grace" ]; then
      log "panel not healthy ${grace}s after start; exiting"; exit 1
    fi
    if [ "$up" = 1 ] && [ "$fails" -ge 9 ]; then
      log "panel unhealthy for 90s; exiting so Railway restarts it"; exit 1
    fi
  fi
done
