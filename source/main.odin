package main

import "assets"
import "core:c"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "game"
import rl "vendor:raylib"

run: bool
texture: rl.Texture
texture2: rl.Texture
texture2_rot: f32

img_raw := #load("assets/atlas.png", []u8)
shader_raw := #load("assets/sample.fs", []u8)
shader: rl.Shader

init :: proc() {
    fmt.println("ok")
    run = true
    rl.SetConfigFlags({ .WINDOW_RESIZABLE, .VSYNC_HINT })
    rl.InitWindow(1280, 720, "Odin + Raylib on the web")

    img := rl.LoadImageFromMemory(".png", &img_raw[0], c.int(len(img_raw)))
    texture = rl.LoadTextureFromImage(img)
    rl.UnloadImage(img)


    shader = rl.LoadShaderFromMemory(nil, cstring(&shader_raw[0]))

    game.init()
    camera.zoom = 1
    camera.target = { 0, 0 }

    energy_cap = 2000

    for i in 0 ..< 50 {
        spawn_storm(i)
    }
}

spawn_storm :: proc(i: int) {
    r := f32(rand.int31() % 10) * 50 + 100
    angle := rand.float32() * math.TAU
    distance :f32= rand.float32_range(3000, 6000)
    vec := vec2{ math.cos(angle), math.sin(angle) }
    storms[i] = Storm{ vec * distance, -vec * 1E1, -vec * 1E1, r }
}

camera: rl.Camera2D
vec2 :: [2]f32
is_dragging := false
drag_start: vec2

Projectile :: struct {
    pos: vec2,
    vel: vec2,
    life: f32,
}
projectiles: [dynamic]Projectile
shoot_cooldown: f32

energy: f32
energy_cap: f32
current_energy_use: f32
hover_energy_use: f32

Storm :: struct {
    pos: vec2,
    vel: vec2,
    acc: vec2,
    radius: f32,
}
storms: [50]Storm

update :: proc() {


    frame_time := rl.GetFrameTime()

    camera.offset = rl.Vector2{ f32(rl.GetScreenWidth()) / 2, f32(rl.GetScreenHeight()) / 2 }

    screen_space_pos := vec2{ f32(rl.GetMouseX()), f32(rl.GetMouseY()) }
    world_pos := rl.GetScreenToWorld2D(screen_space_pos, camera)

    over_node: ^game.Node
    for &node in game.nodes {
        d := rl.Vector2DistanceSqrt(world_pos, node.pos)
        if d < 20 * 20 {
            over_node = &node
        }
    }

    closest_node := &game.nodes[0]
    for &node in game.nodes {
        if node.enabled {
            if rl.Vector2DistanceSqrt(world_pos, node.pos) <
            rl.Vector2DistanceSqrt(world_pos, closest_node.pos) {
                closest_node = &node
            }
        }
    }
    aim_dist: f32
    aim: vec2
    if over_node == nil {
        aim_dist = rl.Vector2Distance(world_pos, closest_node.pos)
        aim = (world_pos - closest_node.pos) / aim_dist
    } else {
        aim_dist = rl.Vector2Distance(closest_node.pos, over_node.pos)
        aim = (over_node.pos - closest_node.pos) / aim_dist
    }


    if rl.IsMouseButtonDown(.RIGHT) && over_node == nil {
        if shoot_cooldown <= 0 {
            append(&projectiles, Projectile{ closest_node.pos, aim * 100, 0 })
            shoot_cooldown = 0.1
        }
    }
    if shoot_cooldown > 0 {
        shoot_cooldown -= frame_time
    }

    if rl.IsMouseButtonDown(.LEFT) {
        if is_dragging {
            camera.target += drag_start - world_pos
        } else if over_node == nil {
            is_dragging = true
            drag_start = world_pos
        }
    } else {
        is_dragging = false
    }


    if rl.IsMouseButtonReleased(.LEFT) {
        if over_node != nil && !over_node.root && !over_node.ghost {
            old_use := game.find_mst(&game.connections)
            over_node.enabled = !over_node.enabled
            new_energy_use := game.find_mst(&game.connections)
            if new_energy_use - old_use < energy {
                energy -= new_energy_use - old_use
                current_energy_use = new_energy_use
            } else {
                over_node.enabled = !over_node.enabled
                game.find_mst(&game.connections)
            }
        }
    }

    game.nodes[1].pos = world_pos
    if over_node != nil {
        hover_energy_use = game.find_mst(&game.hover_connections, ghost_node = over_node)
    } else {
        hover_energy_use = game.find_mst(&game.hover_connections, ghost = true)
    }
    energy = min(energy + frame_time * 50, energy_cap)

    wheel := rl.GetMouseWheelMove()
    if wheel > 0 {
        camera.zoom *= 1.05
    } else if wheel < 0 {
        camera.zoom /= 1.05
    }

    for &projectile in projectiles {
        projectile.pos += projectile.vel * frame_time
    }
    for &storm, i in storms {
        d2 := rl.Vector2LengthSqr(storm.pos)
        storm.radius = max(0, storm.radius - frame_time / d2 * 1E7)
        if storm.radius <= 0.01 || d2 > 10000*10000{
            spawn_storm(i)
        }

        m := storm.radius * storm.radius
        for &other_storm in storms {
            if storm == other_storm {
                continue
            }
            d := storm.pos - other_storm.pos
            d2 := rl.Vector2LengthSqr(d) + 1E4
            m2 := other_storm.radius * other_storm.radius
            storm.acc += d / d2 * 1E-10 * m * m2
        }
        // pull towards center
        //        d2 = abs(d2 - math.round(d2 / 1000))
        storm.acc -= storm.pos / d2 * 1E-5 * m
        storm.vel += storm.acc * frame_time
        dv := rl.Vector2Length(storm.vel)
        limit :: 100
        if dv > limit {
//            storm.vel = storm.vel / dv * limit
        }


        storm.pos += storm.vel * frame_time
            storm.vel *= 0.999
    //        storm.acc *= 0.9
    }

    rl.BeginDrawing()
    rl.ClearBackground({ 30, 30, 30, 255 })
    rl.BeginMode2D(camera)
    {
        for storm in storms {
            rl.DrawCircleLinesV(storm.pos, storm.radius, { 255, 128, 0, 128 })
            rl.DrawCircleV(storm.pos, storm.radius, { 255, 128, 0, 20 })

            rl.DrawLineV(storm.pos, storm.pos + storm.vel*1E0, rl.RED)
            rl.DrawLineV(storm.pos, storm.pos + storm.acc*1E0, rl.BLUE)
        }

        enough_energy := hover_energy_use - current_energy_use < energy
        for connection in game.hover_connections {
            rl.DrawLineEx(
            game.nodes[connection.from].pos,
            game.nodes[connection.to].pos,
            10,
            { 255, 255, 255, 50 } if enough_energy else { 251, 0, 0, 50 },
            )
        }
        for connection in game.connections {
            rl.DrawLineEx(
            game.nodes[connection.from].pos,
            game.nodes[connection.to].pos,
            3,
            { 251, 242, 54, 255 },
            )
        }


        rl.DrawLineEx(
        closest_node.pos,
        closest_node.pos + aim * clamp(aim_dist, 0, energy),
        3,
        rl.YELLOW if enough_energy else rl.RED,
        )

        for projectile in projectiles {
            rl.DrawCircleV(projectile.pos, 5, rl.RED)
        }


        for node, i in game.nodes {
            if node.ghost {
                continue
            }
            s: assets.sprite
            if node.root {
                s = assets.get_sprite(.icons_home)
            } else {
                switch i % 3 {
                case 0:
                    s = assets.get_sprite(.icons_power)
                case 1, 2:
                    s = assets.get_sprite(.icons_battery)
                }
            }
            h := assets.get_sprite(.holder_on if node.enabled else .holder_off)
            rl.DrawTexturePro(
            texture,
            { s.x, s.y, s.w, s.h },
            { node.pos.x, node.pos.y, s.w * 2, s.h * 2 },
            { s.w, s.h },
            texture2_rot,
            rl.WHITE,
            )
            rl.DrawTexturePro(
            texture,
            { h.x, h.y, h.w, h.h },
            { node.pos.x, node.pos.y, h.w * 2, h.h * 2 },
            { h.w, h.h },
            texture2_rot,
            rl.WHITE,
            )
        }
    }

    rl.EndMode2D()
    rl.DrawText(
    fmt.ctprintf("%.1f\n%.1f", hover_energy_use - current_energy_use, energy),
    10,
    10,
    20,
    rl.WHITE,
    )
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

