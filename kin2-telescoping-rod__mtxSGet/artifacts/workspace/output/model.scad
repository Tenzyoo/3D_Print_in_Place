// ============================================================================
// 一体化 FDM 3D 打印四级伸缩棒 (4-Stage Print-in-Place Telescoping Rod)
// ============================================================================
// 适用工艺：PLA 材料, 0.4 mm 喷嘴, 0.2 mm 层高, 垂直立式无支撑一体打印 (Z 轴向上)
// 坐标系约定：
//   - 中心轴为 Z 轴 (X=0, Y=0)，底面位于打印平台 Z = 0
//   - 收缩状态整体高度 L = 116.0 mm (<= 120 mm)，最大外径 D = 24.0 mm (<= 25 mm)
//   - 4 根同轴嵌套圆管：
//       parts_1 (1号管): 最外层基座管 (固定基准)
//       parts_2 (2号管): 第二级伸缩管 (相对1号管沿 +Z 伸出 70.0 mm)
//       parts_3 (3号管): 第三级伸缩管 (相对2号管沿 +Z 伸出 70.0 mm)
//       parts_4 (4号管): 最内层伸缩管 (相对3号管沿 +Z 伸出 70.0 mm)
//   - 完全伸展总长度 = 116.0 + 3 * 70.0 = 326.0 mm (>= 300 mm)
// ============================================================================

/* [全局导出与运动控制参数] */
// 导出零件选择：0 = 全部组装模型(model.stl)，1..4 = 对应独立圆管(parts_1..4.stl)
part_id = 0; // [0:完整模型, 1:1号外管, 2:2号中管, 3:3号中管, 4:4号内管]

// 伸展比例：0.0 = 完全收缩状态(默认打印状态)，1.0 = 完全伸展状态(326 mm)
extension_ratio = 0.0; // [0.0:0.05:1.0]

/* [核心结构与尺寸参数 (单位: mm)] */
// 嵌套圆管级数
num_stages = 4;

// 收缩状态总长度 (要求 <= 120 mm)
retracted_length = 116.0;

// 最大外径 (要求 <= 25 mm)
max_outer_diameter = 24.0;

// 单侧径向滑动配合间隙 (要求 0.4 - 0.6 mm)
radial_clearance = 0.50;

// 防脱限位台阶径向高度 (45度锥面过渡，单侧限位重叠量 = stop_step - radial_clearance = 0.50 mm)
stop_step = 1.00;

// 各级圆管单级最大伸展行程 (3个滑动副总伸展量 = 3 * 70.0 = 210.0 mm，总长 326.0 mm >= 300 mm)
stage_stroke = 70.0;

/* [壁厚与限位几何参数 (单位: mm)] */
// 1号最外管主壁厚 (领口处壁厚 = 1.50 + 1.00 = 2.50 mm)
outer_tube_wall = 1.50;

// 2号、3号中间管主轴壁厚 (活塞段与领口段壁厚 = 1.20 + 1.00 = 2.20 mm)
mid_tube_wall = 1.20;

// 4号最内管主轴壁厚 (中心通孔直径 = 4.40 mm)
inner_tube_wall = 1.40;

// 底部防下脱限位唇高度 (Z = 0 至 bot_lip_h，所有圆管底面平齐贴合打印热床 Z=0)
bot_lip_h = 3.00;

// 底部45度限位锥面轴向偏移量 (确保打印状态下相邻45度锥面法向间隙约 0.50 mm、轴向间隙 0.70 mm)
bot_cone_z_offset = 0.20;

// 内管底部导向活塞段顶部位置 (Z = piston_top_z 处开始 45度防脱限位斜肩)
piston_top_z = 22.50;

// 伸展极限位置微余量 (确保 s = stage_stroke 时网格零干涉，s > stage_stroke 时硬限位锁止)
stroke_contact_margin = 0.05;

// 外管顶部防脱限位领口起始高度 (由行程公式 s_contact = collar_bot_z - piston_top_z + radial_clearance 推导)
collar_bot_z = piston_top_z + stage_stroke - radial_clearance + stroke_contact_margin; // 92.05 mm

// 圆管旋转细分精度 (所有圆管共享相同角度网格，保证同轴间隙精度)
$fn = 128;

// ============================================================================
// 径向尺寸递推函数 (从外向内：stage = 1, 2, 3, 4)
// ============================================================================
// 第1级(最外管)：
//   外半径 R_out(1) = 12.00 mm
//   主内孔半径 R_bore(1) = 12.00 - 1.50 = 10.50 mm
//   限位领口内半径 R_collar(1) = 10.50 - 1.00 = 9.50 mm
// 第2级：
//   底部导向活塞外半径 R_base(2) = R_bore(1) - 0.50 = 10.00 mm
//   主轴外半径 R_shaft(2) = R_collar(1) - 0.50 = 9.00 mm
//   主内孔半径 R_bore(2) = R_shaft(2) - 1.20 = 7.80 mm
//   限位领口内半径 R_collar(2) = 7.80 - 1.00 = 6.80 mm
// 第3级：
//   底部导向活塞外半径 R_base(3) = R_bore(2) - 0.50 = 7.30 mm
//   主轴外半径 R_shaft(3) = R_collar(2) - 0.50 = 6.30 mm
//   主内孔半径 R_bore(3) = R_shaft(3) - 1.20 = 5.10 mm
//   限位领口内半径 R_collar(3) = 5.10 - 1.00 = 4.10 mm
// 第4级(最内管)：
//   底部导向活塞外半径 R_base(4) = R_bore(3) - 0.50 = 4.60 mm
//   主轴外半径 R_shaft(4) = R_collar(3) - 0.50 = 3.60 mm
//   中心通孔内半径 R_bore(4) = 3.60 - 1.40 = 2.20 mm

function stage_pitch() = stop_step + radial_clearance + mid_tube_wall; // 2.70 mm

function r_bore(stage) =
    (stage == 1) ? (max_outer_diameter / 2.0 - outer_tube_wall) :
    (stage < num_stages) ? (r_bore(1) - (stage - 1) * stage_pitch()) :
    (r_shaft(num_stages) - inner_tube_wall);

function r_collar(stage) =
    (stage < num_stages) ? (r_bore(stage) - stop_step) : r_bore(num_stages);

function r_base(stage) =
    (stage == 1) ? (max_outer_diameter / 2.0) : (r_bore(stage - 1) - radial_clearance);

function r_shaft(stage) =
    (stage == 1) ? (max_outer_diameter / 2.0) : (r_collar(stage - 1) - radial_clearance);

// ============================================================================
// 单级圆管二维截面轮廓生成 (用于 rotate_extrude 旋转成体)
// 所有悬垂结构严格采用 45 度锥面 (dr/dz = 1.0)，无需任何支撑即可立式打印
// ============================================================================
module tube_profile_2d(stage) {
    // 1. 内壁轮廓点序列 (从底 Z=0 到顶 Z=retracted_length)
    inner_pts = (stage < num_stages) ? [
        [r_collar(stage), 0.0],
        [r_collar(stage), bot_lip_h],
        [r_bore(stage),   bot_lip_h + stop_step],
        [r_bore(stage),   collar_bot_z],
        [r_collar(stage), collar_bot_z + stop_step],
        [r_collar(stage), retracted_length]
    ] : [
        // 最内管(4号管)内壁为直通圆孔
        [r_bore(num_stages), 0.0],
        [r_bore(num_stages), retracted_length]
    ];

    // 2. 外壁轮廓点序列 (从顶 Z=retracted_length 到底 Z=0)
    z_piston_bot_start = bot_lip_h + bot_cone_z_offset;
    z_piston_bot_end   = z_piston_bot_start + stop_step;
    z_piston_top_start = piston_top_z;
    z_piston_top_end   = piston_top_z + stop_step;

    outer_pts = (stage == 1) ? [
        // 最外管(1号管)外壁为标准圆柱面
        [r_shaft(1), retracted_length],
        [r_shaft(1), 0.0]
    ] : [
        [r_shaft(stage), retracted_length],
        [r_shaft(stage), z_piston_top_end],
        [r_base(stage),  z_piston_top_start],
        [r_base(stage),  z_piston_bot_end],
        [r_shaft(stage), z_piston_bot_start],
        [r_shaft(stage), 0.0]
    ];

    polygon(points = concat(inner_pts, outer_pts));
}

// ============================================================================
// 单级圆管三维模块
// ============================================================================
module telescoping_tube(stage) {
    z_shift = (stage - 1) * stage_stroke * extension_ratio;
    translate([0, 0, z_shift])
        rotate_extrude(convexity = 10)
            tube_profile_2d(stage);
}

// ============================================================================
// 主模型渲染入口
// ============================================================================
if (part_id == 0) {
    for (s = [1 : num_stages]) {
        telescoping_tube(s);
    }
} else if (part_id >= 1 && part_id <= num_stages) {
    telescoping_tube(part_id);
}
