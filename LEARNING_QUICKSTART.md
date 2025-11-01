# bpfilter 快速入门指南

欢迎开始学习 bpfilter！这份指南将帮助你快速上手并进行实践。

## 🚀 第一步：编译项目

```bash
# 简化编译（推荐初学者）
cd /home/work/bpfilter
cmake -S . -B build -DNO_DOCS=ON -DNO_CHECKS=ON -DNO_BENCHMARKS=ON
make -C build

# 如果遇到依赖问题，可以完全最小化编译
cmake -S . -B build -DNO_DOCS=ON -DNO_TESTS=ON -DNO_CHECKS=ON -DNO_BENCHMARKS=ON
make -C build
```

编译产物位置：
- 守护进程：`build/output/sbin/bpfilter`
- CLI 工具：`build/output/sbin/bfcli`
- 库文件：`build/output/lib/libbpfilter.so`

## 🎯 第二步：启动守护进程

在一个终端中启动守护进程（需要 root 权限）：

```bash
# Transient 模式（测试用，不持久化）
sudo build/output/sbin/bpfilter --transient

# 或者使用 verbose 模式查看详细日志
sudo build/output/sbin/bpfilter --transient -v
```

## 📝 第三步：尝试基础命令

在另一个终端中执行 bfcli 命令：

### 示例 1：创建简单的规则（阻止 ICMP）

```bash
sudo build/output/sbin/bfcli ruleset set --from-str \
  "chain block_icmp BF_HOOK_NF_LOCAL_IN ACCEPT
     rule ip4.proto icmp counter DROP"

# 查看规则集
sudo build/output/sbin/bfcli ruleset get
```

### 示例 2：使用文件加载规则

```bash
# 使用现成的示例文件
sudo build/output/sbin/bfcli ruleset set --from-file tests/e2e/rulesets/xdp.bf

# 查看加载的规则
sudo build/output/sbin/bfcli ruleset get
```

### 示例 3：查看规则计数器

```bash
# 规则执行后，counter 会记录匹配的包数
sudo build/output/sbin/bfcli ruleset get

# 你会看到类似输出：
# rule ip4.proto icmp counter(packets: 10, bytes: 840) DROP
```

### 示例 4：清空规则集

```bash
sudo build/output/sbin/bfcli ruleset flush
```

## 🔥 实践练习路径

### Level 1：基础规则（1-2小时）

按顺序完成 `learning_exercises/` 目录下的练习：

1. **exercise_01_basic.bf** - 基础匹配器
2. **exercise_02_ports.bf** - 端口过滤
3. **exercise_03_sets.bf** - 使用 set 批量匹配
4. **exercise_04_counters.bf** - 使用计数器追踪流量

每个练习文件都有详细注释，按照说明执行：

```bash
sudo build/output/sbin/bfcli ruleset set --from-file learning_exercises/exercise_01_basic.bf
sudo build/output/sbin/bfcli ruleset get
# 测试规则...
sudo build/output/sbin/bfcli ruleset flush
```

### Level 2：多 Hook 实践（2-3小时）

探索不同的 hook 类型：

```bash
# XDP hook（最早处理点）
sudo build/output/sbin/bfcli ruleset set --from-file tests/e2e/rulesets/xdp.bf

# TC ingress hook
sudo build/output/sbin/bfcli ruleset set --from-file tests/e2e/rulesets/tc_ingress.bf

# Netfilter hooks
sudo build/output/sbin/bfcli ruleset set --from-file tests/e2e/rulesets/nf_local_in.bf
```

### Level 3：完整示例分析（3-4小时）

深入研究 `tests/rules.bpfilter`，这个文件展示了所有功能：

```bash
# 查看文件内容
cat tests/rules.bpfilter

# 加载并测试
sudo build/output/sbin/bfcli ruleset set --from-file tests/rules.bpfilter
sudo build/output/sbin/bfcli ruleset get
```

## 📚 关键概念速查

### Chain（链）

```
chain <名称> <HOOK类型> <默认策略>
  rule ...
  rule ...
```

- **Hook 类型：**
  - `BF_HOOK_XDP` - 网卡驱动层
  - `BF_HOOK_TC_INGRESS/EGRESS` - 流量控制层
  - `BF_HOOK_NF_LOCAL_IN/LOCAL_OUT/...` - Netfilter 层
  - `BF_HOOK_CGROUP_INGRESS/EGRESS` - Cgroup 层

- **默认策略：** `ACCEPT` 或 `DROP`

### Rule（规则）

```
rule <匹配器> [动作] <判决>
```

- **匹配器：** `ip4.saddr`, `tcp.dport`, `meta.proto` 等
- **动作：** `counter`, `log`, `mark` 等（可选）
- **判决：** `ACCEPT`, `DROP`, `CONTINUE`

### 常用匹配器

| 匹配器 | 说明 | 示例 |
|--------|------|------|
| `ip4.saddr` | IPv4 源地址 | `ip4.saddr 192.168.1.1` |
| `ip4.daddr` | IPv4 目标地址 | `ip4.daddr 10.0.0.0/8` |
| `ip4.proto` | IP 协议 | `ip4.proto tcp` |
| `tcp.sport` | TCP 源端口 | `tcp.sport 80` |
| `tcp.dport` | TCP 目标端口 | `tcp.dport 22` |
| `udp.dport` | UDP 目标端口 | `udp.dport 53` |
| `icmp.type` | ICMP 类型 | `icmp.type 8` |
| `meta.ifindex` | 接口索引 | `meta.ifindex 2` |
| `meta.l3_proto` | L3 协议 | `meta.l3_proto ipv4` |

## 🧪 测试你的规则

### 方法 1：使用 ping 测试 ICMP 规则

```bash
# 加载阻止 ICMP 的规则
sudo build/output/sbin/bfcli ruleset set --from-str \
  "chain test BF_HOOK_NF_LOCAL_IN ACCEPT
     rule ip4.proto icmp counter DROP"

# 在另一台机器上 ping 这台主机（应该失败）
# ping <this-machine-ip>

# 查看计数器
sudo build/output/sbin/bfcli ruleset get
```

### 方法 2：运行 E2E 测试

```bash
# 编译时包含测试
cmake -S . -B build -DNO_DOCS=ON -DNO_CHECKS=ON -DNO_BENCHMARKS=ON
make -C build

# 运行 E2E 测试（会自动验证规则行为）
make -C build e2e
```

## 📖 进阶学习资源

1. **完整命令参考：** [doc/usage/bfcli.rst](doc/usage/bfcli.rst)
2. **开发者文档：** [doc/developers/](doc/developers/)
3. **API 参考：** [src/libbpfilter/include/bpfilter/bpfilter.h](src/libbpfilter/include/bpfilter/bpfilter.h)
4. **示例代码：** [tests/e2e/](tests/e2e/)

## 🐛 常见问题

### 问题：守护进程启动失败

```bash
# 检查是否已有实例在运行
ps aux | grep bpfilter

# 使用 transient 模式避免冲突
sudo build/output/sbin/bpfilter --transient
```

### 问题：规则加载失败

```bash
# 检查规则语法
cat your_rules.bf

# 使用 verbose 模式查看详细错误
sudo build/output/sbin/bpfilter --transient -v
```

### 问题：需要查看详细日志

```bash
# 启动守护进程时使用 -v 参数
sudo build/output/sbin/bpfilter --transient -v

# 或者使用 --syslog 输出到系统日志
sudo build/output/sbin/bpfilter --syslog
```

## 🎯 下一步

完成基础练习后，你可以：

1. **阅读示例代码：** 学习 [src/bfcli/main.c](src/bfcli/main.c)
2. **编写 C 程序：** 使用 libbpfilter API
3. **深入测试：** 研究 [tests/e2e/main.c](tests/e2e/main.c)
4. **贡献代码：** 查看 [CONTRIBUTING.md](CONTRIBUTING.md)

祝学习愉快！🚀
