#!/bin/sh
# 在 OpenWrt 路由器上安装 hnu-login
set -e

HERE=$(cd "$(dirname "$0")" && pwd)

echo "安装 hnu-login ..."

cp "$HERE/hnu-login" /usr/bin/hnu-login
cp "$HERE/hnu-login.init" /etc/init.d/hnu-login
chmod 755 /usr/bin/hnu-login /etc/init.d/hnu-login

# 兼容在 Windows 上编辑后带 CRLF 的文件
sed -i 's/\r$//' /usr/bin/hnu-login /etc/init.d/hnu-login

if [ ! -f /etc/hnu-login.conf ]; then
    cp "$HERE/hnu-login.conf.example" /etc/hnu-login.conf
    chmod 600 /etc/hnu-login.conf
    echo
    echo "已创建配置文件：/etc/hnu-login.conf"
    echo "请先编辑并填写学号、密码和上网出口："
    echo
    echo "  vi /etc/hnu-login.conf"
    echo
    echo "然后启动服务："
    echo
    echo "  /etc/init.d/hnu-login enable"
    echo "  /etc/init.d/hnu-login start"
    exit 0
fi

chmod 600 /etc/hnu-login.conf
/etc/init.d/hnu-login enable
/etc/init.d/hnu-login restart || /etc/init.d/hnu-login start

echo
echo "安装完成。"
echo "查看日志：logread -f | grep hnu-login"
