# 最新 35 个产出的四维评分

更新时间：2026-10-19T14:49:38.640757+00:00。

来源口径：`jobs/kin/trajectory_eval/runs/kin_all_groups_v3` 的 35 条冻结清单；七组各五题，每个条件/任务取最新正常结束且未标废弃的运行。
本次替换 Gemini CLI 的 kin1、kin2；其余 33 条产物评分保持原样。Claude + DSH kin1 仍采用人工 continue 续跑，保留介入标记。

C1 零件分离、C2 活动间隙、C3 运动范围与干涉、C4 轴向防脱各按 0/1 判断；整体通过要求四项均为 1。

## 本次替换

| 任务 | 新运行 | 旧 C1/C2/C3/C4 | 新 C1/C2/C3/C4 |
|---|---|---|---|
| Gemini CLI / kin1 恐龙尾巴 | kin1-dino-tail__R5UU3tN | 0/0/0/0 | 1/1/1/1 |
| Gemini CLI / kin2 伸缩杆 | kin2-telescoping-rod__UG26tuq | 0/0/0/0 | 1/1/1/1 |

两项目前仅完成本地 --skip-slow 核心几何评估，尚未统一完整流程。切片、OpenSCAD 重建和 VTK 预览未执行，不补填辅助结果；当前表为待完整重评的临时汇总。 判分器及冻结配置不变，环境记录见各新运行 regrade/execution_environment.json。

辅助交付情况仍需区分：kin1 未交付 joints.json/report.json，四项几何通过不表示交付文件齐全。

## 分组汇总

| 模型 | Harness | C1 | C2 | C3 | C4 | 整体通过 |
|---|---|---:|---:|---:|---:|---:|
| deepseek-flash | DeepSeek Harness | 5/5 | 5/5 | 5/5 | 4/5 | 4/5 |
| claude-opus-5-5 | Claude Code | 5/5 | 5/5 | 5/5 | 5/5 | 5/5 |
| gpt-6.1-sol | Codex CLI | 5/5 | 5/5 | 5/5 | 3/5 | 3/5 |
| gemini-4-argon-high | Gemini CLI | 5/5 | 5/5 | 4/5 | 5/5 | 4/5 |
| claude-opus-5-5 | DeepSeek Harness | 5/5 | 5/5 | 5/5 | 5/5 | 5/5 |
| gpt-6.1-sol | DeepSeek Harness | 5/5 | 4/5 | 4/5 | 3/5 | 3/5 |
| gemini-4-argon-high | DeepSeek Harness | 5/5 | 5/5 | 5/5 | 5/5 | 5/5 |
| **合计** | **35 个产出** | 35/35 | 34/35 | 33/35 | 30/35 | 29/35 |

## 逐产出明细

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
| claude-opus-5-5 | Claude Code | kin4 蝴蝶 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin4-butterfly__Xm8Q3Qu](../kin4-butterfly__Xm8Q3Qu/regrade/reward.json) |
| claude-opus-5-5 | Claude Code | kin5 折叠尺 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin5-folding-ruler__zPq5bwT](../kin5-folding-ruler__zPq5bwT/regrade/reward.json) |
| gpt-6.1-sol | Codex CLI | kin1 恐龙尾巴 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin1-dino-tail__k9qPpno](../kin1-dino-tail__k9qPpno/regrade/reward.json) |
| gpt-6.1-sol | Codex CLI | kin2 伸缩杆 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin2-telescoping-rod__RpQG8Uh](../kin2-telescoping-rod__RpQG8Uh/regrade/reward.json) |
| gpt-6.1-sol | Codex CLI | kin3 小蛇 | 1 | 1 | 1 | 0 | 否 | 原批次 | [kin3-snake__Wo8EULy](../kin3-snake__Wo8EULy/regrade/reward.json) |
| gpt-6.1-sol | Codex CLI | kin4 蝴蝶 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin4-butterfly__5Bs7Qdd](../kin4-butterfly__5Bs7Qdd/regrade/reward.json) |
| gpt-6.1-sol | Codex CLI | kin5 折叠尺 | 1 | 1 | 1 | 0 | 否 | 原批次 | [kin5-folding-ruler__CyoDRRC](../kin5-folding-ruler__CyoDRRC/regrade/reward.json) |
| gemini-4-argon-high | Gemini CLI | kin1 恐龙尾巴 | 1 | 1 | 1 | 1 | 是 | 替代重跑 | [kin1-dino-tail__R5UU3tN](../kin1-dino-tail__R5UU3tN/regrade/reward.json) |
| gemini-4-argon-high | Gemini CLI | kin2 伸缩杆 | 1 | 1 | 1 | 1 | 是 | 替代重跑 | [kin2-telescoping-rod__UG26tuq](../kin2-telescoping-rod__UG26tuq/regrade/reward.json) |
| gemini-4-argon-high | Gemini CLI | kin3 小蛇 | 1 | 1 | 0 | 1 | 否 | 独立重跑 | [kin3-snake__b2Lh2UU](../../kin_reruns/kin-rerun-gemini/kin3-snake__b2Lh2UU/regrade/reward.json) |
| gemini-4-argon-high | Gemini CLI | kin4 蝴蝶 | 1 | 1 | 1 | 1 | 是 | 独立重跑 | [kin4-butterfly__t37eaXg](../../kin_reruns/kin-rerun-gemini/kin4-butterfly__t37eaXg/regrade/reward.json) |
| gemini-4-argon-high | Gemini CLI | kin5 折叠尺 | 1 | 1 | 1 | 1 | 是 | 独立重跑 | [kin5-folding-ruler__79his4v](../../kin_reruns/kin-rerun-gemini/kin5-folding-ruler__79his4v/regrade/reward.json) |
| claude-opus-5-5 | DeepSeek Harness | kin1 恐龙尾巴 | 1 | 1 | 1 | 1 | 是 | 人工 continue 续跑 | [kin1-dino-tail__Hu4Dx4R](../../kin_reruns/kin-continue-dshclaude/kin1-dino-tail__Hu4Dx4R/regrade/reward.json) |
| claude-opus-5-5 | DeepSeek Harness | kin2 伸缩杆 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin2-telescoping-rod__ib6VAX8](../kin2-telescoping-rod__ib6VAX8/regrade/reward.json) |
| claude-opus-5-5 | DeepSeek Harness | kin3 小蛇 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin3-snake__fGjp8uK](../kin3-snake__fGjp8uK/regrade/reward.json) |
| claude-opus-5-5 | DeepSeek Harness | kin4 蝴蝶 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin4-butterfly__Utgg9AD](../kin4-butterfly__Utgg9AD/regrade/reward.json) |
| claude-opus-5-5 | DeepSeek Harness | kin5 折叠尺 | 1 | 1 | 1 | 1 | 是 | 原批次 | [kin5-folding-ruler__yPgNqnw](../kin5-folding-ruler__yPgNqnw/regrade/reward.json) |
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

## 轨迹与模型汇集

- 这份表是独立几何评分，未把 Judge 轨迹标签当作产物真值。
- 新轨迹批次中 case_001、case_031 待评测；其余 33 条输入、请求、评分及来源哈希与 v2 一致，复用原标注。
- stl_models/ 现有 35 份完整模型，manifest.csv 的来源与此表逐条一致，SHA256 均已核对。
- 原评分表及模型清单备份在 ../_directory_migrations/gemini-cli-t12-20261019/data_update_backup/。
