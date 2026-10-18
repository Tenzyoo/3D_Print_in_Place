# kin：一体打印活动机构 5 题 × 7 个 harness/模型组合（首轮）

题目、判分器、运行设置和失败记录的完整说明见 `kin_tasks/README.md`，指标目录见 `kin_tasks/eval/METRICS.md`。结果汇总在本目录的 `analysis/`：

| 路径 | 内容 |
|---|---|
| `analysis/report.md` | 主结果、按组合汇总、关键测量值、区分度、补跑/续跑/自动重试记录、主要发现（第 6 节，来自 `kin_tasks/analysis/findings.md`） |
| `analysis/trials.csv`、`trials.json` | 每个 trial 一行：核心四维、替代读法、连续测量、辅助检查、轨迹指标 |
| `analysis/trajectory/` | 轨迹评分原始输出：`trajectory_metrics.json`、`calls.jsonl`（每次模型调用一行）、`timelines/` |
| `analysis/transcripts/` | 每个 trial 的可读过程（四种 harness 同一格式） |
| `analysis/gallery/` | 匿名预览图（中立姿态 + 关节全部转到上限），对应关系在 `key.json` |

重跑和续跑不在本目录，在 `jobs/kin_reruns/`：

- `kin-rerun-gemini/`：Gemini CLI，T2–T5 为基础设施失败后的重跑（替换首轮），T1 为补充重跑（不替换）。
- `kin-rerun-dshgem/`：dsh + Gemini，T3–T5 基础设施失败后的重跑（替换首轮）。
- `kin-continue-dshclaude/`：dsh + Opus T1 的"人工补发 continue"，续的是本目录 `kin1-dino-tail__Fmgw63H` 的会话（不替换首轮）。

## 每个 trial 目录里有什么

| 路径 | 内容 |
|---|---|
| `agent/` | agent 的完整过程：CC / Codex / Gemini CLI 有 `trajectory.json`（Harbor ATIF 格式）和原始日志、sessions（CC 的 `sessions/projects/-app/*.jsonl` 含每次请求记录）；dsh 有 `dsh.jsonl` 事件流和 `dsh-home/sessions/` 持久化会话；经过本地 shim 的组合另有每次请求的 shim 日志 |
| `artifacts/workspace/` | 容器里 `/app` 的全部文件，交付物在 `output/` |
| `verifier/` | 运行时占位判分器的输出（只有文件清单，reward 恒为 0） |
| `regrade/` | 最终判分：`details.json`（全部测量值）、`reward.json`、`preview*.png`、`verify.log` |
| `result.json`、`trial.log` | Harbor 记录：用时、token、异常 |

**不要对本目录执行 `harbor jobs resume`**：resume 会删除没有 `result.json` 的子目录（包括 `analysis/`）。
