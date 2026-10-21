#!/bin/sh
# 路由器转发性能 / 链路诊断
# 用法: sh perfdiag.sh
# 建议在“通过路由器测速”的同时再开一个 SSH 窗口看 CPU。

CONF=${HNU_CONFIG:-/etc/hnu-login.conf}
[ -f "$CONF" ] && . "$CONF"
portal_host=${portal_host:-web.hnu.edu.cn}
portal_ip=${portal_ip:-}
gateway=$(ip route 2>/dev/null | sed -n 's/^default via \([0-9.]*\).*/\1/p' | head -n 1)

echo "===== 设备信息 ====="
ubus call system board 2>/dev/null | grep -E '"(model|system|release)"'
grep -E '^(system type|model name|Processor)' /proc/cpuinfo 2>/dev/null | head -5

echo
echo "===== 有线链路速率（speed / duplex）====="
for d in wan eth0 lan1 lan2 lan3 br-lan; do
    if [ -e "/sys/class/net/$d/speed" ]; then
        printf '%s: %s Mbps, %s\n' \
            "$d" \
            "$(cat /sys/class/net/$d/speed 2>/dev/null)" \
            "$(cat /sys/class/net/$d/duplex 2>/dev/null)"
    fi
done

echo
echo "===== 防火墙加速 / SQM ====="
uci show firewall 2>/dev/null | grep -iE 'offload|flow'
echo "--- sqm ---"
uci show sqm 2>/dev/null || echo "未配置 SQM"
echo "--- packet steering ---"
uci get network.globals.packet_steering 2>/dev/null || echo "未设置"

echo
echo "===== Wi-Fi 状态 ====="
if command -v iwinfo >/dev/null 2>&1; then
    iwinfo 2>/dev/null | head -40
else
    echo "iwinfo 未安装"
fi

echo
echo "===== DNS 解析耗时 ====="
time nslookup "$portal_host" 2>&1 | head -10

echo
echo "===== 延迟 ====="
if [ -n "$gateway" ]; then
    echo "网关 $gateway:"
    ping -c 3 "$gateway" 2>&1 | tail -3
else
    echo "未找到默认网关"
fi
echo "认证服务器 $portal_host:"
ping -c 3 "$portal_host" 2>&1 | tail -3
if [ -n "$portal_ip" ]; then
    echo "认证服务器 $portal_ip:"
    ping -c 3 "$portal_ip" 2>&1 | tail -3
fi

echo
echo "===== CPU 占用快照（测速时再看一次）====="
top -b -n 1 2>/dev/null | head -12

echo
echo "===== 在线状态 ====="
if command -v hnu-login >/dev/null 2>&1; then
    hnu-login status 2>/dev/null
else
    echo "hnu-login 未安装"
fi
