# Phase 2: 内部数据结构深度解析

## 🎯 学习目标

- 理解 bpfilter 核心数据结构的设计和实现
- 掌握 Chain、Rule、Matcher、Set 的内存布局
- 理解数据如何在各组件之间流转
- 能够绘制完整的数据结构关系图

## 📚 核心数据结构

### 1. Chain（链）

**定义位置：** [src/libbpfilter/include/bpfilter/chain.h](../src/libbpfilter/include/bpfilter/chain.h)

```c
/**
 * Represents a filtering chain attached to a kernel hook point.
 */
struct bf_chain {
    char *name;                    /* Chain name */
    enum bf_hook hook;             /* Hook point (XDP, TC, NF, cgroup) */
    enum bf_verdict policy;        /* Default policy (ACCEPT/DROP) */

    struct bf_list rules;          /* List of rules (bf_list) */
    size_t num_rules;              /* Number of rules */

    /* For NF hooks */
    uint32_t family;               /* AF_INET or AF_INET6 */
    int32_t priority;              /* Hook priority */

    /* For XDP/TC hooks */
    uint32_t ifindex;              /* Interface index */

    /* For cgroup hooks */
    char *cgroup_path;             /* Cgroup path */

    /* BPF program */
    struct bf_program *program;    /* Generated BPF program */
    bool loaded;                   /* Is program loaded? */
    bool attached;                 /* Is program attached? */
};
```

**关键方法：**
```c
/* Constructor */
struct bf_chain *bf_chain_new(const char *name, enum bf_hook hook,
                               enum bf_verdict policy);

/* Add rule */
int bf_chain_add_rule(struct bf_chain *chain, struct bf_rule *rule);

/* Generate BPF code */
int bf_chain_generate(struct bf_chain *chain);

/* Load BPF program */
int bf_chain_load(struct bf_chain *chain);

/* Attach to hook */
int bf_chain_attach(struct bf_chain *chain);

/* Destructor */
void bf_chain_free(struct bf_chain *chain);
```

**实现文件：** [src/libbpfilter/chain.c](../src/libbpfilter/chain.c)

---

### 2. Rule（规则）

**定义位置：** [src/libbpfilter/include/bpfilter/rule.h](../src/libbpfilter/include/bpfilter/rule.h)

```c
/**
 * Represents a filtering rule with matchers and actions.
 */
struct bf_rule {
    struct bf_list matchers;       /* List of matchers */
    size_t num_matchers;

    struct bf_list actions;        /* List of actions (counter, log, mark) */
    size_t num_actions;

    enum bf_verdict verdict;       /* Final verdict (ACCEPT/DROP/CONTINUE) */

    /* Runtime state */
    struct {
        uint64_t packets;          /* Packet counter */
        uint64_t bytes;            /* Byte counter */
    } counters;
};
```

**关键方法：**
```c
struct bf_rule *bf_rule_new(enum bf_verdict verdict);
int bf_rule_add_matcher(struct bf_rule *rule, struct bf_matcher *matcher);
int bf_rule_add_action(struct bf_rule *rule, struct bf_action *action);
void bf_rule_free(struct bf_rule *rule);
```

**实现文件：** [src/libbpfilter/rule.c](../src/libbpfilter/rule.c)

---

### 3. Matcher（匹配器）

**定义位置：** [src/libbpfilter/include/bpfilter/matcher.h](../src/libbpfilter/include/bpfilter/matcher.h)

```c
/**
 * Matcher types - what field to match.
 */
enum bf_matcher_type {
    /* Meta matchers */
    BF_MATCHER_META_IFINDEX,       /* Interface index */
    BF_MATCHER_META_L3_PROTO,      /* L3 protocol (IPv4/IPv6) */
    BF_MATCHER_META_L4_PROTO,      /* L4 protocol (TCP/UDP/ICMP) */

    /* IPv4 matchers */
    BF_MATCHER_IP4_SADDR,          /* Source address */
    BF_MATCHER_IP4_DADDR,          /* Destination address */
    BF_MATCHER_IP4_SNET,           /* Source network (CIDR) */
    BF_MATCHER_IP4_DNET,           /* Destination network (CIDR) */
    BF_MATCHER_IP4_PROTO,          /* IP protocol */

    /* IPv6 matchers */
    BF_MATCHER_IP6_SADDR,
    BF_MATCHER_IP6_DADDR,
    /* ... */

    /* TCP matchers */
    BF_MATCHER_TCP_SPORT,          /* Source port */
    BF_MATCHER_TCP_DPORT,          /* Destination port */
    BF_MATCHER_TCP_FLAGS,          /* TCP flags */

    /* UDP matchers */
    BF_MATCHER_UDP_SPORT,
    BF_MATCHER_UDP_DPORT,

    /* ICMP matchers */
    BF_MATCHER_ICMP_TYPE,
    BF_MATCHER_ICMP_CODE,
};

/**
 * Matcher instance with type and value.
 */
struct bf_matcher {
    enum bf_matcher_type type;

    /* Payload - actual value to match */
    union {
        uint32_t ifindex;
        uint16_t port;
        uint32_t ip4_addr;
        uint8_t ip6_addr[16];
        uint8_t proto;
        uint16_t tcp_flags;
        uint8_t icmp_type;
        /* ... */
    } payload;

    /* For network matchers (CIDR) */
    uint8_t prefix_len;

    /* For negation */
    bool negate;                   /* NOT operator */
};
```

**关键方法：**
```c
struct bf_matcher *bf_matcher_new(enum bf_matcher_type type, const void *value);
void bf_matcher_free(struct bf_matcher *matcher);
```

**实现文件：** [src/libbpfilter/matcher.c](../src/libbpfilter/matcher.c)

---

### 4. Set（集合）

**定义位置：** [src/libbpfilter/include/bpfilter/set.h](../src/libbpfilter/include/bpfilter/set.h)

```c
/**
 * Set element - a single value in the set.
 */
struct bf_set_elem {
    void *key;                     /* Element key (IP, port, etc.) */
    size_t key_size;               /* Key size in bytes */
    struct bf_set_elem *next;      /* Hash table chain */
};

/**
 * Set - hash table for fast lookups.
 */
struct bf_set {
    char *name;                    /* Set name (or NULL for anonymous) */
    enum bf_matcher_type elem_type; /* Element type */

    struct bf_set_elem **buckets;  /* Hash table buckets */
    size_t num_buckets;            /* Bucket count */
    size_t num_elements;           /* Element count */

    /* BPF map for kernel-side lookups */
    int map_fd;                    /* BPF map file descriptor */
};
```

**关键方法：**
```c
struct bf_set *bf_set_new(const char *name, enum bf_matcher_type elem_type);
int bf_set_add_elem(struct bf_set *set, const void *key, size_t key_size);
bool bf_set_contains(struct bf_set *set, const void *key, size_t key_size);
int bf_set_to_bpf_map(struct bf_set *set);  /* Create BPF map */
void bf_set_free(struct bf_set *set);
```

**实现文件：** [src/libbpfilter/set.c](../src/libbpfilter/set.c)

---

### 5. List（链表）

**定义位置：** [src/libbpfilter/include/bpfilter/list.h](../src/libbpfilter/include/bpfilter/list.h)

```c
/**
 * Intrusive doubly-linked list.
 */
struct bf_list {
    struct bf_list *prev;
    struct bf_list *next;
};
```

**使用示例：**
```c
struct bf_chain {
    /* ... */
    struct bf_list rules;          /* List head */
    /* ... */
};

struct bf_rule {
    struct bf_list list;           /* List node */
    /* ... */
};

/* Iterate over rules */
struct bf_rule *rule;
bf_list_foreach(rule, &chain->rules, list) {
    /* Process each rule */
}
```

**实现文件：** [src/libbpfilter/list.c](../src/libbpfilter/list.c)

---

## 🔄 数据流转

### 从用户输入到内部表示

```
用户输入（文本规则）
    ↓
Lexer/Parser (src/bfcli/)
    ↓
临时 AST 节点
    ↓
构造函数（bf_chain_new, bf_rule_new, etc.）
    ↓
内部数据结构
    ├── bf_chain
    │   └── bf_list (rules)
    │       ├── bf_rule
    │       │   ├── bf_list (matchers)
    │       │   │   ├── bf_matcher
    │       │   │   └── bf_matcher
    │       │   └── bf_list (actions)
    │       └── bf_rule
    └── bf_set
```

### 请求处理流程

```
CLI Tool (bfcli)
    ↓
libbpfilter API (bf_chain_set, bf_ruleset_set, etc.)
    ↓
Unix Socket 通信
    ↓
Daemon (bpfilter)
    ↓
Translation Layer (xlate/)
    ↓
Internal Representation
    ↓
Code Generation (cgen/)
    ↓
BPF Programs
    ↓
Kernel
```

---

## 📊 内存布局

### Chain 内存布局示例

```
bf_chain @ 0x7f1234567000
├── name @ 0x7f1234567100 → "test_chain"
├── hook = BF_HOOK_NF_LOCAL_IN (2)
├── policy = BF_VERDICT_ACCEPT (1)
├── rules (bf_list)
│   ├── prev @ 0x7f1234567020
│   └── next @ 0x7f1234567800 → bf_rule
├── num_rules = 2
└── program @ 0x7f1234568000 → bf_program
```

### Rule 内存布局示例

```
bf_rule @ 0x7f1234567800
├── list (bf_list node)
│   ├── prev @ 0x7f1234567020
│   └── next @ 0x7f1234567900
├── matchers (bf_list)
│   ├── next → bf_matcher @ 0x7f1234567a00
│   └── next → bf_matcher @ 0x7f1234567b00
├── num_matchers = 2
├── actions (bf_list)
├── verdict = BF_VERDICT_DROP (2)
└── counters
    ├── packets = 42
    └── bytes = 3360
```

---

## 🛠️ 实践任务

详见：[practice_02_trace_request.md](practice_02_trace_request.md)

### 任务 1：绘制数据结构关系图

使用工具（如 GraphViz）绘制 bpfilter 核心数据结构的关系图。

### 任务 2：追踪数据流

使用 GDB 追踪一个规则从 CLI 到 Daemon 的完整生命周期：

```bash
# Terminal 1: 启动守护进程并用 GDB 附加
sudo gdb -p $(pgrep bpfilter)
(gdb) break bf_chain_set
(gdb) continue

# Terminal 2: 发送规则
sudo build/output/sbin/bfcli ruleset set --from-str "chain test BF_HOOK_NF_LOCAL_IN ACCEPT"

# 在 Terminal 1 中观察断点触发，查看数据
(gdb) print *chain
(gdb) print *chain->rules
```

### 任务 3：内存分析

使用 GDB 查看数据结构的实际内存布局：

```bash
(gdb) x/32x chain          # 查看 chain 的前 32 字节
(gdb) print sizeof(*chain) # 查看结构体大小
(gdb) print &chain->name - &chain  # 查看字段偏移
```

---

## 📖 关键源码阅读

### 阅读顺序

1. **数据结构定义**（头文件）
   - [include/bpfilter/chain.h](../src/libbpfilter/include/bpfilter/chain.h)
   - [include/bpfilter/rule.h](../src/libbpfilter/include/bpfilter/rule.h)
   - [include/bpfilter/matcher.h](../src/libbpfilter/include/bpfilter/matcher.h)
   - [include/bpfilter/set.h](../src/libbpfilter/include/bpfilter/set.h)

2. **构造/析构函数**（实现文件）
   - [chain.c](../src/libbpfilter/chain.c)
   - [rule.c](../src/libbpfilter/rule.c)
   - [matcher.c](../src/libbpfilter/matcher.c)
   - [set.c](../src/libbpfilter/set.c)

3. **辅助数据结构**
   - [list.c](../src/libbpfilter/list.c) - 链表实现

4. **API 函数**
   - [bpfilter.c](../src/libbpfilter/bpfilter.c) - 公共 API

---

## ✅ 检查清单

完成本章后，确认：

- [ ] 理解 bf_chain、bf_rule、bf_matcher、bf_set 的结构
- [ ] 知道如何使用 bf_list 遍历规则
- [ ] 理解数据从 CLI 到 Daemon 的流转过程
- [ ] 能够使用 GDB 查看内存布局
- [ ] 绘制了完整的数据结构关系图
- [ ] 追踪过至少一个完整的请求流程

---

## 🚀 下一步

- [practice_02_trace_request.md](practice_02_trace_request.md) - 实践项目
- [Phase 3: BPF 代码生成](03_codegen_explained.md) - 下一章节
