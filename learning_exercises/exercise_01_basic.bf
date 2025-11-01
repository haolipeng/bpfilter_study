# 练习 1：基础规则和匹配器
# 难度：⭐ 入门级
# 学习目标：理解 chain、rule、匹配器、判决的基本概念

# ============================================
# 任务 1：阻止所有 ICMP 流量
# ============================================

# 创建一个名为 block_icmp 的链
# - Hook: BF_HOOK_NF_LOCAL_IN（本地输入）
# - 默认策略: ACCEPT（允许其他流量通过）
chain block_icmp BF_HOOK_NF_LOCAL_IN ACCEPT
    # 规则：匹配 ICMP 协议，添加计数器，判决为 DROP
    rule ip4.proto icmp counter DROP

# 测试方法：
# 1. 加载规则：sudo build/output/sbin/bfcli ruleset set --from-file learning_exercises/exercise_01_basic.bf
# 2. 查看规则：sudo build/output/sbin/bfcli ruleset get
# 3. 从其他机器 ping 本机（应该失败）
# 4. 再次查看规则，counter 应该显示增加的包数
# 5. 清空规则：sudo build/output/sbin/bfcli ruleset flush

# ============================================
# 任务 2：只允许特定 IP 的流量
# ============================================

# 创建一个白名单链
# - Hook: BF_HOOK_NF_LOCAL_IN
# - 默认策略: DROP（默认拒绝所有流量）
chain whitelist BF_HOOK_NF_LOCAL_IN DROP
    # 允许来自 192.168.1.100 的流量
    rule ip4.saddr 192.168.1.100 counter ACCEPT

    # 允许来自整个 10.0.0.0/8 网段的流量
    rule ip4.snet 10.0.0.0/8 counter ACCEPT

    # 允许本地回环流量（127.0.0.1）
    rule ip4.saddr 127.0.0.1 counter ACCEPT

# 测试方法：
# 注意：这个规则会阻断大部分网络流量，仅用于学习测试！
# 1. 修改 IP 地址为你的实际网络环境
# 2. 加载规则
# 3. 尝试从允许的 IP 访问
# 4. 尝试从不允许的 IP 访问（应该被阻止）

# ============================================
# 任务 3：记录流量但不阻止
# ============================================

chain monitor BF_HOOK_NF_LOCAL_IN ACCEPT
    # 使用 counter 追踪所有 TCP 流量
    rule ip4.proto tcp counter ACCEPT

    # 使用 log 记录 UDP 流量（包含传输层头部）
    rule ip4.proto udp log transport ACCEPT

# 测试方法：
# 1. 加载规则
# 2. 生成一些网络流量（浏览网页、DNS 查询等）
# 3. 查看规则，观察 counter 的变化
# 4. 查看系统日志以查找 log 输出

# ============================================
# 知识点总结
# ============================================

# 1. Chain 结构：
#    chain <名称> <HOOK> <默认策略>
#      rule ...
#      rule ...

# 2. Rule 结构：
#    rule <匹配器> [动作] <判决>

# 3. 常用匹配器：
#    - ip4.proto <协议>  : 匹配协议（tcp, udp, icmp）
#    - ip4.saddr <地址>  : 匹配源 IP 地址
#    - ip4.daddr <地址>  : 匹配目标 IP 地址
#    - ip4.snet <网段>   : 匹配源网段（CIDR）
#    - ip4.dnet <网段>   : 匹配目标网段（CIDR）

# 4. 动作（可选）：
#    - counter           : 统计包数和字节数
#    - log <选项>        : 记录日志（none/meta/transport）
#    - mark <值>         : 设置包标记

# 5. 判决：
#    - ACCEPT            : 接受流量
#    - DROP              : 丢弃流量
#    - CONTINUE          : 继续匹配后续规则

# ============================================
# 挑战练习
# ============================================

# 尝试自己编写规则实现以下功能：
# 1. 阻止来自特定 IP（如 192.168.1.50）的所有流量
# 2. 记录所有 ICMP 流量但不阻止
# 3. 创建一个黑名单，阻止 3 个特定 IP
# 4. 允许所有流量，但统计 TCP 和 UDP 的包数

# 完成后进入下一个练习：exercise_02_ports.bf
