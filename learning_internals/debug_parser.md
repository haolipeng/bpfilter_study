# Parser 调试指南

## 🎯 目标

掌握各种调试技术，能够快速定位和解决解析相关的问题。

## 🛠️ 调试工具

### 1. GDB（GNU Debugger）

#### 基础使用

```bash
# 编译 debug 版本
cmake -S . -B build -DCMAKE_BUILD_TYPE=debug -DNO_DOCS=ON -DNO_CHECKS=ON
make -C build

# 启动 GDB
gdb build/output/sbin/bfcli

# 常用命令
(gdb) break yyparse          # 在 parser 入口设置断点
(gdb) break yylex            # 在 lexer 设置断点
(gdb) break bf_chain_new     # 在构造函数设置断点
(gdb) run ruleset set --from-str "chain test BF_HOOK_NF_LOCAL_IN ACCEPT"
(gdb) step                   # 单步进入
(gdb) next                   # 单步跳过
(gdb) continue               # 继续执行
(gdb) print yytext           # 打印当前token文本
(gdb) print yylval           # 打印语义值
(gdb) backtrace              # 查看调用栈
```

#### 高级技巧

**条件断点：**
```bash
(gdb) break bf_matcher_new if type == BF_MATCHER_IP4_TTL
```

**监视点：**
```bash
(gdb) watch matcher->payload.ttl
```

**自动打印：**
```bash
(gdb) display yytext
(gdb) display yylval.number
```

#### GDB 脚本

创建 `.gdbinit` 文件：

```gdb
# 在项目根目录创建 .gdbinit
set print pretty on
set pagination off

# 断点
break yyparse
break yyerror

# 自动打印
display yytext

# 自定义命令
define parse-trace
    break yyparse
    commands
        silent
        printf "Parsing: %s\n", yytext
        continue
    end
end
```

使用：
```bash
gdb -x .gdbinit build/output/sbin/bfcli
(gdb) parse-trace
(gdb) run ruleset set --from-str "..."
```

---

### 2. Bison 调试模式

#### 启用调试输出

**方法 1：编译时启用**

在 `parser.y` 中添加：

```c
%{
#define YYDEBUG 1
%}

%debug
```

重新编译后运行：

```bash
export YYDEBUG=1
build/output/sbin/bfcli ruleset set --from-str "chain test BF_HOOK_NF_LOCAL_IN ACCEPT"
```

**输出示例：**
```
Starting parse
Entering state 0
Reading a token: Next token is token CHAIN ()
Shifting token CHAIN ()
Entering state 1
Reading a token: Next token is token IDENTIFIER ()
...
```

**方法 2：运行时启用**

在代码中动态设置：

```c
/* 在 parser.y 的 main 或初始化函数中 */
#if YYDEBUG
    yydebug = 1;  /* 启用调试 */
#endif
```

#### 理解调试输出

```
Reading a token: Next token is token MATCHER_IP4_TTL ()
```
- 表示 Lexer 返回了 `MATCHER_IP4_TTL` token

```
Reducing stack by rule 15 (line 234)
```
- 表示使用第 15 条规则进行归约

```
Shifting token NUMBER ()
Entering state 42
```
- 表示 shift 操作，进入状态 42

---

### 3. Flex 调试模式

#### 启用调试

```bash
# 编译时启用
flex -d src/bfcli/lexer.l

# 或在 lexer.l 中添加
%option debug
```

运行时启用：

```bash
export LEX_DEBUG=1
build/output/sbin/bfcli ruleset set --from-str "..."
```

#### 调试输出

```
--scanning backing up

--accepting rule at line 45 ("chain")
--accepting default rule ("BF_HOOK_NF_LOCAL_IN")
```

---

### 4. Printf 调试

#### 在 Lexer 中添加调试输出

```c
/* lexer.l */

"ip4.ttl" {
    fprintf(stderr, "[LEXER] Matched MATCHER_IP4_TTL\n");
    fprintf(stderr, "[LEXER] yytext='%s'\n", yytext);
    return MATCHER_IP4_TTL;
}

{NUMBER} {
    fprintf(stderr, "[LEXER] Matched NUMBER: %s\n", yytext);
    yylval.number = atoi(yytext);
    fprintf(stderr, "[LEXER] Converted to: %d\n", yylval.number);
    return NUMBER;
}
```

#### 在 Parser 中添加调试输出

```c
/* parser.y */

matcher:
    MATCHER_IP4_TTL NUMBER {
        fprintf(stderr, "[PARSER] Creating IP4 TTL matcher, value=%d\n", $2);
        $$ = bf_matcher_new_ip4_ttl($2);
        fprintf(stderr, "[PARSER] Matcher created at %p\n", $$);
    }
    ;
```

---

### 5. Valgrind 内存调试

#### 检查内存泄漏

```bash
valgrind --leak-check=full \
         --show-leak-kinds=all \
         --track-origins=yes \
         --verbose \
         build/output/sbin/bfcli ruleset set --from-str "chain test BF_HOOK_NF_LOCAL_IN ACCEPT"
```

#### 常见问题

**问题 1：字符串未释放**

```c
/* 错误 */
"ip4.ttl" {
    yylval.string = strdup(yytext);  /* 分配了内存 */
    return MATCHER_IP4_TTL;
}

/* 在 parser 中 */
matcher:
    MATCHER_IP4_TTL NUMBER {
        /* 忘记释放 yylval.string */
        $$ = bf_matcher_new_ip4_ttl($2);
    }
    ;
```

**解决方法：**

```c
matcher:
    MATCHER_IP4_TTL NUMBER {
        $$ = bf_matcher_new_ip4_ttl($2);
        /* 不需要 strdup，因为 MATCHER_IP4_TTL 是固定 token */
    }
    ;
```

**问题 2：结构体未完全初始化**

```c
/* Valgrind 会警告：Conditional jump or move depends on uninitialised value(s) */

struct bf_matcher *bf_matcher_new_ip4_ttl(uint8_t ttl)
{
    struct bf_matcher *matcher = malloc(sizeof(*matcher));
    matcher->type = BF_MATCHER_IP4_TTL;
    matcher->payload.ttl = ttl;
    /* 忘记初始化其他字段 */
    return matcher;
}
```

**解决方法：**

```c
struct bf_matcher *bf_matcher_new_ip4_ttl(uint8_t ttl)
{
    struct bf_matcher *matcher = calloc(1, sizeof(*matcher));  /* 使用 calloc */
    matcher->type = BF_MATCHER_IP4_TTL;
    matcher->payload.ttl = ttl;
    return matcher;
}
```

---

## 🐛 常见错误及解决

### 错误 1：Syntax Error

**症状：**
```
Parse error: syntax error
```

**调试步骤：**

1. 启用 Bison 调试查看在哪里失败：

```bash
export YYDEBUG=1
build/output/sbin/bfcli ruleset set --from-str "..."
```

2. 检查 Lexer 是否正确识别 token：

在 lexer.l 中添加调试打印，确认每个 token 都被正确识别。

3. 检查 Parser 语法规则：

确认产生式是否正确，是否缺少某些规则。

### 错误 2：Shift/Reduce 冲突

**症状：**
```
parser.y:123: warning: 1 shift/reduce conflict
```

**原因：**
语法存在歧义，Parser 不知道应该 shift（移进）还是 reduce（归约）。

**示例：**

```c
/* 有歧义的语法 */
matcher:
    MATCHER_IP4_TTL NUMBER
    | MATCHER_IP4_TTL NUMBER NUMBER  /* 歧义：两个 NUMBER 的含义不明 */
    ;
```

**解决方法 1：使用优先级**

```c
%left '+' '-'
%left '*' '/'
```

**解决方法 2：重构语法**

```c
matcher:
    MATCHER_IP4_TTL ttl_value
    ;

ttl_value:
    NUMBER                    /* 单个值 */
    | NUMBER '-' NUMBER       /* 范围 */
    ;
```

**查看详细信息：**

```bash
bison -v src/bfcli/parser.y
cat parser.output
```

### 错误 3：Reduce/Reduce 冲突

**症状：**
```
parser.y:123: warning: 1 reduce/reduce conflict
```

**原因：**
两条不同的规则可以归约相同的输入。

**示例：**

```c
/* 冲突：无法区分这两条规则 */
rule1: MATCHER_A NUMBER ;
rule2: MATCHER_A NUMBER ;
```

**解决方法：**
合并或重构规则，消除歧义。

### 错误 4：Segmentation Fault

**调试步骤：**

1. 使用 GDB 定位崩溃位置：

```bash
gdb build/output/sbin/bfcli
(gdb) run ruleset set --from-str "..."
# 崩溃后
(gdb) backtrace
(gdb) frame 0
(gdb) print matcher
```

2. 使用 Valgrind 查找内存错误：

```bash
valgrind build/output/sbin/bfcli ruleset set --from-str "..."
```

3. 常见原因：
   - 空指针解引用
   - 访问已释放的内存
   - 数组越界

---

## 📊 Parser 状态机分析

### 生成状态机文件

```bash
bison -v src/bfcli/parser.y
cat parser.output
```

### 理解状态机

**示例输出：**

```
State 42:

    15 matcher: MATCHER_IP4_TTL . NUMBER

    NUMBER  shift, and go to state 68

State 68:

    15 matcher: MATCHER_IP4_TTL NUMBER .

    $default  reduce using rule 15 (matcher)
```

**解读：**
- State 42：看到 `MATCHER_IP4_TTL`，等待 `NUMBER`
- 看到 `NUMBER` 后 shift，进入 State 68
- State 68：匹配完整，使用规则 15 归约

---

## 🧪 测试策略

### 单元测试

为 Parser 编写单元测试：

```c
/* tests/unit/test_parser.c */

#include <cmocka.h>
#include "bfcli/parser.h"

static void test_parse_ip4_ttl(void **state)
{
    const char *input = "chain test BF_HOOK_NF_LOCAL_IN ACCEPT\n"
                        "  rule ip4.ttl 64 ACCEPT\n";

    struct bf_ruleset *ruleset = parse_ruleset(input);

    assert_non_null(ruleset);
    assert_int_equal(ruleset->num_chains, 1);

    struct bf_chain *chain = ruleset->chains[0];
    assert_string_equal(chain->name, "test");
    assert_int_equal(chain->num_rules, 1);

    struct bf_rule *rule = chain->rules[0];
    assert_int_equal(rule->num_matchers, 1);

    struct bf_matcher *matcher = rule->matchers[0];
    assert_int_equal(matcher->type, BF_MATCHER_IP4_TTL);
    assert_int_equal(matcher->payload.ttl, 64);

    bf_ruleset_free(ruleset);
}
```

### 模糊测试（Fuzzing）

使用 AFL 或 libFuzzer 进行模糊测试：

```bash
# 使用 AFL
afl-gcc -o bfcli-fuzz src/bfcli/*.c
afl-fuzz -i testcases -o findings ./bfcli-fuzz @@
```

---

## 📝 调试清单

遇到解析问题时，按顺序检查：

1. **Lexer 层面**
   - [ ] Token 定义是否正确？
   - [ ] 正则表达式是否匹配预期输入？
   - [ ] yylval 是否正确设置？

2. **Parser 层面**
   - [ ] Token 声明是否正确？
   - [ ] 语法规则是否完整？
   - [ ] 语义动作是否正确？
   - [ ] 是否有 shift/reduce 或 reduce/reduce 冲突？

3. **语义层面**
   - [ ] 构造函数是否实现？
   - [ ] 数据结构是否正确初始化？
   - [ ] 内存是否正确分配和释放？

4. **测试**
   - [ ] 基础用例是否通过？
   - [ ] 边界情况是否处理？
   - [ ] 错误情况是否有合理提示？

---

## 🎯 实战演练

### 练习 1：追踪解析流程

使用 GDB 追踪以下规则的完整解析过程：

```
chain test BF_HOOK_NF_LOCAL_IN ACCEPT
  rule ip4.ttl 64 counter DROP
```

记录：
- 生成了哪些 token
- 使用了哪些语法规则
- 创建了哪些对象
- 调用了哪些构造函数

### 练习 2：修复 Bug

给定一个有 Bug 的匹配器实现，使用调试工具定位并修复：

```c
/* Bug: 内存泄漏 */
struct bf_matcher *bf_matcher_new_buggy(const char *value)
{
    struct bf_matcher *m = malloc(sizeof(*m));
    m->type = BF_MATCHER_CUSTOM;
    m->payload.string = strdup(value);  /* 分配内存 */
    return m;
}

/* 调用者忘记释放 payload.string */
```

使用 Valgrind 定位泄漏，然后修复。

### 练习 3：分析冲突

给定以下有冲突的语法，分析冲突原因并重构：

```c
matcher:
    IP4_ADDR
    | IP4_ADDR '/' NUMBER
    | IP4_ADDR IP4_ADDR
    ;
```

---

## 📚 参考资料

- **GDB 手册：** https://sourceware.org/gdb/documentation/
- **Bison 手册：** https://www.gnu.org/software/bison/manual/
- **Flex 手册：** https://github.com/westes/flex
- **Valgrind 手册：** https://valgrind.org/docs/manual/

---

完成本指南学习后，你应该能够独立调试和解决各种解析相关的问题！🚀
