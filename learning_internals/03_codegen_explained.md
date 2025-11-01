# Phase 3: BPF 代码生成详解

## 🎯 学习目标

- 理解 eBPF 指令集基础
- 掌握 bpfilter 的代码生成架构
- 理解如何将规则转换为 BPF 字节码
- 能够为新匹配器实现代码生成逻辑

## 📚 eBPF 基础

### eBPF 虚拟机

eBPF 是一个在 Linux 内核中运行的虚拟机，特点：
- 寄存器型虚拟机（10 个 64 位寄存器：R0-R9, R10）
- R0：返回值寄存器
- R1-R5：函数参数寄存器
- R6-R9：callee-saved 寄存器
- R10：只读帧指针（栈顶）

### 基本指令类型

```c
/* 算术指令 */
BPF_MOV(dst, src)          // dst = src
BPF_ADD(dst, src)          // dst += src
BPF_SUB(dst, src)          // dst -= src

/* 内存访问 */
BPF_LD_ABS(size, off)      // Load from packet[off]
BPF_LDX_MEM(size, dst, src, off)  // dst = *(src + off)
BPF_STX_MEM(size, dst, src, off)  // *(dst + off) = src

/* 跳转指令 */
BPF_JMP_IMM(op, dst, imm, off)    // Jump if dst op imm
BPF_JMP_REG(op, dst, src, off)    // Jump if dst op src
BPF_EXIT()                         // Return from program

/* 比较操作符 */
BPF_JEQ  // ==
BPF_JNE  // !=
BPF_JGT  // >
BPF_JGE  // >=
BPF_JLT  // <
BPF_JLE  // <=
```

### 包处理示例

```c
/* 检查 IP 源地址是否为 192.168.1.100 */

// R6 = packet data
// R7 = packet end

// 1. 检查包长度（Ethernet + IP header >= 34 字节）
BPF_MOV64_REG(BPF_REG_0, BPF_REG_6),      // R0 = packet start
BPF_ALU64_IMM(BPF_ADD, BPF_REG_0, 34),    // R0 += 34
BPF_JMP_REG(BPF_JGT, BPF_REG_0, BPF_REG_7, fail),  // if R0 > packet_end goto fail

// 2. 加载 IP 源地址（offset 26）
BPF_LDX_MEM(BPF_W, BPF_REG_0, BPF_REG_6, 26),  // R0 = *(u32*)(packet + 26)

// 3. 比较地址（192.168.1.100 = 0xc0a80164）
BPF_JMP_IMM(BPF_JNE, BPF_REG_0, 0xc0a80164, fail),  // if R0 != IP goto fail

// 4. 匹配成功
BPF_MOV64_IMM(BPF_REG_0, 1),              // R0 = 1 (ACCEPT)
BPF_EXIT(),                                // return

// fail:
BPF_MOV64_IMM(BPF_REG_0, 0),              // R0 = 0 (DROP)
BPF_EXIT(),                                // return
```

---

## 🏗️ bpfilter 代码生成架构

### 源码位置

- 主逻辑：[src/bpfilter/cgen/program.c](../src/bpfilter/cgen/program.c)
- BPF 程序操作：[src/bpfilter/cgen/prog/](../src/bpfilter/cgen/prog/)
- 匹配器代码生成：[src/bpfilter/cgen/matcher/](../src/bpfilter/cgen/matcher/)

### 核心数据结构

```c
/**
 * BPF program builder.
 */
struct bf_program {
    struct bpf_insn *insns;        /* BPF instructions */
    size_t insns_count;            /* Instruction count */
    size_t insns_cap;              /* Capacity */

    /* Labels for jumps */
    struct bf_label *labels;
    size_t num_labels;

    /* BPF maps */
    int *map_fds;
    size_t num_maps;
};

/**
 * Jump label (for forward jumps).
 */
struct bf_label {
    char *name;
    int offset;                    /* Instruction offset */
    bool defined;                  /* Is label defined? */
};
```

### 代码生成流程

```
Chain
  ↓
bf_chain_generate()
  ↓
创建 bf_program 对象
  ↓
遍历每个 Rule
  ├── 生成匹配器检查代码
  │   ├── IP 地址匹配 → bf_codegen_ip4_saddr()
  │   ├── 端口匹配 → bf_codegen_tcp_dport()
  │   └── ... 其他匹配器
  ├── 生成动作代码（counter, log, mark）
  └── 生成判决跳转
  ↓
添加默认策略代码
  ↓
优化 BPF 程序
  ↓
验证程序（BPF verifier）
  ↓
返回完整的 BPF 程序
```

---

## 💻 实现示例

### 示例 1：IP 源地址匹配器

**源码：** [src/bpfilter/cgen/matcher/ip4_saddr.c](../src/bpfilter/cgen/matcher/ip4_saddr.c)

```c
/**
 * Generate BPF code to match IPv4 source address.
 *
 * @param prog BPF program builder
 * @param matcher Matcher containing IP address
 * @return 0 on success, negative errno on error
 */
int bf_codegen_ip4_saddr(struct bf_program *prog,
                          const struct bf_matcher *matcher)
{
    uint32_t ip_addr = matcher->payload.ip4_addr;
    struct bf_label *fail_label = bf_program_get_label(prog, "next_rule");

    /* 1. Check packet length */
    bf_program_emit_bounds_check(prog, 30, fail_label);

    /* 2. Load source IP (offset 26 in Ethernet + IP packet) */
    bf_program_emit(prog, BPF_LDX_MEM(BPF_W, BPF_REG_0, BPF_REG_6, 26));

    /* 3. Compare with expected IP */
    bf_program_emit(prog, BPF_JMP_IMM(BPF_JNE, BPF_REG_0, htonl(ip_addr),
                                       fail_label->offset));

    return 0;
}
```

### 示例 2：TCP 端口匹配器

```c
int bf_codegen_tcp_dport(struct bf_program *prog,
                          const struct bf_matcher *matcher)
{
    uint16_t port = matcher->payload.port;
    struct bf_label *fail_label = bf_program_get_label(prog, "next_rule");

    /* 1. Check if protocol is TCP */
    // Load IP protocol field (offset 23)
    bf_program_emit(prog, BPF_LDX_MEM(BPF_B, BPF_REG_0, BPF_REG_6, 23));
    bf_program_emit(prog, BPF_JMP_IMM(BPF_JNE, BPF_REG_0, IPPROTO_TCP,
                                       fail_label->offset));

    /* 2. Load IP header length (IHL) */
    bf_program_emit(prog, BPF_LDX_MEM(BPF_B, BPF_REG_1, BPF_REG_6, 14));
    bf_program_emit(prog, BPF_ALU32_IMM(BPF_AND, BPF_REG_1, 0x0F));
    bf_program_emit(prog, BPF_ALU32_IMM(BPF_LSH, BPF_REG_1, 2));  // IHL * 4

    /* 3. Load TCP destination port */
    // TCP dest port at IP_header + 2
    bf_program_emit(prog, BPF_ALU64_IMM(BPF_ADD, BPF_REG_1, 14 + 2));
    bf_program_emit(prog, BPF_LDX_MEM(BPF_H, BPF_REG_0, BPF_REG_6, BPF_REG_1));

    /* 4. Compare port */
    bf_program_emit(prog, BPF_JMP_IMM(BPF_JNE, BPF_REG_0, htons(port),
                                       fail_label->offset));

    return 0;
}
```

### 示例 3：使用 Set 的代码生成

```c
int bf_codegen_set_lookup(struct bf_program *prog,
                           const struct bf_set *set,
                           enum bf_matcher_type key_type)
{
    struct bf_label *fail_label = bf_program_get_label(prog, "next_rule");

    /* 1. Load value to lookup (in R0) */
    // ... already loaded by previous code ...

    /* 2. Lookup in BPF map */
    // R1 = map_fd (stored in program)
    bf_program_emit(prog, BPF_LD_MAP_FD(BPF_REG_1, set->map_fd));

    // R2 = &key (stack pointer)
    bf_program_emit(prog, BPF_MOV64_REG(BPF_REG_2, BPF_REG_10));
    bf_program_emit(prog, BPF_ALU64_IMM(BPF_ADD, BPF_REG_2, -8));
    bf_program_emit(prog, BPF_STX_MEM(BPF_DW, BPF_REG_2, BPF_REG_0, 0));

    // Call BPF helper: map_lookup_elem
    bf_program_emit(prog, BPF_EMIT_CALL(BPF_FUNC_map_lookup_elem));

    /* 3. Check if value exists in map */
    bf_program_emit(prog, BPF_JMP_IMM(BPF_JEQ, BPF_REG_0, 0,
                                       fail_label->offset));

    return 0;
}
```

---

## 🔧 实践任务

详见：[practice_03_analyze_bpf.md](practice_03_analyze_bpf.md)

### 任务 1：分析生成的 BPF 代码

使用 bpftool 查看实际生成的 BPF 程序：

```bash
# 1. 加载规则
sudo build/output/sbin/bfcli ruleset set --from-str \
  "chain test BF_HOOK_XDP ACCEPT
     rule ip4.saddr 192.168.1.100 DROP"

# 2. 查找 BPF 程序 ID
sudo bpftool prog list

# 3. 反汇编 BPF 程序
sudo bpftool prog dump xlated id <ID>

# 4. 查看 JIT 编译后的机器码
sudo bpftool prog dump jited id <ID>
```

### 任务 2：为新匹配器实现代码生成

为 Phase 1 中添加的 `ip4.ttl` 匹配器实现 BPF 代码生成。

### 任务 3：优化代码生成

分析生成的 BPF 代码，找出可以优化的地方。

---

## 🔍 调试技巧

### 查看 BPF 程序

```bash
# 列出所有 BPF 程序
sudo bpftool prog show

# 查看程序详细信息
sudo bpftool prog show id <ID>

# 导出为 C 代码
sudo bpftool prog dump xlated id <ID> > prog.txt
```

### BPF Verifier 日志

```bash
# 查看 verifier 拒绝的原因
sudo dmesg | grep -i bpf

# 或使用 bpftool 加载时查看详细日志
sudo bpftool prog load program.o /sys/fs/bpf/test --debug
```

---

## 📚 延伸阅读

- **eBPF 文档：** https://ebpf.io/
- **BPF 指令集：** https://www.kernel.org/doc/html/latest/bpf/instruction-set.html
- **libbpf 文档：** https://libbpf.readthedocs.io/
- **BPF Verifier：** https://www.kernel.org/doc/html/latest/bpf/verifier.html

---

## ✅ 检查清单

- [ ] 理解 eBPF 基本指令
- [ ] 理解 bpfilter 代码生成流程
- [ ] 阅读过至少 3 个匹配器的代码生成实现
- [ ] 使用 bpftool 查看过生成的 BPF 代码
- [ ] 为新匹配器实现了代码生成
- [ ] 理解 BPF map 的使用

---

## 🚀 下一步

- [practice_03_analyze_bpf.md](practice_03_analyze_bpf.md) - 实践项目
- [Phase 4: 翻译层机制](04_translation_layers.md) - 下一章节
