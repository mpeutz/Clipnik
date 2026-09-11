; Unit tests for src/ui/native/RingGeom.ahk (pure geometry of the action ring).
;   runtime\AutoHotkey64.exe /ErrorStdOut tests\ring_geom.ahk
#Requires AutoHotkey v2.0
#Include ..\src\ui\native\RingGeom.ahk

fails := 0
check(cond, msg) {
    global fails
    FileAppend((cond ? "ok   " : "FAIL ") msg "`n", "*")
    if !cond
        fails++
}
near(a, b, tol := 0.01) => Abs(a - b) <= tol

check(near(RingGeom.Angle(0, -10), 0), "up is 0")
check(near(RingGeom.Angle(10, 0), 90), "right is 90")
check(near(RingGeom.Angle(0, 10), 180), "down is 180")
check(near(RingGeom.Angle(-10, 0), 270), "left is 270")
check(near(RingGeom.Angle(-1, -1000), 359.94, 0.01), "just left of up wraps below 360")

s := RingGeom.Sizes(1)
check(s.r1 = 148 && s.r0 = 56 && s.gap = 8 && s.corner = 8 && s.hub = 48 && s.shadow = 10 && s.travel = 30, "sizes at 100%")
s15 := RingGeom.Sizes(1.5)
check(s15.r1 = 222 && s15.r0 = 84 && s15.gap = 12 && s15.hub = 72 && s15.corner = 12 && s15.travel = 45, "sizes at 150%")

pol(deg, r) => [r * Sin(deg * 0.017453292519943295), -r * Cos(deg * 0.017453292519943295)]
idx(deg, n) {
    p := pol(deg, 100)
    return RingGeom.Hit(p[1], p[2], n, RingGeom.Sizes(1)).index
}
check(idx(0, 8) = 0 && idx(22, 8) = 0 && idx(23, 8) = 1 && idx(44, 8) = 1, "8 wedges: nearest by angle")
check(idx(338, 8) = 0 && idx(337, 8) = 7, "8 wedges: wrap at 0")
check(idx(89, 6) = 1 && idx(91, 6) = 2 && idx(359, 6) = 0, "6 wedges")
check(idx(17, 10) = 0 && idx(19, 10) = 1 && idx(342, 10) = 0, "10 wedges")

h := RingGeom.Hit(0, -20, 8, s)
check(h.zone = "hub" && h.index = -1, "inside the hub")
h := RingGeom.Hit(100, 0, 8, s)
check(h.zone = "ring" && h.index = 2, "on the ring, right is wedge 2 of 8")
h := RingGeom.Hit(0, -155, 8, s)
check(h.zone = "ring", "the shadow band still counts as the ring")
h := RingGeom.Hit(0, -300, 8, s)
check(h.zone = "outside" && h.index = -1, "outside")

arcs := RingGeom.WedgeArcs(0, 8, 52, 148, 5, 0)
check(arcs.Length = 2, "no corner radius: just the two main arcs")
check(near(arcs[1].start, 248.47, 0.05) && near(arcs[1].sweep, 43.06, 0.05), "outer arc of wedge 0 leaves an even 5px gap")
check(near(arcs[2].sweep, -39.49, 0.05), "inner arc runs back, shortened by the same 5px")
arcs := RingGeom.WedgeArcs(2, 8, 52, 148, 5, 7)
check(arcs.Length = 6, "rounded: six arcs")
rad(deg) => deg * 0.017453292519943295
endPt(a) => [a.cx + a.r * Cos(rad(a.start + a.sweep)), a.cy + a.r * Sin(rad(a.start + a.sweep))]
startPt(a) => [a.cx + a.r * Cos(rad(a.start)), a.cy + a.r * Sin(rad(a.start))]
ok := true
for j in [[1, 2], [3, 4], [4, 5], [6, 1]] {
    e := endPt(arcs[j[1]]), b := startPt(arcs[j[2]])
    if (Abs(e[1] - b[1]) > 0.01 || Abs(e[2] - b[2]) > 0.01)
        ok := false
}
check(ok, "fillets meet the main arcs without a step")
fil := true
for k in [2, 3, 5, 6]
    if !(arcs[k].r = 7 && arcs[k].sweep > 0 && arcs[k].sweep < 180)
        fil := false
check(fil, "four 7px fillets, each a short clockwise turn")
nb := [Cos(rad(112.5)), Sin(rad(112.5))]   ; normal of wedge 2's end ray (ring angle 112.5)
p1 := endPt(arcs[2]), p2 := startPt(arcs[3])   ; both ends of the straight side between them
check(near(Abs(p1[1] * nb[1] + p1[2] * nb[2]), 2.5) && near(Abs(p2[1] * nb[1] + p2[2] * nb[2]), 2.5), "the side runs parallel to its ray, half a gap in")
arcs := RingGeom.WedgeArcs(0, 10, 52, 148, 5, 14)
check(arcs[2].r < 14, "a corner too large for a narrow wedge is clamped")
pt := RingGeom.Point(2, 8, 100)
check(near(pt[1], 100) && near(pt[2], 0), "point of wedge 2 of 8 is to the right")

mk(n) {
    out := []
    loop n
        out.Push({key: Chr(64 + A_Index)})
    return out
}
pg := RingGeom.Pages(mk(5))
check(pg.Length = 1 && pg[1].Length = 5, "5 items: one page, no nav")
pg := RingGeom.Pages(mk(8))
check(pg.Length = 1 && pg[1].Length = 8, "8 items: one page, no nav")
pg := RingGeom.Pages(mk(9))
check(pg.Length = 2 && pg[1].Length = 8 && pg[1][8].nav = "more" && pg[2].Length = 3 && pg[2][3].nav = "back", "9 items: 7 + More, 2 + Back")
pg := RingGeom.Pages(mk(14))
check(pg.Length = 2 && pg[2].Length = 8 && pg[2][8].nav = "back" && pg[2][7].key = "N", "14 items: two full pages")
pg := RingGeom.Pages(mk(17))
check(pg.Length = 3 && pg[2][8].nav = "more" && pg[3].Length = 4 && pg[3][4].nav = "back", "17 items: three pages")

c := RingGeom.Clamp(500, 500, 160, 0, 0, 1920, 1040)
check(c[1] = 500 && c[2] = 500, "clamp leaves a centred ring alone")
c := RingGeom.Clamp(10, 1030, 160, 0, 0, 1920, 1040)
check(c[1] = 160 && c[2] = 880, "clamp at the bottom-left corner")
c := RingGeom.Clamp(1915, 5, 160, 0, 0, 1920, 1040)
check(c[1] = 1760 && c[2] = 160, "clamp at the top-right corner")

FileAppend((fails ? fails " FAILED" : "ALL PASSED") "`n", "*")
ExitApp fails
