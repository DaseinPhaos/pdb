package mainp
import "libpdb"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:log"

main ::proc() {
    //odin run test.odin -file -out:build\test.exe -debug -- .\build\test.pdb
    //pdb_path := "H:/projects/pdbReader/build/test.pdb"
    //pdb_path := "G:/repos/PDBDumpWV/PDBDumpWV/bin/Debug/PDBDumpWV.pdb"
    pdb_path, _ := strings.replace_all(os.args[1], "\\", "/")
    log.debugf("reading %v\n", pdb_path)
    file_content, read_ok := os.read_entire_file(pdb_path)
    if !read_ok {
        log.errorf("Unable to open file")
        return
    }

    context.logger.lowest_level = .Debug
    log_proc :: proc(data: rawptr, level: log.Level, text: string, options: log.Options, location:= #caller_location) {
        #partial switch level {
        case log.Level.Debug:
            fmt.printf("[%v]: %v\n", level, text)
        case:
            fmt.printf("[%v]%v: %v\n", level, location, text)
        }
        //fmt.printf("[%v]%v: %v\n", level, location, text)
        //fmt.printf("[%v]: %v\n", level, text)
    }
    context.logger.procedure = log_proc
    
    using libpdb
    sb: SuperBlock
    if !read_superblock(&sb, file_content) {
        log.errorf("Unable to read superBlock")
        return
    }
    log.debugf("superblock: %v", sb)
    streamDir := read_stream_dir(&sb, file_content)
    //log.debugf("streamDir: %v\n", streamDir)

    pdbSr := get_stream_reader(&streamDir, PdbStream_Index)
    pdbHeader, nameMap, pdbFeatures := parse_pdb_stream(&pdbSr)
    for ns in nameMap.names {
        log.debug(ns)
    }
    // for feature in pdbFeatures {
    //     log.debug(feature)
    // }
    
    tpiSr := get_stream_reader(&streamDir, TpiStream_Index)
    tpiStream, _ := parse_tpi_stream(&tpiSr, &streamDir)
    //fmt.println(tpiStream)

    ipiSr := get_stream_reader(&streamDir, IpiStream_Index)
    ipiStream, _ := parse_tpi_stream(&ipiSr, &streamDir)
    //fmt.println(ipiStream)

    when false {
        dbiSr := get_stream_reader(&streamDir, DbiStream_Index)
        dbiStream := parse_dbi_stream(&dbiSr)
    }

    namesStreamIdx, namesStreamFound := find_named_stream(nameMap, "/names")
    if !namesStreamFound {
        log.warn("Names stream unfound")
        return
    }
    namesSr := get_stream_reader(&streamDir, namesStreamIdx)
    namesStreamHdr := parse_names_stream(&namesSr)

    when true {
        modi := DbiModInfo{
            _base = {
            unused1 = 0, 
            sectionContr = DbiSecContrEntry{
                section = 1, 
                padding1 = 0, 
                offset = 0, 
                size = 528566, 
                chaaracteristics = 1615863840, 
                moduleIndex = 0, 
                padding2 = 0, 
                dataCrc = 0, 
                relocCrc = 0,
            }, 
            flags = .None, 
            moduleSymStream = 13, 
            symByteSize = 286364, 
            c11ByteSize = 0, 
            c13ByteSize = 115700, 
            sourceFileCount = 47, 
            padding = 0, 
            unused2 = 0, 
            sourceFileNameIndex = 0, 
            pdbFilePathNameIndex = 0,
            }, 
            moduleName = "H:\\projects\\pdbReader\\build\\test.obj",
            objFileName = "H:\\projects\\pdbReader\\build\\test.obj",
        }
        modSr := get_stream_reader(&streamDir, u32le(modi.moduleSymStream))
        parse_mod_stream(&modSr, &modi, &namesSr)
    }
}
