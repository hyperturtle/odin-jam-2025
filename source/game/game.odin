package game

import "core:math"
import "core:container/bit_array"
import rl "vendor:raylib"

Mod_Flat :: struct {
    value: int,
}

Mod :: union {
    Mod_Flat,
}

Node :: struct {
    pos: [2]f32,
    mods: []Mod,

    ghost: bool,
    root: bool,
    enabled: bool,
}

Connection :: struct {
    from: int,
    to: int,
}

nodes: [dynamic]Node
connections: [dynamic]Connection
hover_connections: [dynamic]Connection

find_mst :: proc(connections: ^[dynamic]Connection, ghost:bool = false) -> f32 {
    cost :f32= 0
    clear(connections)
    all_nodes_set :bit_array.Bit_Array
    count: int
    defer bit_array.destroy(&all_nodes_set)
    for node, i in nodes {
        if node.enabled || (ghost && node.ghost) {
            bit_array.set(&all_nodes_set, i)
            count += 1
        }
    }
    connected_set :bit_array.Bit_Array
    bit_array.set(&connected_set, 0)
    bit_array.unset(&all_nodes_set, 0)
    count -= 1
    defer bit_array.destroy(&connected_set)

    for count > 0 {
        lowest_dist: f32
        lowest_dist_node_a : int
        lowest_dist_node_b : int
        found:bool
        it := bit_array.make_iterator(&all_nodes_set)
        for {
            i, ok := bit_array.iterate_by_set(&it)
            if !ok {
                break
            }
            it_j := bit_array.make_iterator(&connected_set)
            for {
                j, j_ok := bit_array.iterate_by_set(&it_j)
                if !j_ok {
                    break
                }
                dist := rl.Vector2Length(nodes[i].pos - nodes[j].pos)
                if dist < lowest_dist || !found {
                    lowest_dist = dist
                    lowest_dist_node_a = i
                    lowest_dist_node_b = j
                    found = true
                }
            }
        }
        assert(found)
        count -= 1

        bit_array.unset(&all_nodes_set, lowest_dist_node_a)
        bit_array.set(&connected_set, lowest_dist_node_a)
        bit_array.unset(&all_nodes_set, lowest_dist_node_b)
        bit_array.set(&connected_set, lowest_dist_node_b)
        cost += lowest_dist
        append(connections, Connection{ lowest_dist_node_a, lowest_dist_node_b })
    }
    return cost
}

init :: proc() {
//    nodes = make([]Node, 1024)
//    for i in 0 ..< len(nodes) {
//        nodes[i].pos = { 0, 0 }
//    }

    append(&nodes, Node{ enabled = true, root = true, mods = { Mod_Flat{ 10 } } })
    append(&nodes, Node{ enabled = false, root = true, ghost=true })

    gen_circle :: proc($T: int, $div: int, mod: int=0) -> [T][2]f32 {
        circle : [T][2]f32
        for i in 0 ..< T * div {
            if i % div != mod {
                continue
            }
            angle := f32(i) * math.PI * 2 / f32(T * div)
            circle[i / div] = [2]f32{ math.sin(angle) , math.cos(angle) }
        }
        return circle
    }


    for i in gen_circle(5, 2, 0) {
        node:Node
        node.pos = i * 200
        append(&nodes, node)
    }
    for outer, x in gen_circle(6, 1) {
        for inner, y in gen_circle(4, 1) {
            if abs(x - y+12) % 12 < 3 { continue }
            node:Node
            node.pos = outer * 500 + inner * 100
            append(&nodes, node)
        }
    }

    for outer, x in gen_circle(12, 1) {
        for inner, y in gen_circle(12, 1) {

            node:Node
            node.pos = outer * 2000 + inner * 200
            append(&nodes, node)
        }
    }
}