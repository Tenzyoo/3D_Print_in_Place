## 6. 主要发现（人工解读；每格 n=1，只作方向参考）

1. **C4 不脱落是最常见的设计失败，C1/C2 基本触顶。** 只要有交付，零件分离几乎都能过；径向间隙几乎都正好做成窗口中点 0.50 mm，唯一例外是 dsh + GPT 的伸缩棒，只有 0.15 mm。失败主要出在 C4：
   - 伸缩棒最细一节底部开口，可以从下面抽出：dsh + DeepSeek、dsh + GPT。
   - Codex 的蛇：5 个关节都没有轴向限位，沿 −轴可以整段滑脱。
   - Codex 的折叠尺：两个关节沿 +轴没有限位，销只插入 1.6 mm，可以直接提起脱开。
2. **同一个模型换 harness，差别多半来自 harness 行为，不是设计能力。**
   - Opus 5.5：Claude Code 5/5，dsh 4/5。dsh 唯一的失败是 T1：一步输出 64k token 触到上限，headless 模式直接退出。人工补发一次 continue 后，同一会话完成并拿到 4/4，但这不计入主结果。
   - Gemini 4：dsh 5/5，Gemini CLI 2/5。Gemini CLI 的 T1、T2 都没交付几何就结束了。T1 写完 `model.scad` 后，模型返回空响应，CLI 当作回合结束，正常退出。T2 模型只返回了思考、没有最终文本，CLI 记录 "returned reasoning thoughts but no final response text" 后结束，什么都没交付；补充重跑的 T1 也是这种情况。此外，每个 Gemini CLI trial 都有一次读取 `/opt` 被工作区限制挡下，还有 1–8 次 shell 命令被它自己的策略拦截。T3 是真实的设计失败：J2–J5 只能转 ±6°。
   - GPT-6.1-sol：Codex 3/5，dsh 3/5，但失败的题不同。Codex 是蛇和折叠尺的 C4。dsh 是伸缩棒（间隙 0.15 mm、底部开口）和蛇（只能转 ±13°，且 C4 不过）。
3. **成本差距比结果差距大得多。** dsh + DeepSeek 5 题共 0.54 USD，4/5 全过；Claude Code + Opus 16 USD，5/5；dsh + Gemini 也是 5/5，但最贵、最慢：308 min、23.8 USD。注意费用和用时只统计主结果那一次运行：被 Harbor 自动重试删掉的失败尝试、因基础设施故障被替换的首轮，都不在汇总里（首轮见第 5 节）。
4. **过程指标与结果大体一致。** Claude Code + Opus 最后一次改几何之后，几乎每项都重新验证过（改后复验覆盖率 0.95；dsh + Gemini 0.75，其他组合 0.20–0.65）。dsh + GPT 的过度声称最多（4 次）：文档写了满足，实测不满足。这些过程指标来自代码文本的正则启发式，只能说明做过某类检查。
5. **挑选指标的建议。**
   - 对比较 harness 没用的指标（触顶）：`bbox_ok`、`slice_nosupport_ok`、`parts_match_model`、`C4_alt_extension_only_pass`、`scad_regenerates`、`doc_slicing`、`C2_clearance_joint_frac`、`C3_motion_joint_frac`。`C1_separation` 也接近触顶（0.91），只在没交付时才失败。
   - 组合间占比较高（≥0.3）的指标：效率类（调用次数、输出 token、费用、用时，0.58–0.78），过程类（`v_coverage` 0.50、`v_coverage_after_change` 0.42），以及 `doc_orientation` 0.44、`C3_motion` 0.35、`pair_min_gap_mm` 0.34。
   - 核心四维的组合间占比只有 0.16–0.35，题目间占比 0.12–0.19。也就是说，大部分差异是"某个组合在某道题上"的个别失败，每格只跑一次时，分不清是能力差异还是偶然。C4 的两项占比都最低，但它是最常见的设计失败，建议保留，并配合重复运行。
   - 有两个组合满分，存在天花板效应。要拉开差距，有三条路：
     - 每格重复 3 次以上；
     - 加更难的题；
     - 在同一批测量上收紧阈值，例如间隙窗口收窄到 0.5±0.05 mm、要求转角裕量 ≥5°、把自动支撑段数计入打印性。这一条可以直接用 `trials.csv` 重算，不必重跑。
