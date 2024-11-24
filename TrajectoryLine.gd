extends Node3D

var line_mesh: ImmediateMesh
var material: StandardMaterial3D
var mesh_instance: MeshInstance3D

func _ready():
	line_mesh = ImmediateMesh.new()
	material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 0, 0, 0.8)
	material.flags_unshaded = true
	material.vertex_color_use_as_albedo = true
	# Augmenter la taille des points
	material.point_size = 25.0  # Taille des points
	
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = line_mesh
	mesh_instance.material_override = material
	add_child(mesh_instance)

func clear():
	line_mesh.clear_surfaces()

func draw_trajectory(points: Array):
	clear()
	if points.size() < 2:
		return
		
	var valid_points = []
	for point in points:
		if point.y > 0:
			valid_points.append(point)
		elif valid_points.size() > 0:
			break
	
	if valid_points.size() < 2:
		return

	# Dessiner les pointillés
	line_mesh.surface_begin(Mesh.PRIMITIVE_POINTS)
	var spacing = 0.40  # Réduire l'espacement pour plus de points
	
	for i in range(valid_points.size() - 1):
		var start = valid_points[i]
		var end = valid_points[i + 1]
		var segment = end - start
		var segment_length = segment.length()
		var direction = segment.normalized()
		
		var num_points = floor(segment_length / spacing)
		for j in range(num_points):
			var point_pos = start + direction * (j * spacing)
			var alpha = 1.0 - (float(i * num_points + j) / (valid_points.size() * num_points)) * 0.7
			line_mesh.surface_set_color(Color(0, 0, 0, alpha))
			line_mesh.surface_add_vertex(point_pos)
	
	line_mesh.surface_end()
