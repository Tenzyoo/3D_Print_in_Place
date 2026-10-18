# 三节一体化折叠尺：打印与验证记录

## 几何和打印方向

- 文件中的坐标单位为 mm；`model.stl` 是 `angle1=0`、`angle2=0` 的完全展开姿态。
- 轴线是模型的 Z 轴，圆柱销和桶节均沿 Z 建模；折叠发生在 XY 平面。
- 三个主体均为 40 x 12 x 5 mm。为了让宽 12 mm 的刚体在从 0° 运动到 180° 时不互相穿透，主体工作层分别放在 z=0、6、12 mm；相邻主体之间有 1 mm 的 Z 间隙。这样展开时三节在 XY 投影上是连续直线，折叠时仍有实体分层间隙。
- 推荐切片方向：保持模型 Z 轴为打印机 Z 轴（轴线竖直），模型底面朝平台；启用“仅从打印平台生成”的自动支撑。支撑只允许位于三个抬高的主体下方和外侧连接器下方；必须在两个圆柱孔、销轴和挡肩之间建立支撑阻挡器，活动间隙内不放支撑。
- 若切片器不支持局部支撑阻挡，使用无支撑配置并把悬空警告作为不可打印提示，不要让支撑填入孔内。不要在打印后装配任何销、螺钉或其他零件；打印完成后仅清除平台支撑和首层毛边，并逐个关节轻轻松动。

## 关节参数

- 销半径 1.6 mm，孔半径 2.1 mm，因此单侧径向间隙 = 0.5 mm，符合 0.4–0.6 mm 要求。
- 活动桶节 z 范围相对于所在主体层为 0.8–4.2 mm；销的下挡肩与桶节底端、上锥形挡肩与桶节顶端均留出 0.3 mm 轴向空气隙。
- 每个销均与左侧尺段一体成形，并带下挡肩和上方锥形挡肩；右侧尺段的桶节不能沿 Z 轴从销上脱出。
- 两关节均是独立相对角：0° 为相邻主体共线，180° 为向回折叠。`joints.json` 给出了轴位置、方向、连接尺段和折叠方向。

## 已完成的实际几何检查

使用 OpenSCAD 生成 STL，并用 PrusaSlicer 2.7.2 `--info` 检查：

| 文件 | 尺寸 X/Y/Z (mm) | manifold | parts |
|---|---:|---|---:|
| model.stl | 132.0 x 15.6 x 17.2（包围盒 -43..89） | yes | 3 |
| parts/parts_1.stl | 45.35 x 15.15 x 11.2 | yes | 1 |
| parts/parts_2.stl | 51.15 x 15.6 x 11.2 | yes | 1 |
| parts/parts_3.stl | 45.8 x 15.6 x 5.0 | yes | 1 |

三份零件 STL 使用与总装相同的展开坐标和姿态；总装由 3 个独立实体组成。OpenSCAD 对 0°、90°、180° 的 `angle1`/`angle2` 组合均成功导出，PrusaSlicer 对每个样例报告 `manifold = yes`、`number_of_parts = 3`。体积在角度变化时保持不变（约 7.50 cm³），表明两关节作为刚体变换独立运动。

## 已完成的实际切片检查

实际运行了：

```text
prusa-slicer --export-gcode --load /opt/slicer/p1s_pla_0.20mm_nosupport.ini \
  --output /tmp/folding_ruler_nosupport.gcode output/model.stl
prusa-slicer --export-gcode --load /opt/slicer/p1s_pla_0.20mm_autosupport.ini \
  --output /tmp/folding_ruler_autosupport.gcode output/model.stl
```

两种配置都成功导出 G-code。无支撑切片报告了 `Floating object part`、`Floating bridge anchors`、`Long bridging extrusions`，这是 z=6/12 mm 分层设计导致的预期警告，不能直接作为生产打印设置。自动支撑切片成功导出约 32k 行 G-code；配置是 0.4 mm 喷嘴、0.2 mm 层高的 PLA 配置。实际打印前应在 Preview 中逐层确认：孔内没有 support interface、销与桶节没有被支撑连桥、主体下方支撑可拆除且不跨入环形活动间隙。若预览发现支撑进入孔内，使用支撑阻挡器后重新切片，而不是打印该版本。
