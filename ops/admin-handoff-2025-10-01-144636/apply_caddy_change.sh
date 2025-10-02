#!/usr/bin/env bash
set -euo pipefail
CADDY_MAIN='/etc/caddy/Caddyfile'
DOMAIN_HOST='kunkka.spailab.com'
BASE_PATH='/option-learner-guide'
PORT='3101'

SNIPPET=$'\n    handle /option-learner-guide* {\n        reverse_proxy 127.0.0.1:3101 {\n            header_up Host {host}\n            transport http {\n                read_timeout 3600s\n                write_timeout 3600s\n                dial_timeout 10s\n                keepalive 64\n            }\n        }\n    }\n'

cp -a "$CADDY_MAIN" "${CADDY_MAIN}.bak.$(date +%F-%H%M%S)"

if awk '/^kunkka.spailab.com\s*\{/{flag=1} flag && /^\}/{flag=0; found=1} END{exit !found}' "$CADDY_MAIN"; then
  awk -v host="kunkka.spailab.com" -v s="$SNIPPET" '{
    if($0 ~ "^"host"[[:space:]]*\{"){inhost=1}
    if(inhost && $0 ~ /^\}/){print s; inhost=0}
    print $0
  }' "$CADDY_MAIN" > /tmp/Caddyfile.new && mv /tmp/Caddyfile.new "$CADDY_MAIN"
else
  printf '%s\n' "$DOMAIN_HOST {" "    encode zstd gzip" "$SNIPPET" "}" >> "$CADDY_MAIN"
fi

caddy validate --config "$CADDY_MAIN"
systemctl reload caddy || systemctl restart caddy
