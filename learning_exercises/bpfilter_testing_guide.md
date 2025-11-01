# bpfilter 测试体系学习指南

## 概述

bpfilter 采用了一套完整的多层次测试体系，确保代码质量和功能正确性。测试框架基于 CMocka 构建，包含单元测试、端到端测试、集成测试和代码规范测试。

## 测试架构

### 测试目录结构

```
tests/
├── CMakeLists.txt          # 测试总入口
├── harness/                # 测试框架和工具
│   ├── test.h/c           # 测试框架核心
│   ├── mock.h/c           # Mock 功能
│   ├── filters.h/c        # 测试辅助函数
│   ├── daemon.h/c         # 守护进程测试支持
│   ├── prog.h/c           # BPF 程序测试支持
│   └── process.h/c        # 进程管理
├── unit/                   # 单元测试
│   ├── main.c             # 单元测试入口
│   ├── mock.c/h           # Mock 实现
│   ├── fake.c/h           # 假对象
│   ├── libbpfilter/       # libbpfilter 库测试
│   └── bpfilter/          # bpfilter 核心测试
├── e2e/                    # 端到端测试
│   ├── main.c             # E2E 测试入口
│   ├── e2e.c/h            # E2E 测试框架
│   ├── genpkts.py         # 测试数据包生成器
│   ├── cli.sh             # CLI 集成测试脚本
│   └── rulesets/          # 测试规则集
├── pedantic/               # 代码规范测试
│   ├── pedantic.c         # C 标准测试
│   └── pedantic.cpp       # C++ 兼容性测试
└── integration/            # 集成测试
    ├── iptables/          # iptables 集成
    └── nftables/          # nftables 集成
```

## 一、测试框架核心 (harness)

### 1.1 测试定义宏 `Test()`

bpfilter 使用自定义的 `Test()` 宏来定义测试用例：

```c
Test(group, name)
{
    // 测试代码
}
```

**工作原理：**
- 测试被存储在 ELF 文件的特殊段 `bf_test` 中
- 运行时通过符号 `__start_bf_test` 和 `__stop_bf_test` 自动发现所有测试
- 测试按组（group）组织，便于过滤和管理

**示例：**

```c
Test(list, new_and_free)
{
    bf_list *l = NULL;
    bf_list_ops free_ops = bf_list_ops_default(freep, NULL);

    // 测试 NULL 参数断言
    expect_assert_failure(bf_list_new(NULL, NOT_NULL));
    expect_assert_failure(bf_list_free(NULL));

    // 测试正常功能
    assert_success(bf_list_new(&l, NULL));
    assert_int_equal(0, l->len);
    assert_null(l->head);
    
    bf_list_free(&l);
    assert_null(l);
}
```

### 1.2 断言宏

bpfilter 扩展了 CMocka 的断言功能：

```c
// 成功/失败断言
assert_success(x)      // 断言 x 返回 0
assert_error(x)        // 断言 x 返回 < 0

// 参数验证
expect_assert_failure(func(NULL, ...))  // 期望断言失败

// CMocka 标准断言
assert_int_equal(expected, actual)
assert_non_null(ptr)
assert_null(ptr)
assert_true(condition)
assert_false(condition)
```

### 1.3 Mock 系统

Mock 系统允许替换函数实现，用于：
- 模拟系统调用失败
- 避免需要特权的操作
- 控制测试环境

**定义 Mock：**

```c
// 在 mock.h 中声明
bf_test_mock_declare(void *, malloc, (size_t size));

// 在 mock.c 中实现
bf_test_mock_define(void *, malloc, (size_t size))
{
    if (bf_test_mock_malloc_is_enabled())
        return mock_ptr_type(void *);
    return __real_malloc(size);
}
```

**使用 Mock：**

```c
Test(example, malloc_failure)
{
    // 创建 mock，让 malloc 返回 NULL
    _clean_bf_test_mock_ bf_test_mock _ = bf_test_mock_get(malloc, NULL);
    
    // 测试 malloc 失败的情况
    assert_error(some_function_that_uses_malloc());
}
```

**Mock 配置（CMakeLists.txt）：**

```cmake
bf_test_mock(unit_bin
    FUNCTIONS
        malloc
        calloc
        open
        read
        write
)
```

这会使用 `ld --wrap` 选项在链接时替换符号。

## 二、单元测试 (unit)

### 2.1 单元测试结构

单元测试直接包含源文件进行白盒测试：

```c
// tests/unit/libbpfilter/list.c
#include "libbpfilter/list.c"  // 直接包含源文件

#include "harness/test.h"
#include "harness/filters.h"
#include "mock.h"

Test(list, fill_from_head_and_check)
{
    bf_list_ops free_ops = bf_list_ops_default(freep, NULL);
    bf_list list;
    size_t i;

    // 参数验证测试
    expect_assert_failure(bf_list_size(NULL));
    expect_assert_failure(bf_list_get_head(NULL));

    bf_list_init(&list, &free_ops);

    // 填充列表
    init_and_fill(&list, 10, &free_ops, dummy_filler_head);

    // 验证内容
    i = bf_list_size(&list);
    bf_list_foreach (&list, it) {
        assert_non_null(it);
        assert_int_equal(i, *(int *)bf_list_node_get_data(it));
        --i;
    }

    bf_list_clean(&list);
}
```

### 2.2 测试组织

单元测试按模块组织：

```
unit/
├── libbpfilter/        # 核心库测试
│   ├── list.c         # 链表测试
│   ├── chain.c        # 链测试
│   ├── matcher.c      # 匹配器测试
│   └── ...
└── bpfilter/          # 主程序测试
    ├── cgen/          # 代码生成测试
    └── xlate/         # 转换层测试
```

### 2.3 运行单元测试

```bash
# 构建并运行所有单元测试
cmake --build build -- unit

# 运行特定测试组
./build/tests/unit/unit_bin --group "list"
```

### 2.4 代码覆盖率

单元测试自动生成代码覆盖率报告：

```cmake
# CMakeLists.txt 中的配置
set_source_files_properties(${bf_test_srcs}
    PROPERTIES
        COMPILE_OPTIONS "-ftest-coverage;-fprofile-arcs;-fprofile-abs-path"
)

# 生成 lcov 报告
add_custom_command(TARGET unit POST_BUILD
    COMMAND ${LCOV_BIN} --capture --directory ${CMAKE_BINARY_DIR}
            --output-file ${CMAKE_CURRENT_BINARY_DIR}/lcov.out
)
```

报告位置：`build/output/tests/lcov.out`

## 三、端到端测试 (e2e)

### 3.1 E2E 测试概述

端到端测试验证完整的数据包处理流程：
1. 生成 BPF 程序
2. 加载到内核
3. 使用真实数据包测试
4. 验证结果和计数器

### 3.2 测试数据包生成

使用 Python 脚本生成测试数据包：

```python
# tests/e2e/genpkts.py
# 生成各种协议的测试数据包
- IPv4/IPv6 数据包
- TCP/UDP/ICMP 数据包
- 带扩展头的 IPv6 数据包
- 各种网络场景
```

生成的头文件：`build/tests/e2e/include/packets.h`

### 3.3 E2E 测试示例

```c
Test(ip4, saddr)
{
    // 创建匹配源地址的链
    _free_bf_chain_ struct bf_chain *match_eq_pkt = bf_test_chain_get(
        BF_HOOK_XDP,
        BF_VERDICT_ACCEPT,
        NULL,
        (struct bf_rule *[]) {
            bf_rule_get(
                0,
                false,
                BF_VERDICT_DROP,
                (struct bf_matcher *[]) {
                    bf_matcher_get(BF_MATCHER_IP4_SADDR, BF_MATCHER_EQ,
                        (uint8_t[]) {
                            0x7f, 0x02, 0x0a, 0x0a  // 127.2.10.10
                        },
                        4
                    ),
                    NULL,
                }
            ),
            NULL,
        }
    );

    // 测试：数据包应该被 DROP
    bft_e2e_test(match_eq_pkt, BF_VERDICT_DROP, pkt_local_ip4);
}
```

### 3.4 计数器测试

```c
Test(counters, packet_size)
{
    _free_bf_chain_ struct bf_chain *chain = bf_test_chain_get(
        BF_HOOK_XDP, BF_VERDICT_ACCEPT, NULL,
        (struct bf_rule *[]) {
            bf_rule_get(0, true, BF_VERDICT_ACCEPT,
                (struct bf_matcher *[]) {
                    bf_matcher_get(BF_MATCHER_IP4_SADDR, BF_MATCHER_EQ,
                                   (uint8_t[]) { 127, 2, 10, 10 }, 4),
                    NULL,
                }),
            NULL,
        });

    // 验证计数器：规则索引 0，1 个包，正确的字节数
    bft_e2e_test_with_counter(chain, BF_VERDICT_ACCEPT, pkt_local_ip4,
                              bft_counter_p(0, 1, pkt_local_ip4[0].pkt_len));
}
```

### 3.5 运行 E2E 测试

```bash
# 需要 root 权限
cmake --build build -- e2e

# 或手动运行
sudo ./build/tests/e2e/e2e_bin --bpfilter ./build/src/bpfilter/bpfilter
```

## 四、CLI 集成测试

### 4.1 测试脚本结构

`tests/e2e/cli.sh` 是一个完整的 Bash 测试套件：

```bash
#!/usr/bin/env bash

# 1. 设置网络命名空间
setup() {
    ip netns add ${NETNS_NAME}
    ip link add ${VETH_HOST} type veth peer name ${VETH_NS}
    ip link set ${VETH_NS} netns ${NETNS_NAME}
    # ...
}

# 2. 定义测试辅助函数
expect_success() {
    local description="$1"
    shift
    if "$@"; then
        echo -e "${GREEN}[+] Success: ${description}${RESET}"
    else
        echo -e "${RED}[-] Failure: ${description}${RESET}"
        RETURN_VALUE=1
    fi
}

# 3. 测试套件
suite_chain_load() {
    log "[SUITE] chain: load"
    
    expect_success "load a valid chain" \
        ${BFCLI} chain load --from-str "chain test BF_HOOK_XDP ACCEPT"
    
    expect_failure "load with invalid syntax" \
        ${BFCLI} chain load --from-str "invalid"
}
```

### 4.2 测试场景

CLI 测试覆盖：
- **链管理**：load, get, flush, attach, detach, update
- **规则集管理**：set, get, flush
- **守护进程**：启动、停止、恢复
- **网络功能**：XDP、TC、cgroup、Netfilter 钩子
- **实际流量**：使用 ping 测试真实数据包过滤

### 4.3 测试示例

```bash
suite_chain_attach() {
    log "[SUITE] chain: attach"
    
    # 加载 XDP 链
    expect_success "load chain" \
        ${BFCLI} chain load --from-str \
        "chain test BF_HOOK_XDP ACCEPT rule ip4.proto icmp DROP"
    
    # 附加到接口
    expect_success "attach chain" \
        ${BFCLI} chain attach --name test --option ifindex=${NS_IFINDEX}
    
    # 验证：ping 应该失败（ICMP 被阻止）
    expect_failure "pings are blocked" \
        ping -c 1 -W 0.25 ${NS_IP_ADDR}
    
    # 清理
    expect_success "flush chain" \
        ${BFCLI} chain flush --name test
}
```

## 五、代码规范测试 (pedantic)

### 5.1 目的

确保头文件可以：
- 在严格的 C17 标准下编译
- 在 C++17 环境中使用（C++ 兼容性）

### 5.2 实现

```c
// tests/pedantic/pedantic.c
#include <bpfilter/bpf.h>
#include <bpfilter/chain.h>
#include <bpfilter/counter.h>
// ... 包含所有公共头文件

int main(void)
{
    return 0;
}
```

```cmake
# tests/pedantic/CMakeLists.txt
add_executable(pedantic_c EXCLUDE_FROM_ALL pedantic.c)
target_compile_options(pedantic_c PRIVATE -pedantic-errors -std=c17)

add_executable(pedantic_cpp EXCLUDE_FROM_ALL pedantic.cpp)
target_compile_options(pedantic_cpp PRIVATE -pedantic-errors -std=c++17)
```

如果编译成功，说明头文件符合标准。

## 六、测试最佳实践

### 6.1 测试命名规范

```c
// 格式：Test(模块名, 功能描述)
Test(list, new_and_free)           // 测试创建和释放
Test(list, fill_from_head_and_check)  // 测试从头部填充
Test(ip4, saddr)                   // 测试 IPv4 源地址匹配
Test(counters, update_partially_disabled)  // 测试部分禁用的计数器
```

### 6.2 资源管理

使用 cleanup 属性自动释放资源：

```c
Test(example, cleanup_demo)
{
    // 自动清理的变量
    _free_bf_chain_ struct bf_chain *chain = ...;
    _free_bf_list_ bf_list *list = NULL;
    _cleanup_free_ char *str = malloc(100);
    _clean_bf_test_mock_ bf_test_mock mock = bf_test_mock_get(malloc, NULL);
    
    // 函数返回时自动调用清理函数
}
```

### 6.3 测试结构

```c
Test(module, feature)
{
    // 1. 参数验证测试
    expect_assert_failure(function(NULL, ...));
    expect_assert_failure(function(..., NULL));
    
    // 2. 正常功能测试
    assert_success(function(valid_args));
    assert_int_equal(expected, actual);
    
    // 3. 边界条件测试
    assert_success(function(edge_case));
    
    // 4. 错误处理测试
    _clean_bf_test_mock_ bf_test_mock _ = bf_test_mock_get(malloc, NULL);
    assert_error(function_that_needs_malloc());
}
```

### 6.4 E2E 测试模式

```c
Test(hook_type, matcher_type)
{
    // 1. 创建测试链
    _free_bf_chain_ struct bf_chain *chain = bf_test_chain_get(
        BF_HOOK_XDP,
        BF_VERDICT_ACCEPT,
        NULL,  // 或 sets
        (struct bf_rule *[]) {
            bf_rule_get(...),
            NULL,
        }
    );
    
    // 2. 执行测试
    bft_e2e_test(chain, expected_verdict, test_packet);
    
    // 3. 如果需要验证计数器
    bft_e2e_test_with_counter(chain, verdict, packet,
                              bft_counter_p(rule_idx, n_pkts, n_bytes));
}
```

## 七、运行测试

### 7.1 运行所有测试

```bash
# 构建并运行完整测试套件
cmake --build build -- test
```

这会依次运行：
1. 单元测试 (unit)
2. 端到端测试 (e2e)
3. 代码规范测试 (pedantic)

### 7.2 运行特定测试

```bash
# 只运行单元测试
cmake --build build -- unit

# 只运行 E2E 测试
cmake --build build -- e2e

# 只运行代码规范测试
cmake --build build -- pedantic

# 运行特定测试组
./build/tests/unit/unit_bin --group "list"
./build/tests/unit/unit_bin --group "matcher"
```

### 7.3 调试测试

```bash
# 使用 gdb 调试单元测试
gdb --args ./build/tests/unit/unit_bin --group "list"

# 使用 gdb 调试 E2E 测试
sudo gdb --args ./build/tests/e2e/e2e_bin \
    --bpfilter ./build/src/bpfilter/bpfilter

# 查看详细输出
./build/tests/unit/unit_bin --group "list" --verbose
```

## 八、测试覆盖率

### 8.1 生成覆盖率报告

```bash
# 运行单元测试（自动生成覆盖率）
cmake --build build -- unit

# 查看覆盖率摘要
lcov --summary build/output/tests/lcov.out

# 生成 HTML 报告
genhtml build/output/tests/lcov.out \
    --output-directory build/output/tests/coverage
```

### 8.2 查看覆盖率

```bash
# 在浏览器中打开
firefox build/output/tests/coverage/index.html
```

## 九、添加新测试

### 9.1 添加单元测试

1. 在 `tests/unit/` 下创建测试文件
2. 包含要测试的源文件
3. 编写测试用例
4. 更新 `CMakeLists.txt`

```c
// tests/unit/libbpfilter/mymodule.c
#include "libbpfilter/mymodule.c"
#include "harness/test.h"

Test(mymodule, basic_functionality)
{
    // 测试代码
}

Test(mymodule, error_handling)
{
    // 测试代码
}
```

```cmake
# tests/unit/CMakeLists.txt
set(bf_test_srcs
    # ... 现有文件
    libbpfilter/mymodule.c
)
```

### 9.2 添加 E2E 测试

在 `tests/e2e/main.c` 中添加测试：

```c
Test(new_feature, test_case)
{
    _free_bf_chain_ struct bf_chain *chain = bf_test_chain_get(
        BF_HOOK_XDP,
        BF_VERDICT_ACCEPT,
        NULL,
        (struct bf_rule *[]) {
            // 规则定义
            NULL,
        }
    );
    
    bft_e2e_test(chain, expected_verdict, test_packet);
}
```

### 9.3 添加 CLI 测试

在 `tests/e2e/cli.sh` 中添加测试套件：

```bash
suite_new_feature() {
    log "[SUITE] new_feature: description"
    
    expect_success "test case 1" \
        ${BFCLI} command --args
    
    expect_failure "test case 2" \
        ${BFCLI} invalid_command
}
with_daemon suite_new_feature
```

## 十、测试工具和辅助函数

### 10.1 测试辅助函数

```c
// harness/filters.h 提供的辅助函数

// 创建测试链
struct bf_chain *bf_test_chain_get(
    enum bf_hook hook,
    enum bf_verdict policy,
    struct bf_set **sets,
    struct bf_rule **rules
);

// 创建测试规则
struct bf_rule *bf_rule_get(
    uint32_t index,
    bool counters,
    enum bf_verdict verdict,
    struct bf_matcher **matchers
);

// 创建测试匹配器
struct bf_matcher *bf_matcher_get(
    enum bf_matcher_type type,
    enum bf_matcher_op op,
    const void *payload,
    size_t payload_len
);
```

### 10.2 临时文件管理

```c
// 创建临时文件用于序列化测试
_free_tmp_file_ char *path = bf_test_filepath_new_rw();

// 使用文件
FILE *f = fopen(path, "w");
// ...
fclose(f);

// 自动清理
```

## 总结

bpfilter 的测试体系特点：

1. **多层次覆盖**：从单元测试到集成测试，全面覆盖
2. **自动化**：测试发现、执行、覆盖率报告全自动
3. **Mock 系统**：灵活的函数替换机制
4. **真实环境**：E2E 测试使用真实的 BPF 程序和数据包
5. **CI 友好**：所有测试可以在 CI 环境中自动运行
6. **代码质量**：通过 pedantic 测试确保代码标准合规

这套测试体系确保了 bpfilter 的高质量和可靠性。
