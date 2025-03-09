package assets

sprite :: struct {
	x:     f32,
	y:     f32,
	w:     f32,
	h:     f32,
	left:  f32,
	top:   f32,
	src_w: f32,
	src_h: f32,
}
	
sprites: []sprite = {
	{19, 0, 14, 14, 3, 3, 20, 20},
	{0, 0, 18, 18, 1, 1, 20, 20},
	{34, 0, 14, 14, 0, 0, 14, 14},
	{91, 0, 3, 1, 5, 5, 14, 14},
	{87, 0, 3, 1, 6, 6, 14, 14},
	{49, 0, 14, 14, 0, 0, 14, 14},
	{79, 0, 3, 1, 6, 5, 14, 14},
	{83, 0, 3, 1, 3, 8, 14, 14},
	{64, 0, 14, 14, 0, 0, 14, 14},
}

sprite_names :: enum {
	icons = (2 << 4),
	holder = (0 << 4),
	holder_off = (0 << 4) | (0),
	holder_on = (1 << 4) | (0),
	icons_power = (2 << 4) | (2),
	icons_battery = (5 << 4) | (2),
	icons_home = (8 << 4) | (0),
}

get_sprite_max :: proc(name: sprite_names) -> uint {
	return uint(name) & 0xf
}
get_sprite :: proc(name: sprite_names, offset: uint = 0) -> sprite {
	return sprites[(uint(name) >> 4) + (offset % get_sprite_max(name) if offset != 0 else 0)]
}

