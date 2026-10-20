extends SceneTree


func _init() -> void:
	var mesh := generate_curved_double_yellow()
	var err := ResourceSaver.save(mesh, "res://props/connector_turn_yellow_line.res")
	if err != OK:
		push_error("Failed to save mesh: %d" % err)
	else:
		print("Successfully generated and saved res://props/connector_turn_yellow_line.res")
	quit()


func generate_curved_double_yellow() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var stripes: Array[Dictionary] = [
		{"r_center": 5.9, "width": 0.14}, {"r_center": 6.1, "width": 0.14}
	]

	var segments := 48
	var y_top := 0.06
	var y_bot := -0.06

	for stripe in stripes:
		var r_in: float = stripe["r_center"] - stripe["width"] * 0.5
		var r_out: float = stripe["r_center"] + stripe["width"] * 0.5

		for i in range(segments):
			var t0 := (PI * 0.5) * (float(i) / float(segments))
			var t1 := (PI * 0.5) * (float(i + 1) / float(segments))

			var cos0 := cos(t0)
			var sin0 := sin(t0)
			var cos1 := cos(t1)
			var sin1 := sin(t1)

			var p_in0_top := Vector3(-r_in * cos0, y_top, r_in * sin0)
			var p_out0_top := Vector3(-r_out * cos0, y_top, r_out * sin0)
			var p_in1_top := Vector3(-r_in * cos1, y_top, r_in * sin1)
			var p_out1_top := Vector3(-r_out * cos1, y_top, r_out * sin1)

			var p_in0_bot := Vector3(-r_in * cos0, y_bot, r_in * sin0)
			var p_out0_bot := Vector3(-r_out * cos0, y_bot, r_out * sin0)
			var p_in1_bot := Vector3(-r_in * cos1, y_bot, r_in * sin1)
			var p_out1_bot := Vector3(-r_out * cos1, y_bot, r_out * sin1)

			# 1. Top face (normal Vector3.UP, CCW from above)
			st.set_normal(Vector3.UP)
			st.add_vertex(p_in0_top)
			st.add_vertex(p_out1_top)
			st.add_vertex(p_out0_top)

			st.set_normal(Vector3.UP)
			st.add_vertex(p_in0_top)
			st.add_vertex(p_in1_top)
			st.add_vertex(p_out1_top)

			# 2. Bottom face (normal Vector3.DOWN, CCW from below)
			st.set_normal(Vector3.DOWN)
			st.add_vertex(p_in0_bot)
			st.add_vertex(p_out0_bot)
			st.add_vertex(p_out1_bot)

			st.set_normal(Vector3.DOWN)
			st.add_vertex(p_in0_bot)
			st.add_vertex(p_out1_bot)
			st.add_vertex(p_in1_bot)

			# 3. Outer wall (pointing outward away from center)
			var norm_out := (Vector3(-cos0 - cos1, 0, sin0 + sin1) * 0.5).normalized()
			st.set_normal(norm_out)
			st.add_vertex(p_out0_top)
			st.add_vertex(p_out0_bot)
			st.add_vertex(p_out1_top)

			st.set_normal(norm_out)
			st.add_vertex(p_out0_bot)
			st.add_vertex(p_out1_bot)
			st.add_vertex(p_out1_top)

			# 4. Inner wall (pointing inward towards center)
			var norm_in := -norm_out
			st.set_normal(norm_in)
			st.add_vertex(p_in0_top)
			st.add_vertex(p_in1_top)
			st.add_vertex(p_in0_bot)

			st.set_normal(norm_in)
			st.add_vertex(p_in0_bot)
			st.add_vertex(p_in1_top)
			st.add_vertex(p_in1_bot)

		# 5. Cap at t = 0 (z = 22, normal along -Z: Vector3(0, 0, -1))
		var c_in0_top := Vector3(-r_in, y_top, 0)
		var c_out0_top := Vector3(-r_out, y_top, 0)
		var c_in0_bot := Vector3(-r_in, y_bot, 0)
		var c_out0_bot := Vector3(-r_out, y_bot, 0)
		st.set_normal(Vector3(0, 0, -1))
		st.add_vertex(c_out0_top)
		st.add_vertex(c_in0_top)
		st.add_vertex(c_out0_bot)
		st.set_normal(Vector3(0, 0, -1))
		st.add_vertex(c_out0_bot)
		st.add_vertex(c_in0_top)
		st.add_vertex(c_in0_bot)

		# 6. Cap at t = PI/2 (x = 74, normal along +X: Vector3(1, 0, 0))
		var c_in1_top := Vector3(0, y_top, r_in)
		var c_out1_top := Vector3(0, y_top, r_out)
		var c_in1_bot := Vector3(0, y_bot, r_in)
		var c_out1_bot := Vector3(0, y_bot, r_out)
		st.set_normal(Vector3(1, 0, 0))
		st.add_vertex(c_in1_top)
		st.add_vertex(c_out1_top)
		st.add_vertex(c_in1_bot)
		st.set_normal(Vector3(1, 0, 0))
		st.add_vertex(c_in1_bot)
		st.add_vertex(c_out1_top)
		st.add_vertex(c_out1_bot)

	return st.commit()
