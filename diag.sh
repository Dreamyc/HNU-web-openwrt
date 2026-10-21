#!/bin/sh
# hnu-login 网络诊断脚本（在 OpenWrt 路由器上运行）
# 用法: sh diag.sh
# 不会打印密码；输出里有 IP/MAC，发到公开场合前请自行打码。

CONF=${HNU_CONFIG:-/etc/hnu-login.conf}
[ -f "$CONF" ] && . "$CONF"

portal_host=${portal_host:-web.hnu.edu.cn}
portal_ip=${portal_ip:-}

echo "===== 时间 ====="
date

echo
echo "===== 网卡 / MAC ====="
ip link 2>/dev/null | grep -E "^[0-9]+:|link/ether"

echo
echo "===== IPv4 地址 ====="
ip -4 addr show 2>/dev/null

echo
echo "===== 路由 ====="
ip route 2>/dev/null

echo
echo "===== WAN 状态（过滤密码）====="
if command -v ifstatus >/dev/null 2>&1; then
    ifstatus wan 2>/dev/null | grep -v -i password
else
    echo "没有 ifstatus"
fi

echo
echo "===== DNS 配置 ====="
cat /etc/resolv.conf 2>/dev/null

echo
echo "===== 解析 $portal_host ====="
nslookup "$portal_host" 2>&1

echo
if [ -n "$portal_ip" ]; then
    echo "===== ping 认证服务器 $portal_ip ====="
    ping -c 2 -W 2 "$portal_ip" 2>&1 | tail -4
else
    echo "===== 未配置 portal_ip，跳过按 IP 的连通性测试 ====="
fi

echo
echo "===== HTTP chkstatus（用 IP）====="
fetch_test() {
    if command -v uclient-fetch >/dev/null 2>&1; then
        uclient-fetch -q -T 5 -O - "$1" 2>&1 | head -c 500
    elif command -v wget >/dev/null 2>&1; then
        wget -q -T 5 -O - "$1" 2>&1 | head -c 500
    elif command -v curl >/dev/null 2>&1; then
        curl -sS -m 5 "$1" 2>&1 | head -c 500
    else
        echo "没有可用的 HTTP 客户端"
    fi
}
if [ -n "$portal_ip" ]; then
    fetch_test "http://$portal_ip/drcom/chkstatus?callback=diag&v=1&lang=zh"
else
    echo "未配置 portal_ip，跳过（可在 /etc/hnu-login.conf 中设置）"
fi
echo

echo
echo "===== HTTP chkstatus（用域名）====="
fetch_test "http://$portal_host/drcom/chkstatus?callback=diag&v=1&lang=zh"
echo

echo
echo "===== WAN / LAN 配置（过滤密码和用户名）====="
uci show network 2>/dev/null | grep -E "^network\.(wan|lan)(\.|$)" | grep -v -iE "password|username"

echo
echo "===== hnu-login 日志 ====="
logread 2>/dev/null | grep hnu-login | tail -n 20
