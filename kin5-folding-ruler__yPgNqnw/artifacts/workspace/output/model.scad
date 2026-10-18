// =====================================================================
//  三节一体打印折叠尺 (print-in-place 3-segment folding ruler)
//  OpenSCAD 2021.01, 单位 mm
//
//  坐标: 尺长方向 = X, 宽度 = Y, 厚度 = Z (打印方向: 底面 z=0 平放在热床上)
//  关节: 两个绕 Z 轴旋转的销轴关节, 尺段在 XY 平面内折叠
//        关节1 位于 +Y 边, 尺段2 绕 +Z 逆时针折叠到尺段1 的 +Y 侧
//        关节2 位于 -Y 边, 尺段3 绕 -Z (顺时针) 折叠到尺段2 的 -Y 侧 (Z 字形)
//
//  每个关节 (左侧尺段 = "A", 右侧尺段 = "B"):
//    A: 底部带 50° 锥形法兰的销轴 (从热床长出) + 顶部盖板 (桥接到 A 本体)
//    B: 底层轴环 (z 0..ring_h), 内孔底部为与法兰平行的锥面
//    轴向防脱: 向上 -> 轴环顶面被 A 的盖板挡住; 向下 -> 轴环锥面被销轴法兰挡住
//
//  用法:  part = 0 全部 / 1..3 单独尺段;  fold1, fold2 = 关节角 (0 展开, 180 折叠)
// =====================================================================

/* [输出选择] */
part  = 0;      // 0 = 完整模型, 1/2/3 = 单个尺段
fold1 = 0;      // 关节1 角度 [0..180], 仅用于预览
fold2 = 0;      // 关节2 角度 [0..180], 仅用于预览

/* [尺段主体] */
L = 40;         // 每节主体长度
W = 12;         // 宽度
T = 5;          // 厚度
N = 3;          // 尺段数量 (关节数 = N-1)

/* [间隙] */
gap_end  = 0.5; // 展开时相邻尺段端面之间的间隙
gap_side = 0.5; // 折叠 180° 后相邻尺段侧面之间的间隙
gap_pin  = 0.5; // 销轴与轴孔单侧径向间隙 (要求 0.4–0.6)
gap_ring = 0.5; // 轴环外圆与 A 侧避让槽之间的径向间隙
gap_z    = 0.4; // 轴环顶面与 A 盖板底面之间的竖直间隙 (= 2 层)

/* [关节] */
pin_r    = 2.0; // 销轴半径 (Ø4)
flange_w = 1.2; // 底部法兰径向外伸
flange_h = 1.4; // 底部法兰高度 (锥面与水平夹角 = atan(1.4/1.2) ≈ 49.4°, ≥45° 无需支撑)
ring_r   = 5.0; // 轴环外半径
ring_h   = 2.4; // 轴环高度 (= 12 层)

/* [刻度] */
tick_depth = 0.4;
tick_w     = 0.6;
tick_clear = 6.5; // 关节附近不刻线的半径

$fn = 96;
eps = 0.01;

// ---------------- 派生几何 ----------------
pitch = L + gap_end;
function seg_x0(i) = (i - 1) * pitch;                       // 尺段 i 起点 x
function jside(k)  = (k % 2 == 1) ? 1 : -1;                 // 关节 k 所在边 (+Y / -Y), 同时也是折叠旋转方向的符号
function jpos(k)   = [k * L + (k - 0.5) * gap_end, jside(k) * (W / 2 + gap_side / 2), 0];

// ---------------- 关节元素 ----------------
module pin_solid() {          // A: 销轴 + 底部锥形法兰, 从 z=0 到顶面
    rotate_extrude()
        polygon([[0, 0], [pin_r + flange_w, 0], [pin_r, flange_h], [pin_r, T], [0, T]]);
}

module pin_hole() {           // B: 轴孔, 处处与销轴水平偏移 gap_pin
    e = 0.5;
    rotate_extrude()
        polygon([[0, -e],
                 [pin_r + gap_pin + flange_w * (1 + e / flange_h), -e],
                 [pin_r + gap_pin, flange_h],
                 [pin_r + gap_pin, T + 1],
                 [0, T + 1]]);
}

module ring_solid() { cylinder(r = ring_r, h = ring_h); }   // B: 底层轴环

module a_pocket() {           // A: 底层避让槽, 盖板位于其上方
    translate([0, 0, -1]) cylinder(r = ring_r + gap_ring, h = 1 + ring_h + gap_z);
}

// ---------------- 刻度 ----------------
module ticks(i) {
    for (u = [5 : 5 : L - 5]) {
        x  = seg_x0(i) + u;
        ln = (u % 10 == 0) ? 4 : 2.5;
        // 刻在 -Y 边, 跳过位于 -Y 边的关节附近
        near = [for (k = [1 : N - 1]) if (jside(k) == -1 && abs(jpos(k)[0] - x) < tick_clear) 1];
        if (len(near) == 0)
            translate([x - tick_w / 2, -W / 2 - eps, T - tick_depth])
                cube([tick_w, ln + eps, tick_depth + 1]);
    }
}

// ---------------- 尺段 ----------------
module segment(i) {
    difference() {
        union() {
            difference() {
                translate([seg_x0(i), -W / 2, 0]) cube([L, W, T]);
                if (i <= N - 1) translate(jpos(i)) a_pocket();      // 本段是关节 i 的 A 侧
            }
            if (i <= N - 1) translate(jpos(i)) pin_solid();
            if (i >= 2)     translate(jpos(i - 1)) ring_solid();    // 本段是关节 i-1 的 B 侧
        }
        if (i >= 2) translate(jpos(i - 1)) pin_hole();
        ticks(i);
    }
}

// ---------------- 运动学 (预览) ----------------
module about_joint(k, a) {
    p = jpos(k);
    translate(p) rotate([0, 0, jside(k) * a]) translate(-p) children();
}

module posed(i) {
    if (i == 1) segment(1);
    else if (i == 2) about_joint(1, fold1) segment(2);
    else about_joint(1, fold1) about_joint(2, fold2) segment(3);
}

if (part == 0) for (i = [1 : N]) posed(i);
else posed(part);
