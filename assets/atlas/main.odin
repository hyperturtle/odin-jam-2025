package main
import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "core:slice"
import "core:strings"
import ase "odin-aseprite"
import "odin-aseprite/utils"
import "vendor:stb/image"
import "vendor:stb/rect_pack"


dim :: struct {
	top:    int,
	bottom: int,
	left:   int,
	right:  int,
	src_h:  int,
	src_w:  int,
	name:   string,
	index:  int,
}

sources: map[string]int
img_data: [dynamic][]byte
rects: [dynamic]rect_pack.Rect
dims: [dynamic]dim
animations: [dynamic]anim

anim :: struct {
	name: string,
	tag:  string,
	from: int,
	to:   int,
}

SIZE :: 256

final_data: [4 * SIZE * SIZE]u8

default_context: runtime.Context
main :: proc() {
	default_context = context
	load(#load("../on.ase"), {0.5, 1}, "on")
	load(#load("../off.ase"), {0.5, 1}, "off")

	rc: rect_pack.Context
	rc_nodes: [SIZE]rect_pack.Node
	rect_pack.init_target(&rc, SIZE, SIZE, raw_data(rc_nodes[:]), SIZE)

	r := rect_pack.pack_rects(&rc, raw_data(rects[:]), i32(len(rects)))
	if r != 1 {
		fmt.panicf("failed to pack_rects", r)
	}
	for rect in rects {
		img := img_data[rect.id]
		dim := dims[rect.id]
		assert(len(img) == dim.src_w * dim.src_h * 4)
		for y in 0 ..< int(rect.h) - 1 {
			src_offset := (y + dim.top) * dim.src_w + dim.left
			dst_offset := (int(rect.y) + y) * SIZE + int(rect.x)
			intrinsics.mem_copy_non_overlapping(
				rawptr(&final_data[dst_offset * 4]),
				rawptr(&img[src_offset * 4]),
				rect.w * 4 - 4,
			)
		}
	}
	write_func :: proc "c" (ctx: rawptr, data: rawptr, size: i32) {
		context = default_context
		os.write_entire_file("source/assets/atlas.png", slice.bytes_from_ptr(data, int(size)))
	}
	image.write_png_to_func(write_func, nil, SIZE, SIZE, 4, raw_data(final_data[:]), SIZE * 4)

	mode := 0
	when ODIN_OS == .Linux {
		mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
	}

	f, _ := os.open("source/assets/atlas_gen.odin", os.O_WRONLY | os.O_CREATE | os.O_TRUNC, mode)
	defer os.close(f)

	fmt.fprintln(f, "package assets")
	fmt.fprintln(
		f,
		`
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
	`,
	)
	fmt.fprintf(f, "sprites: []sprite = {{\n")
	for rect in rects {
		dim := dims[rect.id]
		fmt.fprintf(
			f,
			"\t{{%d, %d, %d, %d, %d, %d, %d, %d}},\n",
			rect.x,
			rect.y,
			rect.w - 1,
			rect.h - 1,
			dim.left,
			dim.top,
			dim.src_w,
			dim.src_h,
		)
	}
	fmt.fprintln(f, "}\n")
	fmt.fprintln(f, "sprite_names :: enum {")
	for source, i in sources {
		fmt.fprintf(f, "\t%s = (%d << 4),\n", source, i)
	}
	for anim in animations {
		fmt.fprintf(
			f,
			"\t%s_%s = (%d << 4) | (%d),\n",
			anim.name,
			anim.tag,
			sources[anim.name] + anim.from,
			anim.to - anim.from,
		)
	}
	fmt.fprintln(f, "}")
	fmt.fprintln(f, `
get_sprite_max :: proc(name: sprite_names) -> uint {
	return uint(name) & 0xf
}
get_sprite :: proc(name: sprite_names, offset: uint = 0) -> sprite {
	return sprites[(uint(name) >> 4) + (offset % get_sprite_max(name) if offset != 0 else 0)]
}
`)
	fmt.println("done")
}


load :: proc(data: []u8, origin: [2]f32, name: string) {
	sources[name] = len(img_data)
	context.logger = log.create_console_logger()
	doc: ase.Document
	umerr := ase.unmarshal(&doc, data[:])
	defer ase.destroy_doc(&doc)
	if umerr != nil {
		fmt.panicf("Aseprite unmarshal error", umerr)
	}

	info, info_err := utils.get_info(&doc)
	defer utils.destroy(&info)
	if info_err != nil {
		fmt.panicf("Aseprite get_info error", info_err)
	}
	for frame in info.frames {
		fmt.println(frame.duration)
	}
	for tag in info.tags {
		tag_name := strings.clone(tag.name)
		append(&animations, anim{name = name, tag = tag_name, from = tag.from, to = tag.to})
		fmt.println(tag.name)
		fmt.println(tag.from, tag.to, tag.direction)
	}

	anim: utils.Animation
	anim_err := utils.get_animation(&doc, &anim)
	if anim_err != nil {
		fmt.panicf("get_animation error", anim_err)
	}
	defer utils.destroy(&anim)
	fmt.println(anim.md)


	imgs, img_err := utils.get_all_images(&doc)
	defer utils.destroy(imgs)
	if img_err != nil {
		fmt.panicf("Aseprite get_all_images error", img_err)
	}

	for img, index in imgs {
		id: i32 = i32(len(img_data))
		d := find_transparent(img.data, img.width, img.height)
		w := img.width - d.left - d.right + 1 // add padding
		h := img.height - d.top - d.bottom + 1
		imgdata := make([]byte, len(img.data))
		// need to copy because original image data will be deleted
		intrinsics.mem_copy_non_overlapping(
			rawptr(&imgdata[0]),
			rawptr(&img.data[0]),
			len(img.data),
		)
		append(&img_data, imgdata)
		append(&rects, rect_pack.Rect{id = id, w = rect_pack.Coord(w), h = rect_pack.Coord(h)})
		d.name = name
		d.index = index
		append(&dims, d)
	}
}

find_transparent :: proc(data: []byte, width, height: int) -> dim {
	d: dim
	d.src_w = width
	d.src_h = height

	for i in 0 ..< len(data) {
		if data[i * 4 + 3] != 0 {
			break
		}
		d.top = i / width
	}

	for i := height * width - 1; i >= 0; i -= 1 {
		if data[i * 4 + 3] != 0 {
			break
		}
		d.bottom = height - i / width - 1
	}


	LEFT: for x in 0 ..< width {
		for y in d.top ..< height - d.bottom {
			if data[(y * width + x) * 4 + 3] != 0 {
				break LEFT
			}
			d.left = x
		}
	}


	RIGHT: for i in 0 ..< width {
		x := width - i - 1
		for y in d.top ..< height - d.bottom {
			if data[(y * width + x) * 4 + 3] != 0 {
				break RIGHT
			}
			d.right = width - x - 1
		}
	}
	return d
}

