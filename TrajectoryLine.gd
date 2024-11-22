extends Node3D

var line_mesh: ImmediateMesh
var material: StandardMaterial3D
var mesh_instance: MeshInstance3D

func _ready():
	line_mesh = ImmediateMesh.new()
	material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 0, 0, 1) # Jaune semi-transparent
	material.flags_unshaded = true
	
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
		elif valid_points.size() > 0:  # Si on a déjà commencé à dessiner et qu'on passe sous y=0
			break  # On arrête de dessiner
	
	if valid_points.size() < 2:  # S'il n'y a pas assez de points valides
		return
		
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in valid_points:
		line_mesh.surface_add_vertex(point)
	line_mesh.surface_end()
