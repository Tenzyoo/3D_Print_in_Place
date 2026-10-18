# 四维轨迹验证评测（独立于几何评分）

版本：1.0。支持原四组 20 条轨迹，以及全部七组 35 条轨迹（纳入重跑和续跑）；每条标注 C1～C4。不同批次各自冻结提示词与 Schema，旧输入不覆盖。

## 当前全部七组材料

完整材料在 `runs/kin_all_groups_v2/`：35 份 inputs、35 份已组合提示词的 requests、冻结协议，以及人用清单 MATERIALS.md。旧的四组材料继续保留。

重新准备全部七组：

```bash
python3 jobs/kin/trajectory_eval/run.py prepare \
  --job jobs/kin --reruns-root jobs/kin_reruns --scope all \
  --run-dir jobs/kin/trajectory_eval/runs/kin_all_groups_v2
```

同一任务和条件有多个运行时，按结束时间选择最近一次正常结束的尝试，不根据分数挑选。Gemini 独立重跑不和此前失败轨迹拼接；此前尝试保留在 private/manifest.json。Claude + DSH 的 kin1 采用人工 continue 续跑，校验续跑持久化记录完整包含原始前缀，直接读取该完整日志而不重复拼接。输入保留 intervention 消息和人工介入警示；复核表单列 manual_continue，不能当作一次完全自主完成。

以下命令均以最新 v2 七组材料为准。旧四组和 v1 批次保留历史记录，新打标使用 v2。重新 prepare 时需换用尚不存在的 run-dir。

此目录评估 **Agent 做了什么验证**。最终产物是否合格仍由现有 `regrade/` 几何评分确定，不修改原任务、原轨迹或原评分，不把轨迹标签合成为一个总分。

## 提示词与协议

- [通用协议](prompts/common.md)：角色、标签、证据、版本关联、JSON 输出。
- [C1 零件分离](prompts/C1_separation.md)。
- [C2 活动间隙](prompts/C2_clearance.md)。
- [C3 运动与干涉](prompts/C3_motion.md)。
- [C4 防脱限位](prompts/C4_retention.md)。
- [输入 Schema](input.schema.json)、[输出 Schema](output.schema.json)。

一次请求输入一个任务的完整可观察事件，加载通用提示词和四个维度规则，一次输出四条标签。这样每个任务只调用一次 Judge，且四维共享相同证据。更改提示词后应重新 prepare 到新目录，不能混用协议。

| 标签 | 定义 |
|---|---|
| `verified` | 执行了对象、范围、判据合理的检查，并得到可解释结果；结果失败也可记为 verified |
| `attempted_insufficient` | 尝试过，但方法或覆盖不足，或没有得到有效执行结果 |
| `no_evidence` | 可观察记录足够，但未发现该维度的检查尝试 |
| `unknown` | 证据不足、截断或无法判断 |

`outcome` 是 Agent 所做检查的结果，不是最终几何真值。`final_version.status` 为 yes/no/unknown；`self_check` 记录明确自检结论及其针对的版本。没有检查不能根据最终结果反推覆盖；有检查也不保证方法绝对正确。

## 输入与输出

输入顶层：

```json
{
  "schema_version": "1.0",
  "case_id": "case_001",
  "task_instruction": "完整题目",
  "warnings": ["本轨迹的材料限制"],
  "events": [
    {"id": "E00001", "kind": "tool_call", "call_id": "call_1", "tool": "bash", "text": "调用参数/实际代码"},
    {"id": "E00002", "kind": "tool_result", "call_id": "call_1", "tool": "", "text": "实际返回结果"}
  ]
}
```

输出顶层为 `schema_version`、`case_id`、`dimensions`；dimensions 必须恰好按 C1、C2、C3、C4 排列。每条包含：

```json
{
  "dimension": "C1",
  "label": "unknown",
  "method": "",
  "outcome": "unknown",
  "evidence": [],
  "final_version": {"status": "unknown", "reason": "模型版本关联无法确定", "evidence": []},
  "self_check": {"verdict": "none", "target": "unknown", "evidence": []},
  "reason": "示例占位，实际标注必须依据输入证据",
  "limitations": ["示例并非真实评测结果"]
}
```

每条 evidence 包含 `event_id`、`role`、`quote`。role 为 action/result/claim/version/context；quote 必须是所引事件 text 的连续逐字摘录。程序验证 Schema、维度完整性、事件存在、逐字引用及基本标签一致性。程序不能证明检查算法正确，也不能自动证明跨异步调用的语义关联；这些由 Judge 初标和人工复核完成。

## 执行

在仓库根目录运行。需要 Python 3 和 `jsonschema`；环境缺少时安装 `jobs/kin/trajectory_eval/requirements.txt` 中的依赖。

### 1. 整理输入，无 API 调用

```bash
python3 jobs/kin/trajectory_eval/run.py prepare \
  --job jobs/kin --reruns-root jobs/kin_reruns --scope all \
  --run-dir jobs/kin/trajectory_eval/runs/kin_all_groups_v2
```

选择全部七组，每组五题，共 35 条最近正常结束的运行。缺少任何条件/任务组合时停止；不根据评分挑选尝试。若需另建原四组批次，可显式使用 --scope four 和新的目录。

准备时使用固定随机种子生成不含组名的 case_id。Judge 请求不含组名映射、独立评分和原始文件路径；轨迹自身可能透露工具或模型身份，因此是尽量隐藏标签，**不宣称严格盲评**。

DSH 优先读取与主 session_id 匹配的持久化 `session.v4.jsonl`，避免短 `dsh.jsonl` 的截断。Claude/Codex 使用 ATIF `trajectory.json`。Gemini CLI 使用原始 `gemini-cli.trajectory.jsonl`，保留 ATIF 转换可能漏掉的失败和权限拒绝返回，并去重重复消息。不发送隐藏推理、系统提示和图像，不把运行后的脚本内容冒充执行当时的脚本。原始工具输出自身的截断、未展开子 Agent 和图像缺失需结合 warnings 判定。

不自动裁剪长输入，不用关键词检索取代完整轨迹。选 Judge 前检查 `preparation.json` 的输入大小，并选择足够上下文的模型；字节数不是 token 数。上下文超限应保留失败，另行设计分段方案，不静默丢弃内容。

生成目录：

```text
runs/kin_all_groups_v2/
  inputs/case_001.json                # 可送 Judge 的输入
  requests/case_001.json              # 已组装冻结提示词的 Judge 请求
  protocol/prompts/                   # 本轮冻结的提示词副本
  protocol/*.schema.json
  preparation.json                   # 输入数量、大小；Judge 调用数为 0
  private/manifest.json               # 组别映射、来源、重试记录、SHA256
  private/source_maps/case_001.json    # 事件到原文件行号/JSON位置
  private/grades/case_001.json         # 冻结的正式评分；不送 Judge
  private/raw/case_001/               # 原始轨迹、题目、配置、运行结果与评分快照
  private/restoration/case_001.json    # 由原始快照复原输入的配方与哈希
  private/implementation/             # 冻结的执行和审计脚本
  audit/report.md                    # 全量审计报告
```

已存在的 run-dir 会拒绝覆盖。输入、正式评分及协议均保留摘要用于追溯。

### 2. 调用 Judge（两种接口任选一种）

先用 `--limit 2` 试标，人工校准；固定协议后再标全部。不要为达到某个结果调整提示词。建议至少复核全部 35 条；如由多人独立标注，可另设各自的 Judge/人工记录并记录分歧。

HTTP 模式使用完整 Chat Completions 兼容 URL。密钥仅从指定环境变量读取，不自动读取仓库 `.env`、不自动选择被测模型作 Judge。

```bash
export JUDGE_API_KEY='你的密钥'
python3 jobs/kin/trajectory_eval/run.py judge \
  --run-dir jobs/kin/trajectory_eval/runs/kin_all_groups_v2 \
  --judge-id judge_v1 \
  --model '明确的Judge模型版本' \
  --endpoint 'https://你的接口/v1/chat/completions' \
  --extra-body '{"max_completion_tokens":12000}' \
  --limit 2
```

不同兼容端点的预算参数可能是 `max_tokens`；按实际接口调整 extra-body。不支持 JSON mode 时加 `--response-format none`，本地仍严格验证 JSON。HTTP 响应必须以 `finish_reason=stop` 正常结束；截断响应不会被当作标注。兼容协议不保证任意供应商/模型均支持，需要用真实端点试标。

若现有客户端使用 Responses、Anthropic、Gemini 等接口，采用命令模式：客户端从 stdin 读取 `{"messages":[...]}`，转换到其协议，并在 stdout 只输出符合输出 Schema 的标注 JSON，调试信息写 stderr。脚本不通过 shell 执行命令。

```bash
python3 jobs/kin/trajectory_eval/run.py judge \
  --run-dir jobs/kin/trajectory_eval/runs/kin_all_groups_v2 \
  --judge-id judge_v1 \
  --model '明确的Judge模型版本' \
  --command 'python3 /路径/你的judge客户端.py' \
  --limit 2
```

`--case case_001` 可挑选 case，可重复传入。去掉 limit 处理剩余全部；已有合法标注会跳过。失败后不会偷偷重复请求，重新执行会在新编号 attempt 中保留新的请求/返回。不同配置应使用不同 judge-id，避免混淆版本。不得把密钥写入 command/extra-body/endpoint。

### 3. 本地校验与汇总

```bash
python3 jobs/kin/trajectory_eval/run.py validate \
  --run-dir jobs/kin/trajectory_eval/runs/kin_all_groups_v2 --judge-id judge_v1
python3 jobs/kin/trajectory_eval/run.py summarize \
  --run-dir jobs/kin/trajectory_eval/runs/kin_all_groups_v2 --judge-id judge_v1
```

结果保存在 `judges/judge_v1/`：config.json、annotations/、attempts/（原始请求/返回、时间、usage、哈希、失败记录）、reports/review.csv 和 reports/summary.md。

汇总逐组、逐维度展示四种标签计数、最终版本覆盖 yes/no/unknown，以及应标注和已标注数量。未知和缺失不算失败，也不生成整体总分。若需要比率，应同时报告有效分母与未知数量。

独立评分只在 summarize 的第二阶段引入。“明确声称最终版本通过 + 独立评分失败”仅生成 **误判候选**，不自动认定误判；人工需核实版本和判据一致。所有行 human_review 初始为 pending，summary 明确标为待复核。人工结果应另存（例如 reviewed.csv，并增加 reviewer/reviewed_at/review_note），保留 Judge 原标，不能直接覆盖 annotations 冒充原输出。本版不自动生成“人工审定”的排名。

## 全量检查与独立复原

最新材料已完成全量审计：35 份输入和请求均能从 private/raw 和 source_maps 复原，且与冻结 input/request 的 SHA256 完全一致。private 保存的是实际留存的原始会话日志，不承诺包含逐次完整 HTTP 请求，也不恢复已被覆盖的中间 CAD。

审计：

```bash
python3 jobs/kin/trajectory_eval/audit.py \
  --run-dir jobs/kin/trajectory_eval/runs/kin_all_groups_v2
```

复原到新目录，不改现有材料；输出目录必须尚不存在：

```bash
python3 jobs/kin/trajectory_eval/run.py restore \
  --run-dir jobs/kin/trajectory_eval/runs/kin_all_groups_v2 \
  --out-dir /tmp/kin_trajectory_restored
```

restore 不读取原 jobs 中的日志，也不读取现成 inputs/requests 来伪装复原，而是读取 private 原始快照、事件定位和冻结协议，重新生成全部输入与请求并检查字节哈希。主会话证据、截图未提供和子 Agent 未展开的限制，仍如实保留在 warnings。

`private/implementation/` 保存本批使用的脚本版本与哈希。完整材料连同源码保留在仓库中；不要只拷走 inputs 后删除 private 和 protocol。`MATERIALS.md`、`audit/` 及 private 可能显示组名，只有 inputs、requests 中的材料用于 Judge。

材料准备和本地执行链已验证；真实 Judge 的模型版本、端点、密钥和上下文容量仍须配置并试标，不属于已完成的远程接口测试。

## 复现与局限

- 保存原始请求、响应、Judge 配置、输入和提示词摘要；再次运行不是确定性保证。
- 请求失败、返回非法 JSON、缺证据和证据捏造会留记录，不伪装成正常评分。
- 原批次重试前的轨迹被 Harbor 删除，本轮只分析最后一次正常结束的轨迹；manifest 保留 prior_retries 标记。
- 不计算首次成功率/修复成功率；尚未恢复并独立评价中间 CAD 版本。
- 不能把文字 Judge 当作几何求解器；不执行 Agent 轨迹中的代码或命令。
- kind=intervention 记录人工 continue；其本身不是验证行为。子 Agent 未展开、图像未提供等限制仍应按每条输入 warnings 判断。

## 验证开发流程

```bash
python3 -m unittest discover -s jobs/kin/trajectory_eval/tests -v
```

测试只使用模拟返回和临时目录，不产生真实 Judge 成绩，也不调用远程模型。

HTTP 请求格式参考 [OpenAI Docs：Chat Completions](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)。这里选择兼容接口便于更换供应商，不绑定默认 Judge。
