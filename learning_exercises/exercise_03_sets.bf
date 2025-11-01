# 练习 3：使用 Set 进行批量匹配
# 难度：⭐⭐⭐ 中级
# 学习目标：掌握 set 的使用，实现高效的批量 IP/端口匹配

# ============================================
# Set 的优势
# ============================================
# Set 提供了高效的批量匹配能力：
# - O(1) 查找时间（哈希表实现）
# - 减少规则数量
# - 更清晰的规则组织
# - 适合黑名单/白名单场景

# ============================================
# 任务 1：IP 地址黑名单
# ============================================

# 定义一个命名 set，包含需要阻止的 IP 地址
set blacklist_ips {
    192.168.1.50,
    192.168.1.51,
    10.0.0.100,
    172.16.0.50
}

chain ip_blacklist BF_HOOK_NF_LOCAL_IN ACCEPT
    # 使用 set 一次性匹配所有黑名单 IP
    rule ip4.saddr $blacklist_ips log meta counter DROP

# 对比：如果不用 set，需要写 4 条规则：
#   rule ip4.saddr 192.168.1.50 counter DROP
#   rule ip4.saddr 192.168.1.51 counter DROP
#   rule ip4.saddr 10.0.0.100 counter DROP
#   rule ip4.saddr 172.16.0.50 counter DROP

# ============================================
# 任务 2：端口白名单
# ============================================

# 定义允许的服务端口
set allowed_ports {
    22,    # SSH
    80,    # HTTP
    443,   # HTTPS
    3000,  # 开发服务器
    8080   # 备用 HTTP
}

chain port_whitelist BF_HOOK_NF_LOCAL_IN DROP
    # 允许本地回环
    rule ip4.saddr 127.0.0.1 counter ACCEPT

    # 允许白名单端口的 TCP 连接
    rule ip4.proto tcp tcp.dport $allowed_ports counter ACCEPT

    # 其他端口被阻止（默认策略 DROP）

# ============================================
# 任务 3：管理网段白名单
# ============================================

# 定义受信任的管理网段
set trusted_networks {
    192.168.1.0/24,
    10.0.0.0/16,
    172.16.0.0/12
}

chain admin_access BF_HOOK_NF_LOCAL_IN DROP
    # 只允许受信任网段访问管理端口
    rule ip4.proto tcp tcp.dport 22 ip4.snet $trusted_networks counter ACCEPT
    rule ip4.proto tcp tcp.dport 3306 ip4.snet $trusted_networks counter ACCEPT
    rule ip4.proto tcp tcp.dport 5432 ip4.snet $trusted_networks counter ACCEPT

    # 记录未授权的访问尝试
    rule ip4.proto tcp tcp.dport 22 log meta counter DROP
    rule ip4.proto tcp tcp.dport 3306 log meta counter DROP

# ============================================
# 任务 4：匿名 Set（内联定义）
# ============================================

chain inline_sets BF_HOOK_NF_LOCAL_IN ACCEPT
    # 直接在规则中定义 set（匿名 set）
    rule ip4.saddr { 192.168.1.1, 192.168.1.2, 192.168.1.3 } counter ACCEPT

    # 阻止访问危险端口
    rule ip4.proto tcp tcp.dport { 23, 135, 139, 445 } counter DROP

    # 允许 DNS（UDP 和 TCP）
    rule ip4.proto udp udp.dport { 53, 5353 } counter ACCEPT

# ============================================
# 任务 5：复合 Set（多个键）
# ============================================

# Set 可以包含多个组成部分（如 IP + 端口）
# 注意：具体语法可能需要参考文档

set ip_port_pairs {
    (192.168.1.100, 22),
    (192.168.1.101, 22),
    (10.0.0.50, 80),
    (10.0.0.51, 443)
}

# 使用复合 set 进行精确匹配
# rule ip4.saddr ip4.dport $ip_port_pairs counter ACCEPT

# ============================================
# 任务 6：实战场景 - 完整防火墙配置
# ============================================

# 定义各种服务的端口
set public_tcp_ports {
    80,    # HTTP
    443    # HTTPS
}

set public_udp_ports {
    53     # DNS
}

set admin_tcp_ports {
    22,    # SSH
    3306,  # MySQL
    5432,  # PostgreSQL
    6379   # Redis
}

# 定义允许访问的 IP
set admin_ips {
    192.168.1.10,
    192.168.1.11,
    192.168.1.12
}

# 定义黑名单
set blocked_ips {
    203.0.113.0/24,  # 示例黑名单网段
    198.51.100.50
}

chain firewall BF_HOOK_NF_LOCAL_IN DROP
    # 1. 首先阻止黑名单 IP
    rule ip4.saddr $blocked_ips log meta counter DROP

    # 2. 允许本地回环
    rule ip4.saddr 127.0.0.1 counter ACCEPT

    # 3. 允许已建立的连接（如果支持 state）
    # rule meta.state established counter ACCEPT

    # 4. 允许公共服务端口
    rule ip4.proto tcp tcp.dport $public_tcp_ports counter ACCEPT
    rule ip4.proto udp udp.dport $public_udp_ports counter ACCEPT

    # 5. 只允许管理员 IP 访问管理端口
    rule ip4.proto tcp tcp.dport $admin_tcp_ports ip4.saddr $admin_ips counter ACCEPT

    # 6. 记录其他被拒绝的连接
    rule counter log meta DROP

# ============================================
# 任务 7：国家/地区 IP 段（大规模 Set）
# ============================================

# Set 特别适合处理大量 IP 地址
# 例如：阻止来自特定国家的流量

set country_cn_sample {
    # 这里只是示例，实际应该包含完整的 IP 段列表
    1.0.1.0/24,
    1.0.2.0/24,
    1.0.8.0/24
    # ... 可能有数千个条目
}

chain geo_blocking BF_HOOK_NF_LOCAL_IN ACCEPT
    # 一条规则处理所有 IP
    rule ip4.saddr $country_cn_sample log meta counter DROP

# ============================================
# 知识点总结
# ============================================

# 1. Set 定义语法：
#    set <名称> {
#        元素1,
#        元素2,
#        元素3
#    }

# 2. Set 使用：
#    rule <匹配器> $set_name <判决>

# 3. 匿名 Set（内联）：
#    rule <匹配器> { 值1, 值2, 值3 } <判决>

# 4. Set 支持的类型：
#    - IP 地址（单个）
#    - IP 网段（CIDR）
#    - 端口号
#    - 复合键（IP + 端口等）

# 5. Set 的优势：
#    - 高效查找（O(1)）
#    - 减少规则数量
#    - 便于维护
#    - 适合大规模数据

# 6. 最佳实践：
#    - 对于 3 个以上的值，使用 set
#    - 命名 set 便于重用
#    - 匿名 set 适合临时使用
#    - 大规模黑名单必须用 set

# ============================================
# 挑战练习
# ============================================

# 1. 创建一个公司防火墙配置：
#    - 定义办公网段 set
#    - 定义允许的服务端口 set
#    - 定义 DMZ 服务器 IP set
#    - 实现分层访问控制

# 2. 实现动态黑名单：
#    - 创建一个包含恶意 IP 的 set
#    - 阻止这些 IP 的所有流量
#    - 记录被阻止的尝试

# 3. 端口分类管理：
#    - 创建 web_ports set（80, 443, 8080, 8443）
#    - 创建 db_ports set（3306, 5432, 27017）
#    - 创建 admin_ports set（22, 3389）
#    - 为每类端口设置不同的访问策略

# 4. 复杂场景：
#    - 允许特定 IP 访问特定端口
#    - 使用多个 set 组合实现精细控制
#    - 统计每个 set 的匹配次数

# ============================================
# 性能考虑
# ============================================

# Set vs 多条规则性能对比：

# 场景 1：阻止 100 个 IP
# 不用 set：100 条规则，线性查找 O(n)
# 使用 set：1 条规则 + 1 个 set，哈希查找 O(1)

# 场景 2：允许 20 个端口
# 不用 set：20 条规则
# 使用 set：1 条规则

# 结论：Set 在大量匹配时性能优势明显

# ============================================
# 调试和验证
# ============================================

# 1. 查看 set 定义：
#    sudo build/output/sbin/bfcli ruleset get
#    # 输出会显示 set 的内容

# 2. 测试 set 匹配：
#    # 从 set 中的 IP 发起连接
#    # 查看 counter 是否增加

# 3. 验证性能：
#    # 使用大量 IP 的 set
#    # 测试匹配速度

# 完成后进入下一个练习：exercise_04_counters.bf
