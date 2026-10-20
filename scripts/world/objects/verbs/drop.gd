extends RefCounted
## drop: a held row leaves the bag and lands in front of the player as a
## LIVE rigid body (LiveProp), which settles, sleeps and goes back to being
## a row drawn by the field. The row is now placed_by_player: it survives
## the room's rebuild and the save.


static func run(ctx: ObjectContext, row: WorldObject) -> Dictionary:
	if not row.held():
		return {"toast": "YOU AREN'T HOLDING THE %s." % row.name().to_upper()}
	if ctx.bag and not ctx.bag.take(String(row.prop)):
		return {"toast": "THE %s ISN'T IN THE BAG." % row.name().to_upper()}
	var xf := Transform3D(Basis(Vector3.UP, ctx.yaw), ctx.drop_pos)
	ctx.objects.place(row.id, ctx.room, xf)
	ctx.notify_bag()
	if ctx.promote.is_valid():
		ctx.promote.call(row, ctx.drop_velocity)
	return {"toast": "DROPPED THE %s." % row.name().to_upper()}
