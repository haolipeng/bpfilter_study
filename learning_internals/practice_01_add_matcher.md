# 实践项目 1: 添加新的匹配器

## 🎯 项目目标

通过实际动手添加一个新的匹配器，深入理解 bpfilter 的规则解析流程。

## 📝 项目描述

我们将添加一个 **IP TTL（Time To Live）** 匹配器，用于匹配 IP 包的 TTL 值。

**使用示例：**
```
chain test BF_HOOK_NF_LOCAL_IN ACCEPT
  rule ip4.ttl 64 ACCEPT
  rule ip4.ttl 128 counter ACCEPT
```

## 🛠️ 实现步骤

### 步骤 1: 定义匹配器类型

**文件：** [src/libbpfilter/include/bpfilter/matcher.h](../src/libbpfilter/include/bpfilter/matcher.h)

找到 `enum bf_matcher_type` 定义，添加新的匹配器类型：

```c
enum bf_matcher_type {
    BF_MATCHER_META_IFINDEX,
    BF_MATCHER_META_L3_PROTO,
    BF_MATCHER_META_L4_PROTO,
    /* ... 其他类型 ... */
    BF_MATCHER_IP4_SADDR,
    BF_MATCHER_IP4_DADDR,
    BF_MATCHER_IP4_TTL,      // 新增：IP TTL 匹配器
    /* ... */
};
```

找到 `struct bf_matcher` 定义，在 payload 联合体中添加 TTL 字段：

```c
struct bf_matcher {
    enum bf_matcher_type type;

    union {
        uint32_t ifindex;
        uint16_t port;
        uint32_t ip4_addr;
        uint8_t ttl;         // 新增：TTL 值（0-255）
        /* ... 其他字段 ... */
    } payload;

    /* ... */
};
```

### 步骤 2: 添加 Lexer Token

**文件：** [src/bfcli/lexer.l](../src/bfcli/lexer.l)

在匹配器 token 定义部分添加：

```c
/* IPv4 matchers */
"ip4.saddr"     { return MATCHER_IP4_SADDR; }
"ip4.daddr"     { return MATCHER_IP4_DADDR; }
"ip4.snet"      { return MATCHER_IP4_SNET; }
"ip4.dnet"      { return MATCHER_IP4_DNET; }
"ip4.proto"     { return MATCHER_IP4_PROTO; }
"ip4.ttl"       { return MATCHER_IP4_TTL; }    // 新增
```

### 步骤 3: 在 Parser 中定义 Token

**文件：** [src/bfcli/parser.y](../src/bfcli/parser.y)

在 token 定义部分添加：

```c
/* IPv4 matchers */
%token MATCHER_IP4_SADDR
%token MATCHER_IP4_DADDR
%token MATCHER_IP4_SNET
%token MATCHER_IP4_DNET
%token MATCHER_IP4_PROTO
%token MATCHER_IP4_TTL        /* 新增 */
```

### 步骤 4: 添加语法规则

**文件：** [src/bfcli/parser.y](../src/bfcli/parser.y)

找到 `ip4_matcher` 规则（或 `matcher` 规则，取决于实际代码结构），添加新的产生式：

```c
ip4_matcher:
    MATCHER_IP4_SADDR ip4_addr {
        $$ = bf_matcher_new_ip4_saddr($2);
    }
    | MATCHER_IP4_DADDR ip4_addr {
        $$ = bf_matcher_new_ip4_daddr($2);
    }
    /* ... 其他 IP 匹配器 ... */
    | MATCHER_IP4_TTL NUMBER {              // 新增
        if ($2 < 0 || $2 > 255) {
            yyerror("TTL must be between 0 and 255");
            YYERROR;
        }
        $$ = bf_matcher_new_ip4_ttl($2);
    }
    ;
```

### 步骤 5: 实现构造函数

**文件：** [src/libbpfilter/matcher.c](../src/libbpfilter/matcher.c)

添加构造函数实现：

```c
/**
 * Create a new IPv4 TTL matcher.
 *
 * @param ttl TTL value to match (0-255)
 * @return Pointer to new matcher, or NULL on error
 */
struct bf_matcher *bf_matcher_new_ip4_ttl(uint8_t ttl)
{
    struct bf_matcher *matcher;

    matcher = malloc(sizeof(*matcher));
    if (!matcher)
        return NULL;

    matcher->type = BF_MATCHER_IP4_TTL;
    matcher->payload.ttl = ttl;

    return matcher;
}
```

在头文件中声明函数：

**文件：** [src/libbpfilter/include/bpfilter/matcher.h](../src/libbpfilter/include/bpfilter/matcher.h)

```c
/* Constructor declarations */
struct bf_matcher *bf_matcher_new_ip4_saddr(uint32_t addr);
struct bf_matcher *bf_matcher_new_ip4_daddr(uint32_t addr);
struct bf_matcher *bf_matcher_new_ip4_ttl(uint8_t ttl);  // 新增
/* ... */
```

### 步骤 6: 实现序列化（Pretty Print）

**文件：** [src/bfcli/helper.c](../src/bfcli/helper.c)（或类似的文件）

添加打印逻辑，使 `bfcli ruleset get` 能够显示 TTL 匹配器：

```c
static void print_matcher(const struct bf_matcher *matcher)
{
    switch (matcher->type) {
    case BF_MATCHER_IP4_SADDR:
        printf("ip4.saddr %s", ipv4_to_string(matcher->payload.ip4_addr));
        break;
    case BF_MATCHER_IP4_DADDR:
        printf("ip4.daddr %s", ipv4_to_string(matcher->payload.ip4_addr));
        break;
    case BF_MATCHER_IP4_TTL:            // 新增
        printf("ip4.ttl %u", matcher->payload.ttl);
        break;
    /* ... 其他匹配器 ... */
    default:
        printf("<unknown matcher>");
    }
}
```

### 步骤 7: 实现 BPF 代码生成（Phase 3 内容）

**注意：** 这部分在 Phase 3 深入学习，这里只是占位符。

**文件：** [src/bpfilter/cgen/matcher/ip4_ttl.c](../src/bpfilter/cgen/matcher/ip4_ttl.c)（新建）

```c
#include "bpfilter/cgen/matcher/ip4_ttl.h"
#include "bpfilter/cgen/program.h"

/**
 * Generate BPF code to match IPv4 TTL field.
 *
 * @param program BPF program builder
 * @param matcher Matcher containing TTL value
 * @return 0 on success, negative errno on error
 */
int bf_codegen_ip4_ttl(struct bf_program *program,
                        const struct bf_matcher *matcher)
{
    uint8_t ttl = matcher->payload.ttl;

    /*
     * BPF code pseudo:
     * 1. Load TTL field from IP header (offset 8)
     * 2. Compare with expected value
     * 3. Jump if not equal
     */

    // TODO: 在 Phase 3 实现

    return 0;
}
```

### 步骤 8: 编译和测试

```bash
# 重新编译
make -C build clean
make -C build

# 测试解析
sudo build/output/sbin/bfcli ruleset set --from-str \
  "chain test BF_HOOK_NF_LOCAL_IN ACCEPT
     rule ip4.ttl 64 ACCEPT"

# 查看规则（验证打印功能）
sudo build/output/sbin/bfcli ruleset get

# 预期输出：
# chain test BF_HOOK_NF_LOCAL_IN ACCEPT
#   rule ip4.ttl 64 ACCEPT
```

---

## 🔍 调试步骤

### 调试 Lexer

验证 token 是否正确生成：

```bash
# 方法 1：添加调试打印
# 在 lexer.l 中修改：
"ip4.ttl" {
    fprintf(stderr, "DEBUG: Matched MATCHER_IP4_TTL\n");
    return MATCHER_IP4_TTL;
}

# 重新编译并测试
make -C build
sudo build/output/sbin/bfcli ruleset set --from-str "chain test BF_HOOK_NF_LOCAL_IN ACCEPT rule ip4.ttl 64 ACCEPT"
```

### 调试 Parser

使用 GDB 追踪解析过程：

```bash
# 编译 debug 版本
cmake -S . -B build -DCMAKE_BUILD_TYPE=debug
make -C build

# 启动 GDB
gdb build/output/sbin/bfcli

# 设置断点
(gdb) break yyparse
(gdb) break bf_matcher_new_ip4_ttl

# 运行
(gdb) run ruleset set --from-str "chain test BF_HOOK_NF_LOCAL_IN ACCEPT rule ip4.ttl 64 ACCEPT"

# 单步执行
(gdb) step

# 查看变量
(gdb) print matcher->type
(gdb) print matcher->payload.ttl
```

### 验证内存管理

使用 Valgrind 检查内存泄漏：

```bash
sudo valgrind --leak-check=full \
  build/output/sbin/bfcli ruleset set --from-str \
  "chain test BF_HOOK_NF_LOCAL_IN ACCEPT rule ip4.ttl 64 ACCEPT"
```

---

## 🧪 测试用例

### 基础测试

```bash
# 测试 1：单个 TTL 匹配器
sudo build/output/sbin/bfcli ruleset set --from-str \
  "chain test BF_HOOK_NF_LOCAL_IN ACCEPT
     rule ip4.ttl 64 ACCEPT"

# 测试 2：TTL + 其他匹配器
sudo build/output/sbin/bfcli ruleset set --from-str \
  "chain test BF_HOOK_NF_LOCAL_IN ACCEPT
     rule ip4.saddr 192.168.1.100 ip4.ttl 64 counter DROP"

# 测试 3：多个规则
sudo build/output/sbin/bfcli ruleset set --from-str \
  "chain test BF_HOOK_NF_LOCAL_IN ACCEPT
     rule ip4.ttl 64 ACCEPT
     rule ip4.ttl 128 ACCEPT
     rule ip4.ttl 255 DROP"
```

### 错误处理测试

```bash
# 测试 4：无效的 TTL 值（应该报错）
sudo build/output/sbin/bfcli ruleset set --from-str \
  "chain test BF_HOOK_NF_LOCAL_IN ACCEPT
     rule ip4.ttl 256 ACCEPT"
# 预期输出：Parse error: TTL must be between 0 and 255

# 测试 5：负数（应该报错）
sudo build/output/sbin/bfcli ruleset set --from-str \
  "chain test BF_HOOK_NF_LOCAL_IN ACCEPT
     rule ip4.ttl -1 ACCEPT"
```

### 序列化测试

```bash
# 测试 6：验证 pretty print
sudo build/output/sbin/bfcli ruleset set --from-str \
  "chain test BF_HOOK_NF_LOCAL_IN ACCEPT
     rule ip4.ttl 64 counter ACCEPT"

sudo build/output/sbin/bfcli ruleset get

# 预期输出应包含：
# rule ip4.ttl 64 counter(packets: 0, bytes: 0) ACCEPT
```

---

## 🎯 挑战任务

完成基础实现后，尝试以下挑战：

### 挑战 1：支持 TTL 范围匹配

添加语法支持 TTL 范围：

```
rule ip4.ttl 64-128 ACCEPT
```

提示：
1. 修改 `struct bf_matcher` 添加 `ttl_min` 和 `ttl_max`
2. 在 lexer.l 中识别 `-` 符号
3. 在 parser.y 中添加范围语法

### 挑战 2：支持 IPv6 Hop Limit

IPv6 的 Hop Limit 字段等同于 IPv4 的 TTL。添加 `ip6.hlimit` 匹配器。

提示：
- 遵循相同的步骤
- 注意 IPv6 头部结构的不同

### 挑战 3：添加单元测试

**文件：** `tests/unit/test_matcher_ttl.c`（新建）

```c
#include <stdarg.h>
#include <stddef.h>
#include <setjmp.h>
#include <cmocka.h>

#include "bpfilter/matcher.h"

/* Test: Create TTL matcher */
static void test_matcher_ttl_create(void **state)
{
    struct bf_matcher *matcher;

    matcher = bf_matcher_new_ip4_ttl(64);

    assert_non_null(matcher);
    assert_int_equal(matcher->type, BF_MATCHER_IP4_TTL);
    assert_int_equal(matcher->payload.ttl, 64);

    bf_matcher_free(matcher);
}

/* Test: TTL boundary values */
static void test_matcher_ttl_boundary(void **state)
{
    struct bf_matcher *m1, *m2;

    m1 = bf_matcher_new_ip4_ttl(0);
    assert_non_null(m1);
    assert_int_equal(m1->payload.ttl, 0);
    bf_matcher_free(m1);

    m2 = bf_matcher_new_ip4_ttl(255);
    assert_non_null(m2);
    assert_int_equal(m2->payload.ttl, 255);
    bf_matcher_free(m2);
}

int main(void)
{
    const struct CMUnitTest tests[] = {
        cmocka_unit_test(test_matcher_ttl_create),
        cmocka_unit_test(test_matcher_ttl_boundary),
    };

    return cmocka_run_group_tests(tests, NULL, NULL);
}
```

编译并运行测试：

```bash
# 添加到 tests/unit/CMakeLists.txt
# add_executable(test_matcher_ttl test_matcher_ttl.c)
# target_link_libraries(test_matcher_ttl libbpfilter cmocka)

# 编译并运行
make -C build
make -C build unit
```

---

## 📊 检查清单

完成项目后，确认以下内容：

- [ ] 在 `matcher.h` 中定义了 `BF_MATCHER_IP4_TTL` 类型
- [ ] 在 `struct bf_matcher` 的 payload 中添加了 `ttl` 字段
- [ ] 在 `lexer.l` 中添加了 `"ip4.ttl"` token
- [ ] 在 `parser.y` 中定义了 `MATCHER_IP4_TTL` token
- [ ] 在 `parser.y` 中添加了语法规则
- [ ] 实现了 `bf_matcher_new_ip4_ttl()` 函数
- [ ] 实现了打印（pretty print）功能
- [ ] 代码能够编译通过
- [ ] 基础测试全部通过
- [ ] 使用 GDB 追踪过解析流程
- [ ] 使用 Valgrind 检查过内存泄漏

---

## 🎓 学到了什么

通过这个项目，你应该已经掌握：

1. **Lexer 工作原理**
   - 如何定义新的 token
   - 正则表达式的使用

2. **Parser 工作原理**
   - 如何定义语法规则
   - 如何处理语义值（`$$`, `$1`, `$2`）
   - 错误处理

3. **数据结构设计**
   - 如何扩展 `struct bf_matcher`
   - 使用联合体（union）节省内存

4. **代码组织**
   - 头文件和实现文件的分离
   - API 设计

5. **调试技能**
   - 使用 GDB 调试 Parser
   - 使用 Valgrind 检查内存

---

## 📚 相关文件

本项目涉及的所有文件：

- [src/libbpfilter/include/bpfilter/matcher.h](../src/libbpfilter/include/bpfilter/matcher.h)
- [src/libbpfilter/matcher.c](../src/libbpfilter/matcher.c)
- [src/bfcli/lexer.l](../src/bfcli/lexer.l)
- [src/bfcli/parser.y](../src/bfcli/parser.y)
- [src/bfcli/helper.c](../src/bfcli/helper.c)

---

## 🚀 下一步

完成本项目后，你可以：

1. 继续阅读 [debug_parser.md](debug_parser.md) 学习更多调试技巧
2. 尝试添加更多匹配器（如 `tcp.flags`, `udp.len` 等）
3. 进入 [Phase 2: 内部数据结构](02_data_structures.md)

恭喜你完成第一个实践项目！🎉
