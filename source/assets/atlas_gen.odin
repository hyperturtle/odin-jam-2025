package assets

sprite :: struct {
	x:     f32,
	y:     f32,
	w:     f32,
	h:     f32,
	left:  f32,
	top:   f32,
	src_w: f32,
	src_h: f32
}
	
sprites: []sprite = {
	{17, 0, 16, 16, 0, 0, 16, 16},
	{0, 0, 16, 16, 0, 0, 16, 16},
}

sprite_names :: enum {
	on = (0 << 4),
	off = (1 << 4),
}

get_sprite_max :: proc(name: sprite_names) -> uint {
	return uint(name) & 0xf
}
get_sprite :: proc(name: sprite_names, offset: uint = 0) -> sprite {
	return sprites[(uint(name) >> 4) + (offset % get_sprite_max(name) if offset != 0 else 0)]
}

