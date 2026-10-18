# 最终 35 个产出的四维评分

核对时间：2026-10-18T22:49:12+08:00。

选取口径：七组各五题，每个条件/任务取最近一次正常结束的运行，与 `trajectory_eval/runs/kin_all_groups_v2` 的 35 个 case 一致。分数直接读取各运行的 `regrade/reward.json`，并与已冻结的评分逐条核对。

本表包含 Claude + DeepSeek Harness 的 kin1 人工 continue 续跑，以及 Gemini CLI 的 kin1 补充重跑。它呈现最终产物情况；运行结束不等于四维合格，也不等于首轮自主完成。

四项分别按 0/1 判断：C1 零件分离、C2 活动间隙、C3 运动范围与干涉、C4 轴向防脱。1 = 满足，0 = 不满足；“整体通过”仅在四项均为 1 时为“是”。不另列四维平均总分。

## 分组汇总

| 模型 | Harness | C1 分离 | C2 间隙 | C3 运动 | C4 防脱 | 整体通过 |
|---|---|---:|---:|---:|---:|---:|
| deepseek-flash | DeepSeek Harness | 5/5 | 5/5 | 5/5 | 4/5 | 4/5 |
| claude-opus-5-5 | Claude Code | 5/5 | 5/5 | 5/5 | 5/5 | 5/5 |
| gpt-6.1-sol | Codex CLI | 5/5 | 5/5 | 5/5 | 3/5 | 3/5 |
| gemini-4-argon-high | Gemini CLI | 3/5 | 3/5 | 2/5 | 3/5 | 2/5 |
| claude-opus-5-5 | DeepSeek Harness | 5/5 | 5/5 | 5/5 | 5/5 | 5/5 |
| gpt-6.1-sol | DeepSeek Harness | 5/5 | 4/5 | 4/5 | 3/5 | 3/5 |
| gemini-4-argon-high | DeepSeek Harness | 5/5 | 5/5 | 5/5 | 5/5 | 5/5 |
| **合计** | **35 个产出** | 33/35 | 32/35 | 31/35 | 28/35 | **27/35** |

## 逐产出明细（35 行）

评分来源链接可直接定位到采用的运行及其正式评分。

| 模型 | Harness | 任务 | C1 | C2 | C3 | C4 | 整体通过 | 采用的运行 | 评分来源 |
|---|---|---|---:|---:|---:|---:|---|---|---|
| deepseek-flash | DeepSeek Harness | kin1 恐龙尾巴 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin1-dino-tail__xfCUxLG](../kin1-dino-tail__xfCUxLG/regrade/reward.json) |
| deepseek-flash | DeepSeek Harness | kin2 伸缩杆 | 1 | 1 | 1 | 0 | 否 | 原批次 | [kin2-telescoping-rod__X3Gp4cN](../kin2-telescoping-rod__X3Gp4cN/regrade/reward.json) |
| deepseek-flash | DeepSeek Harness | kin3 小蛇 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin3-snake__MefefAZ](../kin3-snake__MefefAZ/regrade/reward.json) |
| deepseek-flash | DeepSeek Harness | kin4 蝴蝶 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin4-butterfly__oWV2LbT](../kin4-butterfly__oWV2LbT/regrade/reward.json) |
| deepseek-flash | DeepSeek Harness | kin5 折叠尺 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin5-folding-ruler__V8cGzeV](../kin5-folding-ruler__V8cGzeV/regrade/reward.json) |
| claude-opus-5-5 | Claude Code | kin1 恐龙尾巴 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin1-dino-tail__D5NP7Bo](../kin1-dino-tail__D5NP7Bo/regrade/reward.json) |
| claude-opus-5-5 | Claude Code | kin2 伸缩杆 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin2-telescoping-rod__ZdkdKz9](../kin2-telescoping-rod__ZdkdKz9/regrade/reward.json) |
| claude-opus-5-5 | Claude Code | kin3 小蛇 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin3-snake__vCWFkG3](../kin3-snake__vCWFkG3/regrade/reward.json) |
| claude-opus-5-5 | Claude Code | kin4 蝴蝶 | 1 | 1 | 1 | 1 | 是 | 原批次（自动重试 2 次） | [kin4-butterfly__Xm8Q3Qu](../kin4-butterfly__Xm8Q3Qu/regrade/reward.json) |
| claude-opus-5-5 | Claude Code | kin5 折叠尺 | 1 | 1 | 1 | 1 | 是 | 原批次（自动重试 1 次） | [kin5-folding-ruler__zPq5bwT](../kin5-folding-ruler__zPq5bwT/regrade/reward.json) |
| gpt-6.1-sol | Codex CLI | kin1 恐龙尾巴 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin1-dino-tail__k9qPpno](../kin1-dino-tail__k9qPpno/regrade/reward.json) |
| gpt-6.1-sol | Codex CLI | kin2 伸缩杆 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin2-telescoping-rod__RpQG8Uh](../kin2-telescoping-rod__RpQG8Uh/regrade/reward.json) |
| gpt-6.1-sol | Codex CLI | kin3 小蛇 | 1 | 1 | 1 | 0 | 否 | 原批次 | [kin3-snake__Wo8EULy](../kin3-snake__Wo8EULy/regrade/reward.json) |
| gpt-6.1-sol | Codex CLI | kin4 蝴蝶 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin4-butterfly__5Bs7Qdd](../kin4-butterfly__5Bs7Qdd/regrade/reward.json) |
| gpt-6.1-sol | Codex CLI | kin5 折叠尺 | 1 | 1 | 1 | 0 | 否 | 原批次 | [kin5-folding-ruler__CyoDRRC](../kin5-folding-ruler__CyoDRRC/regrade/reward.json) |
| gemini-4-argon-high | Gemini CLI | kin1 恐龙尾巴 | 0 | 0 | 0 | 0 | 否 | 独立重跑 | [kin1-dino-tail__Dpvn5EE](../../kin_reruns/kin-rerun-gemini/kin1-dino-tail__Dpvn5EE/regrade/reward.json) |
| gemini-4-argon-high | Gemini CLI | kin2 伸缩杆 | 0 | 0 | 0 | 0 | 否 | 独立重跑 | [kin2-telescoping-rod__6E2BzWz](../../kin_reruns/kin-rerun-gemini/kin2-telescoping-rod__6E2BzWz/regrade/reward.json) |
| gemini-4-argon-high | Gemini CLI | kin3 小蛇 | 1 | 1 | 0 | 1 | 否 | 独立重跑 | [kin3-snake__b2Lh2UU](../../kin_reruns/kin-rerun-gemini/kin3-snake__b2Lh2UU/regrade/reward.json) |
| gemini-4-argon-high | Gemini CLI | kin4 蝴蝶 | 1 | 1 | 1 | 1 | 是 | 独立重跑 | [kin4-butterfly__t37eaXg](../../kin_reruns/kin-rerun-gemini/kin4-butterfly__t37eaXg/regrade/reward.json) |
| gemini-4-argon-high | Gemini CLI | kin5 折叠尺 | 1 | 1 | 1 | 1 | 是 | 独立重跑 | [kin5-folding-ruler__79his4v](../../kin_reruns/kin-rerun-gemini/kin5-folding-ruler__79his4v/regrade/reward.json) |
| claude-opus-5-5 | DeepSeek Harness | kin1 恐龙尾巴 | 1 | 1 | 1 | 1 | 是 | 人工 continue 续跑 | [kin1-dino-tail__Hu4Dx4R](../../kin_reruns/kin-continue-dshclaude/kin1-dino-tail__Hu4Dx4R/regrade/reward.json) |
| claude-opus-5-5 | DeepSeek Harness | kin2 伸缩杆 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin2-telescoping-rod__ib6VAX8](../kin2-telescoping-rod__ib6VAX8/regrade/reward.json) |
| claude-opus-5-5 | DeepSeek Harness | kin3 小蛇 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin3-snake__fGjp8uK](../kin3-snake__fGjp8uK/regrade/reward.json) |
| claude-opus-5-5 | DeepSeek Harness | kin4 蝴蝶 | 1 | 1 | 1 | 1 | 是 | 原批次（自动重试 1 次） | [kin4-butterfly__Utgg9AD](../kin4-butterfly__Utgg9AD/regrade/reward.json) |
| claude-opus-5-5 | DeepSeek Harness | kin5 折叠尺 | 1 | 1 | 1 | 1 | 是 | 原批次（自动重试 1 次） | [kin5-folding-ruler__yPgNqnw](../kin5-folding-ruler__yPgNqnw/regrade/reward.json) |
| gpt-6.1-sol | DeepSeek Harness | kin1 恐龙尾巴 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin1-dino-tail__b4SPQRt](../kin1-dino-tail__b4SPQRt/regrade/reward.json) |
| gpt-6.1-sol | DeepSeek Harness | kin2 伸缩杆 | 1 | 0 | 1 | 0 | 否 | 原批次 | [kin2-telescoping-rod__dSDARSE](../kin2-telescoping-rod__dSDARSE/regrade/reward.json) |
| gpt-6.1-sol | DeepSeek Harness | kin3 小蛇 | 1 | 1 | 0 | 0 | 否 | 原批次 | [kin3-snake__zNrUpEf](../kin3-snake__zNrUpEf/regrade/reward.json) |
| gpt-6.1-sol | DeepSeek Harness | kin4 蝴蝶 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin4-butterfly__xH7gSdL](../kin4-butterfly__xH7gSdL/regrade/reward.json) |
| gpt-6.1-sol | DeepSeek Harness | kin5 折叠尺 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin5-folding-ruler__gcvLA9V](../kin5-folding-ruler__gcvLA9V/regrade/reward.json) |
| gemini-4-argon-high | DeepSeek Harness | kin1 恐龙尾巴 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin1-dino-tail__CWUviex](../kin1-dino-tail__CWUviex/regrade/reward.json) |
| gemini-4-argon-high | DeepSeek Harness | kin2 伸缩杆 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin2-telescoping-rod__mtxSGet](../kin2-telescoping-rod__mtxSGet/regrade/reward.json) |
| gemini-4-argon-high | DeepSeek Harness | kin3 小蛇 | 1 | 1 | 1 | 1 | 是 | 独立重跑 | [kin3-snake__NSqNmYD](../../kin_reruns/kin-rerun-dshgem/kin3-snake__NSqNmYD/regrade/reward.json) |
| gemini-4-argon-high | DeepSeek Harness | kin4 蝴蝶 | 1 | 1 | 1 | 1 | 是 | 独立重跑 | [kin4-butterfly__LoT6i9W](../../kin_reruns/kin-rerun-dshgem/kin4-butterfly__LoT6i9W/regrade/reward.json) |
| gemini-4-argon-high | DeepSeek Harness | kin5 折叠尺 | 1 | 1 | 1 | 1 | 是 | 独立重跑 | [kin5-folding-ruler__PuYxogg](../../kin_reruns/kin-rerun-dshgem/kin5-folding-ruler__PuYxogg/regrade/reward.json) |

## 特殊运行说明

- Claude + DeepSeek Harness / kin1：采用 `kin1-dino-tail__Hu4Dx4R`，人工补发一次 continue 后完成。四维均通过，但必须保留人工介入标记。
- Gemini CLI / kin1：采用最新补充重跑 `kin1-dino-tail__Dpvn5EE`；运行正常结束，正式四维评分仍为 `[0, 0, 0, 0]`。
- 自动重试次数来自运行日志；未拼接已被 Harbor 删除的失败尝试。
- 此表是最终产物几何评分，不含 LLM Judge 轨迹标注结果。
