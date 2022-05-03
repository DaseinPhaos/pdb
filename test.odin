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
        fmt.printf("[%v]%v: %v\n", level, location, text)
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

    pdbStreamReader := get_stream_reader(&streamDir, PdbStream_Index)
    pdbHeader, nameMap, pdbFeatures := parse_pdb_stream(&pdbStreamReader)
    for ns in nameMap.names {
        log.debug(ns)
    }
    for feature in pdbFeatures {
        log.debug(feature)
    }
    
    tpiStreamReader := get_stream_reader(&streamDir, TpiStream_Index)
    tpiStream, _ := parse_tpi_stream(&tpiStreamReader, &streamDir)
    //fmt.println(tpiStream)

    ipiStreamReader := get_stream_reader(&streamDir, IpiStream_Index)
    ipiStream, _ := parse_tpi_stream(&ipiStreamReader, &streamDir)
    //fmt.println(ipiStream)

    dbiStreamReader := get_stream_reader(&streamDir, DbiStream_Index)
    dbiStream := parse_dbi_stream(&dbiStreamReader)
}
