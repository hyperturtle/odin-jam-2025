package aseprite_file_handler_utility

import "base:runtime"
import "core:math/fixed"

@(require) import "core:fmt"
@(require) import "core:log"

import ase ".."


cels_from_doc :: proc(doc: ^ase.Document, alloc := context.allocator) -> (res: []Cel, err: runtime.Allocator_Error) {
    cels := make([dynamic]Cel, alloc) or_return
    defer if err != nil { delete(cels) }

    for frame in doc.frames {
        f_cels := get_cels(frame, alloc) or_return
        for &c in f_cels {
            if c.raw == nil && c.tilemap.tiles == nil {
                for l in cels[c.link:] {
                    if l.layer == c.layer {
                        c.height = l.height
                        c.width = l.width
                        c.raw = l.raw
                    }
                }
            }
        }

        append(&cels, ..f_cels) or_return
        delete(f_cels, alloc) or_return
    }

    return cels[:], nil
}

cels_from_doc_frame :: proc(frame: ase.Frame, alloc := context.allocator) -> (res: []Cel, err: runtime.Allocator_Error) {
    cels := make([dynamic]Cel, alloc) or_return
    defer if err != nil { delete(cels) }

    for chunk in frame.chunks {
        #partial switch c in chunk {
        case ase.Cel_Chunk:
            cel := Cel {
                pos = {int(c.x), int(c.y)},
                opacity = int(c.opacity_level),
                z_index = int(c.z_index),
                layer = int(c.layer_index)
            }
    
            switch v in c.cel {
            case ase.Com_Image_Cel:
                cel.width = int(v.width)
                cel.height = int(v.height)
                cel.raw = v.pixels

            case ase.Raw_Cel:
                cel.width = int(v.width)
                cel.height = int(v.height)
                cel.raw = v.pixels

            case ase.Linked_Cel:
                cel.link = int(v)

            case ase.Com_Tilemap_Cel:
                
                cel.tilemap = Tilemap {
                    width = int(v.width), 
                    height = int(v.height), 
                    x_flip = uint(v.bitmask_x), // Bitmask for X flip
                    y_flip = uint(v.bitmask_y), // Bitmask for Y flip
                    diag_flip = uint(v.bitmask_diagonal), // Bitmask for diagonal flip (swap X/Y axis)
                    tiles = make([]int, len(v.tiles), alloc) or_return, 
                }

                for &n, p in cel.tilemap.tiles {
                    switch t in v.tiles[p] {
                    case ase.BYTE:  n = int(t)
                    case ase.WORD:  n = int(t)
                    case ase.DWORD: n = int(t)
                    }
                }
            
            }
            append(&cels, cel) or_return

        case ase.Cel_Extra_Chunk:
            if ase.Cel_Extra_Flag.Precise in c.flags {
                extra := Precise_Bounds {
                    fixed.to_f64(c.x), fixed.to_f64(c.y), 
                    fixed.to_f64(c.width), fixed.to_f64(c.height), 
                }
                cels[len(cels)-1].extra = extra
            }
        }
    }

    return cels[:], nil
}

get_cels :: proc{cels_from_doc_frame, cels_from_doc}


layers_from_doc :: proc(doc: ^ase.Document, alloc := context.allocator) -> (res: []Layer, err: runtime.Allocator_Error) {
    layers := make([dynamic]Layer, alloc) or_return
    defer if err != nil { delete(layers) }

    for frame in doc.frames {
        f_lays := get_layers(frame, .Layer_Opacity in doc.header.flags) or_return
        append(&layers, ..f_lays) or_return
        delete(f_lays, alloc) or_return
    }

    return layers[:], nil
}

layers_from_doc_frame :: proc(frame: ase.Frame, layer_valid_opacity := false, alloc := context.allocator) -> (res: []Layer, err: runtime.Allocator_Error) {
    layers := make([dynamic]Layer, alloc) or_return
    defer if err != nil { delete(layers) }

    all_lays := make([dynamic]^ase.Layer_Chunk) or_return
    defer delete(all_lays)

    for chunk in frame.chunks {
        #partial switch &v in chunk {
        case ase.Layer_Chunk:
            lay := Layer {
                name = v.name, 
                opacity = int(v.opacity) if layer_valid_opacity else 255,
                index = len(layers),
                blend_mode = Blend_Mode(v.blend_mode),
                visiable = .Visiable in v.flags,
                tileset = int(v.tileset_index),
                is_background = .Background in v.flags,
            }

            #reverse for l in all_lays {
                if l.type == .Group {
                    if .Visiable not_in l.flags {
                        lay.visiable = false
                        break
                    }
                    if l.child_level == 0 {
                        break
                    }
                }
            }

            append(&all_lays, &v) or_return
            append(&layers, lay) or_return
        }
    }

    return layers[:], nil
}

get_layers :: proc{layers_from_doc_frame, layers_from_doc}


tags_from_doc :: proc(doc: ^ase.Document, alloc := context.allocator) -> (res: []Tag, err: runtime.Allocator_Error) {
    tags := make([dynamic]Tag, alloc)
    defer if err != nil { delete(tags) }

    for frame in doc.frames {
        f_tags := get_tags(frame, alloc) or_return
        append(&tags, ..f_tags) or_return
        delete(f_tags, alloc) or_return
    }

    return tags[:], nil
}

tags_from_doc_frame :: proc(frame: ase.Frame, alloc := context.allocator) -> (res: []Tag, err: runtime.Allocator_Error) {
    tags := make([dynamic]Tag, alloc) or_return
    defer if err != nil { delete(tags) }

    for chunk in frame.chunks {
        #partial switch v in chunk {
        case ase.Tags_Chunk:
            for t in v {
                tag := Tag {
                    int(t.from_frame), 
                    int(t.to_frame), 
                    t.loop_direction, 
                    t.name, 
                }
                append(&tags, tag) or_return
            }
        }
    }

    return tags[:], nil
}

get_tags :: proc{tags_from_doc_frame, tags_from_doc}


frames_from_doc :: proc(doc: ^ase.Document, alloc := context.allocator) -> (frames: []Frame, err: runtime.Allocator_Error) {
    return get_frames(doc.frames, alloc)
}

frames_from_doc_frames :: proc(data: []ase.Frame, alloc := context.allocator) -> (frames: []Frame, err: runtime.Allocator_Error) {
    res := make([dynamic]Frame, alloc) or_return
    defer if err != nil { delete(res) }

    for frame in data {
        append(&res, get_frame(frame) or_return) or_return
    }
    return
}

get_frames :: proc {
    frames_from_doc, 
    frames_from_doc_frames, 
}

get_frame :: proc(data: ase.Frame, alloc := context.allocator) -> (frame: Frame, err: runtime.Allocator_Error) {
    frame.duration = i64(data.header.duration)
    frame.cels = get_cels(data, alloc) or_return
    return
}


palette_from_doc :: proc(doc: ^ase.Document, alloc := context.allocator) -> (palette: Palette, err: Errors) {
    pal := make([dynamic]Color, alloc) or_return
    defer if err != nil { delete(pal) }
    
    for frame in doc.frames {
        get_palette(frame, &pal, has_new_palette(doc)) or_return
    }

    return pal[:], nil
}

palette_from_doc_frame:: proc(frame: ase.Frame, pal: ^[dynamic]Color, has_new: bool) -> (err: Errors) { 
    for chunk in frame.chunks {
        #partial switch c in chunk {
        case ase.Palette_Chunk:
            if int(c.last_index) >= len(pal) {
                resize(pal, int(c.last_index)+1) or_return
            }
            
            for i in c.first_index..=c.last_index {
                if int(i) > len(pal) { 
                    return Palette_Error.Color_Index_Out_of_Bounds
                }
                
                if n, ok := c.entries[i].name.(string); ok {
                    pal[i].name = n
                }
                pal[i].color = c.entries[i].color

            }

        case ase.Old_Palette_256_Chunk:
            if has_new { continue }
            for p in c {
                first := len(pal) + int(p.entries_to_skip)
                last := first + len(p.colors)
                if last >= len(pal) {
                    resize(pal, last) or_return
                }

                for i in first..<last {
                    if i >= len(pal) { 
                        return Palette_Error.Color_Index_Out_of_Bounds
                    }
                    pal[i].color.rgb = p.colors[i]
                    if p.colors[i] != 0 {
                        pal[i].color.a = 255
                    }
                    
                }
            }

        case ase.Old_Palette_64_Chunk:
            if has_new { continue }
            for p in c {
                first := len(pal) + int(p.entries_to_skip)
                last := first + len(p.colors)
                if last >= len(pal) {
                    resize(pal, last) or_return
                }

                for i in first..<last {
                    if i >= len(pal) { 
                        return Palette_Error.Color_Index_Out_of_Bounds
                    }

                    pal[i].color.rgb = p.colors[i]
                    if p.colors[i] != 0 {
                        pal[i].color.a = 255
                    }
                }
            }
        }
    }

    return
}

get_palette :: proc{palette_from_doc, palette_from_doc_frame}


tileset_from_doc :: proc(doc: ^ase.Document, alloc := context.allocator) -> (ts: []Tileset, err: runtime.Allocator_Error) {
    buf := make([dynamic]Tileset, alloc) or_return
    for frame in doc.frames {
        err = get_tileset(frame, &buf, alloc)
        if err != nil {
            return buf[:], err
        }
    }
    if len(buf) > 0 {
        log.warn("Tilemaps & Tilesets currently only work for RGBA colour space.")
    }
    return buf[:], nil
}

tileset_from_doc_frame :: proc(frame: ase.Frame, buf: ^[dynamic]Tileset, alloc := context.allocator) -> (err: runtime.Allocator_Error) {
    for chunk in frame.chunks {
        #partial switch v in chunk {
        case ase.Tileset_Chunk:
            ts: Tileset = {
                int(v.id), 
                int(v.width), 
                int(v.height), 
                int(v.num_of_tiles),
                v.name, 
                nil, 
            }

            if t, ok := v.compressed.?; ok {
                ts.tiles = (Pixels)(t)
            }

            append(buf, ts) or_return

        case ase.User_Data_Chunk:
        }
    }
    
    return
}

get_tileset :: proc{tileset_from_doc, tileset_from_doc_frame}


get_info :: proc(doc: ^ase.Document, alloc := context.allocator) -> (info: Info, err: Errors) {
    context.allocator = alloc
    info.allocator = alloc

    layer_valid_opacity := .Layer_Opacity in doc.header.flags
    has_new := has_new_palette(doc)

    frames := make([dynamic]Frame) or_return
    lays   := make([dynamic]Layer) or_return
    tags   := make([dynamic]Tag) or_return
    all_ts := make([dynamic]Tileset) or_return
    pal    := make([dynamic]Color) or_return
    sls    := make([dynamic]Slice) or_return
    md     := get_metadata(doc.header)

    all_lays := make([dynamic]^ase.Layer_Chunk) or_return
    defer delete(all_lays)

    hue_sat_warn: bool

    // TODO: Make big assumption that only Cel Chunks appear after first frame.

    for doc_frame in doc.frames {
        frame: Frame
        frame.duration = i64(doc_frame.header.duration)
        cels := make([dynamic]Cel) or_return

        for &chunk in doc_frame.chunks {

            #partial switch &c in chunk {
            case ase.Cel_Chunk:
                cel := Cel {
                    pos = {int(c.x), int(c.y)},
                    opacity = int(c.opacity_level),
                    z_index = int(c.z_index),
                    layer = int(c.layer_index)
                } 
        
                switch v in c.cel {
                case ase.Com_Image_Cel:
                    cel.width = int(v.width)
                    cel.height = int(v.height)
                    cel.raw = v.pixels

                case ase.Raw_Cel:
                    cel.width = int(v.width)
                    cel.height = int(v.height)
                    cel.raw = v.pixels

                case ase.Linked_Cel: 
                    for l in frames[v].cels {
                        if l.layer == cel.layer {
                            cel.height = l.height
                            cel.width = l.width
                            cel.raw = l.raw
                            cel.link = int(v)
                        }
                    }
                
                case ase.Com_Tilemap_Cel:
                    cel.tilemap = Tilemap {
                        width = int(v.width), 
                        height = int(v.height), 
                        x_flip = uint(v.bitmask_x), // Bitmask for X flip
                        y_flip = uint(v.bitmask_y), // Bitmask for Y flip
                        diag_flip = uint(v.bitmask_diagonal), // Bitmask for diagonal flip (swap X/Y axis)
                        tiles = make([]int, len(v.tiles), alloc) or_return, 
                    }
    
                    for &n, p in cel.tilemap.tiles {
                        switch t in v.tiles[p] {
                        case ase.BYTE:  n = int(t)
                        case ase.WORD:  n = int(t)
                        case ase.DWORD: n = int(t)
                        }
                    }
                }

                append(&cels, cel) or_return
            
            case ase.Cel_Extra_Chunk:
                if ase.Cel_Extra_Flag.Precise in c.flags {
                    extra := Precise_Bounds {
                        fixed.to_f64(c.x), fixed.to_f64(c.y), 
                        fixed.to_f64(c.width), fixed.to_f64(c.height), 
                    }
                    cels[len(cels)-1].extra = extra
                }
            
            case ase.Layer_Chunk:
                lay := Layer {
                    name = c.name, 
                    opacity = int(c.opacity) if layer_valid_opacity else 255,
                    index = len(lays),
                    blend_mode = Blend_Mode(c.blend_mode),
                    visiable = .Visiable in c.flags,
                    tileset = int(c.tileset_index),
                }

                when !ASE_USE_BUGGED_SAT {
                    if !hue_sat_warn && (lay.blend_mode == .Saturation || lay.blend_mode == .Hue) {
                        log.infof("Layer: \"%v\"; \"%v\" blend mode is bugged in Aseprite, in ways we can't replicate.", lay.name, lay.blend_mode)
                        log.info("By default we use a fixed version. Compile with `ASE_USE_BUGGED_SAT=true` to use a bugged version.")
                        hue_sat_warn = true
                    }
                }
                

                if c.child_level != 0 {
                    #reverse for l in all_lays {
                        if l.type == .Group {
                            if .Visiable not_in l.flags {
                                lay.visiable = false
                                break
                            }
                            if l.child_level == 0 {
                                break
                            }
                        }
                    }
                }

                append(&lays, lay) or_return
                append(&all_lays, &c) or_return

            case ase.Tags_Chunk:
                for t in c {
                    tag := Tag {
                        int(t.from_frame), 
                        int(t.to_frame), 
                        t.loop_direction, 
                        t.name
                    }
                    append(&tags, tag) or_return
                }
            
            case ase.Palette_Chunk:
                if int(c.last_index) >= len(pal) {
                    resize(&pal, int(c.last_index)+1) or_return
                }
                
                for i in c.first_index..=c.last_index {
                    if int(i) >= len(pal) { 
                        err = Palette_Error.Color_Index_Out_of_Bounds
                        return 
                    }
                    
                    if n, ok := c.entries[i].name.(string); ok {
                        pal[i].name = n
                    }
                    pal[i].color = c.entries[i].color
                }
    
            case ase.Old_Palette_256_Chunk:
                if has_new { continue }
                for p in c {
                    first := len(pal) + int(p.entries_to_skip)
                    last := first + len(p.colors)
                    if last >= len(pal) {
                        resize(&pal, last) or_return
                    }
    
                    for i in first..<last {
                        if i >= len(pal) { 
                            err = Palette_Error.Color_Index_Out_of_Bounds
                            return
                        }
                        pal[i].color.rgb = p.colors[i]
                        if p.colors[i] != 0 {
                            pal[i].color.a = 255
                        }
                    }
                }
    
            case ase.Old_Palette_64_Chunk:
                if has_new { continue }
                for p in c {
                    first := len(pal) + int(p.entries_to_skip)
                    last := first + len(p.colors)
                    if last >= len(pal) {
                        resize(&pal, last) or_return
                    }
    
                    for i in first..<last {
                        if i >= len(pal) { 
                            err = Palette_Error.Color_Index_Out_of_Bounds
                            return
                        }
                        if max(p.colors[i].r, p.colors[i].b, p.colors[i].g) > 63 {
                            err = Palette_Error.Color_Index_Out_of_Bounds
                            return
                        }

                        // https://github.com/alpine-alpaca/asefile/blob/2274c354cea6764f85597252a0d2228e64709348/src/palette.rs#L134
                        // Scale such that 0 -> 0 & 63 -> 255
                        pal[i].color.r = p.colors[i].r << 2 | p.colors[i].r >> 4
                        pal[i].color.g = p.colors[i].g << 2 | p.colors[i].g >> 4
                        pal[i].color.b = p.colors[i].b << 2 | p.colors[i].b >> 4
                        if p.colors[i] != 0 {
                            pal[i].color.a = 255
                        }
                    }
                }

            case ase.Tileset_Chunk:
                ts: Tileset
                ts.id = int(c.id)
                ts.width = int(c.width)
                ts.height = int(c.height)
                ts.name = c.name

                if t, ok := c.compressed.?; ok {
                    ts.tiles = (Pixels)(t)
                }

                append(&all_ts, ts) or_return
            
            /*case ase.Slice_Chunk:
                sl: Slice
                sl.name = c.name
                sl.flags = c.flags
                sl.keys = make([]Slice_Key, len(c.keys))

                for &key, pos in sl.keys {
                    c_key := c.keys[pos]
                    key.frame = int(c_key.frame_num)
                    key.x = int(c_key.x)
                    key.y = int(c_key.y)
                    key.w = int(c_key.width)
                    key.h = int(c_key.height)

                    if center, ok := c_key.center.?; ok {
                        key.center = {
                            int(center.x), int(center.y),
                            int(center.width), int(center.height)
                        }
                    }

                    if pivot, ok := c_key.pivot.?; ok {
                        key.pivot = { int(pivot.x), int(pivot.y) }
                    }
                }
                append(&sls, sl)*/
            }
        }

        frame.cels = cels[:]
        append(&frames, frame) or_return
    }

    return {frames[:], lays[:], tags[:], all_ts[:], sls[:], pal[:], md, alloc}, nil
}
