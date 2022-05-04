package mainp
import "libpdb"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:log"

main ::proc() {
    //odin run test -debug -out:test\demo.exe
    //odin run test.odin -file -out:build\test.exe -- .\test\demo.exe
    //odin run test.odin -file -out:build\test.exe -debug -- .\build\test.pdb
    path, _ := strings.replace_all(os.args[1], "\\", "/")
    log.debugf("reading %v\n", path)
    file_content, read_ok := os.read_entire_file(path)
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

    if strings.has_suffix(path, "pdb") {
        //test_pdb(file_content)
        test_find_proc(file_content)
    } else {
        test_exe(file_content)
    }

}

test_find_proc :: proc(file_content: []byte) {
    using libpdb
    callerRva := 57406
    block0Offset := 4096
    callerOffsetInSec := callerRva - block0Offset
    callerSeg := 1
    moduleToFind :: "C:\\repos\\pdbReader\\test\\demo.obj"

    // TODO: find module based on exe name

    sb : SuperBlock
    read_superblock(&sb, file_content)
    streamDir := read_stream_dir(&sb, file_content)
    modFound : union{DbiModInfo}
    {
        dbiSr := get_stream_reader(&streamDir, DbiStream_Index)
        dbiHeader := readv(&dbiSr, DbiStreamHeader)
        substreamEnd := uint(dbiHeader.modInfoSize) + dbiSr.offset
        for dbiSr.offset < substreamEnd {
            modi := readv(&dbiSr, DbiModInfo)
            if strings.compare(modi.moduleName, moduleToFind) == 0 {
                modFound = modi
                break
            }
        }
    }
    
    pdbSr := get_stream_reader(&streamDir, PdbStream_Index)
    pdbHeader, nameMap, pdbFeatures := parse_pdb_stream(&pdbSr)
    namesStreamIdx, namesStreamFound := find_named_stream(nameMap, "/names")
    if !namesStreamFound {
        log.warn("Names stream unfound")
        return
    }
    namesSr := get_stream_reader(&streamDir, namesStreamIdx)
    namesStreamHdr := parse_names_stream(&namesSr)

    if mod, ok := modFound.?; ok {
        modSr := get_stream_reader(&streamDir, u32le(mod.moduleSymStream))
        modHeader := readv(&modSr, ModStreamHeader)

        parentProc : union{CvsProc32}
        { // symbol substream
            symSubStreamSize := mod.symByteSize - 4
            symSubStreamEnd := modSr.offset + uint(symSubStreamSize)
            defer modSr.offset = symSubStreamEnd
            //context.logger.lowest_level = .Warning
            for modSr.offset < symSubStreamEnd {
                cvsHeader  := readv(&modSr, CvsRecordHeader)
                baseOffset := modSr.offset
                defer modSr.offset = baseOffset+ uint(cvsHeader.length) - size_of(CvsRecordKind)
                if cvsHeader.kind != .S_LPROC32 do continue
                cvsProc := readv(&modSr, CvsProc32)
                if int(cvsProc.seg) != callerSeg do continue
                if int(cvsProc.offset) <= callerOffsetInSec && int(cvsProc.offset + cvsProc.length) > callerOffsetInSec {
                    log.debugf("found contaning proc: %v, offset from procBase: %v", cvsProc, callerOffsetInSec - int(cvsProc.offset))
                    parentProc = cvsProc
                }
            }
        }

        ppv, ppvFound := parentProc.?
        if !ppvFound {
            log.errorf("ppv not found")
            return
        }

        // skip c11 lines
        modSr.offset += uint(mod.c11ByteSize)
        c13StreamStart  := modSr.offset
        c13StreamEnd    := modSr.offset + uint(mod.c13ByteSize)
        // pass 1: find FileChecksumSection
        fileChecksumOffset := modSr.offset
        fileChecksumFound  := false
        {
            defer modSr.offset = c13StreamStart
            for modSr.offset < c13StreamEnd {
                ssh := readv(&modSr, CvDbgSubsectionHeader)
                baseOffset := modSr.offset
                endOffset  := baseOffset + uint(ssh.length)
                defer modSr.offset = endOffset
                if ssh.subsectionType == .FileChecksums {
                    fileChecksumFound  = true
                    fileChecksumOffset = modSr.offset
                    break
                }
            }
        }
        if !fileChecksumFound {
            log.error("File checksum not found")
            return
        }
        for modSr.offset < c13StreamEnd {
            ssh := readv(&modSr, CvDbgSubsectionHeader)
            baseOffset := modSr.offset
            endOffset  := baseOffset + uint(ssh.length)
            defer modSr.offset = endOffset
            if ssh.subsectionType != .Lines do continue
            ssLines := readv(&modSr, CvDbgssLinesHeader)
            if ssLines.seg != ppv.seg || ssLines.offset != ppv.offset do continue
            lineBlock := readv(&modSr, CvDbgLinesFileBlockHeader)
            log.debugf("[%v:%v]%v, %v",baseOffset, endOffset, ssLines, lineBlock)
            filename : string
            {
                curOffset := modSr.offset
                defer modSr.offset = curOffset
                // look for file checksum info
                modSr.offset = uint(lineBlock.offFile) + fileChecksumOffset
                checksumHdr := readv(&modSr, CvDbgFileChecksumHeader)
                namesSr.offset = NamesStream_StartOffset + uint(checksumHdr.nameOffset)
                filename = read_length_prefixed_name(&namesSr)
                log.debugf("\tassociated fileChecksum: %v, filename: %v", checksumHdr, filename)
            }
            lastLeLine : CvDbgLinePacked
            lastLeLineIdx :u32le= 0
            // TODO: return in a buffer that would be easier to work with
            callerOffsetFromProcBase := u32le(callerOffsetInSec - int(ppv.offset))
            for i in 0..<lineBlock.nLines {
                line := readv(&modSr, CvDbgLinePacked)
                if line.offset <= callerOffsetFromProcBase {
                    lastLeLine = line
                    lastLeLineIdx = i
                }
                //lns, lne, isStatement := unpack_lineFlag(line.flags)
                //log.debugf("\t#%v[%v:%v, %v]%v", modSr.offset, lns, lne, isStatement, line)
            }
            lns, lne, isStatement := unpack_lineFlag(lastLeLine.flags)
            log.debugf("\tat [%v:%v, %v]%v", lns, lne, isStatement, lastLeLine)
            if ssLines.flags != .hasColumns {
                if endOffset - modSr.offset == size_of(CvDbgColumn)  * uint(lineBlock.nLines) {
                    log.warn("Flag indicates no column info, but infered from block length we assume column info anyway")
                    ssLines.flags = .hasColumns
                }
            }
            //this.offset += uint(lineBlock.size) - size_of(CvDbgLinesFileBlockHeader)
            //log.debugf("\t[:%v]", this.offset)
            column : CvDbgColumn
            if ssLines.flags == .hasColumns {
                for i in 0..<lineBlock.nLines {
                    column = readv(&modSr, CvDbgColumn)
                    if i == lastLeLineIdx {
                        log.debugf("\t%v", column)
                        break
                    }
                }
            }
            log.debugf("Finally: %v:%v:%v", filename, lns, column.start)

        }
    }

}

test_exe :: proc(file_content: []byte) {
    using libpdb
    usrFmts := make(map[typeid]fmt.User_Formatter, 4)
    fmt.set_user_formatters(&usrFmts)
    fmt.register_user_formatter(PESectionName, peSectionName_formatter)
    reader := make_dummy_reader(file_content)
    parse_exe_file(&reader)
}

test_pdb :: proc(file_content : []byte) {
    
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

    when true {
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
