# 湖南大学校园网自动登录（OpenWrt）

在 OpenWrt 路由器上运行，替代电脑上的 Dr.COM 网页认证。
路由器完成认证后，所有通过它上网的设备都可以直接联网。

纯 BusyBox ash 脚本，**不需要 Python**，会自动检测并使用
`wget` / `curl` / `uclient-fetch` 中的任意一个。

## 目录文件

| 文件 | 说明 |
| --- | --- |
| `hnu-login` | 主脚本（安装后位于 `/usr/bin/hnu-login`） |
| `hnu-login.init` | procd 服务（安装后位于 `/etc/init.d/hnu-login`） |
| `hnu-login.conf.example` | 配置模板 |
| `install.sh` / `uninstall.sh` | 安装 / 卸载 |
| `diag.sh` | 网络 / DNS / WAN 诊断 |
| `perfdiag.sh` | 转发性能、链路速率、Wi-Fi、CPU 诊断 |

## 安装步骤

在 Windows 上把整个 `openwrt` 目录传到路由器（把 `<路由器IP>` 换成你的路由器地址）：

```powershell
scp -r .\openwrt root@<路由器IP>:/tmp/
ssh root@<路由器IP>
```

然后在路由器的 SSH 里执行：

```sh
cd /tmp/openwrt
sh install.sh
vi /etc/hnu-login.conf
```

配置文件至少填写这三项：

```sh
username='你的学号'
password='你的密码'
isp='campus'         # 校园网填 campus，电信填 telecom
```

启动并设置开机自启：

```sh
/etc/init.d/hnu-login enable
/etc/init.d/hnu-login start
```

查看日志：

```sh
logread -f | grep hnu-login
```

## 手动命令

```sh
hnu-login status          # 查看是否已认证
hnu-login login           # 登录一次
hnu-login debug           # 显示配置、认证 IP 和 chkstatus 原始返回
hnu-login watch           # 前台常驻（调试时用）
hnu-login encode '文本'    # 查看 URL 编码结果（调试用）
```

服务控制：

```sh
/etc/init.d/hnu-login start
/etc/init.d/hnu-login stop
/etc/init.d/hnu-login restart
/etc/init.d/hnu-login enable
/etc/init.d/hnu-login disable
```

## 上网出口

登录页的下拉框有两个出口，脚本通过账号后缀区分：

| 出口 | 配置 | 提交的账号 |
| --- | --- | --- |
| 校园网 | `isp='campus'` | `,0,学号` |
| 电信 | `isp='telecom'` | `,0,学号@telecom` |

出口选错时，认证会提示“学号或工号有误或密码错误”。改完配置后
执行 `/etc/init.d/hnu-login restart` 生效。

## 工作原理

1. `GET http://web.hnu.edu.cn/drcom/chkstatus` 查询路由器 WAN 口 IP 是否已认证；
   返回 `result: 1` 表示在线，`result: 0` 表示未认证。
2. 未认证时调用
   `GET http://web.hnu.edu.cn:801/eportal/portal/login`，参数包括：
   - `login_method=1`
   - `user_account=,0,学号[@telecom]`
   - `user_password=密码`
   - `wlan_user_ip` / `wlan_ac_ip`（来自 chkstatus）
   - `terminal_type=1`、`lang=zh`、`jsVersion=4.2.1`
3. 返回 `result: 1` 后再次查询状态复核。

登录守护每 `interval` 秒检查一次；掉线会自动重连。
如果认证失败（例如密码错误），会指数退避（120 秒起，最长 `max_backoff`），
避免反复试错导致账号被临时锁定。

## 注意事项

- 路由器需要是 **NAT 路由模式**，WAN 口使用 **DHCP（自动获取 IP）**，
  不要配置成 PPPoE；认证的是路由器的 WAN 口 IP。AP/桥接模式下认证的是
  上游设备，本脚本不适用。
- 配置文件含明文密码，已设为 `600` 权限，请勿分享。
- **认证前 DNS 被拦截是常见现象**：WAN 能拿到 IP、能 ping 通认证服务器，
  但 `nslookup web.hnu.edu.cn` 没有结果。此时保持 `portal_host` 为域名，
  在配置里填上 `portal_ip`（在已联网设备上用 `nslookup web.hnu.edu.cn`
  获取），脚本会在域名访问不通时自动回退到 IP。也可以直接把
  `portal_host` 改成 IP。认证成功后 DNS 通常会恢复。
- 脚本只用 HTTP，不需要安装 `ca-bundle` 等证书包。
- 如果在 Windows 上修改过脚本，`install.sh` 会自动去掉 CRLF；手动复制时
  建议保持 LF 换行。
- 卸载：`sh uninstall.sh`（配置文件会保留）。

## 常见问题

**日志提示“无法连接认证服务器”**
确认路由器 WAN 口已连接校园网、能解析/访问 `web.hnu.edu.cn`。
未认证时 DNS 可能被校园网拦截，按上面的 `portal_ip` 回退方法处理。

**日志提示 `od: not found` / “无法获取用户认证账号”**
部分 ImmortalWrt/OpenWrt 的 BusyBox 没有编译 `od`。请更新到最新版
`hnu-login`：新版自带纯 shell 编码回退，不需要 `od`。

**域名解析为空 / 0.00 秒返回空，但用 IP 能访问**
`web.hnu.edu.cn` 解析到私网地址，OpenWrt 的 dnsmasq 默认
DNS-rebind protection 会丢弃这种 RFC1918 响应（日志里会看到
`DNS rebinding protection is active`）。放行湖大域名：

```sh
uci add_list dhcp.@dnsmasq[0].rebind_domain='hnu.edu.cn'
uci commit dhcp
/etc/init.d/dnsmasq restart
nslookup web.hnu.edu.cn
```

也可以临时关闭保护：`uci set dhcp.@dnsmasq[0].rebind_protection='0'`。

**通过路由器测速很慢**
先只保留路由器在线，排除多设备共享带宽和账号多会话；再检查
`perfdiag.sh` 里的 WAN/LAN 协商速率（100 还是 1000）、offload/SQM、
CPU 占用和 WAN 错误计数。MT7621 + 千兆口 + flow offloading 正常应能跑满
校园网带宽，若明显低于直连，优先查 DNS、端口协商和 MAC 绑定档位。

**提示“学号或工号有误或密码错误”**
先确认密码正确，再确认 `isp` 是否与套餐一致（校园网 / 电信）。

**认证成功但局域网设备仍不能上网**
检查路由器的 NAT、防火墙和 DNS 配置；脚本只负责 WAN 口认证。
