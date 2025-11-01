# 练习 2：端口过滤和传输层匹配
# 难度：⭐⭐ 初级
# 学习目标：掌握 TCP/UDP 端口匹配，理解传输层过滤

# ============================================
# 任务 1：保护 SSH 服务（端口 22）
# ============================================

chain protect_ssh BF_HOOK_NF_LOCAL_IN DROP
    # 只允许来自管理网段（192.168.1.0/24）的 SSH 连接
    rule ip4.proto tcp tcp.dport 22 ip4.snet 192.168.1.0/24 counter ACCEPT

    # 其他 SSH 连接都被阻止（记录日志）
    # 注意：由于默认策略是 DROP，这条规则是可选的（用于统计被阻止的尝试）
    rule ip4.proto tcp tcp.dport 22 log meta counter DROP

# 测试方法：
# 1. 修改 IP 网段为你的实际网络
# 2. 加载规则：sudo build/output/sbin/bfcli ruleset set --from-file learning_exercises/exercise_02_ports.bf
# 3. 从允许的 IP 尝试 SSH（应该成功）
# 4. 从其他 IP 尝试 SSH（应该被阻止）
# 5. 查看 counter 统计

# ============================================
# 任务 2：Web 服务器端口控制
# ============================================

chain web_server BF_HOOK_NF_LOCAL_IN ACCEPT
    # 允许 HTTP 流量（端口 80）
    rule ip4.proto tcp tcp.dport 80 counter ACCEPT

    # 允许 HTTPS 流量（端口 443）
    rule ip4.proto tcp tcp.dport 443 counter ACCEPT

    # 阻止其他高危端口
    # 阻止 Telnet（端口 23）
    rule ip4.proto tcp tcp.dport 23 log meta counter DROP

    # 阻止 FTP（端口 21）
    rule ip4.proto tcp tcp.dport 21 counter DROP

    # 阻止 MySQL（端口 3306）- 只允许本地访问
    rule ip4.proto tcp tcp.dport 3306 ip4.saddr !127.0.0.1 counter DROP

# 注意：最后一条规则使用了 ! 操作符（取反）
# ip4.saddr !127.0.0.1 表示"源地址不是 127.0.0.1"

# ============================================
# 任务 3：DNS 和 DHCP 服务
# ============================================

chain network_services BF_HOOK_NF_LOCAL_IN ACCEPT
    # 允许 DNS 查询（UDP 端口 53）
    rule ip4.proto udp udp.dport 53 counter ACCEPT

    # 允许 DNS over TCP（端口 53）
    rule ip4.proto tcp tcp.dport 53 counter ACCEPT

    # 允许 DHCP 客户端（UDP 端口 67-68）
    rule ip4.proto udp udp.sport 67 counter ACCEPT
    rule ip4.proto udp udp.dport 68 counter ACCEPT

# ============================================
# 任务 4：出站流量控制（LOCAL_OUT）
# ============================================

# 控制本机发出的流量
chain outbound_control BF_HOOK_NF_LOCAL_OUT ACCEPT
    # 统计本机访问的 HTTP 流量
    rule ip4.proto tcp tcp.dport 80 counter ACCEPT

    # 统计本机访问的 HTTPS 流量
    rule ip4.proto tcp tcp.dport 443 counter ACCEPT

    # 阻止本机访问特定端口（如恶意软件常用端口）
    rule ip4.proto tcp tcp.dport 4444 log meta counter DROP
    rule ip4.proto tcp tcp.dport 5555 log meta counter DROP

    # 限制只能 SSH 到特定服务器
    rule ip4.proto tcp tcp.dport 22 ip4.daddr 192.168.1.100 counter ACCEPT
    rule ip4.proto tcp tcp.dport 22 counter DROP

# ============================================
# 任务 5：源端口匹配
# ============================================

chain source_port_filter BF_HOOK_NF_LOCAL_IN ACCEPT
    # 阻止来自特权端口的可疑流量（通常客户端不应该使用这些端口）
    # 阻止源端口为 0-1023 的入站 TCP 连接（除了标准响应）

    # 允许 HTTP 响应（源端口 80）
    rule ip4.proto tcp tcp.sport 80 counter ACCEPT

    # 允许 HTTPS 响应（源端口 443）
    rule ip4.proto tcp tcp.sport 443 counter ACCEPT

    # 记录其他使用特权源端口的流量（可能是扫描或欺骗）
    # 注意：这是示例，实际使用需要更精细的规则
    # rule ip4.proto tcp tcp.sport 0-1023 log meta counter DROP

# ============================================
# 任务 6：TCP 标志位匹配
# ============================================

chain tcp_flags_control BF_HOOK_NF_LOCAL_IN ACCEPT
    # 阻止 TCP SYN flood 攻击的基础防御
    # 匹配只设置了 SYN 标志的包
    rule ip4.proto tcp tcp.flags syn counter ACCEPT

    # 阻止无效的 TCP 标志组合（XMAS 扫描：FIN+PSH+URG）
    # 注意：tcp.flags 匹配需要查看文档了解具体语法

# ============================================
# 知识点总结
# ============================================

# 1. TCP 端口匹配：
#    - tcp.sport <端口>     : 源端口
#    - tcp.dport <端口>     : 目标端口
#    - tcp.flags <标志>     : TCP 标志位

# 2. UDP 端口匹配：
#    - udp.sport <端口>     : 源端口
#    - udp.dport <端口>     : 目标端口

# 3. 端口表示方法：
#    - 单个端口：22
#    - 端口范围：1000-2000（如果支持）

# 4. 组合匹配器：
#    在一条规则中可以组合多个匹配器
#    rule ip4.proto tcp tcp.dport 22 ip4.saddr 192.168.1.100 ACCEPT

# 5. 取反操作符：
#    使用 ! 表示"不等于"
#    ip4.saddr !192.168.1.1

# 6. 不同 Hook 的用途：
#    - NF_LOCAL_IN  : 入站流量（发往本机）
#    - NF_LOCAL_OUT : 出站流量（本机发出）
#    - NF_FORWARD   : 转发流量（路由器场景）

# ============================================
# 挑战练习
# ============================================

# 尝试自己编写规则实现以下功能：

# 1. 防火墙基础配置：
#    - 允许 SSH（22）、HTTP（80）、HTTPS（443）
#    - 允许本地回环（127.0.0.1）
#    - 阻止所有其他入站流量
#    - 允许所有出站流量

# 2. 端口敲门（Port Knocking）概念：
#    - 正常情况下阻止 SSH
#    - 只有先访问特定端口序列后才开放 SSH
#    （提示：这需要 stateful 功能，可能超出当前练习范围）

# 3. 服务器保护：
#    - 统计访问各个服务端口的流量
#    - 记录所有被拒绝的连接尝试
#    - 只允许特定 IP 访问管理端口

# ============================================
# 调试技巧
# ============================================

# 1. 查看规则和计数器：
#    sudo build/output/sbin/bfcli ruleset get

# 2. 清空规则重新测试：
#    sudo build/output/sbin/bfcli ruleset flush

# 3. 使用 log 追踪匹配的包：
#    rule ... log meta ...
#    然后查看系统日志

# 4. 测试工具：
#    - telnet <IP> <端口>  : 测试 TCP 端口
#    - nc -v <IP> <端口>   : netcat 测试
#    - nmap <IP>           : 端口扫描

# 完成后进入下一个练习：exercise_03_sets.bf
