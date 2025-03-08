package game

import rl "vendor:raylib"
import "core:fmt"
import "core:c"
import "assets"

run: bool
texture: rl.Texture
texture2: rl.Texture
texture2_rot: f32

img_raw := #load("assets/atlas.png", []u8)
shader_raw := #load("assets/sample.fs", []u8)
shader : rl.Shader

init :: proc() {
    fmt.println("ok")
    run = true
    rl.SetConfigFlags({ .WINDOW_RESIZABLE, .VSYNC_HINT })
    rl.InitWindow(1280, 720, "Odin + Raylib on the web")

    img := rl.LoadImageFromMemory(".png", &img_raw[0], c.int(len(img_raw)))
    texture = rl.LoadTextureFromImage(img)
    rl.UnloadImage(img)


    shader = rl.LoadShaderFromMemory(nil, cstring(&shader_raw[0]))
}

update :: proc() {
    rl.BeginDrawing()
    rl.ClearBackground({ 0, 120, 153, 255 })
    {
        texture2_rot += rl.GetFrameTime() * 50
        source_rect := rl.Rectangle {
            0, 0,
            f32(texture.width), f32(texture.height),
        }
        dest_rect := rl.Rectangle {
            300, 220,
            f32(texture.width) * 5, f32(texture.height) * 5,
        }
        s := assets.get_sprite(.off)
        rl.DrawTexturePro(texture, {s.x, s.y, s.w, s.h}, {100, 100, s.w*2, s.h*2}, { s.w, s.h }, texture2_rot, rl.WHITE)
    }
    rl.BeginShaderMode(shader)
    rl.EndShaderMode()
    rl.EndDrawing()

    // Anything allocated using temp allocator is invalid after this.
    free_all(context.temp_allocator)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
parent_window_size_changed :: proc(w, h: int) {
    rl.SetWindowSize(c.int(w), c.int(h))
}

shutdown :: proc() {
    rl.CloseWindow()
}

should_run :: proc() -> bool {
    when ODIN_OS != .JS {
    // Never run this proc in browser. It contains a 16 ms sleep on web!
        if rl.WindowShouldClose() {
            run = false
        }
    }

    return run
}