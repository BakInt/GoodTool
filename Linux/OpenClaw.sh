#!/bin/bash
# OpenClaw Gateway Recovery Script
# 综合修复：环境变量、systemd user 会话、服务文件缺失、is-enabled 误判

set -e

echo "=== OpenClaw Gateway 一键恢复脚本 ==="

# ---------- 1. 修复 Node 环境（nvm 路径补全）----------
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# 强制使用 nvm 中的 Node 22+（避免系统旧版 Node 干扰）
if command -v nvm &> /dev/null; then
    nvm use 22 2>/dev/null || nvm use node 2>/dev/null || true
fi

# 确保 openclaw 在 PATH 中
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH:/usr/local/bin"

# ---------- 2. 修复 systemd user 环境变量 ----------
USER_ID=$(id -u)
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$USER_ID}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$USER_ID/bus}"

echo "[1/5] 环境变量已设置：XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"

# ---------- 3. 启用 systemd linger（确保退出 SSH 后服务不停止）----------
if command -v loginctl &> /dev/null; then
    LINGER_STATUS=$(loginctl show-user "$USER" 2>/dev/null | grep Linger || true)
    if ! echo "$LINGER_STATUS" | grep -q "yes"; then
        echo "[2/5] 启用 systemd linger（需要 sudo，确保后台持久运行）..."
        sudo loginctl enable-linger "$USER" || echo "⚠️ linger 启用失败，请手动运行: sudo loginctl enable-linger $USER"
    else
        echo "[2/5] systemd linger 已启用"
    fi
else
    echo "[2/5] loginctl 不可用，跳过 linger 检查"
fi

# ---------- 4. 预创建占位服务文件（绕过 is-enabled not-found 误判）----------
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"

# 如果服务文件不存在，先放一个占位符，让 openclaw 的 is-enabled 检查通过
if [ ! -f "$SYSTEMD_USER_DIR/openclaw-gateway.service" ]; then
    echo "[3/5] 创建占位服务文件（绕过 fresh install 的 not-found 误判）..."
    cat > "$SYSTEMD_USER_DIR/openclaw-gateway.service" <<'EOF'
[Unit]
Description=OpenClaw Gateway (placeholder)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/true
RemainAfterExit=yes

[Install]
WantedBy=default.target
EOF
fi

# ---------- 5. 重新加载 systemd 并启用占位服务 ----------
systemctl --user daemon-reload
systemctl --user enable openclaw-gateway.service 2>/dev/null || true

# ---------- 6. 获取真实的 openclaw 路径并写入正式服务文件 ----------
OPENCLAW_BIN=$(command -v openclaw || echo "$HOME/.npm-global/bin/openclaw")
if [ ! -x "$OPENCLAW_BIN" ]; then
    OPENCLAW_BIN=$(find "$HOME" /usr/local/bin -name "openclaw" -type f 2>/dev/null | head -n1)
fi

if [ -z "$OPENCLAW_BIN" ] || [ ! -x "$OPENCLAW_BIN" ]; then
    echo "❌ 找不到 openclaw 可执行文件，请确认已运行: npm install -g openclaw"
    exit 1
fi

echo "[4/5] 找到 openclaw: $OPENCLAW_BIN"

# 写入正式服务文件（包含 DBUS 环境变量，避免 crash loop）
cat > "$SYSTEMD_USER_DIR/openclaw-gateway.service" <<EOF
[Unit]
Description=OpenClaw Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$OPENCLAW_BIN gateway run --port 18789
Restart=always
RestartSec=5
KillMode=process
WorkingDirectory=$HOME/.openclaw
Environment=HOME=$HOME
Environment=PATH=$PATH
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_ID/bus

[Install]
WantedBy=default.target
EOF

# ---------- 7. 最终加载并启动 ----------
echo "[5/5] 重新加载 systemd 并启动 Gateway..."
systemctl --user daemon-reload
systemctl --user enable openclaw-gateway.service
systemctl --user restart openclaw-gateway.service || systemctl --user start openclaw-gateway.service

echo ""
echo "✅ 恢复完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
systemctl --user status openclaw-gateway.service --no-pager || true
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "常用命令："
echo "  查看日志: journalctl --user -u openclaw-gateway -f"
echo "  重启服务: systemctl --user restart openclaw-gateway"
echo "  查看状态: systemctl --user status openclaw-gateway"
