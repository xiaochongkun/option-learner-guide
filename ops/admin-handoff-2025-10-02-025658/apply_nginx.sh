#!/usr/bin/env bash
set -euo pipefail
DOMAIN='option-learner-guide-kunkka.opsignalplus.com'
PORT='3101'

echo '[i] 安装 Nginx + Certbot'
apt update -y
apt install -y nginx certbot python3-certbot-nginx

echo '[i] 写入 Nginx 站点配置'
tee /etc/nginx/sites-available/$DOMAIN > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }

    location /api/stream {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Cache-Control "no-cache";
        proxy_set_header X-Accel-Buffering "no";
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 24h;
        proxy_send_timeout 24h;
    }
}
EOF

echo '[i] 启用站点并移除默认配置'
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN
rm -f /etc/nginx/sites-enabled/default || true

echo '[i] 校验并重载 Nginx'
nginx -t
systemctl reload nginx

echo '[i] 申请 Let'\''s Encrypt 证书'
certbot --nginx -d "$DOMAIN" \
  --agree-tos -m "admin@$DOMAIN" \
  --no-eff-email -n || true

echo '[i] 重载 Nginx 启用 HTTPS'
systemctl reload nginx || true

echo '[✓] 上线完成！验证命令：'
echo "    curl -I https://$DOMAIN"
echo "    curl -s https://$DOMAIN/api/teaching | head -5"
echo "    timeout 6 curl -Ns https://$DOMAIN/api/stream | head -1"
