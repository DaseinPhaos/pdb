package mainp
import "libpdb"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:log"

main ::proc() {
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

    pdbStreamReader := BlocksReader{
        data = file_content, blockSize = cast(uint)sb.blockSize, indices = streamDir.streamBlocks[PdbStream_Index], size = cast(uint)streamDir.streamSizes[PdbStream_Index],
    }
    // headerVersion := PdbStreamVersion(read_u32_from_blocks(&pdbStreamReader))
    //log.debugf("pdbStreamReaderSize: %v", pdbStreamReader.size)
    pdbHeader := readv_from_blocks(&pdbStreamReader, PdbStreamHeader)
    if pdbHeader.version != .VC70 {
        log.warnf("unrecoginized pdbStreamVersion: %v", pdbHeader.version)
    }

    nameStringLen := readv_from_blocks(&pdbStreamReader, u32le)
    log.debugf("nameStringLen: %v", nameStringLen)
    nameString := make([]byte, nameStringLen)
    for i in 0..<nameStringLen {
        nameString[i] = readv_from_blocks(&pdbStreamReader, byte)
    }
    //fmt.println(strings.string_from_ptr(&nameString[0], cast(int)nameStringLen))

    snamesMap := read_hash_table(&pdbStreamReader, u32le)
    //log.debugf("pdbHashTable: %v\n", pdbHashTable)
    for i in 0..< snamesMap.capacity {
        kv, ok := get_kv_at(&snamesMap, i)
        if ok {
            //fmt.printf("k: %v, v: %v, vstr: %v\n", kv.key, kv.value, ))
            nameStr : string
            assert(kv.key < nameStringLen, "invalid name key")
            nameStr = strings.string_from_nul_terminated_ptr(&nameString[kv.key], len(nameString)-int(kv.key))
            fmt.printf("bucket#%v [%v:%v], name: %v\n", i, kv.key, kv.value, nameStr)
        }
    }
}
