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
        log.errorf("Unable to open file %v", path)
        return
    }

    if strings.has_suffix(path, "pdb") {
        test_pdb(file_content)
    } else {
        test_exe(file_content)
    }
}

test_dump_stack ::#force_inline proc() {
    foo()
}

foo ::#force_inline proc() {
    fmt.println("foo..")
    bar()
    fmt.println("...done")
}

bar :: proc() {
    using libpdb
    when false {
        aov := make([]uint, 32)
        for i in 0..=32 {
            fmt.print(aov[i])
        }
    } else {
        traceBuf := make([]StackFrame , 32)
        traceCount := capture_stack_trace(traceBuf)
        srcCodeLocs : RingBuffer(runtime.Source_Code_Location)
        init_rb(&srcCodeLocs, 32)
        parse_stack_trace(traceBuf[:traceCount], true, &srcCodeLocs)
        for i in 0..<srcCodeLocs.len {
            scl := get_rb(&srcCodeLocs, i)
            fmt.printf("%v:%d:%d: %v()\n", scl.file_path, scl.line, scl.column, scl.procedure)
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

    dbiStream := parse_dbi_stream(&streamDir)
    //log.debug(dbiStream)
    mainModule : Maybe(SlimDbiMod)
    for module in dbiStream.modules {
        if module.moduleName == "H:\\projects\\pdbReader\\build\\test.obj" {
            mainModule = module
            break
        }
    }
    modi, mmOk := mainModule.?
    if !mmOk do return

    namesStreamIdx := find_named_stream(nameMap, NamesStream_Name)
    if !stream_idx_valid(namesStreamIdx) {
        log.warn("Names stream unfound")
        return
    }
    namesSr := get_stream_reader(&streamDir, namesStreamIdx)
    namesStreamHdr := parse_names_stream(&namesSr)

    when false {
        modSr := get_stream_reader(&streamDir, modi.moduleSymStream)
        modHeader := readv(&modSr, ModStreamHeader)
        log.debug(modHeader)

        { // symbol substream
            symSubStreamSize := modi.symByteSize - 4
            symSubStreamEnd := modSr.offset + uint(symSubStreamSize)
            defer modSr.offset = symSubStreamEnd
            //stack := make_stack(CvsInlineSite, cast(int)symSubStreamSize / ((size_of(CvsInlineSite)+size_of(CvsRecordKind))*4), context.temp_allocator)
            //defer delete_stack(&stack)
            for modSr.offset < symSubStreamEnd {
                cvsHeader  := readv(&modSr, CvsRecordHeader)
                baseOffset := modSr.offset
                blockEnd := baseOffset+ uint(cvsHeader.length) - size_of(CvsRecordKind)
                defer modSr.offset = blockEnd
                #partial switch cvsHeader.kind {
                case .S_INLINESITE:
                    cvsIs := readv(&modSr, blockEnd, CvsInlineSite)
                    log.debug(cvsIs)
                }
            }
        }

        {
            // skip c11 lines
            modSr.offset += uint(modi.c11ByteSize)
            c13StreamStart  := modSr.offset
            c13StreamEnd    := modSr.offset + uint(modi.c13ByteSize)
            // second pass
            modSr.offset = c13StreamStart
            for modSr.offset < c13StreamEnd {
                ssh := readv(&modSr, CvDbgSubsectionHeader)
                endOffset := modSr.offset + uint(ssh.length)
                //log.debugf("[%v:%v] %v", modSr.offset, endOffset, ssh)
                defer modSr.offset = endOffset
                #partial switch ssh.subsectionType {
                case .InlineeLines: 
                    ilHdr := readv(&modSr, CvDbgssInlineeLinesHeader)
                    // TODO: if ilHdr == .ex 
                    ilSrcline := readv(&modSr, CvDbgInlineeSrcLine)
                    log.debugf("%v: %v", ilHdr, ilSrcline)
                }
            }
        }

        return
    } else {
        modData := parse_mod_stream(&streamDir, &modi)
        log.debug(modData)
    }
}
