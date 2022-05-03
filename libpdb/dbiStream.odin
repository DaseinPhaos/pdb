//! DBI Debug Info Stream reference: https://llvm.org/docs/PDB/DbiStream.html
package libpdb
import "core:log"
import "core:intrinsics"

DbiStream_Index :: 3

DbiStreamHeader :: struct #packed {
    versionSignature    : i32le,
    versionHeader       : DbiStreamVersion,
    age                 : u32le,
    globalStreamIndex   : u16le,
    buildNumber         : DbiBuildNumber,
    publicStreamIndex   : u16le,
    pdbDllVersion       : u16le,
    symRecordStream     : u16le,
    pdbDllRbld          : u16le,
    modInfoSize         : i32le,
    secContributionSize : i32le,
    secMapSize          : i32le,
    srcInfoSize         : i32le,
    typeServerMapSize   : i32le,
    mfcTypeServerIndex  : u32le,
    optDbgHeaderSize    : i32le,
    ecSubstreamSize     : i32le,
    flags               : DbiFlags,
    machine             : u16le, // Image File Machine Constants from https://docs.microsoft.com/en-us/windows/win32/sysinfo/image-file-machine-constants
    padding             : u32le,
}
DbiStreamVersion :: enum u32le {
    VC41 = 930803,
    V50 = 19960307,
    V60 = 19970606,
    V70 = 19990903,
    V110 = 20091201,
}
//-|-------|--------|
//+15      +8       +0
//isNew majorVer minorVer
DbiBuildNumber :: distinct u16le
@private
_is_new_version_format :: #force_inline proc (b: DbiBuildNumber) -> bool {
    return (b & (1<<15)) != 0
}

DbiFlags :: enum u16le {
    None = 0x0,
    WasIncrenetallyLinked = 1 << 0,
    ArePrivateSymbolsStripped = 1 << 1,
    HasConflictingTypes = 1 << 2,
}

//==== Module Info Substream, array of DbiModInfos.
DbiModInfo :: struct {
    // using _npm : MsfNotPackedMarker,
    using _base : struct #packed {
        unused1             : u32le,
        sectionContr        : DbiSecContrEntry,
        flags               : DbiModInfo_Flags,
        moduleSymStream     : i16le, // index of the stream..
        symByteSize         : u32le,
        c11ByteSize         : u32le,
        c13ByteSize         : u32le,
        sourceFileCount     : u16le,
        padding             : u16le,
        unused2             : u32le,
        sourceFileNameIndex : u32le,
        pdbFilePathNameIndex: u32le,
    },
    moduleName              : string,
    objFileName             : string,
}
DbiModInfo_Flags :: enum u16le {
    None = 0,
    Dirty = 1 << 0,
    EC = 1 << 1, // edit and continue
    // TODO: TypeServerIndex stuff in high8
}
read_dbiModInfo :: proc(this: ^BlocksReader, $T: typeid) -> (ret: T) where intrinsics.type_is_subtype_of(T, DbiModInfo) {
    ret._base = readv(this, type_of(ret._base))
    ret.moduleName = read_length_prefixed_name(this)
    ret.objFileName = read_length_prefixed_name(this)
    return ret
}

DbiSecContrVersion :: enum u32le {
    Ver60 = 0xeffe0000 + 19970605,
    V2 = 0xeffe0000 + 20140516,
}
DbiSecContrEntry :: struct #packed {
    section         : u16le,
    padding1        : u16le,
    offset          : i32le,
    size            : i32le,
    chaaracteristics: u32le,
    moduleIndex     : u16le,
    padding2        : u16le,
    dataCrc         : u32le,
    relocCrc        : u32le,
}
DbiSecContrEntry2 :: struct #packed {
    using sc  : DbiSecContrEntry,
    iSectCoff : u32le,
}

DbiSecMapHeader :: struct #packed {
    count   : u16le, // segment descriptors
    logCount: u16le, // logival segment descriptors
}
DbiSecMapEntry :: struct #packed {
    flags           : DbiSecMapEntryFlags,
    ovl             : u16le,
    group           : u16le,
    frame           : u16le,
    sectionName     : u16le,
    className       : u16le,
    offset          : u32le,
    sectionLength   : u32le,
}
DbiSecMapEntryFlags :: enum u16le {
    None = 0,
    Read = 1 << 0,
    Write = 1 << 1,
    Execute = 1 << 2,
    AddressIs32Bit = 1 << 3,
    IsSelector = 1 << 8,
    IsAbsoluteAddress = 1 << 9,
    IsGroup = 1 << 10,
}

DbiFileInfos :: struct {
    using _npm : MsfNotPackedMarker,
    // numModules :: u16le
    // numSourceFiles :: u16le
    // modIndices      : []u16le, // len==numModules
    modFileCounts   : []u16le, // len==numModules
    srcFileNames    : []string, // fileNameOffsets : []u32le,
    // namesBuffer     : []string,
}
read_dbiFileInfos :: proc(this: ^BlocksReader, $T: typeid) -> (ret: T) where intrinsics.type_is_subtype_of(T, DbiFileInfos) {
    moduleCount := readv(this, u16le)
    readv(this, u16le) // ignored invalid src count
    //log.debugf("Module count: %v", moduleCount)
    this.offset += size_of(u16le) * uint(moduleCount) // skip unused mod indices
    ret.modFileCounts = make([]u16le, cast(int)moduleCount)
    srcFileSum :uint=0
    for i in 0..<len(ret.modFileCounts) {
        ret.modFileCounts[i] = readv(this, u16le)
        srcFileSum += uint(ret.modFileCounts[i])
    }
    //log.debugf("Src File count: %v", srcFileSum)
    nameMap := make(map[u32le]string, srcFileSum, context.temp_allocator)
    defer delete(nameMap)
    ret.srcFileNames = make([]string, srcFileSum)
    nameBufOffset := this.offset + size_of(u32le) * srcFileSum
    for i in 0..<srcFileSum {
        baseOffset := this.offset
        defer this.offset = baseOffset + size_of(u32le)
        nameOffset := readv(this, u32le)
        existingName, nameExist := nameMap[nameOffset]
        if nameExist {
            ret.srcFileNames[i] = existingName
        } else {
            this.offset = nameBufOffset + uint(nameOffset)
            ret.srcFileNames[i] = read_length_prefixed_name(this)
            nameMap[nameOffset] = ret.srcFileNames[i]
        }
        
    }
    return
}

// TODO: Type Server Map Substream, EC Substream

// Optional Debug Header Streams
DbiOptDbgHeaders :: struct #packed {
    framePointerOmission: i16le,
    exception           : i16le,
    fixup               : i16le,
    omapToSrc           : i16le,
    omapFromSrc         : i16le,
    sectionHeader       : i16le,
    tokenToRID          : i16le,
    xdata               : i16le,
    pdata               : i16le,
    newFPO              : i16le,
    oSectionHeader      : i16le,
}

parse_dbi_stream :: proc(this: ^BlocksReader) -> (header : DbiStreamHeader) {
    header = readv(this, DbiStreamHeader)
    if header.versionSignature != -1 {
        log.warnf("unrecoginized dbiVersionSignature: %v", header.versionSignature)
    }
    if header.versionHeader != .V70 {
        log.warnf("unrecoginized dbiVersionHeader: %v", header.versionHeader)
    }
    if !_is_new_version_format(header.buildNumber) {
        log.warnf("unrecoginized old dbiBuildNumber: %v", header.buildNumber)
    }

    log.debug(header)
    
    { // Module Info substream
        // TODO: return all mod infos. make buffer in temp array and copy to dynamic arrays in the end?
        substreamEnd := uint(header.modInfoSize) + this.offset
        defer assert(this.offset == substreamEnd)
        for this.offset < substreamEnd {
            readv(this, DbiModInfo)
            //log.debug(modi)
        }
    }

    { // section contribution substream
        substreamEnd := uint(header.secContributionSize) + this.offset
        defer assert(this.offset == substreamEnd)
        secContrSubstreamVersion := readv(this, DbiSecContrVersion)
        log.debug(secContrSubstreamVersion)
        secContrEntrySize := size_of(DbiSecContrEntry)
        switch secContrSubstreamVersion {
        case .Ver60:
        case .V2: secContrEntrySize = size_of(DbiSecContrEntry2)
        case: assert(false, "Invalid DbiSecContrVersion")
        }
        for this.offset < substreamEnd {
            baseOffset := this.offset
            defer this.offset = baseOffset + cast(uint)secContrEntrySize
            readv(this, DbiSecContrEntry)
            //log.debug(secContrEntry)
        }
    }

    { // setion map substream
        substreamEnd := uint(header.secMapSize) + this.offset
        defer assert(this.offset == substreamEnd)
        secMapHeader := readv(this, DbiSecMapHeader)
        log.debug(secMapHeader)

        for this.offset < substreamEnd {
            readv(this, DbiSecMapEntry)
        }
    }

    { // file info substream
        substreamEnd := uint(header.srcInfoSize) + this.offset
        defer this.offset = substreamEnd // because...
        readv(this, DbiFileInfos)
        //log.debug(dbiFileInfos)
    }
    this.offset += uint(header.typeServerMapSize)
    this.offset += uint(header.ecSubstreamSize)
    { // optDbgHeaderSize
        readv(this, DbiOptDbgHeaders)
        //log.debug(optDbgHeaders)
    }

    return
}
