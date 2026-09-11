; RingGeom.ahk - pure geometry for the action ring: sizes, angles, hit zones, wedge arcs, pages and clamping.
; Angles are degrees, 0 = 12 o'clock, clockwise, screen y down. Wedge i (0-based) of n is centred on i * 360 / n.

class RingGeom {
	static TapMs := 300

	; radii and distances in physical pixels for a DPI scale; the hub sits one gap inside the ring
	static Sizes(scale := 1) {
		r0 := Round(56 * scale), gap := Round(8 * scale)
		return {r1: Round(148 * scale), r0: r0, gap: gap, corner: Round(8 * scale), hub: r0 - gap
			, shadow: Round(10 * scale), travel: Round(30 * scale)}
	}

	static Angle(dx, dy) {
		a := RingGeom.Atan2(dx, -dy) * 57.29577951308232
		return a < 0 ? a + 360 : a
	}

	; atan2(y, x) in radians; AutoHotkey has no built-in
	static Atan2(y, x) {
		if (x > 0)
			return ATan(y / x)
		if (x < 0)
			return ATan(y / x) + (y >= 0 ? 3.141592653589793 : -3.141592653589793)
		return y > 0 ? 1.5707963267948966 : (y < 0 ? -1.5707963267948966 : 0)
	}

	; zone "hub" inside the hub, "ring" out to the edge of the shadow, else "outside"; index is the nearest
	; wedge by angle (no dead gaps between wedges), -1 unless the zone is "ring"
	static Hit(dx, dy, n, s) {
		dist := Sqrt(dx * dx + dy * dy)
		if (dist < s.hub)
			return {zone: "hub", index: -1}
		if (dist > s.r1 + s.shadow)
			return {zone: "outside", index: -1}
		return {zone: "ring", index: Mod(Round(RingGeom.Angle(dx, dy) / (360 / n)), n)}
	}

	; the arcs of wedge i in drawing order, relative to the centre, in GDI+ degrees (0 = 3 o'clock, clockwise):
	; outer arc, outer-end fillet, inner-end fillet, inner arc (reversed), inner-start fillet, outer-start fillet.
	; GDI+ joins consecutive arcs with straight lines, which become the two sides. The sides run parallel to the
	; wedge's boundary rays half a gap in, so neighbours are separated by an even gap from hub to rim. A corner
	; too large for a narrow wedge is clamped; a zero corner returns only the two main arcs.
	static WedgeArcs(i, n, r0, r1, gap, corner) {
		step := 360 / n, a0 := i * step - step / 2, a1 := i * step + step / 2
		rad := Max(0, Min(corner, 0.3 * r0 * (6.283185307179586 / n), (r1 - r0) / 2 - 2))
		d := gap / 2
		AO := RingGeom.Corner(a0, 1, r1, true, d, rad), BO := RingGeom.Corner(a1, -1, r1, true, d, rad)
		BI := RingGeom.Corner(a1, -1, r0, false, d, rad), AI := RingGeom.Corner(a0, 1, r0, false, d, rad)
		out := [RingGeom.ArcFrom(0, 0, r1, AO.onArc, BO.onArc, 1)]
		if (rad >= 0.5)
			out.Push(RingGeom.ArcFrom(BO.cx, BO.cy, rad, BO.onArc, BO.onLine, 1), RingGeom.ArcFrom(BI.cx, BI.cy, rad, BI.onLine, BI.onArc, 1))
		out.Push(RingGeom.ArcFrom(0, 0, r0, BI.onArc, AI.onArc, -1))
		if (rad >= 0.5)
			out.Push(RingGeom.ArcFrom(AI.cx, AI.cy, rad, AI.onArc, AI.onLine, 1), RingGeom.ArcFrom(AO.cx, AO.cy, rad, AO.onLine, AO.onArc, 1))
		return out
	}

	; fillet between the side parallel to ray a (offset d into the wedge; sign 1 = the wedge lies clockwise of
	; the ray) and the circle of radius R (outer: the fillet sits inside it, else outside). Returns the fillet's
	; centre and its tangent points on the side and on the circle; with rad 0 both points are the sharp corner.
	static Corner(a, sign, R, outer, d, rad) {
		t0 := a * 0.017453292519943295
		ex := Sin(t0), ey := -Cos(t0), nx := sign * Cos(t0), ny := sign * Sin(t0)
		cr := outer ? R - rad : R + rad, off := d + rad
		t := Sqrt(Max(cr * cr - off * off, 0))
		cx := ex * t + nx * off, cy := ey * t + ny * off
		len := Sqrt(cx * cx + cy * cy)
		return {cx: cx, cy: cy, onLine: [ex * t + nx * d, ey * t + ny * d], onArc: [cx / len * R, cy / len * R]}
	}

	; arc on the circle (cx, cy, r) from point p to point q; dir 1 = clockwise on screen, -1 = counter-clockwise
	static ArcFrom(cx, cy, r, p, q, dir) {
		s := RingGeom.Deg(p[1] - cx, p[2] - cy), e := RingGeom.Deg(q[1] - cx, q[2] - cy)
		return {cx: cx, cy: cy, r: r, start: s, sweep: dir * Mod(dir * (e - s) + 720, 360)}
	}

	; GDI+ angle of a vector: 0 = +x, clockwise on screen, 0 <= a < 360
	static Deg(x, y) {
		a := RingGeom.Atan2(y, x) * 57.29577951308232
		return a < 0 ? a + 360 : a
	}

	static Point(i, n, radius) {
		a := i * 360 / n * 0.017453292519943295
		return [radius * Sin(a), -radius * Cos(a)]
	}

	; one page when it fits, else pages of cap - 1 items each ending with a More or (last page) Back entry
	static Pages(items, cap := 8) {
		if (items.Length <= cap)
			return [items.Clone()]
		pages := [], i := 1
		while (i <= items.Length) {
			page := []
			loop cap - 1 {
				if (i > items.Length)
					break
				page.Push(items[i++])
			}
			page.Push({nav: i > items.Length ? "back" : "more"})
			pages.Push(page)
		}
		return pages
	}

	; centre that keeps a disc of radius rad inside the rectangle
	static Clamp(x, y, rad, l, t, r, b) => [Max(l + rad, Min(x, r - rad)), Max(t + rad, Min(y, b - rad))]
}
