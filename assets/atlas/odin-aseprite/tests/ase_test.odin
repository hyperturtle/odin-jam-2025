package ase_tests

import "base:runtime"
import "core:os"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:slice"
import "core:testing"
import "core:strings"
import fp "core:path/filepath"
import ase ".."


@(test)
ase_unmarshal :: proc(t: ^testing.T) {
    context.logger = log.create_console_logger()
    defer log.destroy_console_logger(context.logger)

    track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		for _, leak in track.allocation_map {
			fmt.printf("%v leaked %v bytes\n", leak.location, leak.size)
		}

		for bad_free in track.bad_free_array {
			fmt.printf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory)
		}
	}

    data := #load("/asefile/basic-16x16.aseprite")
    doc: ase.Document
    defer ase.destroy_doc(&doc)

    n, uerr := ase.unmarshal(data[:], &doc)

    ok := expect(t, n == int(doc.header.size), fmt.tprintf("%s Wrong Read Size: %v, File: /asefile/basic-16x16.aseprite", #procedure, n))

    ok = expect(t, uerr == nil, fmt.tprintf("%s Error: %v, File: /asefile/basic-16x16.aseprite", #procedure, uerr))
}

@(test)
ase_marshal :: proc(t: ^testing.T) {
    context.logger = log.create_console_logger()
    defer log.destroy_console_logger(context.logger)

    track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		for _, leak in track.allocation_map {
			fmt.printf("%v leaked %v bytes\n", leak.location, leak.size)
		}

		for bad_free in track.bad_free_array {
			fmt.printf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory)
		}
	}

    data := #load("/asefile/basic-16x16.aseprite")
    doc: ase.Document
    defer ase.destroy_doc(&doc)

    n, uerr := ase.unmarshal(data[:], &doc)

    ok := expect(t, n == int(doc.header.size), fmt.tprintf("%s Wrong Read Size: %v, File: /asefile/basic-16x16.aseprite", #procedure, n))
    ok = expect(t, uerr == nil, fmt.tprintf("%s Error: %v, File: /asefile/basic-16x16.aseprite", #procedure, uerr))
    if !ok {
        testing.fail_now(t, "Unable to unmarshal")
    }

    buf := make([dynamic]byte, context.temp_allocator)
    defer delete(buf)
    _, merr := ase.marshal(&buf, &doc)

    ok = expect(t, merr == nil, fmt.tprintf("%s Error: %v, File: /asefile/basic-16x16.aseprite", #procedure, merr))
    if !ok {
        testing.fail_now(t, "Unable to marshal")
    }

    ok = expect(t, slice.equal(buf[:], data[:]), fmt.tprintf("%s File: /asefile/basic-16x16.aseprite", #procedure))
    if !ok {
        testing.fail_now(t, "Marshaled doesn't match input")
    }

}


@(test)
ase_full_test :: proc(t: ^testing.T) {
    context.logger = log.create_console_logger()
    defer log.destroy_console_logger(context.logger)

    track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
    defer {
        for _, leak in track.allocation_map {
            fmt.printf("%v leaked %v bytes\n", leak.location, leak.size)
		}

		for bad_free in track.bad_free_array {
			fmt.printf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory)
		}
    }

    fd, f_err := os.open(".", os.O_RDONLY, 0)
    base_f, FF_err := os.read_dir(fd, 0)
    defer {
        for b in base_f {
            delete(b.fullpath)
        }
        delete(base_f)
    }
    os.close(fd)
    fmt.println(" ")

    for f in base_f {
        if f.is_dir {
            folder_h, f_err := os.open(f.fullpath, os.O_RDONLY, 0)
            defer os.close(folder_h)
            sprites, ff_err := os.read_dir(folder_h, 0)
            defer { 
                for s in sprites {
                    delete(s.fullpath)
                }
                delete(sprites) 
            }
            fmt.println("Found Dir:", f.name)

            for s in sprites {
                if strings.has_suffix(s.name, ".aseprite") || strings.has_suffix(s.name, ".ase") {
                    file_h, f_err := os.open(s.fullpath, os.O_RDONLY, 0)
                    defer os.close(file_h)
                    data, ok := os.read_entire_file(file_h)
                    defer delete(data)

                    if !ok {
                        testing.fail_now(t, fmt.tprintf("%s: Failed to load file %v", #procedure, s.name))
                    }
                    fmt.println("   Testing:", s.name)

                    doc: ase.Document
                    defer ase.destroy_doc(&doc)
                    n, unerr := ase.unmarshal(data[:], &doc)

                    if unerr != nil {
                        errorf(t, "%s: Unmarshal Error: %v, File: %v", #procedure, unerr, s.name)
                        continue
                    }

                    buf, bur_err := make([dynamic]byte)
                    defer delete(buf)
                    if bur_err != nil {
                        testing.fail_now(t, fmt.tprintf("%s: Failed to make buffer.", #procedure))
                    }

                    _, merr := ase.marshal(&buf, &doc)
                    if merr != nil {
                        errorf(t, "%s: Marshal Error: %v, File: %v", #procedure, merr, s.name)
                        continue
                    }

                    doc2: ase.Document
                    defer ase.destroy_doc(&doc2)
                    n2, unerr2 := ase.unmarshal(data[:], &doc2)

                    if unerr2 != nil {
                        errorf(t, "Full Test: Unmarshal Error 2: %v, File: %v", unerr2, s.name)
                        continue
                    }

                    for frame in doc2.frames {
                        for chunk in frame.chunks {
                            #partial switch chunk in chunk {
                                case ase.Cel_Chunk: {
                                    #partial switch cel in chunk.cel {
                                        case ase.Com_Image_Cel: {
                                            if cel.width > 0 && cel.height > 0 && len(cel.pixel) == 0 {
                                                testing.fail_now(t, fmt.tprintf("No pixel generated for cel.", #procedure))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    /*a, b, ty, o := ase.document_equal(doc, doc2)
                    if !o {
                        errorf (
                            t, 
                            "Full Test: Unmarshaled Doc don't equal OG Doc. %s \nx: %v\ny: %v\nType: %v", 
                            s.name, a, b, ty \
                        )
                    }*/
                }
            }
            fmt.println(" ")
        }
    }
}