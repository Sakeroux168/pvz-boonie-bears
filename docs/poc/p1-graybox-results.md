# P1｜World 01 灰盒 PoC 结果

日期：2026-08-23

状态：PoC 交付，等待技术/产品评审；不构成正式技术或产品决定。

## 结论

P1 的最小闭环已跑通：5 路/可变列数、鼠标拖拽部署、同路敌人推进与攻击、一次性路线保险、`A1+A1→A2`、`A2+A2→A3`、固定 `A1+B1→AB`、单资源扣费、固定结果预览和 `protected_tree` 目标均已实现。全部画面由代码绘制的矩形、圆形、三角形和功能代号组成。

建议：**Godot 4.7.2 + GDScript 值得进入下一阶段的正式开发候选评审，但本 PR 不把它写成已批准技术栈。** 自动化测试候选建议选 **GUT 9.7.1**。选择理由是当前核心以 GDScript 纯规则为主，GUT 的 Windows/headless 调用更直接；若以后大量依赖场景、UI 与复杂 mock，再重新评估 GdUnit4。

## Windows 启动

1. 从 Godot 官方下载 `Godot 4.7.2 Standard / Windows` 并解压。
2. 在仓库根目录打开 CMD 或 PowerShell。
3. 执行：

```bat
scripts\start-graybox.cmd -GodotBin "C:\Tools\Godot_v4.7.2-stable_win64.exe"
```

也可设置环境变量后省略参数：

```bat
set "GODOT_BIN=C:\Tools\Godot_v4.7.2-stable_win64_console.exe"
scripts\start-graybox.cmd
```

操作：

- 从右侧拖 `unit_a_1` / `unit_b_1` 到空格部署。
- 把一个已部署单位拖到另一个单位上，显示并执行固定升级/融合结果。
- 敌人从右向左前进；单位只打本路；每路左侧小矩形是一次性保险。
- 紫色 `enemy_tree_targeter` 会优先攻击同路 `protected_tree`。

将 `src/data/level_graybox.json` 的 `columns` 从 `9` 改成 `8` 或 `10` 即可改变列数，不需要修改核心脚本。

## 自动测试

一键跑两套同条件测试：

```bat
scripts\run-tests.cmd -GodotBin "C:\Tools\Godot_v4.7.2-stable_win64_console.exe"
```

首次运行会从两个框架的官方 GitHub tag 下载源码包，校验 `THIRD_PARTY_NOTICES.md` 中的 SHA-256，再解压到已忽略的 `addons/`；灰盒本体启动不依赖测试插件。

单独运行：

```bat
scripts\run-gut.cmd -GodotBin "C:\Tools\Godot_v4.7.2-stable_win64_console.exe"
scripts\run-gdunit4.cmd -GodotBin "C:\Tools\Godot_v4.7.2-stable_win64_console.exe"
```

报告：

- GUT JUnit：`reports/gut/results.xml`
- GdUnit4 JUnit/HTML：`reports/gdunit4/report_<n>/results.xml` 与 `index.html`

两层测试包装只负责各框架语法，真正的 8 个样例全部来自 `src/tests/shared/spec_cases.gd`：

1. 5 路与 8/10 列配置；
2. 占格冲突；
3. 敌人同路推进；
4. `A1+A1→A2`，并校验行为变化、资源与运行时状态不刷新；
5. 非法升级被拒绝；
6. `A+B→AB`，并校验两格变一格的覆盖损失；
7. 非法配方被拒绝；
8. 保护目标占格与胜负条件。

## Windows/headless 实测

环境：Windows、包含中文路径的工作区、Godot `4.7.2.stable.official.ed1daf0bf`。

| 项目 | GUT 9.7.1 | GdUnit4 6.2.0 |
|---|---:|---:|
| 同一规格结果 | 8/8 通过 | 8/8 通过 |
| 框架报告的测试时间 | 0.393 s | 0.059 s |
| 冷启动脚本墙钟时间（一次样本） | 3.086 s | 3.324 s |
| 成功退出码 | 0 | 0 |
| 故意失败探针退出码 | 1 | 100 |
| JUnit XML | 已生成，固定路径 | 已生成，编号报告目录 |
| HTML 报告 | 无内建同等默认产物 | 已生成 |
| 主场景 headless 冒烟 | 120 帧，退出码 0，无脚本/运行时错误 | 与框架无关 |

时间仅用于观察启动/集成成本，不是性能基准。受控执行环境无法读取 Windows 根证书存储，因此 Godot 输出一条证书警告；测试、报告和退出码不受影响。

## GUT vs GdUnit4

| 维度 | GUT 9.7.1 | GdUnit4 6.2.0 |
|---|---|---|
| License | MIT；插件自带字体为 SIL OFL 1.1 | MIT |
| Godot 4.7.2 | 官方版本矩阵为 4.7.x；实测通过 | 6.2.x 面向 Godot 4.7；实测通过 |
| Windows 安装 | 复制 `addons/gut`；仓库已锁版本 | 复制 `addons/gdUnit4`；仓库已锁版本 |
| CMD / PowerShell | 自带 CLI，仓库包装器直接传 `--headless` | 官方 `runtest.cmd` 主进程未传 `--headless`；仓库改为直接调用官方 `GdUnitCmdTool.gd` |
| 真 headless | 无额外开关，8/8 通过 | 默认拒绝并返回 103；需显式 `--ignoreHeadlessMode`，随后 8/8 通过 |
| UI/InputEvent headless | 可做规则/节点测试；输入仍受 Godot headless 限制 | 框架明确警告 InputEvent 在 headless 不会传递 |
| 失败退出码 | 1，CI 直接判断 | 100；101 表示 warning，CI 要映射返回码 |
| JUnit | `-gjunit_xml_file`，路径可固定 | 默认 JUnit + HTML，报告目录更完整 |
| 场景/节点体验 | 有节点测试、hooks、doubles，API 较直接 | Inspector、scene runner、fluent assertions 和报告更强 |
| doubles/mocks | full/partial doubles、stubs、spies；4.7 对返回类型更严格 | mock/spy、参数匹配、错误监控与场景工具更完整 |
| CI 复杂度 | 较低：单命令、0/1、固定 JUnit | 中等：额外 headless 开关、100/101 映射、编号报告目录 |
| 删除成本 | 删除 addon 与薄包装；共享规格/核心不变 | 同左；文件数更多但核心不依赖插件格式 |
| 维护状态 | 9.7.1 于 2026-07 发布，适配 4.7 | 6.2.0 于 2026-07 发布，适配 4.7 |

### 二选一建议

选择 **GUT 9.7.1** 作为下一阶段默认测试候选：

- 本项目当前最重要的是纯规则、配方和状态边界，GUT 已覆盖且 Windows/headless 入口更短。
- GdUnit4 的报告和场景工具更强，但 `--headless` 需要绕过保护开关，官方 Windows 包装器也不是纯 headless；这会增加 CI 解释成本。
- GdUnit4 的测试体本身更快，但本样本总时长主要由 Godot 冷启动决定，不能据此选择框架。
- 这只是 PoC 建议，不修改 `docs/decisions.md`。若正式阶段出现大量场景/UI 自动化，再用真实场景样例复评。

## 关键架构

```text
level_graybox.json
        ↓
BoardState / UnitCatalog / RecipeBook / BattleState / EnemyState
        ↓
main.gd（几何绘制、鼠标拖拽、最小调试 HUD）
        ↓
shared spec cases
   ↙             ↘
GUT wrapper   GdUnit4 wrapper
```

- `src/core/` 不依赖 UI、正式角色、美术或剧情。
- `UnitCatalog` 分别配置 A1/A2/A3；升级改变射击行为，合并按较差生命比例和较长冷却保留状态，不会满血/满技能刷新。
- `RecipeBook` 用排序后的输入键查询固定配方，没有随机结果或组合 if/else 链。
- `BattleState.last_merge_receipt` 记录前后占格、资源与 3 秒撤销截止时间；`undo_last_merge` 明确返回未实现。
- `protected_tree` 属于棋盘目标数据，不塞进单位类型；特殊敌人通过偏好标记选择它。
- UI 只调用规则接口并画状态，不承担配方/资源/胜负计算。

## PoC 问题回答

1. 5 路/变列数：实现和测试简单；8/9/10 列无需改核心。
2. 拖拽：鼠标部署、单位间拖拽与合法/非法预览稳定；尚未覆盖触屏与自动化 InputEvent。
3. 敌人：固定路线、同路攻击、越线保险/失败状态清楚。
4. 同角色升级：数据规则可维护；A2/A3 行为不同，运行状态不会刷新。
5. 固定融合：配方可查询且确定；两格压成一格会损失跨路覆盖，因此存在“不融合”的合理局面。
6. 单资源：足以统一表达部署/升级/融合成本与日志，PoC 中融合并非免费最优解；但尚无生产单位和完整波次，不能据此锁正式数值或断言长期无滚雪球。
7. 测试框架：推荐 GUT，理由见上。
8. Godot：值得有条件进入正式开发候选评审。

## Godot 是否值得进入正式开发

建议为“**值得，有条件进入**”：

- 2D 几何交互、数据文件、固定路线和拖拽都可用很少引擎胶水完成。
- GDScript 核心可以脱离场景测试；Windows/headless、非 ASCII 路径、JUnit 和失败退出码均已验证。
- 文本项目文件与独立 addon 目录便于 PR 审查和删除依赖。

进入正式开发前仍应由技术评审确认：Windows 导出模板与发布包、目标低配机性能、触屏输入、CI 干净机安装、正式数据格式/迁移策略，以及只保留一套测试框架。P1 不验证这些项目，也不更改既定产品方向。

## 第三方依赖与素材

完整版本、commit、归属与 License 见仓库根目录 `THIRD_PARTY_NOTICES.md`。没有复制任何塔防模板或 clone 代码；没有位图角色、原作图像、音乐、音效或未知授权素材。测试插件自己的图标/字体仅用于测试工具界面，不用于灰盒游戏画面，并已逐项列入清单。

## 已知问题

- 这是灰盒，不含完整 UI、卡组、10 关、剧情、Boss、正式存档、正式数值或正式资产。
- 鼠标拖拽未覆盖触屏、键盘和手柄；headless 只自动验证规则，拖拽通过场景冒烟与人工入口验证。
- 撤销只有 3 秒窗口/收据接口，没有真正恢复；拆分规则仍等待产品决定。
- 资源只有初始池，没有生产角色与完整波次经济，无法据此完成平衡结论。
- `enemy_tree_targeter` 是最小规则验证，不是最终 AI；没有寻路、动画、预警或复杂目标排序。
- 路线保险只做一次性整路清除与状态变化，没有正式演出。
- GdUnit4 在真 headless 下需要 `--ignoreHeadlessMode`；UI/InputEvent 测试仍不适合这条流水线。
- 两套测试插件仅在本地按固定 hash 安装到忽略目录；正式阶段应按评审结果只保留一套安装路径。
- 本次未验证 Windows 导出包、Web/移动端导出或长期性能。
