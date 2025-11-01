# 练习 4：流量统计和监控
# 难度：⭐⭐ 初级
# 学习目标：掌握 counter 和 log 的使用，实现流量分析和监控

# ============================================
# Counter 的作用
# ============================================
# Counter 可以统计：
# - 匹配的包数量（packets）
# - 传输的字节数（bytes）
#
# 用途：
# - 流量分析
# - 规则验证
# - 性能监控
# - 安全审计

# ============================================
# 任务 1：基础流量统计
# ============================================

chain traffic_stats BF_HOOK_NF_LOCAL_IN ACCEPT
    # 统计所有 TCP 流量
    rule ip4.proto tcp counter ACCEPT

    # 统计所有 UDP 流量
    rule ip4.proto udp counter ACCEPT

    # 统计所有 ICMP 流量
    rule ip4.proto icmp counter ACCEPT

# 查看统计：
# sudo build/output/sbin/bfcli ruleset get
# 输出示例：
# rule ip4.proto tcp counter(packets: 1234, bytes: 567890) ACCEPT

# ============================================
# 任务 2：按服务端口统计
# ============================================

chain service_stats BF_HOOK_NF_LOCAL_IN ACCEPT
    # Web 流量统计
    rule ip4.proto tcp tcp.dport 80 counter ACCEPT
    rule ip4.proto tcp tcp.dport 443 counter ACCEPT

    # SSH 流量统计
    rule ip4.proto tcp tcp.dport 22 counter ACCEPT

    # DNS 流量统计
    rule ip4.proto udp udp.dport 53 counter ACCEPT

    # 数据库流量统计
    rule ip4.proto tcp tcp.dport 3306 counter ACCEPT   # MySQL
    rule ip4.proto tcp tcp.dport 5432 counter ACCEPT   # PostgreSQL

    # 其他流量统计
    rule counter ACCEPT

# 分析方法：
# 1. 运行一段时间后查看统计
# 2. 对比各服务的流量占比
# 3. 识别异常的流量模式

# ============================================
# 任务 3：按源 IP 统计（监控特定主机）
# ============================================

chain ip_monitoring BF_HOOK_NF_LOCAL_IN ACCEPT
    # 监控管理员主机的流量
    rule ip4.saddr 192.168.1.10 counter ACCEPT

    # 监控应用服务器的流量
    rule ip4.saddr 10.0.0.100 counter ACCEPT
    rule ip4.saddr 10.0.0.101 counter ACCEPT

    # 监控特定网段的流量
    rule ip4.snet 192.168.100.0/24 counter ACCEPT

# 用途：
# - 追踪特定主机的活动
# - 检测异常流量
# - 容量规划

# ============================================
# 任务 4：出站流量监控
# ============================================

chain outbound_stats BF_HOOK_NF_LOCAL_OUT ACCEPT
    # 统计本机发出的 HTTP/HTTPS 请求
    rule ip4.proto tcp tcp.dport 80 counter ACCEPT
    rule ip4.proto tcp tcp.dport 443 counter ACCEPT

    # 统计本机发出的 DNS 查询
    rule ip4.proto udp udp.dport 53 counter ACCEPT

    # 统计本机发出的 SSH 连接
    rule ip4.proto tcp tcp.dport 22 counter ACCEPT

    # 监控是否有异常的出站连接
    rule ip4.proto tcp tcp.dport 4444 log meta counter DROP  # 常见后门端口
    rule ip4.proto tcp tcp.dport 31337 log meta counter DROP # 黑客常用端口

# ============================================
# 任务 5：使用 Log 记录详细信息
# ============================================

chain detailed_logging BF_HOOK_NF_LOCAL_IN ACCEPT
    # Log 级别：
    # - none      : 只记录基本信息
    # - meta      : 记录元数据（接口、协议等）
    # - transport : 记录传输层信息（端口等）

    # 记录所有 SSH 连接尝试（包含源 IP 和端口）
    rule ip4.proto tcp tcp.dport 22 log transport counter ACCEPT

    # 记录所有被拒绝的 ICMP（包含元数据）
    rule ip4.proto icmp log meta counter DROP

    # 记录来自外部网络的连接（基本信息）
    rule ip4.snet !192.168.0.0/16 log none counter ACCEPT

# 查看日志：
# sudo journalctl -f | grep bpfilter
# 或
# sudo tail -f /var/log/syslog | grep bpfilter

# ============================================
# 任务 6：安全事件监控
# ============================================

# 定义可疑端口
set suspicious_ports {
    23,     # Telnet
    135,    # Windows RPC
    139,    # NetBIOS
    445,    # SMB
    1433,   # MS SQL
    3389,   # RDP
    4444,   # Metasploit 默认端口
    5555    # Android Debug Bridge
}

# 定义内部网络
set internal_networks {
    192.168.0.0/16,
    10.0.0.0/8,
    172.16.0.0/12
}

chain security_monitoring BF_HOOK_NF_LOCAL_IN ACCEPT
    # 记录所有访问可疑端口的尝试
    rule ip4.proto tcp tcp.dport $suspicious_ports log transport counter DROP

    # 记录来自外部的端口扫描（访问未开放端口）
    rule ip4.snet !$internal_networks ip4.proto tcp log meta counter DROP

    # 记录异常的 ICMP 流量（可能是扫描或 DDoS）
    rule ip4.proto icmp log meta counter ACCEPT

    # 统计被阻止的包总数
    rule counter DROP

# ============================================
# 任务 7：流量分析仪表板
# ============================================

# 创建一个全面的流量统计链
chain dashboard BF_HOOK_NF_LOCAL_IN ACCEPT
    # === 按协议分类 ===
    rule ip4.proto tcp counter ACCEPT
    rule ip4.proto udp counter ACCEPT
    rule ip4.proto icmp counter ACCEPT

    # === 按服务分类 ===
    rule ip4.proto tcp tcp.dport 80 counter ACCEPT      # HTTP
    rule ip4.proto tcp tcp.dport 443 counter ACCEPT     # HTTPS
    rule ip4.proto tcp tcp.dport 22 counter ACCEPT      # SSH
    rule ip4.proto udp udp.dport 53 counter ACCEPT      # DNS

    # === 按源网络分类 ===
    rule ip4.snet 192.168.0.0/16 counter ACCEPT         # 内网
    rule ip4.snet 10.0.0.0/8 counter ACCEPT             # 内网
    rule counter ACCEPT                                  # 外网

# 使用脚本定期收集统计：
# #!/bin/bash
# while true; do
#     echo "=== $(date) ==="
#     sudo build/output/sbin/bfcli ruleset get | grep counter
#     sleep 60
# done

# ============================================
# 任务 8：带宽监控
# ============================================

chain bandwidth_monitoring BF_HOOK_NF_LOCAL_IN ACCEPT
    # 监控大流量用户（通过字节数）
    rule ip4.saddr 192.168.1.100 counter ACCEPT
    rule ip4.saddr 192.168.1.101 counter ACCEPT
    rule ip4.saddr 192.168.1.102 counter ACCEPT

    # 监控大流量服务（通过字节数）
    rule ip4.proto tcp tcp.dport 80 counter ACCEPT
    rule ip4.proto tcp tcp.dport 443 counter ACCEPT

# 分析带宽：
# 1. 记录初始的 bytes 值
# 2. 等待一段时间（如 1 分钟）
# 3. 再次查询，计算差值
# 4. 带宽 = (bytes_new - bytes_old) / 时间间隔

# ============================================
# 知识点总结
# ============================================

# 1. Counter 语法：
#    rule <匹配器> counter <判决>
#
#    输出格式：
#    counter(packets: N, bytes: M)

# 2. Log 语法：
#    rule <匹配器> log <级别> <判决>
#
#    级别选项：
#    - none      : 基本信息
#    - meta      : + 元数据（接口、协议）
#    - transport : + 传输层（端口、标志位）

# 3. Counter + Log 组合：
#    rule <匹配器> log meta counter <判决>
#    # 既统计又记录日志

# 4. 最佳实践：
#    - 为重要规则添加 counter
#    - 为安全相关规则添加 log
#    - 定期收集统计数据
#    - 建立流量基线

# 5. 性能考虑：
#    - Counter 开销很小
#    - Log 有一定开销（写日志）
#    - 不要为每个包都记录日志
#    - 只为关键事件记录 log

# ============================================
# 实战场景
# ============================================

# 场景 1：检测端口扫描
# - 统计短时间内访问多个端口的 IP
# - 使用 log 记录详细信息
# - 触发告警

# 场景 2：流量分析
# - 收集各服务的流量统计
# - 分析流量趋势
# - 容量规划

# 场景 3：安全审计
# - 记录所有被拒绝的连接
# - 分析攻击模式
# - 改进防火墙规则

# 场景 4：性能优化
# - 统计规则匹配次数
# - 识别热点规则
# - 调整规则顺序

# ============================================
# 挑战练习
# ============================================

# 1. 创建流量监控脚本：
#    - 定期查询 counter
#    - 计算流量速率
#    - 输出人类可读的报告

# 2. 实现告警系统：
#    - 监控 log 输出
#    - 检测异常模式
#    - 发送告警通知

# 3. 流量可视化：
#    - 收集历史统计数据
#    - 使用图表展示
#    - 分析流量趋势

# 4. 安全事件分析：
#    - 记录所有可疑活动
#    - 聚合分析日志
#    - 生成安全报告

# ============================================
# 数据采集脚本示例
# ============================================

# 保存为 collect_stats.sh：
# #!/bin/bash
# OUTPUT_FILE="bpfilter_stats_$(date +%Y%m%d_%H%M%S).log"
#
# echo "开始收集统计数据..."
# echo "时间戳: $(date)" > "$OUTPUT_FILE"
# echo "==================================" >> "$OUTPUT_FILE"
#
# sudo build/output/sbin/bfcli ruleset get >> "$OUTPUT_FILE"
#
# echo "" >> "$OUTPUT_FILE"
# echo "数据已保存到: $OUTPUT_FILE"

# 定时采集：
# watch -n 60 './collect_stats.sh'

# ============================================
# 日志分析示例
# ============================================

# 查看最近的 bpfilter 日志：
# sudo journalctl -u bpfilter -n 100

# 实时监控日志：
# sudo journalctl -u bpfilter -f

# 筛选特定端口的日志：
# sudo journalctl -u bpfilter | grep "dport:22"

# 统计日志中的源 IP：
# sudo journalctl -u bpfilter | grep -oP 'saddr:\K[0-9.]+' | sort | uniq -c | sort -nr

# 完成！你已经掌握了 bpfilter 的核心功能。
# 接下来可以：
# 1. 查看实际项目示例：tests/e2e/rulesets/
# 2. 学习 API 编程：阅读 src/bfcli/main.c
# 3. 研究内部实现：阅读 src/bpfilter/cgen/
