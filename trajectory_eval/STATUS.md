# 当前交付状态

当前批次为 `runs/kin_all_groups_v3/`，CURRENT_RUN.txt 已切换。旧 v2 保留，不能把其 case_001/case_031 的标签用于新轨迹。

- 最新 35 条来源：七组各五题。Gemini CLI kin1/kin2 采用 `jobs/kin/kin1-dino-tail__R5UU3tN`、`jobs/kin/kin2-telescoping-rod__UG26tuq`；废弃目录已标记并被选取脚本跳过。
- 新两项 C1–C4 均为 [1,1,1,1]，正式评分在各自 regrade/。判分器和冻结配置未变；Docker 不可用，本次本地运行 --skip-slow，核心四项完成，切片、重建与预览未执行。环境记录在 execution_environment.json。
- 最新几何评分：`jobs/kin/analysis/final_35_scores.md`，四项全过 29/35。trials.csv/json、report.md、可读轨迹与过程指标已刷新。
- 模型汇集：`jobs/kin/stl_models/` 共 35 个完整模型，manifest.csv 与最新 35 条来源逐条一致，SHA256 全部通过。
- 新轨迹输入：35 条、140 个维度、3,699 个证据事件；212 份原始材料快照全部通过哈希和逐字节复原审计，详见 v3/audit/report.md。
- 新增两条现均已取得标注：case_001 由用户第二次调用直接通过；case_031 第二次返回的 12 处 JSON 换行引用转义已离线恢复并通过校验，原始响应与判断不变。当前 v3 共 35/35 条标注通过程序校验，仍待人工语义复核。
- 已复用：其余 33 条输入/请求/来源/协议/几何评分哈希与 v2 相同，对应 132 个维度保留原合法标注及原始 attempt、引用修订来源记录。全部仍待人工语义复核。
- 用户已实际调用新增两条 Judge；本次 case_031 修复未发起 API 请求。v3 当前无需为这次格式错误再重跑；完整 Docker 几何重评和后续 v4 流程为独立步骤。
- 新旧来源/案例映射：v3/private/version_mapping.json；人用清单：v3/MATERIALS.md、v3/private/inventory.csv。几何评分位于 private，不进入 Judge 请求。
- 冻结协议、规范化与复原脚本快照位于 v3/protocol/ 和 v3/private/implementation/。不静默修改旧输入、不把旧标签改名用于新轨迹。

历史 v2：35/35 旧案例已通过引用校验，其中 15 条自动格式恢复、3 条经用户授权由助手审校引用；全部待人工语义复核。新批次仅复用来源完全一致的 33 条。人工 continue、子 Agent 未展开、原输出可能截断、图像不可见等限制继续保留在各输入 warnings。

流程一致性复核：其他 33 条均有切片、SCAD 重建和预览，新增两条目前仅局部核心评分。统一重评入口为 bash kin_tasks/regrade_gemini_t12_full.sh，需在有 Docker 权限的服务器终端执行；成功后生成 v4 并切换 CURRENT_RUN。当前 v3 两条 Judge 请求均因引用校验失败，原始响应保留。本工具尚未执行完整 Docker 重评。
