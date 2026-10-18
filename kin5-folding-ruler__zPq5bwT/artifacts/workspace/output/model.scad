// =====================================================================
// 三节可活动折叠尺 —— 一体化打印 (print-in-place) 参数化模型
// 3-segment print-in-place folding rule, OpenSCAD 2021.01+
//
// 坐标系 / frame (mm):
//   Z 向上 = 打印方向，z = 0 为热床面；所有零件平放、顶面朝上一次打印。
//   0° (完全展开) 时，尺段 k (k = 1..3) 占据
//     x ∈ [(k-1)(L+end_gap), (k-1)(L+end_gap)+L],  y ∈ [-W/2, W/2],  z ∈ [0, T]
//
// 关节原理 (每个关节相同，绕 Z 轴):
//   * 父段 (编号小的段) 提供销轴：立在热床上的圆柱销 + 底部 50° 锥形防脱脚，
//     销顶通过父段尺身上方的"桥板(web)"与父段相连；
//   * 子段提供环形轴孔 (轴套)：立在热床上，孔底部为与防脱脚配合的锥形内壁，
//     环的顶面为人字形 (两侧 50° 斜面)，桥板下表面为对应的人字形凹面；
//   * 防脱：子段向上被父段桥板挡住，向下被锥形脚挡住 → 双向轴向限位；
//   * 所有悬垂面均 ≥ 50°(相对水平面)，关节间隙内无水平桥接、无需支撑；
//   * 轴心设在尺身侧边以外 edge_off 处，因此折叠到 180° 时两段并排、
//     互不重叠 (并排间隙 2*edge_off)；相邻关节轴心位于尺身相反两侧，
//     形成 Z 字形折叠，两个关节可同时折叠到 180°。
//
// 用法:
//   openscad -o model.stl model.scad                 (part = 0 → 整体)
//   openscad -D part=1 -o parts/parts_1.stl model.scad (单个尺段)
// =====================================================================

/* [输出选择] */
part = 0;            // 0 = 全部零件(展开 0°); 1..n_seg = 单个尺段

/* [尺段] */
n_seg   = 3;         // 尺段数量
L       = 40;        // 每节主体长度
W       = 12;        // 宽度
T       = 5;         // 厚度
end_gap = 0.5;       // 相邻尺段端面间隙 (0° 状态)
edge_off = 0.4;      // 轴心到尺身侧边的距离 → 180° 并排间隙 = 2*edge_off

/* [关节] */
pin_r    = 2.0;      // 销轴半径 (Ø4)
pin_clr  = 0.5;      // 销轴/轴孔 单侧径向间隙 (要求 0.4–0.6)
foot_r   = 3.3;      // 防脱锥形脚底部半径 (轴向下限位)
ring_r   = 4.7;      // 子段轴套外半径
ring_clr = 0.5;      // 轴套外圆与父段让位圆柱面的径向间隙
ring_h   = 0.6;      // 轴套外边缘高度 (顶面最低处)
ridge_dr = 0.15;     // 顶脊距轴孔边缘的径向距离 (小 → 销轴一侧悬挑短，利于打印稳定)
cone_gap = 0.4;      // 斜面(锥面)法向间隙
ov       = 50;       // 斜面与水平面夹角 (≥45° 无需支撑)

/* [刻度] */
ticks      = true;
tick_step  = 5;      // 刻度间距
tick_w     = 0.6;
tick_d     = 0.6;    // 刻槽深度 (3 层)
tick_len_s = 3;      // 5 mm 刻度长
tick_len_l = 5;      // 10 mm 刻度长

/* [精度] */
fn_joint = 128;

// ---------------- 派生量 ----------------
tn   = tan(ov);
hoff = cone_gap / sin(ov);          // 斜面间隙的水平分量
voff = cone_gap / cos(ov);          // 斜面间隙的竖直分量
rb   = pin_r + pin_clr;             // 轴孔半径
rc   = ring_r + ring_clr;           // 父段让位圆柱半径
rm   = rb + ridge_dr;               // 人字顶脊所在半径
foot_h = (foot_r - pin_r) * tn;     // 锥形脚高度
eps  = 0.01;

// 轴套顶面 (不对称人字形) 高度，ρ ∈ [rb, ring_r]；向两侧线性延长
ridge_z = ring_h + tn * (ring_r - rm);
function ring_top(rho) = ridge_z - tn * abs(rho - rm);
// 父段桥板下表面高度 = 轴套顶面 + 竖直间隙
function web_bot(rho) = ring_top(rho) + voff;

pitch = L + end_gap;
function seg_x0(k) = (k - 1) * pitch;                 // k = 1..n_seg
function piv(j) = [j * pitch - end_gap / 2,           // j = 1..n_seg-1
                   (j % 2 == 1 ? 1 : -1) * (W / 2 + edge_off), 0];

assert(web_bot(rm) < T - 0.8, "桥板过薄：减小 ring_r/ring_h 或增大 T");
assert(foot_r + hoff < ring_r - 0.8, "轴套底部过薄");
assert(pin_clr >= 0.4 && pin_clr <= 0.6, "销轴径向间隙须在 0.4–0.6 mm");

// ---------------- 关节几何 (以轴心为原点) ----------------
// 父段：销轴 + 锥形防脱脚
module pin_body() {
    rotate_extrude($fn = fn_joint)
        polygon([[0, 0], [foot_r, 0], [pin_r, foot_h], [pin_r, T], [0, T]]);
}
// 从父段尺身中挖去的让位空间 (轴套及其间隙)，上方保留桥板
module parent_clear() {
    rotate_extrude($fn = fn_joint)
        polygon([[0, -1], [rc, -1], [rc, web_bot(rc)], [rm, web_bot(rm)],
                 [pin_r - eps, web_bot(pin_r - eps)], [0, web_bot(pin_r - eps)]]);
}
// 子段：环形轴套 (人字形顶面)
module ring_body() {
    rotate_extrude($fn = fn_joint)
        polygon([[0, 0], [ring_r, 0], [ring_r, ring_top(ring_r)], [rm, ring_top(rm)],
                 [rb, ring_top(rb)], [0, ring_top(rb)]]);
}
// 从子段中挖去的轴孔：圆柱孔 + 底部锥形让位
module child_clear() {
    rotate_extrude($fn = fn_joint)
        polygon([[0, -1], [foot_r + hoff + 1 / tn, -1],
                 [rb, (foot_r + hoff - rb) * tn], [rb, T + 1], [0, T + 1]]);
}

// ---------------- 尺段 ----------------
module strip(k) { translate([seg_x0(k), -W / 2, 0]) cube([L, W, T]); }

module tick_marks(k) {
    if (ticks)
        for (p = [tick_step : tick_step : L - tick_step]) {
            tl = (p % 10 == 0) ? tick_len_l : tick_len_s;
            x = seg_x0(k) + p;
            // 刻度避开关节区域 (到任一轴心水平距离 > rc + 1)
            near = [for (j = [1 : n_seg - 1])
                        if (abs(x - piv(j)[0]) < rc + 1 + tick_w) 1];
            if (len(near) == 0)
                translate([x - tick_w / 2, -W / 2 - 1, T - tick_d])
                    cube([tick_w, tl + 1, tick_d + 1]);
        }
}

module segment(k) {
    union() {
        difference() {
            union() {
                strip(k);
                if (k > 1) translate(piv(k - 1)) ring_body();          // 与上一段的关节：本段为子段
            }
            if (k > 1)     translate(piv(k - 1)) child_clear();
            if (k < n_seg) translate(piv(k))     parent_clear();       // 与下一段的关节：本段为父段
            tick_marks(k);
        }
        if (k < n_seg) translate(piv(k)) pin_body();
    }
}

if (part == 0) for (k = [1 : n_seg]) segment(k);
else segment(part);
