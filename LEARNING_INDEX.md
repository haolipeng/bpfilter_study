# bpfilter 完整学习资源索引

欢迎来到 bpfilter 学习资源中心！这里汇集了从入门到精通的所有学习材料。

## 📚 学习路径概览

```
入门阶段（Week 1-2）
    ↓
基础实践（Week 2-3）
    ↓
内部原理（Week 3-6）
    ↓
高级实战（Week 6+）
```

---

## 🚀 阶段一：快速入门（1-2周）

### 目标
- 理解 bpfilter 基本概念
- 能够编写和运行简单规则
- 掌握基础命令和工具

### 学习资源

#### 1. 快速入门指南
📄 [LEARNING_QUICKSTART.md](LEARNING_QUICKSTART.md)
- 编译和安装
- 第一个规则
- 常用命令
- 故障排除

#### 2. 基础练习（learning_exercises/）
按顺序完成以下练习：

- 📝 [Exercise 1: 基础规则](learning_exercises/exercise_01_basic.bf) - 入门级（1-2小时）
  - Chain、Rule、Matcher 基础
  - IP 地址匹配
  - Counter 和 Log

- 📝 [Exercise 2: 端口过滤](learning_exercises/exercise_02_ports.bf) - 初级（2-3小时）
  - TCP/UDP 端口匹配
  - 保护服务（SSH、Web）
  - 不同 Hook 使用

- 📝 [Exercise 3: Set 批量匹配](learning_exercises/exercise_03_sets.bf) - 中级（2-3小时）
  - Set 的定义和使用
  - IP 黑白名单
  - 性能优化

- 📝 [Exercise 4: 流量监控](learning_exercises/exercise_04_counters.bf) - 初级（2-3小时）
  - Counter 深度使用
  - Log 级别
  - 流量分析

#### 3. 练习指南
📖 [learning_exercises/README.md](learning_exercises/README.md)
- 使用说明
- 学习路径
- 故障排除
- 评估标准

---

## 🔧 阶段二：内部原理（3-4周）

### 目标
- 理解 bpfilter 内部实现
- 能够阅读和修改源代码
- 掌握调试和分析技能

### 学习资源

#### 总体规划
📖 [learning_internals/README.md](learning_internals/README.md)
- 完整学习路线图
- 7 个 Phase 详解
- 时间安排建议
- 学习评估标准

---

### Phase 1: 规则解析机制（3-5天）⭐⭐⭐

**理论学习：**
📘 [01_parsing_deep_dive.md](learning_internals/01_parsing_deep_dive.md)
- Flex 词法分析器详解
- Bison 语法分析器详解
- AST 构建过程
- 从文本到数据结构

**实践项目：**
🛠️ [practice_01_add_matcher.md](learning_internals/practice_01_add_matcher.md)
- 添加新的匹配器（ip4.ttl）
- 修改 lexer.l 和 parser.y
- 完整实现流程

**调试指南：**
🔍 [debug_parser.md](learning_internals/debug_parser.md)
- GDB 调试技巧
- Bison/Flex 调试模式
- 常见错误解决

**关键源码：**
- [src/bfcli/lexer.l](src/bfcli/lexer.l)
- [src/bfcli/parser.y](src/bfcli/parser.y)
- [src/bfcli/context.c](src/bfcli/context.c)

---

### Phase 2: 内部数据结构（3-5天）⭐⭐⭐

**理论学习：**
📘 [02_data_structures.md](learning_internals/02_data_structures.md)
- Chain、Rule、Matcher、Set 详解
- 内存布局分析
- 数据流转过程

**实践项目：**
🛠️ practice_02_trace_request.md（待创建）
- 追踪请求完整生命周期
- 绘制数据结构关系图
- GDB 内存分析

**关键源码：**
- [src/libbpfilter/chain.c](src/libbpfilter/chain.c)
- [src/libbpfilter/rule.c](src/libbpfilter/rule.c)
- [src/libbpfilter/matcher.c](src/libbpfilter/matcher.c)
- [src/libbpfilter/set.c](src/libbpfilter/set.c)
- [src/libbpfilter/list.c](src/libbpfilter/list.c)

---

### Phase 3: BPF 代码生成（5-7天）⭐⭐⭐⭐⭐

**理论学习：**
📘 [03_codegen_explained.md](learning_internals/03_codegen_explained.md)
- eBPF 指令集基础
- 代码生成架构
- 匹配器代码生成示例

**实践项目：**
🛠️ practice_03_analyze_bpf.md（待创建）
- 分析生成的 BPF 代码
- 使用 bpftool 反汇编
- 为新匹配器实现代码生成

**工具脚本：**
🔧 [tools/dump_bpf.sh](learning_internals/tools/dump_bpf.sh)
- 导出 BPF 程序
- 分析 BPF map
- 生成完整报告

**关键源码：**
- [src/bpfilter/cgen/program.c](src/bpfilter/cgen/program.c)
- [src/bpfilter/cgen/prog/](src/bpfilter/cgen/prog/)
- [src/bpfilter/cgen/matcher/](src/bpfilter/cgen/matcher/)

---

### Phase 4: 翻译层机制（3-5天）⭐⭐⭐

**理论学习：**
📘 04_translation_layers.md（待创建）
- xlate 层架构
- iptables 兼容实现
- nftables 兼容实现

**实践项目：**
🛠️ practice_04_iptables_xlate.md（待创建）
- 追踪 iptables 规则翻译
- 实现自定义格式翻译器

**关键源码：**
- [src/bpfilter/xlate/cli.c](src/bpfilter/xlate/cli.c)
- [src/bpfilter/xlate/ipt/](src/bpfilter/xlate/ipt/)
- [src/bpfilter/xlate/nft/](src/bpfilter/xlate/nft/)

---

### Phase 5: BPF 程序加载（3-5天）⭐⭐⭐⭐

**理论学习：**
📘 05_bpf_loading.md（待创建）
- libbpf 库使用
- BPF 程序加载流程
- Hook 点附加机制

**实践项目：**
🛠️ practice_05_monitor_loading.md（待创建）
- 使用 bpftool 监控程序
- 查看 BPF map 内容
- 测试原子更新

**关键源码：**
- [src/bpfilter/bpf/prog.c](src/bpfilter/bpf/prog.c)
- [src/bpfilter/bpf/map.c](src/bpfilter/bpf/map.c)
- [src/bpfilter/hook.c](src/bpfilter/hook.c)

---

### Phase 6: 测试框架（3-5天）⭐⭐⭐

**理论学习：**
📘 06_testing_framework.md（待创建）
- 单元测试（cmocka）
- E2E 测试架构
- Scapy 数据包生成

**实践项目：**
🛠️ practice_06_write_tests.md（待创建）
- 编写单元测试
- 编写 E2E 测试
- 使用 Scapy 生成测试包

**关键源码：**
- [tests/unit/](tests/unit/)
- [tests/e2e/main.c](tests/e2e/main.c)
- [tests/e2e/genpkts.py](tests/e2e/genpkts.py)

---

### Phase 7: 端到端实战（5-7天）⭐⭐⭐⭐⭐

**理论学习：**
📘 07_end_to_end_flow.md（待创建）
- 完整数据流程
- 组件交互关系
- 性能优化技巧

**实践项目：**
🛠️ practice_07_full_feature.md（待创建）
- 实现完整新功能
- 包含解析、数据结构、代码生成、测试
- 性能测试和文档

---

## 📖 辅助资源

### 参考文档

📚 **术语表**
[glossary.md](learning_internals/glossary.md)
- 所有专业术语解释
- 缩写对照表
- 相关概念说明

📚 **架构总览**
architecture_overview.md（待创建）
- 整体架构图
- 模块关系
- 设计模式

📚 **代码阅读技巧**
code_reading_tips.md（待创建）
- 如何阅读大型代码库
- 推荐阅读顺序
- 标注和笔记方法

📚 **调试指南**
debugging_guide.md（待创建）
- GDB 高级技巧
- bpftool 使用大全
- Valgrind 内存分析

---

### 工具脚本

🔧 **BPF 程序导出工具**
[tools/dump_bpf.sh](learning_internals/tools/dump_bpf.sh)
```bash
# 列出所有 BPF 程序
sudo ./learning_internals/tools/dump_bpf.sh list

# 导出程序指令
sudo ./learning_internals/tools/dump_bpf.sh xlated <prog_id>

# 生成完整报告
sudo ./learning_internals/tools/dump_bpf.sh report
```

🔧 **Parser 追踪工具**
tools/trace_parser.sh（待创建）

🔧 **规则对比工具**
tools/compare_rules.py（待创建）

---

## 📊 学习进度追踪

### 建议使用清单

复制以下清单到你的学习笔记中：

```markdown
## Week 1: 入门阶段
- [ ] 阅读 LEARNING_QUICKSTART.md
- [ ] 完成 Exercise 1: 基础规则
- [ ] 完成 Exercise 2: 端口过滤
- [ ] 完成 Exercise 3: Set 使用
- [ ] 完成 Exercise 4: 流量监控

## Week 2: 解析和数据结构
- [ ] 阅读 Phase 1 理论文档
- [ ] 完成 practice_01_add_matcher
- [ ] 阅读 debug_parser.md
- [ ] 阅读 Phase 2 理论文档
- [ ] 完成 practice_02_trace_request

## Week 3: BPF 代码生成
- [ ] 学习 eBPF 基础
- [ ] 阅读 Phase 3 理论文档
- [ ] 完成 practice_03_analyze_bpf
- [ ] 使用 dump_bpf.sh 分析程序

## Week 4: 翻译和加载
- [ ] 阅读 Phase 4 理论文档
- [ ] 完成 practice_04_iptables_xlate
- [ ] 阅读 Phase 5 理论文档
- [ ] 完成 practice_05_monitor_loading

## Week 5: 测试和实战
- [ ] 阅读 Phase 6 理论文档
- [ ] 完成 practice_06_write_tests
- [ ] 阅读 Phase 7 理论文档
- [ ] 开始综合实战项目

## Week 6+: 高级项目
- [ ] 完成综合实战项目
- [ ] 性能测试和优化
- [ ] 编写文档
- [ ] 准备提交 PR
```

---

## 🎯 学习成果检验

### 入门阶段检验

完成入门阶段后，你应该能够：
- [ ] 独立编写 bpfilter 规则
- [ ] 使用不同的 Hook 类型
- [ ] 使用 Set 进行批量匹配
- [ ] 分析流量统计数据
- [ ] 解决常见配置问题

### 内部原理检验

完成内部原理学习后，你应该能够：
- [ ] 阅读和理解所有源代码
- [ ] 添加新的匹配器
- [ ] 修改代码生成逻辑
- [ ] 编写单元测试和 E2E 测试
- [ ] 使用调试工具定位问题
- [ ] 为项目贡献代码

---

## 📚 推荐阅读顺序

### 对于初学者

1. [LEARNING_QUICKSTART.md](LEARNING_QUICKSTART.md)
2. [learning_exercises/README.md](learning_exercises/README.md)
3. 完成所有 exercise_*.bf 练习
4. [learning_internals/README.md](learning_internals/README.md)
5. 按 Phase 1-7 顺序学习

### 对于有经验的开发者

1. [LEARNING_QUICKSTART.md](LEARNING_QUICKSTART.md) - 快速浏览
2. [learning_exercises/](learning_exercises/) - 选择性练习
3. [learning_internals/README.md](learning_internals/README.md)
4. 重点学习 Phase 3（BPF 代码生成）和 Phase 7（实战）
5. 直接开始贡献代码

### 对于想要贡献代码的开发者

1. 完成所有基础练习
2. Phase 1-2（理解解析和数据结构）
3. Phase 3（理解代码生成）
4. Phase 6（理解测试框架）
5. Phase 7（实现完整功能）
6. 阅读 [CONTRIBUTING.md](CONTRIBUTING.md)

---

## 🤝 获取帮助

### 官方资源

- **官方文档：** https://bpfilter.io/
- **GitHub 仓库：** https://github.com/facebook/bpfilter
- **Issues：** https://github.com/facebook/bpfilter/issues

### 相关社区

- **eBPF 社区：** https://ebpf.io/
- **Linux 内核邮件列表**
- **eBPF Slack**

### 学习资料

- **eBPF 入门：** https://ebpf.io/what-is-ebpf/
- **libbpf 文档：** https://libbpf.readthedocs.io/
- **BPF 指令集：** https://www.kernel.org/doc/html/latest/bpf/

---

## 📝 学习笔记建议

创建一个学习日志，记录：

```markdown
# bpfilter 学习日志

## 2025-11-01

### 今日学习
- Phase 1: 规则解析机制
- 阅读了 lexer.l 和 parser.y

### 关键收获
- Flex 使用正则表达式定义 token
- Bison 使用 BNF 定义语法
- $$ 和 $1, $2 的含义

### 实践项目
- 添加了 ip4.ttl 匹配器
- 遇到编译错误，通过查看 parser.output 解决

### 问题和解答
- Q: 如何解决 shift/reduce 冲突？
- A: 使用 %left 定义优先级

### 明天计划
- 完成 practice_01 的剩余部分
- 开始 Phase 2 学习
```

---

## 🌟 学习建议

1. **循序渐进**
   - 不要跳过基础练习
   - 按照推荐顺序学习
   - 每个 Phase 都很重要

2. **动手实践**
   - 不要只看文档
   - 每个概念都要编码验证
   - 使用调试工具理解流程

3. **记录笔记**
   - 记录学习心得
   - 为代码添加注释
   - 绘制图表辅助理解

4. **积极提问**
   - 遇到问题及时查阅文档
   - 在 GitHub Issues 提问
   - 与社区交流

5. **贡献代码**
   - 学以致用
   - 为项目贡献代码
   - 分享学习经验

---

祝你学习愉快！从入门到精通 bpfilter！🚀

如有任何问题，欢迎查阅相关文档或在社区提问。
