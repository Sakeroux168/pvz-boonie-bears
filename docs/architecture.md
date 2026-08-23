# 初始架构边界

本文只定义模块边界和数据流，不提前把所有实现绑定到某个引擎或框架。

当前首要目标是让“路线塔防 + 角色融合 + 世界机制 + 剧情关系”可以长期扩展，而不是第一版写完后每增加一个世界都重构。

## 总体数据流

```text
World / Level Data
        ↓
Deck / Character Data
        ↓
Battle Core
 ┌──────┼────────┬────────┐
 Grid   Units    Enemies   Resources
        ↓
 Fusion / Synergy / Abilities
        ↓
 Wave / Boss / World Rules
        ↓
 Result / Progress / Save
        ↓
 UI / Narrative / Unlocks
```

## 1. App / UI

负责：

- 主界面 / 世界时间轴
- 选关
- 卡组选择
- 角色图鉴 / 关系展示
- 战斗 HUD
- 拖拽部署与合成预览
- 暂停 / 设置
- 结算 / 解锁演出

UI 不直接承担战斗规则计算。

## 2. World / Level Data

每个世界应数据化保存：

- 世界 ID / 名称 / 对应动画时期
- 场景主题
- 路线和格子布局
- 世界特殊机制
- 天气/地形
- 可用角色
- 敌人池
- 关卡脚本
- Boss
- 剧情节点
- 解锁内容

目标：增加新世界主要通过“新增内容与规则模块”，而不是复制整个战斗系统。

## 3. Character Data

角色定义至少包括：

- ID
- 名称
- 阵营/时期
- 标签
- 部署成本
- 基础攻击/行为
- 生命/防御
- 爆发技
- 同角色升级链
- 可用融合配方
- 羁绊
- 解锁条件
- 动画/音效引用

数值与表现配置应尽量与战斗代码分离。

## 4. Grid / Lane System

负责：

- 路线
- 格子占用
- 地形属性
- 部署合法性
- 单位位置
- 敌人路线推进
- 特殊地块

第一版优先做标准多路线矩形网格 PoC；未来世界允许水路、冰面、小镇道路、地下等特殊规则。

## 5. Unit System

统一处理我方战斗单位：

- 部署
- 生命周期
- 攻击/辅助/坦克/资源等行为
- 状态效果
- 动画状态
- 伤害/治疗/控制

角色特殊行为通过可组合组件或清晰接口扩展，避免每个角色都把逻辑写死在一个巨大脚本中。

## 6. Fusion System

这是项目核心模块之一。

负责：

- 同角色升级
- 指定跨角色融合
- 融合合法性检查
- 融合预览
- 融合成本
- 融合后的单位/协作形态
- 拆分/撤销规则
- 剧情关系锁定

推荐数据结构概念：

```text
FusionRecipe
- input_a
- input_b
- required_relationship_state
- cost
- result_form
- inherited_behaviors
- special_behavior
- presentation
```

不得依靠大量 if/else 硬编码所有组合。

## 7. Synergy / Relationship System

区分两类概念：

- 战斗羁绊：角色同时存在时触发的行为。
- 剧情关系：随世界/剧情推进，决定角色立场、配方、台词和解锁。

剧情关系不应和单局临时数值混在一起。

## 8. Enemy / AI

负责：

- 路线选择/推进
- 攻击目标
- 特殊移动
- 飞行/地下/跳跃
- 偷资源
- 护盾
- 指挥/增益
- 针对机关或融合单位的特殊行为

第一阶段 AI 以可预测、可读为优先，不追求复杂通用 AI。

## 9. Wave / Encounter

负责：

- 敌人波次
- 大波提示
- 生成节奏
- 特殊事件
- 关卡目标
- Boss 阶段切换

关卡脚本应数据化，便于策划调整而不需要改核心代码。

## 10. World Rule System

世界规则作为独立模块接入战斗。

例如：

```text
SpringRule
SummerWaterRule
AutumnWindRule
WinterIceRule
TownTrafficRule
MicroWorldRule
```

规则模块可以修改地形、资源、移动、状态或事件，但不得直接破坏 Unit/Fusion 的内部数据。

## 11. Resource System

负责：

- 基础部署资源
- 候选协作/融合资源
- 生产/掉落
- 消耗
- UI 同步

双资源是否正式采用需要 PoC 和数值测试后决定。

## 12. Ability System

负责角色爆发技和可复用技能效果：

- 伤害
- 治疗
- 击退
- 加速
- 护盾
- 召唤
- 地形变化
- 机关部署

技能效果优先组件化，避免为每个角色复制近似代码。

## 13. Narrative / Unlocks

负责：

- 世界剧情节点
- 角色立场变化
- 关系阶段
- 角色解锁
- 融合配方解锁
- 特殊演出

战斗核心只读取“当前允许什么”，不直接维护剧情文本。

## 14. Save / Progress

至少保存：

- 世界/关卡进度
- 已解锁角色
- 已解锁融合配方
- 人物关系阶段
- 图鉴
- 设置

局内合成等级默认不跨关保存。

## 15. Presentation / Assets

代码引用资产 ID，不直接依赖混乱路径。

建议将资产分为：

```text
characters/
enemies/
worlds/
ui/
fx/
audio/
fonts/
```

第三方或参考资产必须记录来源与授权。

## 16. Testing

第一阶段至少需要：

- 核心规则单元测试（如果引擎/语言允许）
- Headless 或可自动运行的战斗规则测试
- 关卡最小冒烟测试
- 融合配方验证
- 存档读写验证
- 无效部署/错误配方的边界测试

## 17. 技术路线状态

最终游戏引擎尚未正式批准。

当前优先候选：Godot 4.x + GDScript；原因是 2D、开源、文本化项目文件和 Agent 开发友好，但仍需 Work 研究与 Codex 小型 PoC 后再写入正式决策。

备选路线可以研究 Unity / 其他实现，但不得在未评审前同时搭建多套正式项目。

## 强制边界

- UI 不直接实现战斗规则。
- 世界规则不得复制整套 Battle Core。
- Fusion 必须是独立核心模块。
- 数值/关卡/角色尽量数据驱动。
- 角色关系状态与单局战斗状态分离。
- 新世界不应要求重写核心塔防。
- 第三方代码/素材必须通过 License 审查。
- 技术路线未在 `docs/decisions.md` 批准前，只能做 PoC，不得视为正式架构。
