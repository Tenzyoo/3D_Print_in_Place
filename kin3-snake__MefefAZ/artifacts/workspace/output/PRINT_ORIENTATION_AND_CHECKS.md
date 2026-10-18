# 可活动小蛇：打印方向、几何与切片检查

## 1. 交付文件

| 文件 | 内容 |
|---|---|
| `model.scad` | 参数化 OpenSCAD 源码，`export_part=0/1..6` 控制整体或单件导出 |
| `model.stl` | 中立伸直姿态的完整模型，6 个刚体零件在同一坐标系中 |
| `parts/parts_1.stl` | 头部 |
| `parts/parts_2.stl` ... `parts/parts_6.stl` | 身体第 1～5 段 |
| `joints.json` | 零件、关节、旋转轴、位置、运动范围、间隙与验证结果 |
| `validation/` | 几何碰撞、层截面、切片指标、首层/逐层孤岛检查的脚本与 JSON |
| `model.gcode` | 用 PrusaSlicer 2.7.2 和给定 0.4 mm/0.2 mm/PLA 无支撑配置实际切出的 G-code |

`parts/` 中的 6 个 STL 没有各自的局部坐标变换：它们已经位于与 `model.stl`
完全相同的世界坐标和中立姿态中。6 个零件的体积之和等于整体模型体积，
在同一坐标系下直接合并即为 `model.stl`。

## 2. 零件与关节编号

- 零件 1：头部（head）
- 零件 2～6：身体第 1～5 段（body_1～body_5）
- 关节 1：头部—身体 1
- 关节 2～5：身体第 1—2、2—3、3—4、4—5 段

5 个关节全部为绕 **+Z** 的销轴式转动关节，关节中心在：

```text
(x, y, z) = (28, 0, 0), (54, 0, 0), (80, 0, 0), (106, 0, 0), (132, 0, 0)
```

## 3. 打印方向

**不需要旋转模型。直接按导出的姿态打印：Z 轴向上，所有零件的底面都在
`z=0` 热床上。** 头尾沿 X 方向，关节轴竖直。

- 材料：PLA
- 喷嘴：0.4 mm
- 层高：0.2 mm
- 支撑：关闭
- Brim / skirt / raft：关闭（不要添加 brim；它可能跨过零件间隙，把应独立的零件连在一起）
- 所有 6 个零件在同一张热床上一次打印，打印后不需要安装销轴、螺丝或任何其他零件

切片使用：

```bash
prusa-slicer --export-gcode \
  --load /opt/slicer/p1s_pla_0.20mm_nosupport.ini \
  --output model.gcode model.stl
```

### 为什么关节间隙内不需要支撑

- 销轴、轴孔、上下止退法兰和 C 形开口都沿 Z 方向拉伸，侧壁为竖直面。
- 轴孔下侧的过渡锥面为 45° 自支撑斜面；上侧是向外扩大的孔，不形成悬空材料。
- 销轴上法兰的过渡锥面为 45°，从销轴本体向外生长，不需要支撑。
- 关节间隙在每层都是开放的空气槽；C 形开口朝 `-X`，切层时不会封闭成需要支撑的空腔。
- 切片配置中 `support_material = 0`，最终 G-code 中没有 `;TYPE:Support`。

建议首层保证良好附着；模型已有多处独立底面积，不需要 raft。若机器挤出量偏大，
可把流量降低 1%～2%，以保持 0.5 mm 级间隙。

## 4. 关节几何与防脱结构

每个关节由同一根竖直销轴和对应的阶梯轴孔组成：

- 销轴腰部半径 `R_PIN = 3.50 mm`
- 轴孔窄段半径 `R_HOLE = 4.05 mm`
  - 单侧径向间隙 **0.55 mm**（在 0.4～0.6 mm 要求内）
- 下止退法兰半径 `R_FLANGE = 5.00 mm`
- 上止退法兰半径 `R_FLANGE_T = 5.00 mm`
- 上下沉孔半径 `R_CB = 5.50 mm`
  - 法兰与沉孔单侧径向间隙 **0.50 mm**
- 轴孔中部保留内唇，内唇位于上下两个法兰之间，形成**双向轴向捕获**：
  - 零件相对向上移动约 **0.75 mm** 时，上法兰/内唇首次接触并止挡；
  - 相对向下移动约 **1.00 mm** 时，下法兰/下肩首次接触并止挡。
  - 因此不能沿关节轴线直接把相邻零件拔出。
- C 形开口半角 `MOUTH_HALF = 80°`（开口 160°），让 5 mm 宽的连接臂通过；
  在 ±30° 摆动时连接臂与开口边缘仍有间隙。
- 相邻本体端面到关节外圆的距离为 `R_SEP = 8.0 mm`，C 形环外半径
  `R_RING = 7.5 mm`，中立姿态下留有 0.5 mm 平面间隙。

## 5. 实际完成的几何检查

检查脚本：`validation/validate_model.py`；结果：`validation/validation_report.json`。

- 整体中立姿态外接尺寸：**158.0 × 20.0 × 10.8 mm**
  - 要求上限 160 × 50 × 40 mm，满足。
- `model.stl`：watertight/manifold = yes，6 个连通体
- 6 个零件 STL：全部 watertight/manifold，每个 1 个连通体
- 6 个零件体积之和 = 整体模型体积（误差 < 0.01 mm³）
- 中立姿态下任意两个零件之间无三角面相交
- 每个关节在 **-30°、+30°** 下旋转整个下游链：
  - 碰撞体积 = **0.0 mm³**
  - 相邻零件最小三维表面间隙约 **0.459 mm**
- 另外测试到 **±35°** 仍无碰撞（最小间隙约 0.363 mm），因此 ±30° 的功能范围
  对“左右各至少 25°”有 5° 余量。
- 每个关节从 **-35° 到 +35°，每 5° 扫掠** 检查全部固定/运动零件对，均无碰撞；
  结果见 `validation/angle_sweep_check.json`。
- 独立验证脚本 `validation/verify_from_joints_json.py` 只读取 `joints.json`，
  按其中声明的零件、轴、位置和 ±30° 范围重新加载零件并检查；结果
  `validation/joints_json_motion_check.json` 为全部无碰撞。
- 0.2 mm 层高的 0.1～9.9 mm 中点截面逐层检查：
  - 相邻零件在每层均无截面重叠
  - 最小层内平面间隙 **0.499 mm**
- PrusaSlicer 模型信息：
  - `manifold = yes`
  - `number_of_parts = 6`
  - `size = 158.000 × 20.000 × 10.800 mm`

## 6. 实际切片检查

指标来自 `model.gcode`、`validation/slice_metrics.json` 和
`validation/layer_island_check.json`。

| 项目 | 结果 |
|---|---|
| 切片器 | PrusaSlicer 2.7.2 |
| 配置 | `/opt/slicer/p1s_pla_0.20mm_nosupport.ini` |
| 喷嘴 / 层高 | 0.4 mm / 0.2 mm |
| 层数 | 54 |
| 最高 Z | 10.8 mm |
| 支撑路径 `;TYPE:Support` | 0 |
| Brim / skirt 路径 | 0 / 0 |
| 预估时间 | 1 h 18 min 39 s |
| 挤出材料 | 10.27 cm³（4268.58 mm 线材） |

G-code 连通性检查：

- 把每层挤出中心线按 0.21 mm（半个挤出宽度）膨胀，统计连通的“打印岛”。
- **首层正好 6 个独立打印岛**，对应 6 个零件。
- `z ≤ 10.0 mm` 的 **50 个切片层全部正好 6 个独立打印岛**。
- 这说明切片没有把相邻零件在层内连成一体，也没有支撑路径穿过关节间隙。
- `z = 10.0 mm` 以上只有头部两个 0.8 mm 高的装饰眼凸点，不影响关节。

本环境没有实体 3D 打印机，因此没有做实际耗材打印；上述是实际完成的
STL 几何检查、逐层截面检查和真实 PrusaSlicer 切片检查。

## 7. 复现命令

```bash
cd /app/output

# 整体模型
openscad -o model.stl model.scad

# 6 个零件（1=头，2..6=身体 1..5）
for i in 1 2 3 4 5 6; do
  openscad -D export_part=$i -o parts/parts_${i}.stl model.scad
done

# 几何、碰撞、层截面和轴向止挡检查
python3 validation/validate_model.py

# 切片
prusa-slicer --export-gcode \
  --load /opt/slicer/p1s_pla_0.20mm_nosupport.ini \
  --output model.gcode model.stl

# 切片指标与逐层 6 岛检查
python3 validation/collect_slice_metrics.py
python3 validation/check_layer_islands.py
```

## 8. 使用注意

- 打印完成后，从热床上取下整体件，轻轻来回活动每个关节；不要用钳子夹关节间隙。
- 设计功能范围为 ±30°，实测 ±35° 仍无碰撞；不要强行超过该范围，以免 C 形开口或连接臂受损。
- 推荐用锋利的 0.4 mm 喷嘴并确认首层正常；关节间隙为 0.5 mm 量级，过度挤出会减小实际间隙。
