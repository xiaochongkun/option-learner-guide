#!/usr/bin/env bash
set -euo pipefail
CADDY_MAIN='/etc/caddy/Caddyfile'
DOMAIN_HOST='kunkka.spailab.com'
BASE_PATH='/option-learner-guide'
PORT='3101'

read -r -d '' SNIPPET <<EOT
    handle /option-learner-guide* {
        reverse_proxy 127.0.0.1:3101 {
            header_up Host {host}
            transport http {
                read_timeout 3600s
                write_timeout 3600s
                dial_timeout 10s
                keepalive 64
            }
        }
    }
EOT

cp -a "$CADDY_MAIN" "${CADDY_MAIN}.bak.$(date +%F-%H%M%S)"

if awk '/^kunkka.spailab.com\s*\{/{flag=1} flag && /^\}/{flag=0; found=1} END{exit !found}' "$CADDY_MAIN"; then
  awk -v host='kunkka.spailab.com' -v s="$SNIPPET" '{
    if($0 ~ "^"host"[[:space:]]*\{"){inhost=1}
    if(inhost && $0 ~ /^\}/){print s; inhost=0}
    print $0
  }' "$CADDY_MAIN" > /tmp/Caddyfile.new && mv /tmp/Caddyfile.new "$CADDY_MAIN"
else
  printf '%s\n' 'kunkka.spailab.com {' '    encode zstd gzip' "$SNIPPET" '}' >> "$CADDY_MAIN"
fi

caddy validate --config "$CADDY_MAIN"
systemctl reload caddy || systemctl restart caddy
