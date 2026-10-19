# 完整评分流程核对

当前最新 35 条中，33 条都有切片记录、OpenSCAD 重建记录和 preview.png；新增 Gemini CLI kin1/kin2 缺少这三项。
标准 regrade.sh 未传 --skip-slow。新两条当前评分是局部核心评估，不应描述为完整统一重评。

| case | 运行 | 切片记录 | 重建记录 | 预览 |
|---|---|---|---|---|
| case_001 | kin1-dino-tail__R5UU3tN | False | False | False |
| case_002 | kin5-folding-ruler__yPgNqnw | True | True | True |
| case_003 | kin5-folding-ruler__V8cGzeV | True | True | True |
| case_004 | kin4-butterfly__LoT6i9W | True | True | True |
| case_005 | kin1-dino-tail__D5NP7Bo | True | True | True |
| case_006 | kin2-telescoping-rod__ib6VAX8 | True | True | True |
| case_007 | kin3-snake__zNrUpEf | True | True | True |
| case_008 | kin4-butterfly__xH7gSdL | True | True | True |
| case_009 | kin3-snake__Wo8EULy | True | True | True |
| case_010 | kin2-telescoping-rod__X3Gp4cN | True | True | True |
| case_011 | kin1-dino-tail__CWUviex | True | True | True |
| case_012 | kin1-dino-tail__xfCUxLG | True | True | True |
| case_013 | kin3-snake__vCWFkG3 | True | True | True |
| case_014 | kin5-folding-ruler__gcvLA9V | True | True | True |
| case_015 | kin4-butterfly__oWV2LbT | True | True | True |
| case_016 | kin4-butterfly__5Bs7Qdd | True | True | True |
| case_017 | kin5-folding-ruler__PuYxogg | True | True | True |
| case_018 | kin1-dino-tail__b4SPQRt | True | True | True |
| case_019 | kin2-telescoping-rod__dSDARSE | True | True | True |
| case_020 | kin1-dino-tail__Hu4Dx4R | True | True | True |
| case_021 | kin4-butterfly__t37eaXg | True | True | True |
| case_022 | kin3-snake__NSqNmYD | True | True | True |
| case_023 | kin4-butterfly__Utgg9AD | True | True | True |
| case_024 | kin5-folding-ruler__79his4v | True | True | True |
| case_025 | kin2-telescoping-rod__ZdkdKz9 | True | True | True |
| case_026 | kin3-snake__fGjp8uK | True | True | True |
| case_027 | kin2-telescoping-rod__RpQG8Uh | True | True | True |
| case_028 | kin4-butterfly__Xm8Q3Qu | True | True | True |
| case_029 | kin1-dino-tail__k9qPpno | True | True | True |
| case_030 | kin3-snake__b2Lh2UU | True | True | True |
| case_031 | kin2-telescoping-rod__UG26tuq | False | False | False |
| case_032 | kin5-folding-ruler__CyoDRRC | True | True | True |
| case_033 | kin5-folding-ruler__zPq5bwT | True | True | True |
| case_034 | kin2-telescoping-rod__mtxSGet | True | True | True |
| case_035 | kin3-snake__MefefAZ | True | True | True |

在服务器执行 `bash kin_tasks/regrade_gemini_t12_full.sh`：先检查 Docker、备份两个旧 regrade/，再全量重评，核对辅助记录，生成 v4，刷新 analysis/stl_models，只复用其余 33 条标注，不调用 API。
完成后再运行 `python3 jobs/kin/trajectory_eval/launch.py --provider deepseek --case case_001 --case case_031`。
当前 v3 的这两条 Judge 请求已经返回，但均因逐字引用校验失败；这是另一个问题，原始响应保留在 v3/attempts。新 v4 不携带这两条失败 attempt。
