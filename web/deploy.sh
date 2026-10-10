#!/usr/bin/env bash
# 一条龙部署：把 web/ 下三个页面上传到 ECS 并配置 nginx + HTTPS。
# 用法（在 Mac 项目根目录执行）：
#   bash web/deploy.sh root@47.116.203.151
# 前置：ECS 安全组已放行 80/443 端口（入方向），见仓库 APPSTORE.md 提醒。
set -euo pipefail
DEST="${1:?用法: bash web/deploy.sh root@<ECS公网IP>}"
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> 上传页面到 $DEST"
ssh "$DEST" 'rm -rf /tmp/nephron-web-up && mkdir -p /tmp/nephron-web-up/nephron'
scp "$DIR/index.html" "$DEST:/tmp/nephron-web-up/"
scp "$DIR"/nephron/*.html "$DEST:/tmp/nephron-web-up/nephron/"

echo "==> 服务器端：安装 nginx、布置站点、申请 HTTPS 证书"
ssh "$DEST" 'bash -s' <<'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx certbot python3-certbot-nginx

rm -rf /var/www/nephron && mkdir -p /var/www/nephron
cp -r /tmp/nephron-web-up/* /var/www/nephron/

cat > /etc/nginx/sites-available/nephron <<'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name ygysdev.cn www.ygysdev.cn;
    root /var/www/nephron;
    index index.html;
    location / {}
}
NGINX
ln -sf /etc/nginx/sites-available/nephron /etc/nginx/sites-enabled/nephron
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

certbot --nginx -d ygysdev.cn -d www.ygysdev.cn \
  --non-interactive --agree-tos -m lvxiulei.cloud@outlook.com --redirect

echo "==> 部署完成：http/https 均已生效"
REMOTE

echo "==> 本机验证"
sleep 2
curl -sI "https://ygysdev.cn/nephron/privacy.html" | head -1
curl -sI "https://ygysdev.cn/nephron/support.html" | head -1
