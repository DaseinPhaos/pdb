//! Module Information Stream, ref: https://llvm.org/docs/PDB/ModiStream.html https://github.com/willglynn/pdb/tree/master/src/modi
package libpdb
import "core:log"
import "core:strings"

ModStreamHeader :: struct #packed {
    signature : ModStreamSignature, // == C13
    // symbolsSubStream : [modi.symByteSize-4]byte
    // c11LineInfoSubStream : [c11ByteSize]byte
    // c13LineInfoSubStream : [c13ByteSize]byte
    // globalRefsSize : u32le
    // globalRefs: [globalRefsSize]byte
}

ModStreamSignature :: enum u32le {C7 = 1, C11 = 2, C13 = 4,}

parse_mod_stream :: proc(this: ^BlocksReader, modi: ^DbiModInfo, namesStream: ^BlocksReader) {
    header := readv(this, ModStreamHeader)
    if header.signature != .C13 {
        log.warnf("unrecognized mod stream signature:%v. only support C13", header.signature)
        assert(false, "unrecognized mod stream signature")
    }
    
    procToFind  := "libpdb.read_stream_dir"
    procInfo    : Maybe(CvsProc32)
    { // symbol substream
        symSubStreamSize := modi.symByteSize - 4
        symSubStreamEnd := this.offset + uint(symSubStreamSize)
        defer this.offset = symSubStreamEnd
        //context.logger.lowest_level = .Warning
        for this.offset < symSubStreamEnd {
            cvsHeader  := readv(this, CvsRecordHeader)
            baseOffset := this.offset
            defer this.offset = baseOffset+ uint(cvsHeader.length) - size_of(CvsRecordKind)
            if procInfo != nil do continue
            cvs := parse_cvs(this, cvsHeader)
            if cvsProc, ok := cvs.value.(CvsProc32); ok {
                if strings.compare(procToFind, cvsProc.name) == 0 {
                    procInfo = cvsProc
                }
            }
        }
    }

    { // c13 line info sub stream
        // skip c11 lines
        this.offset += uint(modi.c11ByteSize)
        c13StreamStart  := this.offset
        c13StreamEnd    := this.offset + uint(modi.c13ByteSize)
        // pass 1: find FileChecksumSection
        fileChecksumOffset := this.offset
        fileChecksumFound  := false
        {
            defer this.offset = c13StreamStart
            for this.offset < c13StreamEnd {
                ssh := readv(this, CvDbgSubsectionHeader)
                baseOffset := this.offset
                endOffset  := baseOffset + uint(ssh.length)
                defer this.offset = endOffset
                if ssh.subsectionType == .FileChecksums {
                    fileChecksumFound  = true
                    fileChecksumOffset = this.offset
                    break
                }
            }
        }
        
        for this.offset < c13StreamEnd {
            ssh := readv(this, CvDbgSubsectionHeader)
            baseOffset := this.offset
            endOffset  := baseOffset + uint(ssh.length)
            defer this.offset = endOffset
            #partial switch ssh.subsectionType {
            case .Lines: {
                defer assert(this.offset == endOffset)
                ssLines := readv(this, CvDbgssLinesHeader)
                lineBlock := readv(this, CvDbgLinesFileBlockHeader)
                log.debugf("[%v:%v]%v, %v",baseOffset, endOffset, ssLines, lineBlock)
                if fileChecksumFound {
                    curOffset := this.offset
                    defer this.offset = curOffset
                    // look for file checksum info
                    this.offset = uint(lineBlock.offFile) + fileChecksumOffset
                    checksumHdr := readv(this, CvDbgFileChecksumHeader)
                    namesStream.offset = NamesStream_StartOffset + uint(checksumHdr.nameOffset)
                    filename := read_length_prefixed_name(namesStream)
                    log.debugf("\tassociated fileChecksum: %v, filename: %v", checksumHdr, filename)
                    if procInfoV, ok := procInfo.?; ok && procInfoV.offset == ssLines.offset && procInfoV.seg == ssLines.seg {
                        log.warnf("\tFLineFound for %v", procInfoV.name)
                    }
                }
                for i in 0..<lineBlock.nLines {
                    line := readv(this, CvDbgLinePacked)
                    lns, lne, isStatement := unpack_lineFlag(line.flags)
                    log.debugf("\t#%v[%v:%v, %v]%v", this.offset, lns, lne, isStatement, line)
                }
                
                if ssLines.flags != .hasColumns {
                    if endOffset - this.offset == size_of(CvDbgColumn)  * uint(lineBlock.nLines) {
                        log.warn("Flag indicates no column info, but infered from block length we assume column info anyway")
                        ssLines.flags = .hasColumns
                    }
                }
                //this.offset += uint(lineBlock.size) - size_of(CvDbgLinesFileBlockHeader)
                //log.debugf("\t[:%v]", this.offset)
                if ssLines.flags == .hasColumns {
                    for i in 0..<lineBlock.nLines {
                        column := readv(this, CvDbgColumn)
                        log.debugf("\t%v", column)
                    }
                }
                
            }
            case .FileChecksums: {
                defer assert(this.offset == endOffset)
                for this.offset < endOffset {
                    checksumHdr := readv(this, CvDbgFileChecksumHeader)
                    this.offset += uint(checksumHdr.checksumSize)
                    // align to 4-byte boundary
                    this.offset = (this.offset + 3) & ~uint(3)
                    log.debugf("%v", checksumHdr)
                }
            }
            case: log.warnf("Unhandled subsection:%v, len:%v", ssh.subsectionType, ssh.length)
            }
        }
    }
}


// SubsectionHeader->Subsection from kind to stuff
CvDbgSubsectionHeader :: struct #packed {
    subsectionType  : CvDbgSubsectionType,
    length          : u32le,
}
CvDbgSubsectionType :: enum u32 { // DEBUG_S_SUBSECTION_TYPE
    // Native
    Symbols = 0xf1, 
    Lines, 
    StringTable, 
    FileChecksums, 
    FrameData, 
    InlineeLines, 
    CrossScopeImports, 
    CrossScopeExports,
    // .NET
    IlLines, // seems that this can be parsed by SsLinesHeader as well, need further investigation
    FuncMdtokenMap,
    TypeMdtokenMap,
    MergedAssemblyInput,
    CoffSymbolRVA,

    ShouldIgnore = 0x8000_0000, // if set, the subsection content should be ignored
}

// lines subsection starts with this header, then follows []LinesFileBlocks
CvDbgssLinesHeader :: struct #packed {
    offset  : u32le, // section offset
    seg     : u16le, // seg index in the PDB's section header list, incremented by 1
    flags   : CvDbgssLinesFlags,
    codeSize: u32le,
}
CvDbgssLinesFlags :: enum u16le { none, hasColumns= 0x0001, }

// follows by []CvDbgLinePacked and []CvDbgColumn, if hasColumns
CvDbgLinesFileBlockHeader :: struct #packed {
    offFile : u32le, // offset of the file checksum in the file checksums debug subsection (after reading header)
    nLines  : u32le, // number of lines. if hasColumns, then same number of column entries with follow the line entries buffer
    size    : u32le, // total block size
}

CvDbgLinePacked :: struct #packed {
    offset : u32le, // ?to start of code bytes for line number
    flags  : CvDbgLinePackedFlags,
}
//1       +31|(7)                   +24|(24)        +0
//isStatement, deltaToLineEnd(optional), lineNumStart,
CvDbgLinePackedFlags :: distinct u32le
unpack_lineFlag :: proc(this: CvDbgLinePackedFlags) -> (lineNumStart:u32, lineNumEnd: u32, isStatement: bool) {
    lineNumStart = u32(this & 0xff_ffff)
    dLineEnd := (u32(this) & (0x7f00_0000)) >> 24 // this has been a truncation instead of delta
    lineNumEnd = (lineNumStart & 0x7f) | dLineEnd
    if lineNumEnd < lineNumStart do lineNumEnd += 1 << 7
    isStatement = (this & 0x8000_0000) != 0
    return
}

CvDbgColumn :: struct #packed {
    // byte offsets in a src line
    start : u16le,
    end   : u16le,
}

// InlineeLines subsection, starts with this header, follows with CvDbgInlineeSrcLine(Ex) depending on the flag
CvDbgssInlineeLinesHeader :: struct #packed {
    signature : CvDbgssInlineeLinesSignature,
}
CvDbgssInlineeLinesSignature :: enum u32le { none, ex = 0x1, }

CvDbgInlineeSrcLine :: struct #packed {
    inlinee     : CvItemId, // inlinee function id
    fileId      : u32le, // offset into file table DEBUG_S_FILECHKSMS
    srcLineNum  : u32le, // definition start line number
}
CvDbgInlineeSrcLineEx :: struct {// TODO: read this
    using _base : CvDbgInlineeSrcLine,
    // extraFileCount: u32le,
    extraFileIds: []u32le,
}

// File checksum subsection: []CvDbgFileChecksumHeader(variable length depending on checksumSize and 4byte alignment)
CvDbgFileChecksumHeader :: struct #packed {
    nameOffset  : u32le, // name ref into the global name table(after reading header)
    checksumSize: u8,
    checksumKind: CvDbgFileChecksumKind,
    // then follows the checksum value buffer of len checksumSize
    // then align to 4byte boundary to the next header
}
CvDbgFileChecksumKind :: enum u8 {none, md5, sha1, sha256, }

// TODO: StringTable, FrameData, CrossScopeImports, CrossScopeExports etc

