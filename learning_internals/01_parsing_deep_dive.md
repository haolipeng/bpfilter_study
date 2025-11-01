# Phase 1: 规则解析机制深度解析

## 🎯 学习目标

通过本章学习，你将理解：
- bpfilter 规则文本如何被词法分析器（Lexer）切分成 token
- 语法分析器（Parser）如何根据 token 构建抽象语法树（AST）
- AST 如何转换成内部数据结构（Chain、Rule、Matcher 等）
- 如何添加新的匹配器和语法规则

## 📚 背景知识

### 编译原理基础

规则解析遵循经典的编译器前端流程：

```
规则文本
    ↓
词法分析（Lexer）- 生成 Token 流
    ↓
语法分析（Parser）- 构建 AST
    ↓
语义分析 - 转换成内部数据结构
    ↓
内部表示（Chain、Rule、Matcher）
```

### 工具介绍

**Flex（Fast Lexical Analyzer）**
- 用于词法分析（Lexical Analysis）
- 使用正则表达式定义 token 规则
- 生成 C 代码（yylex 函数）
- 源文件：[src/bfcli/lexer.l](../src/bfcli/lexer.l)

**Bison（GNU Parser Generator）**
- 用于语法分析（Syntax Analysis）
- 使用 BNF（巴克斯范式）定义语法规则
- 生成 C 代码（yyparse 函数）
- 源文件：[src/bfcli/parser.y](../src/bfcli/parser.y)

## 🔍 词法分析详解

### 源码位置
[src/bfcli/lexer.l](../src/bfcli/lexer.l)

### Lexer 的工作原理

Lexer 读取输入文本，根据正则表达式规则匹配并生成 token。

**示例规则解析：**

输入文本：
```
chain test BF_HOOK_NF_LOCAL_IN ACCEPT
  rule ip4.saddr 192.168.1.100 counter DROP
```

Token 流：
```
CHAIN -> "chain"
IDENTIFIER -> "test"
HOOK_TYPE -> "BF_HOOK_NF_LOCAL_IN"
ACCEPT -> "ACCEPT"
RULE -> "rule"
MATCHER_IP4_SADDR -> "ip4.saddr"
IP_ADDRESS -> "192.168.1.100"
COUNTER -> "counter"
DROP -> "DROP"
```

### Lexer.l 文件结构

```c
%{
/* C 代码段：头文件、声明 */
#include "parser.h"
%}

/* 选项定义 */
%option noyywrap
%option noinput
%option nounput

/* 正则表达式定义（命名模式） */
DIGIT       [0-9]
ALPHA       [a-zA-Z_]
ALPHANUM    [a-zA-Z0-9_]

%%

/* 规则段：正则表达式 -> 动作 */

/* 关键字 */
"chain"     { return CHAIN; }
"rule"      { return RULE; }
"set"       { return SET; }

/* Hook 类型 */
"BF_HOOK_XDP"           { return HOOK_XDP; }
"BF_HOOK_TC_INGRESS"    { return HOOK_TC_INGRESS; }
"BF_HOOK_NF_LOCAL_IN"   { return HOOK_NF_LOCAL_IN; }

/* 匹配器 */
"ip4.saddr" { return MATCHER_IP4_SADDR; }
"ip4.daddr" { return MATCHER_IP4_DADDR; }
"tcp.dport" { return MATCHER_TCP_DPORT; }

/* 判决 */
"ACCEPT"    { return ACCEPT; }
"DROP"      { return DROP; }

/* IP 地址 */
{DIGIT}{1,3}"."{DIGIT}{1,3}"."{DIGIT}{1,3}"."{DIGIT}{1,3} {
    yylval.string = strdup(yytext);
    return IP_ADDRESS;
}

/* 标识符 */
{ALPHA}{ALPHANUM}* {
    yylval.string = strdup(yytext);
    return IDENTIFIER;
}

/* 空白字符 */
[ \t\n]+    { /* 忽略 */ }

/* 注释 */
"#"[^\n]*   { /* 忽略 */ }

%%

/* C 代码段：辅助函数 */
```

### 关键概念解析

**1. Token 类型定义**

Token 类型在 parser.y 中的 `%token` 部分定义：

```c
%token CHAIN RULE SET
%token HOOK_XDP HOOK_TC_INGRESS
%token MATCHER_IP4_SADDR MATCHER_IP4_DADDR
%token ACCEPT DROP CONTINUE
%token <string> IDENTIFIER IP_ADDRESS
```

**2. 语义值（yylval）**

某些 token 需要携带额外信息（如标识符的名称、IP 地址的值）：

```c
"ip4.saddr" {
    /* 不需要携带值，只是一个类型标记 */
    return MATCHER_IP4_SADDR;
}

{IP_ADDRESS} {
    /* 需要携带 IP 地址字符串 */
    yylval.string = strdup(yytext);
    return IP_ADDRESS;
}
```

**3. yytext 变量**

`yytext` 是 Flex 自动提供的全局变量，指向当前匹配的文本。

### 实际代码示例

让我们看一个真实的匹配器定义：

```c
/* 在 lexer.l 中 */

/* IPv4 源地址匹配器 */
"ip4.saddr" {
    return MATCHER_IP4_SADDR;
}

/* IPv4 目标地址匹配器 */
"ip4.daddr" {
    return MATCHER_IP4_DADDR;
}

/* TCP 目标端口匹配器 */
"tcp.dport" {
    return MATCHER_TCP_DPORT;
}
```

### 调试 Lexer

**方法 1：添加调试输出**

修改 lexer.l，在规则动作中添加打印：

```c
"ip4.saddr" {
    fprintf(stderr, "DEBUG: Matched MATCHER_IP4_SADDR\n");
    return MATCHER_IP4_SADDR;
}
```

**方法 2：使用 Flex 的调试选项**

```bash
# 编译时启用调试
flex -d src/bfcli/lexer.l

# 运行时设置调试变量
export FLEX_DEBUG=1
build/output/sbin/bfcli ruleset set --from-str "..."
```

---

## 🌳 语法分析详解

### 源码位置
[src/bfcli/parser.y](../src/bfcli/parser.y)

### Parser 的工作原理

Parser 根据 token 流和语法规则构建抽象语法树（AST）。

**示例：**

Token 流：
```
CHAIN IDENTIFIER("test") HOOK_NF_LOCAL_IN ACCEPT
RULE MATCHER_IP4_SADDR IP_ADDRESS("192.168.1.100") DROP
```

AST：
```
Ruleset
  ├── Chain: name="test", hook=NF_LOCAL_IN, policy=ACCEPT
  │     └── Rule: verdict=DROP
  │           └── Matcher: type=IP4_SADDR, value="192.168.1.100"
```

### Parser.y 文件结构

```c
%{
/* C 代码段：头文件、声明 */
#include <stdio.h>
#include <stdlib.h>
#include "context.h"
%}

/* 联合类型定义（语义值的类型） */
%union {
    char *string;
    int number;
    struct bf_chain *chain;
    struct bf_rule *rule;
    struct bf_matcher *matcher;
}

/* Token 定义 */
%token CHAIN RULE SET
%token HOOK_XDP HOOK_TC_INGRESS
%token ACCEPT DROP CONTINUE

/* 类型化的 Token */
%token <string> IDENTIFIER IP_ADDRESS
%token <number> NUMBER

/* 非终结符类型 */
%type <chain> chain_definition
%type <rule> rule_definition
%type <matcher> matcher

%%

/* 语法规则 */

ruleset:
    /* 空规则集 */
    | ruleset chain_definition {
        /* 将链添加到规则集 */
        add_chain_to_ruleset($2);
    }
    | ruleset set_definition {
        /* 将 set 添加到规则集 */
        add_set_to_ruleset($2);
    }
    ;

chain_definition:
    CHAIN IDENTIFIER hook_type policy {
        /* 创建链对象 */
        $$ = bf_chain_new($2, $3, $4);
    }
    | chain_definition rule_definition {
        /* 将规则添加到链 */
        bf_chain_add_rule($1, $2);
        $$ = $1;
    }
    ;

rule_definition:
    RULE matcher_list verdict {
        /* 创建规则对象 */
        $$ = bf_rule_new($2, $3);
    }
    | RULE matcher_list action_list verdict {
        /* 创建带动作的规则 */
        $$ = bf_rule_new_with_actions($2, $3, $4);
    }
    ;

matcher:
    MATCHER_IP4_SADDR IP_ADDRESS {
        /* 创建 IP 源地址匹配器 */
        $$ = bf_matcher_new_ip4_saddr($2);
    }
    | MATCHER_IP4_DADDR IP_ADDRESS {
        /* 创建 IP 目标地址匹配器 */
        $$ = bf_matcher_new_ip4_daddr($2);
    }
    | MATCHER_TCP_DPORT NUMBER {
        /* 创建 TCP 端口匹配器 */
        $$ = bf_matcher_new_tcp_dport($2);
    }
    ;

%%

/* C 代码段：错误处理、辅助函数 */

void yyerror(const char *s) {
    fprintf(stderr, "Parse error: %s\n", s);
}
```

### 关键概念解析

**1. BNF 语法规则**

格式：
```
非终结符: 产生式1 { 动作1 }
        | 产生式2 { 动作2 }
        | ...
        ;
```

示例：
```c
rule_definition:
    RULE matcher_list verdict {
        $$ = bf_rule_new($2, $3);
    }
    ;
```

- `rule_definition`：非终结符（规则名）
- `RULE matcher_list verdict`：产生式（由哪些符号组成）
- `{ ... }`：语义动作（生成 AST 节点）

**2. 语义值引用**

- `$$`：当前规则的返回值
- `$1, $2, $3...`：产生式中各符号的值

示例：
```c
chain_definition:
    CHAIN IDENTIFIER hook_type policy {
        /*       $1        $2       $3      $4  */
        $$ = bf_chain_new($2, $3, $4);
    }
    ;
```

**3. %union 联合类型**

定义语义值可能的类型：

```c
%union {
    char *string;          /* 字符串类型 */
    int number;            /* 数字类型 */
    struct bf_chain *chain;    /* 链对象指针 */
    struct bf_rule *rule;      /* 规则对象指针 */
    struct bf_matcher *matcher; /* 匹配器对象指针 */
}
```

使用类型：
```c
%token <string> IDENTIFIER    /* IDENTIFIER 的值是 string 类型 */
%type <chain> chain_definition /* chain_definition 的值是 chain 指针 */
```

**4. 优先级和结合性**

使用 `%left`, `%right`, `%nonassoc` 定义优先级：

```c
%left OR
%left AND
%right NOT
```

### 实际语法规则示例

**完整的规则定义：**

```c
rule_definition:
    RULE matcher_list verdict {
        struct bf_rule *rule = bf_rule_new($3);

        /* 添加所有匹配器 */
        for (struct matcher_node *node = $2; node; node = node->next) {
            bf_rule_add_matcher(rule, node->matcher);
        }

        $$ = rule;
    }
    | RULE matcher_list action_list verdict {
        struct bf_rule *rule = bf_rule_new($4);

        /* 添加匹配器 */
        for (struct matcher_node *node = $2; node; node = node->next) {
            bf_rule_add_matcher(rule, node->matcher);
        }

        /* 添加动作 */
        for (struct action_node *node = $3; node; node = node->next) {
            bf_rule_add_action(rule, node->action);
        }

        $$ = rule;
    }
    ;

matcher_list:
    matcher {
        /* 创建链表节点 */
        $$ = matcher_node_new($1);
    }
    | matcher_list matcher {
        /* 添加到链表末尾 */
        $$ = matcher_list_append($1, $2);
    }
    ;

matcher:
    MATCHER_IP4_SADDR IP_ADDRESS {
        $$ = bf_matcher_new(BF_MATCHER_IP4_SADDR, $2);
    }
    | MATCHER_IP4_SADDR IP_CIDR {
        $$ = bf_matcher_new(BF_MATCHER_IP4_SNET, $2);
    }
    | MATCHER_TCP_DPORT NUMBER {
        $$ = bf_matcher_new(BF_MATCHER_TCP_DPORT, &$2);
    }
    ;
```

### 调试 Parser

**方法 1：启用 Bison 调试**

在 parser.y 中添加：

```c
%{
#define YYDEBUG 1
%}

%debug
```

运行时启用：
```bash
export YYDEBUG=1
build/output/sbin/bfcli ruleset set --from-str "..."
```

**方法 2：添加调试打印**

```c
rule_definition:
    RULE matcher_list verdict {
        fprintf(stderr, "DEBUG: Creating rule with verdict %d\n", $3);
        $$ = bf_rule_new($3);
    }
    ;
```

**方法 3：生成调试信息**

```bash
# 生成带调试信息的 parser
bison -t -v src/bfcli/parser.y

# 查看生成的 parser.output 文件（包含状态机信息）
cat parser.output
```

---

## 🔄 从 AST 到内部数据结构

### 转换流程

```
Parser 动作
    ↓
创建临时 AST 节点
    ↓
调用构造函数（bf_chain_new, bf_rule_new 等）
    ↓
内部数据结构（struct bf_chain, struct bf_rule）
```

### 关键函数

**Chain 创建：**
```c
/* 在 parser.y 中 */
chain_definition:
    CHAIN IDENTIFIER hook_type policy {
        $$ = bf_chain_new($2, $3, $4);
    }
    ;

/* 实际实现在 src/libbpfilter/chain.c */
struct bf_chain *bf_chain_new(const char *name,
                                enum bf_hook hook,
                                enum bf_verdict policy)
{
    struct bf_chain *chain = malloc(sizeof(*chain));
    chain->name = strdup(name);
    chain->hook = hook;
    chain->policy = policy;
    bf_list_init(&chain->rules);
    return chain;
}
```

**Matcher 创建：**
```c
/* 在 parser.y 中 */
matcher:
    MATCHER_IP4_SADDR IP_ADDRESS {
        $$ = bf_matcher_new_ip4_saddr($2);
    }
    ;

/* 实际实现在 src/libbpfilter/matcher.c */
struct bf_matcher *bf_matcher_new_ip4_saddr(const char *ip_str)
{
    struct bf_matcher *matcher = malloc(sizeof(*matcher));
    matcher->type = BF_MATCHER_IP4_SADDR;

    /* 解析 IP 地址字符串 */
    inet_pton(AF_INET, ip_str, &matcher->payload.ip4_addr);

    return matcher;
}
```

---

## 🛠️ 实践：添加新匹配器

详见：[practice_01_add_matcher.md](practice_01_add_matcher.md)

### 快速步骤

假设我们要添加 `ip4.ttl` 匹配器（匹配 IP TTL 值）：

**步骤 1：在 lexer.l 中添加 token**

```c
"ip4.ttl"   { return MATCHER_IP4_TTL; }
```

**步骤 2：在 parser.y 中定义 token**

```c
%token MATCHER_IP4_TTL
```

**步骤 3：在 parser.y 中添加语法规则**

```c
matcher:
    /* ... 其他匹配器 ... */
    | MATCHER_IP4_TTL NUMBER {
        $$ = bf_matcher_new_ip4_ttl($2);
    }
    ;
```

**步骤 4：实现构造函数**

在 [src/libbpfilter/matcher.c](../src/libbpfilter/matcher.c) 中：

```c
struct bf_matcher *bf_matcher_new_ip4_ttl(uint8_t ttl)
{
    struct bf_matcher *matcher = malloc(sizeof(*matcher));
    matcher->type = BF_MATCHER_IP4_TTL;
    matcher->payload.ttl = ttl;
    return matcher;
}
```

**步骤 5：定义匹配器类型**

在 [src/libbpfilter/include/bpfilter/matcher.h](../src/libbpfilter/include/bpfilter/matcher.h) 中：

```c
enum bf_matcher_type {
    /* ... */
    BF_MATCHER_IP4_TTL,
    /* ... */
};

struct bf_matcher {
    enum bf_matcher_type type;
    union {
        uint32_t ip4_addr;
        uint16_t port;
        uint8_t ttl;  /* 新增 */
        /* ... */
    } payload;
};
```

**步骤 6：编译测试**

```bash
make -C build
sudo build/output/sbin/bfcli ruleset set --from-str \
  "chain test BF_HOOK_NF_LOCAL_IN ACCEPT
     rule ip4.ttl 64 ACCEPT"
```

---

## 🔍 调试技巧

### 使用 GDB 调试解析过程

```bash
# 编译 debug 版本
cmake -S . -B build -DCMAKE_BUILD_TYPE=debug
make -C build

# 调试 bfcli
gdb build/output/sbin/bfcli

# 设置断点
(gdb) break yyparse
(gdb) break bf_chain_new
(gdb) break bf_rule_new

# 运行
(gdb) run ruleset set --from-str "chain test BF_HOOK_NF_LOCAL_IN ACCEPT"

# 单步执行
(gdb) step

# 查看变量
(gdb) print yytext
(gdb) print yylval
```

### 查看 Parser 状态机

```bash
# 生成 parser.output 文件
bison -v src/bfcli/parser.y

# 查看状态机
cat parser.output
```

输出示例：
```
State 0:
    0 $accept: . ruleset $end

    $default  reduce using rule 1 (ruleset)

    ruleset  go to state 1

State 1:
    0 $accept: ruleset . $end
    2 ruleset: ruleset . chain_definition

    $end             shift, and go to state 2
    CHAIN            shift, and go to state 3
    ...
```

### 常见错误处理

**Shift/Reduce 冲突：**

```
Warning: 1 shift/reduce conflict
```

解决方法：
1. 使用 `%left`, `%right` 定义优先级
2. 重构语法规则避免歧义

**Reduce/Reduce 冲突：**

```
Warning: 1 reduce/reduce conflict
```

解决方法：
1. 检查是否有重复的规则
2. 合并或重构冲突的规则

---

## 📖 延伸阅读

### 推荐资料

1. **Flex 和 Bison 教程**
   - https://github.com/meyerd/flex-bison-example
   - "flex & bison" by John Levine (O'Reilly)

2. **编译原理**
   - "Compilers: Principles, Techniques, and Tools" (龙书)
   - 第 2-4 章（词法分析和语法分析）

3. **bpfilter 相关文档**
   - [doc/usage/bfcli.rst](../doc/usage/bfcli.rst) - 完整语法参考
   - [CONTRIBUTING.md](../CONTRIBUTING.md) - 贡献指南

### 相关源码文件

- [src/bfcli/lexer.l](../src/bfcli/lexer.l) - 词法分析器
- [src/bfcli/parser.y](../src/bfcli/parser.y) - 语法分析器
- [src/bfcli/context.c](../src/bfcli/context.c) - 解析上下文
- [src/bfcli/context.h](../src/bfcli/context.h) - 数据结构定义

---

## ✅ 自我检验

完成本章后，你应该能够：

- [ ] 解释 Lexer 和 Parser 的作用和区别
- [ ] 读懂 lexer.l 中的所有 token 定义
- [ ] 读懂 parser.y 中的语法规则
- [ ] 理解 `$$`, `$1`, `$2` 的含义
- [ ] 理解 `%union` 和类型系统
- [ ] 独立添加一个新的匹配器
- [ ] 使用调试工具追踪解析过程
- [ ] 解决基本的 shift/reduce 冲突

---

## 🎯 下一步

完成本章学习后，继续学习：

- [practice_01_add_matcher.md](practice_01_add_matcher.md) - 实践项目：添加新匹配器
- [debug_parser.md](debug_parser.md) - 深入调试技巧
- [Phase 2: 内部数据结构](02_data_structures.md) - 下一章节

祝学习愉快！🚀
