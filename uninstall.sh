#!/bin/sh
# 卸载 hnu-login（保留配置文件）
/etc/init.d/hnu-login stop 2>/dev/null || true
/etc/init.d/hnu-login disable 2>/dev/null || true
rm -f /etc/init.d/hnu-login /usr/bin/hnu-login
echo "已卸载。配置文件 /etc/hnu-login.conf 仍保留，如不需要请手动删除。"
