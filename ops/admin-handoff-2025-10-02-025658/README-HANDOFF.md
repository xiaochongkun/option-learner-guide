# 管理员交付包：option-learner-guide 上线配置

## 目标
将子域名 `option-learner-guide-kunkka.opsignalplus.com` 反代到本地 `127.0.0.1:3101`（Next.js 已由 PM2 托管），并用 Let's Encrypt 启用 HTTPS（80/443），不依赖任何外部托管。

## 当前状态
✅ Next.js 项目已构建（basePath: '' 根路径部署）
✅ SSE 接口已修复（/api/stream 客户端断开安全处理）
✅ PM2 托管服务运行正常（端口 3101）
✅ 本地健康检查通过：
   - http://127.0.0.1:3101/ → 200
   - http://127.0.0.1:3101/api/teaching → 200
   - http://127.0.0.1:3101/api/stream → SSE流正常

## 快速执行（一键上线）
```bash
sudo bash apply_nginx.sh
```

## 手动步骤（如需分步执行）

### 1. 安装 Nginx + Certbot
```bash
apt update -y
apt install -y nginx certbot python3-certbot-nginx
```

### 2. 配置 Nginx 站点
站点配置已生成在 `/etc/nginx/sites-available/option-learner-guide-kunkka.opsignalplus.com`，包含：
- HTTP (80) → HTTPS (443) 自动跳转
- 根路径 `/` 反向代理到 `127.0.0.1:3101`
- SSE 流式接口 `/api/stream` 优化配置（禁用缓冲、24小时超时）

### 3. 启用站点并重载
```bash
ln -sf /etc/nginx/sites-available/option-learner-guide-kunkka.opsignalplus.com /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
```

### 4. 申请 SSL 证书
```bash
certbot --nginx -d option-learner-guide-kunkka.opsignalplus.com \
  --agree-tos -m admin@option-learner-guide-kunkka.opsignalplus.com \
  --no-eff-email -n
systemctl reload nginx
```

## 回归验证（预期 200/304）
```bash
curl -I https://option-learner-guide-kunkka.opsignalplus.com
curl -s https://option-learner-guide-kunkka.opsignalplus.com/api/teaching | head -5
timeout 6 curl -Ns https://option-learner-guide-kunkka.opsignalplus.com/api/stream | head -1
```

## 故障排查

### DNS 未解析
```bash
nslookup option-learner-guide-kunkka.opsignalplus.com
# 确保 A 记录指向服务器公网 IP
```

### 端口 80/443 被占用
```bash
netstat -tlnp | grep ':80\|:443'
# 停止冲突服务或调整配置
```

### PM2 服务异常
```bash
pm2 status option-learner-guide
pm2 logs option-learner-guide --lines 50
pm2 restart option-learner-guide
```

### Nginx 配置错误
```bash
nginx -t
journalctl -u nginx -n 50
```

## 联系信息
- 项目路径: /home/kunkka/projects/option-learner-guide
- PM2 服务名: option-learner-guide
- 端口: 3101
