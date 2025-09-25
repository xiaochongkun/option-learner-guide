#!/bin/bash
set -e

PROJECT_DIR="/home/kunkka/projects/option-learner-guide"
DOMAIN="kunkka.opsignalplus.com"
PORT_DEFAULT="3601"
NPM_BIN="/usr/bin/npm"
NODE_BIN="/usr/bin/node"
MODE_DEFAULT="pm2"

while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --project-dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            if [[ ! "$PORT" =~ ^36[0-9][0-9]$ ]] || [[ "$PORT" -lt 3601 ]] || [[ "$PORT" -gt 3700 ]]; then
                echo "错误：端口必须在 3601-3700 范围内"
                exit 1
            fi
            shift 2
            ;;
        --mode)
            MODE="$2"
            if [[ "$MODE" != "pm2" && "$MODE" != "systemd" ]]; then
                echo "错误：模式只能是 pm2 或 systemd"
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "未知参数: $1"
            echo "用法: $0 [--domain 域名] [--project-dir 项目路径] [--port 端口] [--mode pm2|systemd]"
            exit 1
            ;;
    esac
done

PORT="${PORT:-$PORT_DEFAULT}"
MODE="${MODE:-$MODE_DEFAULT}"

echo "=== 开始部署 Option Learner Guide ==="
echo "项目目录: $PROJECT_DIR"
echo "域名: $DOMAIN"
echo "端口: $PORT"
echo "守护模式: $MODE"
echo ""

cd "$PROJECT_DIR"

echo "=== 1. 安装依赖 ==="
if [[ ! -f "package.json" ]]; then
    echo "错误：未找到 package.json 文件"
    exit 1
fi

$NPM_BIN install
echo "✓ 依赖安装完成"

echo "=== 2. 构建项目 ==="
$NPM_BIN run build
echo "✓ 项目构建完成"

echo "=== 3. 生成配置文件 ==="
sed "s/{{PORT}}/$PORT/g; s|{{PROJECT_DIR}}|$PROJECT_DIR|g; s|{{NODE_BIN}}|$NODE_BIN|g" ops/ecosystem.config.js.template > ops/ecosystem.config.cjs
sed "s/{{PORT}}/$PORT/g; s|{{PROJECT_DIR}}|$PROJECT_DIR|g; s|{{NODE_BIN}}|$NODE_BIN|g" ops/option-learner-guide.service.template > ops/option-learner-guide.service
sed "s/{{DOMAIN}}/$DOMAIN/g; s/{{PORT}}/$PORT/g" ops/nginx.conf.template > ops/nginx.conf
echo "✓ 配置文件生成完成"

echo "=== 4. 部署应用（$MODE 模式）==="
if [[ "$MODE" == "pm2" ]]; then
    if ! command -v pm2 &> /dev/null; then
        echo "安装 PM2..."
        npm install -g pm2
    fi

    pm2 delete option-learner-guide 2>/dev/null || true
    pm2 start ops/ecosystem.config.cjs
    pm2 save
    echo "✓ PM2 部署完成"

    if ! pm2 startup | grep -q "already setup"; then
        echo "配置 PM2 开机启动（需要 sudo 权限）:"
        pm2 startup
    fi
else
    sudo cp ops/option-learner-guide.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable option-learner-guide
    sudo systemctl restart option-learner-guide
    echo "✓ Systemd 部署完成"
fi

echo "=== 5. 配置 Nginx ==="
if [[ ! -d "/etc/nginx/sites-available" ]]; then
    echo "错误：Nginx 未安装或配置不正确"
    exit 1
fi

sudo cp ops/nginx.conf /etc/nginx/sites-available/$DOMAIN
sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

if sudo nginx -t; then
    sudo systemctl reload nginx
    echo "✓ Nginx 配置完成"
else
    echo "错误：Nginx 配置验证失败"
    exit 1
fi

echo ""
echo "=== 部署完成 ==="
echo "应用地址: https://$DOMAIN"
echo "应用端口: $PORT"
echo "守护模式: $MODE"
echo ""
echo "验证部署:"
echo "  curl -I https://$DOMAIN"
echo "  curl https://$DOMAIN/api/stream"
echo ""
echo "查看日志:"
if [[ "$MODE" == "pm2" ]]; then
    echo "  pm2 logs option-learner-guide"
else
    echo "  sudo journalctl -u option-learner-guide -f"
fi
echo "  sudo tail -f /var/log/nginx/$DOMAIN.access.log"