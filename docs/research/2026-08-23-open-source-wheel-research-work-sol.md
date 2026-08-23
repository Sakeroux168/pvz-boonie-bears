# W4｜开源轮子、许可证与 Windows/Godot 适配研究

- 日期：2026-08-23
- 状态：P0 候选调研，不批准技术栈或依赖
- 检查方法：2026-08-23 通过 GitHub 仓库页/API核对默认分支、根目录许可证、README、主要语言和可见维护状态；**Star 只记录为社区信号，不进入推荐评分**。

## 结论先行

1. **没有一个仓库适合直接当本项目底座。**最接近的 Godot 塔防模板都以自由路径、导航或通用炮塔为核心，而本项目需要固定路线、角色卡、同角色升级、固定跨角色融合、世界规则与数据驱动架构。直接 fork 会先继承大量错误假设。
2. 最值得做 PoC 的参考组合是：
   - `quiver-dev/tower-defense-tutorial`：看 Godot 4 塔放置、经济、敌人、UI 与有限状态机；代码 MIT、素材 CC BY 4.0，必须分开履行许可。
   - `GuaraProductions/towerdefensegodot`：看较新的 Godot 4.5 波次/关卡/升级交互；Star 很少但功能与目标相关，正好说明不按热度筛选。
   - `godot-gdunit-labs/gdUnit4`：若项目批准 Godot，作为自动化测试候选；版本仍需和最终 Godot 版本锁定。
   - `godotengine/godot-demo-projects`：以官方示例核对 Godot 惯用法，而不是照抄民间模板结构。
3. `ape1121/Godot-4-Tower-Defense-Template` 和 `cheng1559/pvz-remake` 适合**阅读/对照**，不适合作为依赖。前者数据结构偏硬编码，后者使用 Cocos Creator/TypeScript 且是对 PVZ 的重制研究，技术栈和 IP 边界都不匹配。
4. `v-pukman-gd/godot-anti-zombie-game`、`ZixuanShi/PlantsVSZombies`、`laitooo/Plants-vs-Zombies` 未发现明确根许可证；公开可看不等于可复制，放弃直接复用。
5. `bitwes/Gut` 在检查时 GitHub API 未识别许可证，根目录也未发现许可证文件。即使项目活跃、Star 多，也不应在许可不清时直接采用。可向作者核实或改用许可证清楚的候选。
6. “MIT 代码”不覆盖仓库内的第三方素材，也不覆盖 PVZ 或《熊出没》的角色、图像、音乐、名称。每个候选都必须做代码、素材、字体、音频、依赖五层清单。

## 评价方法

| 维度 | 问题 | 权重思路 |
|---|---|---|
| 许可证可执行性 | 根许可证是否明确？代码/素材是否分开？归属和通知义务是否清楚？ | 一票否决项 |
| 架构匹配 | 是否支持固定路线、数据驱动单位、波次、UI 分离、可测试性？ | 高 |
| 维护/版本 | 最近提交、目标 Godot 版本、弃用说明、Issue 状态 | 高 |
| 引入成本 | 是否要求 LFS、原生扩展、错误引擎或大量资产清理？ | 高 |
| 可验证性 | 有测试、可运行 demo、清楚 README、版本矩阵吗？ | 中 |
| Windows 风险 | 路径大小写、LFS、脚本/CLI、原生编译、导出模板 | 中 |
| Star | 只能说明一定可见度，不能证明许可、质量或适配 | **不计分** |

GitHub 明确说明：没有许可证时默认版权法适用，其他人通常无权复制、分发或制作衍生作品；公开仓库的 GitHub 服务条款只提供在平台内查看和 fork 的权限，不等于通用再利用许可。[GitHub：Licensing a repository](https://docs.github.com/articles/licensing-a-repository)、[GitHub：Reusing other people's code](https://docs.github.com/en/get-started/learning-to-code/reusing-other-peoples-code-in-your-projects)、[GitHub Terms of Service](https://docs.github.com/site-policy/github-terms/github-terms-of-service)

## 候选项目逐项核验

“最近推送”来自 2026-08-23 检查时 GitHub 元数据；它只能说明仓库有提交，不能证明兼容或维护质量。

| 项目 | 栈/最近推送 | 许可证核验 | 真正可转化的部分 | 不推荐直接复用的部分 | Windows/集成风险 | 处理建议 |
|---|---|---|---|---|---|---|
| [quiver-dev/tower-defense-tutorial](https://github.com/quiver-dev/tower-defense-tutorial) | Godot 4/GDScript；README 要求 4.0+ | [代码 MIT](https://github.com/quiver-dev/tower-defense-tutorial/blob/main/LICENSE.txt)；[素材 CC BY 4.0](https://github.com/quiver-dev/tower-defense-tutorial/blob/main/LICENSE_ASSETS.txt) | 塔放置、三类塔/敌人/投射物、经济、HUD、FSM、场景组合 | 自由导航与炮塔继承结构不等于 5 路角色卡；不要带入其世界和素材 | 使用 Git LFS；Windows 开发机/CI都需安装并拉取 LFS；旧 TileMap/导航 API 需用最终 Godot 版本验证 | **PoC/阅读优先**，抽取模式不整仓 fork |
| [quiver-dev/tower-defense-godot4](https://github.com/quiver-dev/tower-defense-godot4) | Godot 4 RC6；2026-08-21 仍有推送 | [代码 MIT](https://github.com/quiver-dev/tower-defense-godot4/blob/main/LICENSE.txt)；[素材单独许可](https://github.com/quiver-dev/tower-defense-godot4/blob/main/LICENSE_ASSETS.txt) | 命中状态等旧版特性可对照 | README 明示已被上一个 tutorial 仓库取代、较不更新、缺爆炸/音效 | LFS；RC6 时代 API；“最近推送”不抵消作者的弃用说明 | **仅差异参考**，不选为底座 |
| [GuaraProductions/towerdefensegodot](https://github.com/GuaraProductions/towerdefensegodot) | Godot 4.5/GDScript；2025-10-15 | [MIT](https://github.com/GuaraProductions/towerdefensegodot/blob/main/LICENSE) | 波次/生成管理、模块关卡、塔选择与升级弹窗、Stage Manager、Web/Android/桌面目标 | 通用塔防，不含角色融合与固定路线；需要审查场景耦合 | 先在 Windows 上验证 Godot 4.5 项目导入和 Web/Android 导出；路径大小写差异需检查 | **PoC/阅读**；低 Star 不构成否决 |
| [ape1121/Godot-4-Tower-Defense-Template](https://github.com/ape1121/Godot-4-Tower-Defense-Template) | Godot 4/GDScript；2024-08-26 | [MIT](https://github.com/ape1121/Godot-4-Tower-Defense-Template/blob/main/LICENSE) | 拖放、升级/出售、两张地图、基础数据表 | README/代码结构以全局字典数据为主，可能与计划中的资源化、数据驱动模块冲突 | 旧版 Godot 4 工程导入；拖放触屏手感与 Windows 鼠标行为都需重测 | **阅读参考**，不作为依赖 |
| [godotengine/godot-demo-projects](https://github.com/godotengine/godot-demo-projects) | 官方 Godot 示例；2026-08-12 | [MIT](https://github.com/godotengine/godot-demo-projects/blob/master/LICENSE.md) | 输入、2D、UI、保存、导航等官方惯用法与最小示例 | 不是一体化游戏框架；不要把多个 demo 拼成架构 | 选与最终引擎版本一致的分支/标签；示例资产也需读各目录说明 | **权威参考** |
| [godot-gdunit-labs/gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) | Godot 4 测试；2026-08-20；可见 4.3—4.7 版本矩阵 | [MIT](https://github.com/godot-gdunit-labs/gdUnit4/blob/master/LICENSE) | GDScript/C#/场景测试、mock、发现、编辑器与命令行 | 插件本身不能替代可测试架构；不应在引擎未决定前提前锁定 | Windows CLI/PowerShell、路径和 CI headless 需要做一条真实流水线；插件版本须固定 | **条件式依赖候选** |
| [bitwes/Gut](https://github.com/bitwes/Gut) | Godot 测试；2026-08-18 | **GitHub API 未识别许可证，根目录未发现 LICENSE（2026-08-23）** | CLI、JUnit 输出、test doubles 的功能思路 | 未获明确许可前不得复制/集成；Star/活跃度不能替代授权 | CLI 可用性还需 Windows 验证，但许可已先阻断 | **暂停/放弃直接采用**；若作者明确补证再复评 |
| [derkork/godot-statecharts](https://github.com/derkork/godot-statecharts) | Godot 4 GDScript/C#；2026-06-26 | [代码 MIT](https://github.com/derkork/godot-statecharts/blob/main/LICENSE)；demo 素材可能有各自 CC/公共领域声明 | 状态、守卫、延迟/冷却、调试与暂停可用于复杂 Boss | 5 路普通敌人多为可预测短状态，插件可能比手写 FSM 更重 | Addon 版本与 Godot 版本；demo 素材不要默认随代码许可；Windows 测试脚本需实跑 | **条件式 PoC**，只有复杂度证明确需时再引入 |
| [limbonaut/limboai](https://github.com/limbonaut/limboai) | Godot 4 C++/GDExtension；2026-08-21 | [代码许可证](https://github.com/limbonaut/limboai/blob/master/LICENSE)；demo 美术含 CC BY 4.0 等单独条款 | 行为树/状态机思想、调试工具 | 固定路线小规模敌人不需要大型 AI 框架；原生扩展增加构建面 | Windows 二进制兼容、Godot 小版本、原生构建/签名、导出平台矩阵 | **P0/P1 不采用**；仅复杂 AI 阶段重评 |
| [AdamKormos/SaveMadeEasy](https://github.com/AdamKormos/SaveMadeEasy) | Godot/GDScript；2025-01-01 | [MIT](https://github.com/AdamKormos/SaveMadeEasy/blob/main/LICENSE) | 嵌套变量/Resource 保存、加密接口可供 API 对照 | 用设备唯一 ID 等策略可能妨碍跨设备/可移植；插件不替项目定义版本迁移 | Windows 用户数据目录、权限、升级迁移和损坏恢复都需自测 | **阅读/小 PoC**，不自动依赖 |
| [cheng1559/pvz-remake](https://github.com/cheng1559/pvz-remake) | Cocos Creator 3.8.8/TypeScript；2026-07-25 | [MIT](https://github.com/cheng1559/pvz-remake/blob/main/LICENSE)；README 称源码不含原作资产 | 1-1—1-10、选卡、阳光、波次/旗帜波、推车、存档快照、调试 CLI、合法持有资产的导入流程，适合做系统清单对照 | 错误技术栈；目标是重制 PVZ；不要引入原作表达、关卡、资产导入或数据 | Cocos 编辑器/原生构建模板与 Godot 流程完全不同；Windows 版本固定成本 | **黑盒/源码阅读参考**，不做依赖或底座 |
| [HectorPulido/UnityPlantsVsZombiesClone](https://github.com/HectorPulido/UnityPlantsVsZombiesClone) | Unity/C#；2017-12-25 | [MIT](https://github.com/HectorPulido/UnityPlantsVsZombiesClone/blob/master/LICENSE) | 旧教程可帮助列出最小系统 | 近九年未更新、错误引擎、克隆目标；不值得迁移代码 | 旧 Unity 项目升级、序列化和包版本风险高 | **只看概念，不复用** |
| [v-pukman-gd/godot-anti-zombie-game](https://github.com/v-pukman-gd/godot-anti-zombie-game) | 旧 Godot；2020-10-11 | **未发现明确许可证** | 可仅运行观察早期 Godot lane defense 思路（若无需复制） | 不复制代码/素材；旧版本与克隆表达不匹配 | 老 Godot 项目升级、导入资源、Windows 路径 | **放弃直接复用** |
| [ZixuanShi/PlantsVSZombies](https://github.com/ZixuanShi/PlantsVSZombies) | Unity/C#；2025-12-18 | **未发现明确许可证** | 无需引入；最多作为公开页面层面的存在性线索 | 无授权，且为 PVZ 克隆语境 | Unity/Windows 不是许可问题的替代答案 | **放弃** |
| [laitooo/Plants-vs-Zombies](https://github.com/laitooo/Plants-vs-Zombies) | Unity；2022-06-10 | **未发现明确许可证** | 无显著独特价值 | 无授权、错误引擎、克隆表达 | 旧 Unity 版本 | **放弃** |

## 为什么不按 Star 推荐

本次样本给出了三个反例：

- `GuaraProductions/towerdefensegodot` Star 很少，但使用较新的 Godot 4.5，且波次、关卡与升级弹窗都直接对应 PoC 问题；值得阅读。
- `bitwes/Gut` 活跃且知名，但检查时没有可确认根许可证；许可门槛未过，不能采用。
- `quiver-dev/tower-defense-godot4` 可见度较高且最近仍有推送，但作者 README 明示已被新仓库取代；推荐应服从作者维护说明。

因此排序依据是“许可明确 × 版本匹配 × 可转化模块 × 引入成本 × 可测试性”，不是受欢迎程度。

## 模块级“自研/参考/候选依赖”建议

| 模块 | 自研 | 参考来源 | 候选依赖 | 理由 |
|---|---|---|---|---|
| 固定 5 路棋盘与格子占用 | 是 | Godot 官方 2D/Input 示例 | 无 | 这是本项目核心规则，通用导航模板假设不同 |
| 角色卡、同角色升级、固定配方 | 是 | W3 原型、数据驱动原则 | 无 | 决定产品差异化，不能交给通用模板 |
| 波次/Spawn 数据 | 是，参考模式 | Quiver、Guara、Cocos remake | 无 | 可借调度思想，但数据结构需服务世界规则与测试 |
| 普通敌人状态 | 是 | Quiver FSM、Godot statecharts | `godot-statecharts` 仅条件式 | 普通敌人有限状态足够；Boss 复杂度出现后再评 |
| 自动化测试 | 测试本身自研 | Godot 官方、GdUnit 文档 | `gdUnit4` 条件式 | 许可证清晰、更新活跃；需先确定 Godot 版本 |
| 保存/版本迁移 | 是 | SaveMadeEasy API 及官方文档 | 暂无 | 存档格式是长期契约，插件不能替代项目版本策略 |
| 美术/音频 | 自制或逐项获权 | 占位素材只用明确许可 | 无整包引入 | 《熊出没》与 PVZ 权利不由代码许可证解决 |

## Windows 与供应链验收清单

每个进入 PoC 的候选都必须在干净 Windows 环境完成：

1. 固定仓库 commit SHA、Godot 版本和插件版本，不跟随 `main` 漂移。
2. 若含 Git LFS，先确认 `git lfs pull` 后没有指针文件残留；同时确认 CI runner 安装 LFS。[Git LFS 官方站](https://git-lfs.com/)
3. 用只区分大小写的代码审查检查路径引用；Windows 本地大小写不敏感可能掩盖 Linux/Web 导出失败。
4. 检查绝对路径、反斜杠、PowerShell/批处理依赖和非 ASCII 路径。
5. 在 Godot 编辑器、headless 测试、Windows 导出、Web 导出各运行一次最小场景。
6. 对 addon 验证禁用/删除后项目可诊断失败，不让核心数据只存在插件私有格式。
7. 生成第三方清单：项目名、版本/SHA、代码许可证、素材许可证、版权通知、修改说明、来源 URL。
8. 对许可证检测结果做人工复核。GitHub 说明 License API 只检测可识别的仓库许可证，不能代替依赖和文件级审计。[GitHub Licenses API](https://docs.github.com/en/rest/licenses/licenses)

## 许可证履约要点

- MIT：分发软件或重要部分时保留版权声明和许可文本；不能把它理解为“无条件无署名”。
- CC BY 4.0 素材：需要适当署名、许可链接和修改说明；代码 MIT 与素材 CC BY 必须分别记录。
- 无许可证：不要复制、修改、打包或迁移；公开浏览和 GitHub fork 权限不等于可发布衍生软件。
- 仓库内每个子目录、素材包、字体、音效和第三方依赖可能有不同许可；根许可证不能自动覆盖它们。
- 本报告是工程风险筛选，不是法律意见；W5 给出公开发布前的权利门槛。

## 推荐的三个小 PoC（若 Godot 获批后）

1. **放置/波次 PoC**：只参考 Quiver + Guara 的信号和管理器边界，自研 5 路棋盘；不搬素材。
2. **测试 PoC**：固定一个 Godot 版本与一个 GdUnit4 release，验证 Windows headless、JUnit 输出、场景测试和 CI。
3. **复杂状态反证 PoC**：用手写 FSM 和 `godot-statecharts` 各做一个两阶段 Boss；只有插件显著降低复杂度且许可/导出均过关才采用。

每个 PoC 应单独记录：来源 commit、拷贝的具体文件/思想、修改、许可证、测试结果和删除成本。

## 明确不建议

1. 不 fork 任一 PVZ clone 作为项目起点。
2. 不因 MIT 代码就复制仓库内图像、音乐、字体或 PVZ 资产导入脚本产物。
3. 不因 Star、最近推送或 demo 能运行就跳过许可证和版本检查。
4. 不在 Godot 尚未正式批准时把 GdUnit4、statecharts 或保存插件写成既定依赖。
5. 不让通用自由路径塔防模板决定本项目的 5 路架构。

## 仍需用户/GPT 决定

- 是否批准 Godot 及具体版本，随后才能锁测试/插件兼容矩阵。
- 是否批准三个 PoC 的顺序与时间盒。
- `gdUnit4` 是否作为测试候选进入 P1；`godot-statecharts` 是否仅保留为 Boss 阶段备选。
- 第三方通知文件的项目标准与存放位置。
- 是否向 `bitwes/Gut` 作者核实许可证，还是直接从候选集中移除。

