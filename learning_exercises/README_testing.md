# bpfilter 测试文档索引

本目录包含 bpfilter 测试体系的完整学习资料。

## 📚 文档列表

### 1. [bpfilter_testing_guide.md](./bpfilter_testing_guide.md) - 完整测试指南
**适合：** 想要深入了解测试体系的开发者

**内容：**
- 测试架构详解
- 测试框架核心 (harness)
- 单元测试详解
- 端到端测试详解
- CLI 集成测试
- 代码规范测试
- 测试最佳实践
- 运行和调试测试
- 添加新测试

**阅读时间：** 30-45 分钟

---

### 2. [testing_quick_reference.md](./testing_quick_reference.md) - 快速参考手册
**适合：** 需要快速查找命令和示例的开发者

**内容：**
- 常用命令速查
- 测试类型对照表
- 断言宏参考
- 测试模板
- 调试技巧
- 常见问题解答

**阅读时间：** 5-10 分钟

---

### 3. [testing_architecture.md](./testing_architecture.md) - 架构图解
**适合：** 想要理解测试系统设计的开发者

**内容：**
- 整体测试架构图
- 测试框架层次结构
- 执行流程图
- Mock 系统原理
- 测试发现机制
- 代码覆盖率流程
- 网络拓扑图

**阅读时间：** 15-20 分钟

---

## 🚀 快速开始

### 第一次使用？从这里开始：

1. **快速了解**（5分钟）
   ```bash
   # 阅读快速参考
   cat testing_quick_reference.md
   
   # 运行第一个测试
   cmake --build build -- unit
   ```

2. **深入学习**（30分钟）
   ```bash
   # 阅读完整指南
   cat bpfilter_testing_guide.md
   
   # 尝试不同类型的测试
   cmake --build build -- unit
   sudo cmake --build build -- e2e
   ```

3. **理解架构**（15分钟）
   ```bash
   # 阅读架构文档
   cat testing_architecture.md
   
   # 查看测试代码
   less ../tests/unit/libbpfilter/list.c
   less ../tests/e2e/main.c
   ```

---

## 📖 学习路径

### 路径 1：快速上手（适合赶时间的开发者）
```
testing_quick_reference.md
    ↓
运行几个测试命令
    ↓
开始写测试
```

### 路径 2：系统学习（推荐）
```
bpfilter_testing_guide.md (概述部分)
    ↓
testing_architecture.md (理解架构)
    ↓
bpfilter_testing_guide.md (详细阅读)
    ↓
testing_quick_reference.md (作为参考)
    ↓
实践：添加自己的测试
```

### 路径 3：问题驱动（遇到问题时）
```
遇到问题
    ↓
testing_quick_reference.md (查找常见问题)
    ↓
bpfilter_testing_guide.md (查找详细说明)
    ↓
testing_architecture.md (理解底层原理)
```

---

## 🎯 按需求查找

### 我想要...

#### 运行测试
→ `testing_quick_reference.md` - "快速命令" 部分

#### 理解测试框架
→ `testing_architecture.md` - "测试框架层次结构"

#### 写单元测试
→ `bpfilter_testing_guide.md` - "二、单元测试" 部分
→ `testing_quick_reference.md` - "单元测试模板"

#### 写 E2E 测试
→ `bpfilter_testing_guide.md` - "三、端到端测试" 部分
→ `testing_quick_reference.md` - "E2E 测试模板"

#### 使用 Mock
→ `bpfilter_testing_guide.md` - "1.3 Mock 系统"
→ `testing_architecture.md` - "Mock 系统工作原理"

#### 调试测试失败
→ `testing_quick_reference.md` - "调试技巧"
→ `bpfilter_testing_guide.md` - "七、运行测试"

#### 查看代码覆盖率
→ `bpfilter_testing_guide.md` - "八、测试覆盖率"
→ `testing_quick_reference.md` - "快速命令"

#### 理解 CLI 测试
→ `bpfilter_testing_guide.md` - "四、CLI 集成测试"
→ `testing_architecture.md` - "CLI 测试网络拓扑"

---

## 💡 实用技巧

### 测试开发工作流

```bash
# 1. 写代码
vim src/libbpfilter/mymodule.c

# 2. 写测试
vim tests/unit/libbpfilter/mymodule.c

# 3. 更新构建配置
vim tests/unit/CMakeLists.txt

# 4. 编译并运行测试
cmake --build build -- unit

# 5. 查看覆盖率
lcov --summary build/output/tests/lcov.out

# 6. 如果测试失败，调试
gdb --args ./build/tests/unit/unit_bin --group "mymodule"
```

### 常用命令组合

```bash
# 快速测试循环
alias test-unit='cmake --build build -- unit'
alias test-e2e='sudo cmake --build build -- e2e'
alias test-all='cmake --build build -- test'

# 查看覆盖率
alias cov='lcov --summary build/output/tests/lcov.out'
alias cov-html='genhtml build/output/tests/lcov.out -o build/coverage && firefox build/coverage/index.html'

# 运行特定测试组
alias test-list='./build/tests/unit/unit_bin --group "list"'
alias test-matcher='./build/tests/unit/unit_bin --group "matcher"'
```

---

## 📊 测试统计

bpfilter 测试覆盖情况：

| 测试类型 | 数量 | 覆盖率目标 |
|---------|------|-----------|
| 单元测试 | 200+ | > 85% |
| E2E 测试 | 100+ | 核心功能 100% |
| CLI 测试 | 50+ | 所有命令 |
| 集成测试 | 若干 | iptables/nftables |

**测试文件统计：**
- 单元测试文件：25+ 个
- E2E 测试用例：100+ 个
- CLI 测试套件：15+ 个
- 测试辅助代码：~3000 行

---

## 🔍 深入主题

### 想深入了解某个主题？

#### CMocka 框架
- 官方文档：https://cmocka.org/
- 本地示例：`tests/unit/libbpfilter/list.c`

#### BPF 测试
- E2E 测试：`tests/e2e/main.c`
- BPF 程序加载：`tests/harness/prog.c`

#### Mock 技术
- Mock 实现：`tests/harness/mock.c`
- 使用示例：`tests/unit/mock.c`

#### 网络测试
- CLI 测试脚本：`tests/e2e/cli.sh`
- 网络设置：查看脚本中的 `setup()` 函数

---

## 🤝 贡献测试

### 添加新测试的检查清单

- [ ] 阅读相关文档
- [ ] 确定测试类型（单元/E2E/CLI）
- [ ] 编写测试代码
- [ ] 更新 CMakeLists.txt
- [ ] 运行测试确保通过
- [ ] 检查代码覆盖率
- [ ] 提交代码

### 测试代码规范

1. **命名清晰**：`Test(module, feature_description)`
2. **结构完整**：参数验证 + 正常功能 + 错误处理
3. **资源清理**：使用 cleanup 属性
4. **注释充分**：复杂逻辑需要注释
5. **独立性**：测试之间不应有依赖

---

## 📞 获取帮助

### 遇到问题？

1. **查看文档**：先查看本目录的三个文档
2. **查看示例**：参考现有测试代码
3. **运行调试**：使用 gdb 调试测试
4. **查看日志**：检查测试输出和覆盖率报告

### 相关资源

- **测试源码**：`../tests/`
- **测试框架**：`../tests/harness/`
- **CMake 配置**：`../tests/CMakeLists.txt`
- **主项目文档**：`../README.md`

---

## 📝 文档更新

这些文档会随着 bpfilter 的发展而更新。如果发现文档过时或有错误，请：

1. 检查最新的测试代码
2. 更新相应文档
3. 提交更改

---

## 总结

bpfilter 的测试体系是一个完善的、多层次的测试框架：

- ✅ **完整覆盖**：单元、E2E、集成、CLI 测试
- ✅ **自动化**：测试发现、执行、报告全自动
- ✅ **易用性**：清晰的 API 和丰富的工具
- ✅ **可维护**：良好的代码组织和文档
- ✅ **高质量**：严格的覆盖率要求和代码规范

开始你的测试之旅吧！🚀
