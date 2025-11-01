# bpfilter 测试快速参考

## 快速命令

```bash
# 运行所有测试
cmake --build build -- test

# 单独运行各类测试
cmake --build build -- unit      # 单元测试
cmake --build build -- e2e       # 端到端测试
cmake --build build -- pedantic  # 代码规范测试

# 运行特定测试组
./build/tests/unit/unit_bin --group "list"
./build/tests/unit/unit_bin --group "matcher"

# 查看代码覆盖率
lcov --summary build/output/tests/lcov.out
genhtml build/output/tests/lcov.out -o build/output/tests/coverage
```

## 测试类型速查

| 测试类型 | 位置 | 目的 | 运行方式 |
|---------|------|------|---------|
| **单元测试** | `tests/unit/` | 测试单个函数/模块 | `make unit` |
| **E2E 测试** | `tests/e2e/` | 测试完整数据包处理 | `make e2e` (需要 root) |
| **CLI 测试** | `tests/e2e/cli.sh` | 测试命令行工具 | 由 `make e2e` 调用 |
| **代码规范** | `tests/pedantic/` | 验证标准合规性 | `make pedantic` |
| **集成测试** | `tests/integration/` | 与 iptables/nftables 集成 | 手动运行 |

## 常用测试宏

### 断言

```c
assert_success(expr)              // 期望返回 0
assert_error(expr)                // 期望返回 < 0
assert_int_equal(expected, actual)
assert_non_null(ptr)
assert_null(ptr)
assert_true(condition)
assert_false(condition)
expect_assert_failure(expr)       // 期望触发断言
```

### 资源管理

```c
_free_bf_chain_ struct bf_chain *chain = ...;
_free_bf_list_ bf_list *list = NULL;
_cleanup_free_ char *str = malloc(100);
_clean_bf_test_mock_ bf_test_mock mock = ...;
```

## 测试模板

### 单元测试模板

```c
#include "libbpfilter/module.c"
#include "harness/test.h"

Test(module, feature)
{
    // 1. 参数验证
    expect_assert_failure(function(NULL));
    
    // 2. 正常功能
    assert_success(function(valid_args));
    
    // 3. 错误处理
    _clean_bf_test_mock_ bf_test_mock _ = bf_test_mock_get(malloc, NULL);
    assert_error(function_needs_malloc());
}
```

### E2E 测试模板

```c
Test(hook, matcher)
{
    _free_bf_chain_ struct bf_chain *chain = bf_test_chain_get(
        BF_HOOK_XDP,
        BF_VERDICT_ACCEPT,
        NULL,
        (struct bf_rule *[]) {
            bf_rule_get(0, false, BF_VERDICT_DROP,
                (struct bf_matcher *[]) {
                    bf_matcher_get(BF_MATCHER_IP4_SADDR, BF_MATCHER_EQ,
                                   (uint8_t[]) { 127, 0, 0, 1 }, 4),
                    NULL,
                }),
            NULL,
        }
    );
    
    bft_e2e_test(chain, BF_VERDICT_DROP, pkt_local_ip4);
}
```

### Mock 使用模板

```c
Test(module, malloc_failure)
{
    // 方法 1：简单 mock
    _clean_bf_test_mock_ bf_test_mock _ = bf_test_mock_get(malloc, NULL);
    assert_error(function_that_needs_malloc());
    
    // 方法 2：多次返回
    _clean_bf_test_mock_ bf_test_mock m = bf_test_mock_empty(malloc);
    bf_test_mock_will_return(m, NULL);      // 第一次返回 NULL
    bf_test_mock_will_return(m, (void*)1);  // 第二次返回非 NULL
    
    // 方法 3：总是返回
    _clean_bf_test_mock_ bf_test_mock m = bf_test_mock_empty(malloc);
    bf_test_mock_will_return_always(m, NULL);  // 总是返回 NULL
}
```

## 测试数据包

E2E 测试中可用的预定义数据包：

```c
pkt_local_ip4           // 本地 IPv4 数据包
pkt_local_ip4_icmp      // 本地 IPv4 ICMP 数据包
pkt_local_ip6_tcp       // 本地 IPv6 TCP 数据包
pkt_remote_ip6_tcp      // 远程 IPv6 TCP 数据包
pkt_remote_ip6_eh_tcp   // 带扩展头的 IPv6 TCP 数据包
pkt_local_ip6_hop       // 带 Hop-by-Hop 的 IPv6 数据包
```

## 调试技巧

### 1. 运行单个测试

```bash
# 使用 gdb
gdb --args ./build/tests/unit/unit_bin --group "list"

# 设置断点
(gdb) break bf_list_new
(gdb) run
```

### 2. 查看测试输出

```bash
# 详细输出
./build/tests/unit/unit_bin --group "list" 2>&1 | less

# 只看失败的测试
./build/tests/unit/unit_bin 2>&1 | grep -A 10 "FAILED"
```

### 3. E2E 测试调试

```bash
# 查看 bpfilter 日志
sudo ./build/tests/e2e/e2e_bin --bpfilter ./build/src/bpfilter/bpfilter 2>&1 | tee e2e.log

# 使用 bpftool 检查 BPF 程序
sudo bpftool prog list
sudo bpftool prog dump xlated id <ID>
```

### 4. CLI 测试调试

```bash
# 启用早期退出（遇到第一个失败就停止）
./tests/e2e/cli.sh --early-exit

# 手动运行单个测试套件
# 编辑 cli.sh，注释掉其他测试，只保留要调试的
```

## 常见问题

### Q: 单元测试编译失败

**A:** 检查是否在 `CMakeLists.txt` 中添加了测试文件：

```cmake
set(bf_test_srcs
    libbpfilter/mymodule.c  # 添加这一行
)
```

### Q: E2E 测试需要 root 权限

**A:** E2E 测试需要加载 BPF 程序，必须使用 sudo：

```bash
sudo cmake --build build -- e2e
```

### Q: Mock 不工作

**A:** 确保在 `CMakeLists.txt` 中配置了 mock：

```cmake
bf_test_mock(unit_bin
    FUNCTIONS
        your_function
)
```

### Q: 测试发现不了新测试

**A:** 确保使用了 `Test()` 宏，并且重新编译：

```bash
rm -rf build/tests/unit
cmake --build build -- unit
```

## 测试覆盖率目标

bpfilter 项目的覆盖率目标：

- **核心库 (libbpfilter)**：> 90%
- **代码生成 (cgen)**：> 85%
- **转换层 (xlate)**：> 80%
- **整体**：> 85%

## 添加新测试检查清单

- [ ] 测试文件已创建
- [ ] 已添加到 `CMakeLists.txt`
- [ ] 测试编译通过
- [ ] 测试运行通过
- [ ] 代码覆盖率增加
- [ ] 测试命名清晰
- [ ] 包含边界条件测试
- [ ] 包含错误处理测试
- [ ] 资源正确清理

## 参考资源

- **CMocka 文档**: https://cmocka.org/
- **测试框架源码**: `tests/harness/test.h`
- **Mock 系统**: `tests/harness/mock.h`
- **测试示例**: `tests/unit/libbpfilter/list.c`
- **E2E 示例**: `tests/e2e/main.c`
