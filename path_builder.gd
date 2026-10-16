class_name PathBuilder
extends RefCounted


static func build(points: PackedVector3Array, radius := 4.0) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.25

	if points.size() == 0:
		return curve
	if points.size() == 1:
		curve.add_point(points[0])
		return curve

	var pts := _merge_waypoints(points, radius)
	if pts.size() <= 2:
		for p in pts:
			curve.add_point(p)
		return curve

	# Start by adding the very first point of the polyline
	# Interior corners will add fillet entry and exit points with handles.
	var last_added_point := pts[0]
	curve.add_point(pts[0])

	for i in range(1, pts.size() - 1):
		var p_prev := pts[i - 1]
		var p_corner := pts[i]
		var p_next := pts[i + 1]

		var v_in := p_corner - p_prev
		var v_out := p_next - p_corner

		var len_in := v_in.length()
		var len_out := v_out.length()

		if len_in < 0.0001 or len_out < 0.0001:
			continue

		var dir_in := v_in / len_in
		var dir_out := v_out / len_out

		# Turn angle θ between incoming direction dir_in and outgoing direction dir_out
		# θ = 0 for straight line, θ = PI/2 for 90° turn, θ = PI for complete reversal
		var cos_angle := clampf(dir_in.dot(dir_out), -1.0, 1.0)
		var theta := acos(cos_angle)

		# Clamp radius to half of each adjacent segment length
		var r := radius
		r = minf(r, len_in * 0.5)
		r = minf(r, len_out * 0.5)

		# If nearly straight or radius is negligible, pass through corner point
		if theta < 0.001 or r < 0.0001:
			curve.add_point(p_corner)
			last_added_point = p_corner
			continue

		# Trim distance: d = r · tan(θ / 2)
		# Ensure trim distance does not exceed available segment bounds
		var trim := r * tan(theta * 0.5)
		if trim > len_in * 0.5 or trim > len_out * 0.5:
			# If tan(θ/2) would require more trim than segment allows, scale r down
			var max_trim := minf(len_in * 0.5, len_out * 0.5)
			r = max_trim / tan(theta * 0.5)
			trim = max_trim

		var p_entry := p_corner - dir_in * trim
		var p_exit := p_corner + dir_out * trim

		# Handle length for cubic Bézier approximating circular arc:
		# h = (4/3) · tan(θ / 4) · r
		var h := (4.0 / 3.0) * tan(theta * 0.25) * r

		# Tangent handles:
		# At p_entry, curve continues along dir_in, so out_handle = dir_in * h
		# At p_exit, curve arrives along dir_out, so in_handle = -dir_out * h
		curve.add_point(p_entry, Vector3.ZERO, dir_in * h)
		curve.add_point(p_exit, -dir_out * h, Vector3.ZERO)

		last_added_point = p_exit

	# Finally add the destination point
	curve.add_point(pts[pts.size() - 1])

	return curve


static func _merge_waypoints(points: PackedVector3Array, radius: float) -> PackedVector3Array:
	if points.size() <= 2:
		return points.duplicate()

	var threshold := 2.0 * radius
	var pts := points.duplicate()

	var i := 1
	while i < pts.size() - 2:
		if pts[i].distance_to(pts[i + 1]) < threshold:
			pts.remove_at(i)
		else:
			i += 1
	return pts
