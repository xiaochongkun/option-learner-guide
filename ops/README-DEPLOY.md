# 部署运行手册（Option Learner Guide）

**项目路径**：/home/kunkka/projects/option-learner-guide
**公网地址/域名**：172.93.186.229
**默认端口**：3000

## 快速开始（推荐 tmux 防断线）
```bash
sudo apt update && sudo apt install -y tmux
tmux new -s optguide
# 在 tmux 中执行（假设你已在项目根）
bash ops/deploy.sh --domain 172.93.186.229 --project-dir /home/kunkka/projects/option-learner-guide --port 3000 --mode pm2
```

## 部署方式说明

### 1. PM2 模式（推荐）
```bash
bash ops/deploy.sh --mode pm2
```
- 自动重启、日志管理
- 支持集群模式
- 内置进程监控

### 2. Systemd 模式
```bash
bash ops/deploy.sh --mode systemd
```
- 系统级服务管理
- 开机自启
- systemctl 命令控制

### 3. 直接运行模式
```bash
bash ops/deploy.sh --mode direct
```
- 前台运行，适合调试
- Ctrl+C 停止服务

## 配置参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| --domain | 172.93.186.229 | 公网域名/IP |
| --port | 3000 | 应用端口 |
| --project-dir | /home/kunkka/projects/option-learner-guide | 项目路径 |
| --mode | pm2 | 运行模式 (pm2/systemd/direct) |
| --node-bin | /usr/bin/node | Node.js 可执行文件路径 |
| --npm-bin | /usr/bin/npm | NPM 可执行文件路径 |

## 服务管理命令

### PM2 模式
```bash
# 查看状态
pm2 status option-learner-guide
pm2 logs option-learner-guide

# 重启/停止
pm2 restart option-learner-guide
pm2 stop option-learner-guide
pm2 delete option-learner-guide
```

### Systemd 模式
```bash
# 查看状态
sudo systemctl status option-learner-guide
sudo journalctl -u option-learner-guide -f

# 重启/停止
sudo systemctl restart option-learner-guide
sudo systemctl stop option-learner-guide
sudo systemctl disable option-learner-guide
```

## 故障排查

### 1. 端口被占用
```bash
sudo lsof -i :3000
sudo kill -9 <PID>
```

### 2. Nginx 配置检查
```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 3. 日志查看
```bash
# PM2 日志
pm2 logs option-learner-guide --lines 100

# Systemd 日志
sudo journalctl -u option-learner-guide --since "1 hour ago"

# Nginx 日志
sudo tail -f /var/log/nginx/option-learner-guide.access.log
sudo tail -f /var/log/nginx/option-learner-guide.error.log
```

### 4. 依赖问题
```bash
# 重新安装依赖
cd /home/kunkka/projects/option-learner-guide
npm install

# 清理缓存
npm cache clean --force
rm -rf node_modules package-lock.json
npm install
```

## SSE 接口说明

应用包含 Server-Sent Events 接口 `/api/stream`，Nginx 已配置：
- 关闭代理缓冲 (`proxy_buffering off`)
- 延长超时时间 (`proxy_read_timeout 24h`)
- 设置正确的头部信息

测试 SSE 接口：
```bash
curl -N http://172.93.186.229/api/stream
```

## 安全建议

1. 配置防火墙只开放必要端口
2. 定期更新系统和依赖
3. 监控服务状态和日志
4. 备份重要配置文件

## 联系与支持

如遇问题，请检查：
1. 服务运行状态
2. 端口是否被占用
3. 日志文件错误信息
4. 网络连通性