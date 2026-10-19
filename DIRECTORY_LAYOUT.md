# kin 运行目录约定

- 当前 Gemini CLI kin1：`kin1-dino-tail__R5UU3tN/`。
- 当前 Gemini CLI kin2：`kin2-telescoping-rod__UG26tuq/`。
- 两个首轮旧目录已改名为 `kin1-dino-tail__MGRvcYz__deprecated/`、`kin2-telescoping-rod__wqTauSA__deprecated/`。
- 单次任务目录保留原有 agent/、artifacts/、verifier/、config.json、result.json、trial.log 等结构，已有 regrade/ 也保留。
- 带 SUPERSEDED.md 或以 __deprecated 结尾的目录被当前汇总及轨迹选取脚本跳过。
- 根目录 result.json 保留 Harbor 历史批次统计；analysis/ 和 stl_models/ 已按最新两项更新。最新统一评分见 analysis/final_35_scores.md；新轨迹输入在 trajectory_eval/runs/kin_all_groups_v3/。
- 最新来源映射：gemini_cli_t12_supersession.json。旧版冻结评测中的绝对路径保留为历史，现址由 _directory_migrations/gemini-cli-t12-20261019/migration.json 映射。
