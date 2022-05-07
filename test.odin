package test
import "libpdb"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:log"
import "core:runtime"
import "core:intrinsics"
import "core:bytes"
import "core:io"
import windows "core:sys/windows"

main ::proc() {
    //odin run test -debug -out:test\demo.exe > .\build\demo.log
    //odin run test.odin -file -out:build\test.pdb -- .\test\demo.pdb
    //odin run test.odin -file -out:build\test.exe -debug -- .\build\test.pdb
    //context.assertion_failure_proc = on_assert_fail
    windows.AddVectoredExceptionHandler(1, libpdb.dump_stack_trace_on_exception)

    context.logger.lowest_level = .Debug
    log_proc :: proc(data: rawptr, level: log.Level, text: string, options: log.Options, location:= #caller_location) {
        #partial switch level {
        // case log.Level.Debug: fmt.printf("[%v]: %v\n", level, text)
        case: fmt.printf("[%v]%v: %v\n", level, location, text)
        }
        //fmt.printf("[%v]%v: %v\n", level, location, text)
        //fmt.printf("[%v]: %v\n", level, text)
    }
    context.logger.procedure = log_proc

    {
        using libpdb
        usrFmts := make(map[typeid]fmt.User_Formatter, 4)
        fmt.set_user_formatters(&usrFmts)
        fmt.register_user_formatter(PESectionName, peSectionName_formatter)
    }

    if len(os.args) < 2 {
        test_dump_stack()
        return
    }
    path, _ := strings.replace_all(os.args[1], "\\", "/")
    log.debugf("reading %v\n", path)
    file_content, read_ok := os.read_entire_file(path)
    if !read_ok {
        log.errorf("Unable to open file")
        return
    }

    if strings.has_suffix(path, "pdb") {
        test_pdb(file_content)
    } else {
        test_exe(file_content)
    }
}

test_dump_stack :: proc() {
    foo()
}

foo :: proc() {
    fmt.println("foo..")
    bar()
    fmt.println("...done")
}

bar :: proc() {
    using libpdb
    when true {
        aov := make([]uint, 32)
        for i in 0..=32 {
            fmt.print(aov[i])
        }
    } else {
        traceBuf := make([]StackFrame , 32)
        traceCount := capture_stack_trace(traceBuf)
        srcCodeLines := parse_stack_trace(traceBuf[:traceCount], false)
        for scl in srcCodeLines {
            fmt.printf("%v:%d:%d:%v()\n", scl.file_path, scl.line, scl.column, scl.procedure)
        }
    }
}

test_exe :: proc(file_content: []byte) {
    using libpdb
    reader := make_dummy_reader(file_content)
    seek_to_pe_headers(&reader)
    coffHdr, optHdr, dataDirs := read_pe_headers(&reader)
    log.info(coffHdr)
    log.info(optHdr)
    log.info(dataDirs)
    secs := read_packed_array(&reader, uint(coffHdr.numSecs), PESectionHeader)
    log.info(secs)
}

test_pdb :: proc(file_content : []byte) {
    br : bytes.Reader
    bytes.reader_init(&br, file_content)
    bs := bytes.reader_to_stream(&br)
    bsr := io.Reader{bs}
    using libpdb
    sb, sbOk := read_superblock(bsr)
    if !sbOk {
        log.errorf("Unable to read superBlock")
        return
    }
    log.debugf("superblock: %v", sb)
    streamDir, streamDirOk := read_stream_dir(&sb, bsr)
    assert(streamDirOk)
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

    when true {
        
        dbiStream := parse_dbi_stream(&streamDir)
        // dbiStream := find_dbi_stream(&streamDir)
        log.debug(dbiStream)
        // mi := search_for_module(&dbiStream, 4096+446632)
        // log.debug(dbiStream.modules[mi])
    }

    namesStreamIdx := find_named_stream(nameMap, NamesStream_Name)
    if !stream_idx_valid(namesStreamIdx) {
        log.warn("Names stream unfound")
        return
    }
    namesSr := get_stream_reader(&streamDir, namesStreamIdx)
    namesStreamHdr := parse_names_stream(&namesSr)

    when false {
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
