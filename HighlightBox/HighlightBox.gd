extends Panel

# A 2D highlight overlay box that covers a MeshInstance in screen space

export(NodePath) onready var parentMesh = get_node(parentMesh) as MeshInstance
export(Vector2) var maxSize : Vector2 = Vector2(512,512)
export(bool) var renderAsSquare : bool = true
export(bool) var useAABB : bool = true

# Reference to scene camera
onready var sceneCamera : Camera = get_viewport().get_camera()

# Cached points of either AABB or simplified convex shape of parent mesh to improve performance
var pointCache : PoolVector3Array

func _ready() -> void:
	# Auto assign parent as parent mesh if it exists
	if get_parent() is MeshInstance && parentMesh == null:
		parentMesh = get_parent()
	
	# Generate point cache 
	# Maybe could be improved by doing this in the editor and saving it there
	if useAABB:
		# Cache all 8 AABB points for parent mesh
		var parentAABB : AABB = parentMesh.mesh.get_aabb()
		pointCache.append(parentAABB.get_endpoint(0))
		pointCache.append(parentAABB.get_endpoint(1))
		pointCache.append(parentAABB.get_endpoint(2))
		pointCache.append(parentAABB.get_endpoint(3))
		pointCache.append(parentAABB.get_endpoint(4))
		pointCache.append(parentAABB.get_endpoint(5))
		pointCache.append(parentAABB.get_endpoint(6))
		pointCache.append(parentAABB.get_endpoint(7))
	else:
		# Generate and cache points using simplified convex shape of parent mesh
		pointCache = parentMesh.mesh.create_convex_shape(true,true).points

func _process(delta: float) -> void:
	# Transform cached points by parent mesh's current transform
	var transformedPoints : PoolVector3Array = parentMesh.global_transform.xform(pointCache)
	
	# Initially set min and max XY values
	var minX : float = sceneCamera.unproject_position(transformedPoints[0]).x
	var minY : float = sceneCamera.unproject_position(transformedPoints[0]).y
	var maxX : float = sceneCamera.unproject_position(transformedPoints[0]).x
	var maxY : float = sceneCamera.unproject_position(transformedPoints[0]).y
	
	# Find actual min and max XY values
	for point in transformedPoints:
		var unprojectedPoint : Vector2 = sceneCamera.unproject_position(point)
		if unprojectedPoint.x < minX:
			minX = unprojectedPoint.x
		if unprojectedPoint.y < minY:
			minY = unprojectedPoint.y
		if unprojectedPoint.x > maxX:
			maxX = unprojectedPoint.x
		if unprojectedPoint.y > maxY:
			maxY = unprojectedPoint.y
			
	# Set rect size based on calculated min and max values (use largest side if render as square)
	if renderAsSquare:
		var side : float = max(maxX - minX, maxY - minY)
		rect_size = Vector2(side, side)
	else:
		rect_size = Vector2(maxX - minX, maxY - minY)
	
	# Clamp size using maxSize if maxSize is not set to zero
	if !maxSize.is_equal_approx(Vector2.ZERO):
		rect_size = Vector2(min(rect_size.x, maxSize.x), min(rect_size.y, maxSize.y))
	
	# Transform box to screen space position of parentMesh
	var pos2D : Vector2 = sceneCamera.unproject_position(parentMesh.global_transform.origin)
	rect_position = pos2D - rect_size/2
	
	# Hide this UI element if the world position is behind the camera
	set_visible(!sceneCamera.is_position_behind(parentMesh.global_transform.origin))
