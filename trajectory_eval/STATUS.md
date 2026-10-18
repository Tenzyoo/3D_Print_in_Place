# 当前交付状态

- 提示词：通用协议与 C1～C4 四份规则已完成。
- 输入输出：JSON Schema 已生成，输出必须包含四维标签与逐字证据。
- 执行器：prepare / restore / judge / validate / summarize 已实现，另有 audit.py；支持 HTTP 兼容端点和外部命令。
- 最新完整材料：`runs/kin_all_groups_v2/` 已准备 35 条轨迹、35 份完整 Judge 请求，七组各 5 条，对应 140 个待标注维度。入口为该目录的 MATERIALS.md；CURRENT_RUN.txt 指向本批次。
- 原四组材料：`runs/kin_four_groups_v1/` 的 20 条输入继续保留，是此前冻结的独立批次，不与新批次混用 case_id。
- 选取策略：每个条件/任务选择最近一次正常结束的运行，不根据评分选择。其他尝试在 private/manifest.json 中留记录。
- Claude + DSH kin1：采用含完整原始前缀的人工 continue 续跑；原始前缀已校验，外部 continue 消息已保留并明确标记，不视为一次完全自主完成。
- v2 修复：改用 Gemini 原始日志，补回通用 ATIF 转换遗漏的 19 个工具返回；目前所有主会话工具调用与返回均配对。
- 独立复原：private/raw 保存 212 份原始材料快照；private/restoration 保存 35 份复原配方，private/implementation 冻结脚本。35 份输入与请求全部实际复原成功，SHA256 逐字节一致，不依赖外部原始日志。
- 本地验证：12 项自动测试通过；35 个 case、3,548 个证据事件均通过 Schema、来源定位、哈希、评分隔离及续跑前缀检查。详细结果在 runs/kin_all_groups_v2/audit/report.md 与 restoration_smoke.json。
- 历史批次：v1 及原四组保留原始输入并标记 SUPERSEDED.md，不作为新打标入口。
- 正式 Judge 调用：0。尚未指定 Judge 模型/版本和接口，当前没有真实标注结果或轨迹得分。
- 模拟测试只在临时目录执行，没有混入真实运行目录。

下一步：按 README 配置 Judge，先试标 2 条并人工校准，再冻结协议标注全部。人工复核后才可报告审定的轨迹指标。

范围说明：本轮“复原”指由留存的会话日志还原打标输入和请求，不代表恢复全部 HTTP 请求、中间 CAD 版本或不可见子 Agent/图像；这些限制已在协议和各输入 warnings 中说明。
