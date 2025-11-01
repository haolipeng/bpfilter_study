# bpfilter 术语表

## A

**Action（动作）**
- 规则匹配成功后执行的操作（如 counter、log、mark）
- 动作不影响最终判决，只执行副作用

**AST（Abstract Syntax Tree，抽象语法树）**
- Parser 根据语法规则构建的树形结构
- 表示代码的语法结构

**Attach（附加）**
- 将 BPF 程序附加到内核 Hook 点
- 只有附加后程序才会实际执行

## B

**BPF（Berkeley Packet Filter）**
- 最初用于包过滤的虚拟机
- 现在泛指 eBPF（extended BPF）

**BPF Map**
- BPF 程序中的键值存储
- 用于用户空间和内核空间的数据交换
- 用于实现 Set 的高效查找

**BPF Verifier**
- Linux 内核中的 BPF 程序验证器
- 确保 BPF 程序安全（不会崩溃内核）
- 检查指令合法性、内存访问边界等

**Bison**
- GNU Parser Generator
- 根据 BNF 语法生成 Parser 代码

## C

**Chain（链）**
- 一组规则的集合
- 附加到特定的 Hook 点
- 有默认策略（ACCEPT 或 DROP）

**Cgroup Hook**
- 附加到 cgroup 的 Hook 点
- 用于控制进程组的网络流量

**Codegen（Code Generation，代码生成）**
- 将规则转换为 BPF 字节码的过程

**Counter（计数器）**
- 统计匹配规则的包数和字节数
- 每个规则可以有独立的计数器

## D

**Daemon（守护进程）**
- bpfilter 的后台服务进程
- 负责规则管理和 BPF 程序生成

## E

**eBPF（extended BPF）**
- 扩展的 BPF 虚拟机
- 支持更多指令、更大程序、更多功能

## F

**Flex（Fast Lexical Analyzer）**
- 词法分析器生成工具
- 根据正则表达式生成 Lexer 代码

## H

**Hook（钩子）**
- 内核中可以附加 BPF 程序的位置
- bpfilter 支持 XDP、TC、Netfilter、Cgroup hook

## I

**IHL（IP Header Length）**
- IP 头部长度字段
- 以 32 位字（4 字节）为单位

**iptables**
- 传统的 Linux 防火墙工具
- bpfilter 提供兼容层

## J

**JIT（Just-In-Time Compilation）**
- BPF 程序的即时编译
- 将 BPF 字节码编译为本机机器码
- 提高执行性能

## L

**Lexer（词法分析器）**
- 将文本切分成 token 的程序
- bpfilter 使用 Flex 生成

**libbpf**
- BPF 程序加载和管理库
- bpfilter 使用它与内核交互

**libbpfilter**
- bpfilter 的客户端库
- 提供 C API 用于规则管理

**Log（日志）**
- 记录匹配规则的包信息
- 可选级别：none、meta、transport

## M

**Matcher（匹配器）**
- 规则的匹配条件
- 如 ip4.saddr、tcp.dport 等

**Mark（标记）**
- 为包设置标记值
- 可用于后续的策略路由

## N

**Netfilter**
- Linux 内核的包过滤框架
- 提供多个 Hook 点（PRE_ROUTING、LOCAL_IN 等）

**nftables**
- 新一代 Linux 防火墙
- bpfilter 提供兼容层

## P

**Parser（语法分析器）**
- 根据语法规则构建 AST
- bpfilter 使用 Bison 生成

**Policy（策略）**
- Chain 的默认判决
- 当所有规则都不匹配时使用

## R

**Rule（规则）**
- 包含匹配器和判决的过滤规则
- 按顺序在 Chain 中检查

**Ruleset（规则集）**
- 所有 Chain 和 Set 的集合
- bpfilter 管理的完整配置

## S

**Set（集合）**
- 批量匹配值的集合
- 使用哈希表实现 O(1) 查找
- 在内核中对应 BPF Map

**Socket（套接字）**
- Unix domain socket
- bfcli 和 bpfilter daemon 的通信方式

## T

**TC（Traffic Control）**
- Linux 流量控制子系统
- 提供 ingress 和 egress Hook 点

**Token（词法单元）**
- Lexer 输出的最小语法单位
- 如关键字、标识符、数字等

**Transient Mode（临时模式）**
- bpfilter daemon 的测试模式
- 不持久化配置到磁盘

**TTL（Time To Live）**
- IP 包的生存时间
- 每经过一个路由器减 1

## V

**Verdict（判决）**
- 规则的最终决定
- 可能值：ACCEPT、DROP、CONTINUE

**Verifier（验证器）**
- 见 BPF Verifier

## X

**XDP（eXpress Data Path）**
- 最早的包处理 Hook 点
- 在网卡驱动层处理包
- 性能最高

**xlate（Translation，翻译）**
- 将不同格式（iptables、nftables）转换为内部表示
- 翻译层模块

## Y

**YYDEBUG**
- Bison 的调试开关
- 启用后输出详细的解析过程

**yylex**
- Lexer 函数
- Flex 生成，返回下一个 token

**yyparse**
- Parser 函数
- Bison 生成，执行语法分析

**yylval**
- 语义值变量
- 存储 token 的附加信息

**yytext**
- 当前匹配的文本
- Flex 自动设置

---

## 缩写对照

| 缩写 | 全称 | 中文 |
|------|------|------|
| AST | Abstract Syntax Tree | 抽象语法树 |
| BNF | Backus-Naur Form | 巴克斯范式 |
| BPF | Berkeley Packet Filter | 伯克利包过滤器 |
| CIDR | Classless Inter-Domain Routing | 无类域间路由 |
| CLI | Command-Line Interface | 命令行界面 |
| eBPF | extended BPF | 扩展 BPF |
| GDB | GNU Debugger | GNU 调试器 |
| IHL | IP Header Length | IP 头部长度 |
| JIT | Just-In-Time | 即时编译 |
| NF | Netfilter | 网络过滤器 |
| TC | Traffic Control | 流量控制 |
| TTL | Time To Live | 生存时间 |
| XDP | eXpress Data Path | 快速数据路径 |

---

## 相关概念

### Hook 优先级

从早到晚的包处理顺序：

1. **XDP** - 网卡驱动层（最早）
2. **TC Ingress** - 进入协议栈前
3. **Netfilter PRE_ROUTING** - 路由前
4. **Netfilter LOCAL_IN** - 本地入站
5. **Netfilter FORWARD** - 转发
6. **Netfilter LOCAL_OUT** - 本地出站
7. **TC Egress** - 离开协议栈
8. **Netfilter POST_ROUTING** - 路由后

### Verdict 语义

- **ACCEPT**：接受包，继续正常处理
- **DROP**：丢弃包，不做任何响应
- **CONTINUE**：继续检查下一条规则

### BPF 寄存器约定

- **R0**：返回值、函数返回
- **R1-R5**：函数参数
- **R6-R9**：Callee-saved（被调用者保存）
- **R10**：只读栈帧指针

---

使用本术语表快速查阅不熟悉的概念！
