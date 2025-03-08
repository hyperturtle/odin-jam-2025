package example

import "core:io"
import "core:os"
import "core:log"
import "core:fmt"
import "core:slice"
import "core:bytes"

import ase ".."


ase_example :: proc() {
    data := #load("../tests/blob/geralt.aseprite")
    doc: ase.Document
    defer ase.destroy_doc(&doc)

    un_err := ase.unmarshal(&doc, data[:])
    if un_err != nil {
        fmt.eprintln("Failed to Unmarshal my beloved, geralt.", un_err)
        return
    }

    fmt.println("Successfully Unmarshaled my beloved, geralt.")

    buf: [dynamic]byte
    defer delete(buf)

    written, m_err := ase.marshal(&doc, &buf)
    if m_err != nil {
        fmt.eprintln("Failed to Marshal my beloved, geralt.", m_err)
        return
    }

    fmt.println("Successfully Marshaled my beloved, geralt.")

    sus := os.write_entire_file("./out.aseprite", buf[:])
    if !sus {
        fmt.eprintln("Failed to Write my beloved, geralt.")
        return
    }
    
    fmt.println("Successfully Wrote my beloved, geralt.")
}


read_only :: proc() {
    data := #load("../tests/blob/geralt.aseprite")
    r: bytes.Reader
    bytes.reader_init(&r, data[:])
    ir, ok := io.to_reader(bytes.reader_to_stream(&r))

    cs_buf := make([dynamic]ase.Cel_Chunk)
    defer { 
        for c in cs_buf { 
            ase.destroy_chunk(c) 
        }
        delete(cs_buf)
    }
    err := ase.unmarshal_single_chunk(ir, &cs_buf)


    cm_buf := make([dynamic]ase.Chunk)
    defer {
        for c in cm_buf {
            #partial switch v in c {
            case ase.Cel_Chunk:       ase.destroy_chunk(v)
            case ase.Cel_Extra_Chunk: ase.destroy_chunk(v)
            case ase.Tileset_Chunk:   ase.destroy_chunk(v)
            }
        }
        delete(cm_buf)
    }
    set := ase.Chunk_Set{.cel, .cel_extra, .tileset}
    err = ase.unmarshal_multi_chunks(ir, &cm_buf, set)



    c_buf := make([dynamic]ase.Layer_Chunk)
    defer { 
        for c in c_buf { 
            ase.destroy_chunk(c) 
        }
        delete(c_buf)
    }
    err = ase.unmarshal_chunks(ir, &c_buf)


    cmc_buf := make([dynamic]ase.Chunk)
    defer {
        for c in cmc_buf {
            #partial switch v in c {
            case ase.Cel_Chunk:       ase.destroy_chunk(v)
            case ase.Cel_Extra_Chunk: ase.destroy_chunk(v)
            case ase.Tileset_Chunk:   ase.destroy_chunk(v)
            }
        }
        delete(cmc_buf)
    }
    err = ase.unmarshal_chunks(ir, &cmc_buf, set)
}
