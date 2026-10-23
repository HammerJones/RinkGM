class_name VoxelPart
extends MeshInstance3D
## A posable voxel model. Parts are oriented freely (any rotation), so a rig is
## just a hierarchy of VoxelParts animated by code.


static func make(model: VoxelModel) -> VoxelPart:
	var p := VoxelPart.new()
	p.mesh = model.build_mesh()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return p
