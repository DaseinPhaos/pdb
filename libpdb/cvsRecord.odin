//! CodeView Symbol Records, reference: https://llvm.org/docs/PDB/CodeViewSymbols.html
package libpdb
import "core:log"
import "core:intrinsics"

CvsRecordHeader :: struct #packed {
    length  : u16le, // record length excluding this 2 byte field
    kind    : CvsRecordKind,
}

CvsRecordKind :: enum u16le {
    //Public Symbols
    S_PUB32             = 0x110e, // CvsPub32
    //Global Symbols
    S_GDATA32           = 0x110d, // CvsData32
    S_GTHREAD32         = 0x1113, // CvsData32
    S_PROCREF           = 0x1125, // CvsRef2
    S_DATAREF           = 0x1126, // CvsRef2
    S_LPROCREF          = 0x1127, // CvsRef2
    S_GMANDATA          = 0x111d, // CvsData32
    //Module Symbols
    S_END               = 0x0006, // nothing follows
    S_FRAMEPROC         = 0x1012, // CvsFrameProc
    S_OBJNAME           = 0x1101, // CvsObjName
    S_THUNK32           = 0x1102, // CvsThunk32
    S_BLOCK32           = 0x1103, // CvsBlocks32
    S_LABEL32           = 0x1105, // CvsLabel32
    S_REGISTER          = 0x1106, // CvsRegister
    S_BPREL32           = 0x110b, // CvsBPRel32
    S_LPROC32           = 0x110f, // CvsProc32
    S_GPROC32           = 0x1110, // CvsProc32
    S_REGREL32          = 0x1111, // CvsRegRel32
    S_COMPILE2          = 0x1116, // CvsCompile2
    S_UNAMESPACE        = 0x1124, // CsvNamespace
    S_TRAMPOLINE        = 0x112c, // CvsTrampoline
    S_SECTION           = 0x1136, // CvsSection
    S_COFFGROUP         = 0x1137, // CvsCoffGroup
    S_EXPORT            = 0x1138, // CvsExport
    S_CALLSITEINFO      = 0x1139, // S_CALLSITEINFO
    S_FRAMECOOKIE       = 0x113a, // CvsFrameCookie
    S_COMPILE3          = 0x113c, // CvsCompile3
    S_ENVBLOCK          = 0x113d, // CvsEnvBlock
    S_LOCAL             = 0x113e, // CvsLocal
    S_DEFRANGE          = 0x113f,
    S_DEFRANGE_SUBFIELD = 0x1140, // CvsDefRangeSubfield
    S_DEFRANGE_REGISTER = 0x1141, // CvsDefRangeRegister
    S_DEFRANGE_FRAMEPOINTER_REL = 0x1142,  // CvsDefRangeFramePointerRel
    S_DEFRANGE_SUBFIELD_REGISTER = 0x1143, // CvsDefRangeSubfieldRegister
    S_DEFRANGE_FRAMEPOINTER_REL_FULL_SCOPE = 0x1144, // CvsDefRangeFramePointerRelFullScope
    S_DEFRANGE_REGISTER_REL = 0x1145, // CvsDefRangeRegisterRel
    S_LPROC32_ID        = 0x1146, // CvsProc32
    S_GPROC32_ID        = 0x1147, // CvsProc32
    S_BUILDINFO         = 0x114c, // CvsBuildInfo
    S_INLINESITE        = 0x114d, // CvsInlineSite
    S_INLINESITE_END    = 0x114e, // nothing
    S_PROC_ID_END       = 0x114f, // nothing
    S_FILESTATIC        = 0x1153, // CvsFileStatic
    S_LPROC32_DPC       = 0x1155, // CvsProc32
    S_LPROC32_DPC_ID    = 0x1156, // CvsProc32
    S_CALLEES           = 0x115a, // CvsFunctionList
    S_CALLERS           = 0x115b, // CvsFunctionList
    S_HEAPALLOCSITE     = 0x115e, // CvsHeapAllocSite
    //? S_FASTLINK          = 0x1167,
    //? S_INLINEES          = 0x1168,
    // either/both of the module info stream & global stream
    S_CONSTANT          = 0x1107, // CvsConstant
    S_UDT               = 0x1108, // CvsUDT
    S_LDATA32           = 0x110c, // CvsData32
    S_LTHREAD32         = 0x1112, // CvsData32
    S_LMANDATA          = 0x111c, // CvsData32
    S_MANCONSTANT       = 0x112d, // CvsConstant
}

// S_PUB32
CvsPub32 :: struct {
    using _base : struct #packed {
        flags : CvsPub32_Flags,
        offset  : u32le,
        seg     : u16le,
    },
    name        : string,
}
CvsPub32_Flags :: enum u32le {
    None = 0,
    Code = 1 << 0, // code address
    Function = 1 << 1,
    Managed = 1 << 2,
    MSIL = 1 << 3, // managed IL code
}

// S_LDATA32, S_GDATA32, S_LMANDATA, S_GMANDATA, S_LTHREAD32, S_GTHREAD32
CvsData32 :: struct {
    using _base : struct #packed {
        typind : TypeIndex,
        offset : u32le,
        seg    : u16le,
    },
    name       : string,
}

// S_PROCREF, S_DATAREF, S_LPROCREF
CvsRef2 :: struct {
    using _base : struct #packed {
        sucName : u32le,
        ibSym   : u32le, // offset of actual symbol in $$Symbols
        imod    : u16le, // module containing the actual symbol
    },
    name        : string,
}

// S_FRAMEPROC
CvsFrameProc :: struct #packed {
    frameCount  : u32le, // bytes of total frame of proc
    padCount    : u32le, // bytes of padding in frame
    padOffset   : u32le, // pad offset (relative to frame pointer)
    saveRegs    : u32le, // byteCount of callee save registers
    exHdlrOffset: u32le, // exception handler offset
    exHdlrSect  : u16le, // section id of exception handler
    flags       : CvsFrameProc_Flags,
}
CvsFrameProc_Flags :: enum u32le {
    none = 0,
    hasAlloca  =  1<<0,   // function uses _alloca()
    hasSetJmp  =  1<<1,   // function uses setjmp()
    hasLongJmp =  1<<2,   // function uses longjmp()
    hasInlAsm  =  1<<3,   // function uses inline asm
    hasEH      =  1<<4,   // function has EH states
    inlSpec    =  1<<5,   // function was speced as inline
    hasSEH     =  1<<6,   // function has SEH
    naked      =  1<<7,   // function is __declspec(naked)
    securityChecks =  1<<8,   // function has buffer security check introduced by /GS.
    asyncEH    =  1<<9,   // function compiled with /EHa
    gSNoStackOrdering =  1<<10,   // function has /GS buffer checks, but stack ordering couldn't be done
    wasInlined =  1<<11,   // function was inlined within another function
    gSCheck    =  1<<12,   // function is __declspec(strict_gs_check)
    safeBuffers = 1<<13,   // function is __declspec(safebuffers)
    encodedLocalBasePointer0 = 1<<14,  // record function's local pointer explicitly.
    encodedLocalBasePointer1 = 1<<15,  // record function's local pointer explicitly.
    encodedParamBasePointer0 = 1<<16,  // record function's parameter pointer explicitly.
    encodedParamBasePointer1 = 1<<17,  // record function's parameter pointer explicitly.
    pogoOn      = 1<<18,   // function was compiled with PGO/PGU
    validCounts = 1<<19,   // Do we have valid Pogo counts?
    optSpeed    = 1<<20,  // Did we optimize for speed?
    guardCF    =  1<<21,   // function contains CFG checks (and no write checks)
    guardCFW   =  1<<22,   // function contains CFW checks and/or instrumentation
}

// S_OBJNAME
CvsObjName :: struct {
    using _base : struct #packed {
        signature : u32le,
    },
    name          : string,
}

// S_THUNK32
CvsThunk32 :: struct {
    using _base : struct #packed {
        pParent : u32le,
        pEnd    : u32le,
        pNext   : u32le,
        offset  : u32le,
        seg     : u16le,
        length  : u16le,
        ordinal : CvsThunkOrdinal,
    },
    name        : string,
    // TODO: ??variant following name
}
CvsThunkOrdinal :: enum u8 {
    NoType,
    Adjustor, 
    VirtCall,
    PCode,
    Load,
    TrampIncremental,
    TrampBranchIsland,
}

// S_BLOCK32
CvsBlocks32 :: struct {
    using _base : struct #packed {
        pParent : u32le,
        pEnd    : u32le,
        blockLen: u32le,
        offset  : u32le,
        seg     : u16le,
    },
    name        : string,
}

// S_LABEL32
CvsLabel32 :: struct {
    using _base : struct #packed {
        offset  : u32le,
        seg     : u16le,
        flags   : CvsProcFlags,
    },
    name        : string,
}

// S_REGISTER
CvsRegister :: struct {
    using _base : struct #packed {
        regType : TypeIndex,
        reg     : u16le, // register enumerate
    },
    name        : string,
}

// S_BPREL32
CvsBPRel32 :: struct {
    using _base : struct #packed {
        offset : u32le, // BP-relative offset
        typind : TypeIndex,
    },
    name       : string,
}

// S_GPROC32, S_LPROC32, S_GPROC32_ID, S_LPROC32_ID, S_LPROC32_DPC, S_LPROC32_DPC_ID
CvsProc32 :: struct {
    using _base : struct #packed {
        pParent : u32le,
        pEnd    : u32le,   // pointer to this blocks end
        pNext   : u32le,
        length  : u32le,
        dbgStart: u32le,
        dbgEnd  : u32le,
        typind  : TypeIndex,
        offset  : u32le,
        seg     : u16le,
        flags   : CvsProcFlags,
    },
    name        : string,
}
// TODO: CV_PROCFLAGS
CvsProcFlags :: distinct u8 

// S_REGREL32
CvsRegRel32 :: struct {
using _base : struct #packed {
        offset : u32le,
        typind : TypeIndex,
        reg    : u16le,
    },
    name       : string,
}

// S_COMPILE2
CvsCompile2 :: struct {
    using _base : struct #packed {
        flags       : CvsCompile2_Flags,
        machine     : u16le,    // target processor
        verFEMajor  : u16le, // front end major version #
        verFEMinor  : u16le, // front end minor version #
        verFEBuild  : u16le, // front end build version #
        verMajor    : u16le,   // back end major version #
        verMinor    : u16le,   // back end minor version #
        verBuild    : u16le,   // back end build version #
    },
    name            : string, // TODO: verSt should be an array of strings double terminated by 00
}
// TODO: COMPILESYM.flags
CvsCompile2_Flags :: distinct u32le

// S_UNAMESPACE
CvsUnamespace :: struct {
    using _base : struct #packed {},
    name : string,
}

// S_TRAMPOLINE
CvsTrampoline :: struct #packed {
    trampType   : u16le,  // trampoline sym subtype
    thunkSize   : u16le,
    thunkOffset : u32le,   // offset of the thunk
    targetOffset: u32le,  // offset of the target of the thunk
    thunkSect   : u16le,  // section index of the thunk
    targetSect  : u16le, // section index of the target of the thunk
}

// S_SECTION
CvsSection :: struct {
    using _base : struct #packed {
        isec            : u16le, // Section number
        align           : u8, // Alignment of this section (power of 2)
        bReserved       : u8, // Must be zero.
        rva             : u32le,
        cb              : u32le,
        characteristics : u32le,
    },
    name                : string,
}

// S_COFFGROUP
CvsCoffGroup :: struct {
    using _base : struct #packed {
        cb              : u32le,
        characteristics : u32le,
        offset          : u32le,
        seg             : u16le,
    },
    name                : string,
}

// S_EXPORT
CvsExport :: struct {
    using _base : struct #packed {
        ordinal : u16le,
        flags   : CvsExportFlags,
    },
    name        : string,
}
CvsExportFlags :: enum u16le {
    none     = 0,
    constant = 1 << 0,
    data     = 1 << 1,
    private  = 1 << 2,
    noName   = 1 << 3,
    ordinal  = 1 << 4,
    forwarder= 1 << 5,
}

// S_CALLSITEINFO
CvsCallsiteInfo :: struct #packed {
    offset : u32le,
    sect   : u16le,
    pad0   : u16le,
    typind : TypeIndex, // for funtion signature
}

// S_FRAMECOOKIE
CvsFrameCookie :: struct #packed {
    offset     : u32le,
    reg        : u16le,
    cookieType : CvsCookieType,
    flags      : u8, //?
}
CvsCookieType :: enum u32le {
    Copy, XorSP, XorBP, XorR13,
}

// S_COMPILE3
CvsCompile3 :: struct {
using _base : struct #packed {
        flags       : CvsCompile3_Flags,
        machine     : u16le,    // target processor
        verFEMajor  : u16le, // front end major version #
        verFEMinor  : u16le, // front end minor version #
        verFEBuild  : u16le, // front end build version #
        verFEQFE    : u16le, // front end QFE version #
        verMajor    : u16le,   // back end major version #
        verMinor    : u16le,   // back end minor version #
        verBuild    : u16le,   // back end build version #
        verQFE      : u16le,   // back end QFE version #
    },
    name            : string,
}
// TODO: COMPILESYM3.flags
CvsCompile3_Flags :: distinct u32le

// S_ENVBLOCK
CvsEnvBlock :: struct {
    using _base : struct #packed {
        reserved    : u8,
    },
    name            : string, // TODO: should be an array of cstrings, double terminated by \0\0
}

// S_LOCAL
CvsLocal :: struct {
    using _base : struct #packed {
        typind : TypeIndex,
        flags  : CvsLvarFlags,
    },
    name       : string,
}
CvsLvarFlags :: enum u16le {
    none            =0,
    isParam         =1<<0,
    addrTaken       =1<<1,
    compGenx        =1<<2, // compiler generated
    isAggregate     =1<<3, // the symbol is splitted in temporaries,
    isAggregated    =1<<4, // Counterpart of fAggregate
    isAliased       =1<<5, // has multiple simultaneous lifetimes
    isAlias         =1<<6, // Counterparts of Aliased
    isRetValue      =1<<7, // represents a function return value
    isOptimizedOut  =1<<8, // has no lifetimes
    isEnregGlob     =1<<9, // an enregistered global
    isEnregStat     =1<<10, // an enregistered static
}

// S_BUILDINFO
CvsBuildInfo :: struct #packed {
    id : CvItemId, // build info id
}

// S_INLINESITE
CvsInlineSite :: struct {
    using _base : struct #packed {
        pParent : u32le,
        pEnd    : u32le,
        inlinee : CvItemId,
    },
    name        : string, //???binaryAnnotations[CV_ZEROLEN];   // an array of compressed binary annotations.
}

// S_FILESTATIC
CvsFileStatic :: struct {
    using _base : struct #packed {
        typeind     : TypeIndex,
        modOffset   : u32le, // index of mod filename in stringtable
        flags       : CvsLvarFlags, // local var flags
    },
    name            : string,
}

// S_CALLEES, S_CALLERS
CvsFunctionList :: struct {
    using _npm : MsfNotPackedMarker,
    // count : u32le
    funcs : []TypeIndex,
}
read_cvsFunctionList :: proc(this: ^BlocksReader, $T: typeid) -> (ret: T)
    where intrinsics.type_is_subtype_of(T, CvsFunctionList) {
        count := readv(this, u32le)
        ret.funcs = make([]TypeIndex, uint(count))
        for i in 0..<uint(count) {
            ret.funcs[i] = readv(this, TypeIndex)
        }
        return
}

// S_HEAPALLOCSITE
CvsHeapAllocSite :: struct #packed {
    offset   : u32le,
    sect     : u16le,
    instrLen : u16le,
    typind   : TypeIndex,
}

// S_CONSTANT, S_MANCONSTANT
CvsConstant :: struct {
    using _base : struct #packed {
        typind : TypeIndex,
        value  : u16le, // numeric leaf containing value
    },
    name       : string,
}

// S_UDT
CvsUDT :: struct {
    using _base : struct #packed {
        typind : TypeIndex,
    },
    name       : string,
}

// S_DEFRANGE
CvsDefRange :: struct {
    using _base : struct #packed {
        program : u32le, // DIA program to evaluate the value of the symbol
    },
    using _rag  : CvsLvarAddrRangeAndGap,
}

// S_DEFRANGE_SUBFIELD
CvsDefRangeSubfield :: struct {
    using _base : struct #packed {
        program : u32le, // DIA program to evaluate the value of the symbol
        oParent : u32le, // offset in parent variable
    },
    using _rag  : CvsLvarAddrRangeAndGap,
}

// S_DEFRANGE_REGISTER
CvsDefRangeRegister :: struct {
    using _base : struct #packed {
        reg     : u16le,
        attr    : CvsRangeAttr,
    },
    using _rag  : CvsLvarAddrRangeAndGap,
}

// S_DEFRANGE_SUBFIELD_REGISTER
CvsDefRangeSubfieldRegister :: struct {
    using _base : struct #packed {
        reg     : u16le,
        attr    : CvsRangeAttr,
        pOffset : u32le, // offset in parent variable, only lower 12 bits used
    },
    using _rag : CvsLvarAddrRangeAndGap,
}

// S_DEFRANGE_FRAMEPOINTER_REL
CvsDefRangeFramePointerRel :: struct {
    using _base : CvsDefRangeFramePointerRelFullScope,
    using _rag : CvsLvarAddrRangeAndGap,
}
// S_DEFRANGE_FRAMEPOINTER_REL_FULL_SCOPE
CvsDefRangeFramePointerRelFullScope :: struct #packed {
    oFramePtr : u32le, // offset to frame pointer
}

// S_DEFRANGE_REGISTER_REL
CvsDefRangeRegisterRel :: struct {
    using _base : struct #packed {
        baseReg     : u16le, // register to hold the base pointer
        flags       : CvsDefRangeRegisterRelFlags,
        baseOffset  : u32le, // offset to base pointer register
    },
    using _rag      : CvsLvarAddrRangeAndGap,
}
// TODO: methods to extract parent offset from this
// ------------|---|-
// offsetParent|pad|spilledUdtMember
CvsDefRangeRegisterRelFlags :: distinct u16le

read_with_trailing_rag :: #force_inline proc(this: ^BlocksReader, recLen: u16le, $T : typeid) -> (ret: T) 
    where intrinsics.type_has_field(T, "_base"),
          intrinsics.type_has_field(T, "_rag"), 
          intrinsics.type_field_index_of(T, "_rag") == 1,
          intrinsics.type_struct_field_count(T) == 2 {
    ret._base = readv(this, type_of(ret._base))
    ret._rag = read_cvsLvarAddrRangeAndGap(this, recLen, size_of(ret._base))
    return
}
CvsRangeAttr :: enum u16le { none = 0, maybe = 1, }
CvsLvarAddrRangeAndGap :: struct {
    range : struct #packed {
        offsetStart : u32le,
        iSectStart  : u16le,
        length      : u16le,
    },
    gaps            : []CvsLvarAddrGap,
}
CvsLvarAddrGap :: struct #packed {
    relOffset : u16le,
    length    : u16le,
}
read_cvsLvarAddrRangeAndGap :: proc (this: ^BlocksReader, recLen : u16le, headLen: int) -> (ret : CvsLvarAddrRangeAndGap) {
    ret.range = readv(this, type_of(ret.range))
    gapsSize := int(recLen) - size_of(CvsRecordKind) - headLen - size_of(ret.range)
    gapsCount := gapsSize / size_of(CvsLvarAddrGap)
    if gapsCount <= 0 do return
    ret.gaps = make([]CvsLvarAddrGap, gapsCount)
    for i in 0..<gapsCount {
        ret.gaps[i] = readv(this, CvsLvarAddrGap)
    }
    return
}

inspect_cvs :: proc(this: ^BlocksReader, cvsHeader : CvsRecordHeader) {
    switch  cvsHeader.kind {
        case .S_PUB32: {
            v := readv(this, CvsPub32)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_PROCREF:fallthrough
        case .S_DATAREF:fallthrough
        case .S_LPROCREF: {
            v := readv(this, CvsRef2)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_OBJNAME: {
            v := readv(this, CvsObjName)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_THUNK32: {
            v := readv(this, CvsThunk32)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_LABEL32: {
            v := readv(this, CvsLabel32)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_BPREL32: {
            v := readv(this, CvsBPRel32)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_REGISTER: {
            v := readv(this, CvsRegister)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_COMPILE3: {
            v := readv(this, CvsCompile3)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_BUILDINFO: {
            v := readv(this, CvsBuildInfo)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_LDATA32:fallthrough
        case .S_GDATA32:fallthrough
        case .S_LMANDATA:fallthrough
        case .S_GMANDATA:fallthrough
        case .S_LTHREAD32:fallthrough
        case .S_GTHREAD32: {
            v := readv(this, CvsData32)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_LOCAL: {
            v := readv(this, CvsLocal)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_BLOCK32: {
            v := readv(this, CvsBlocks32)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_FRAMEPROC: {
            v := readv(this, CvsFrameProc)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_COMPILE2: {
            v := readv(this, CvsCompile2)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_UNAMESPACE: {
            v := readv(this, CvsUnamespace)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_TRAMPOLINE: {
            v := readv(this, CvsTrampoline)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_SECTION: {
            v := readv(this, CvsSection)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_COFFGROUP: {
            v := readv(this, CvsCoffGroup)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_EXPORT: {
            v := readv(this, CvsExport)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_CALLSITEINFO: {
            v := readv(this, CvsCallsiteInfo)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_FRAMECOOKIE: {
            v := readv(this, CvsFrameCookie)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_REGREL32: {
            v := readv(this, CvsRegRel32)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_ENVBLOCK: {
            v := readv(this, CvsEnvBlock)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_INLINESITE: {
            v := readv(this, CvsInlineSite)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_FILESTATIC: {
            v := readv(this, CvsFileStatic)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_CALLEES:fallthrough
        case .S_CALLERS: {
            v := readv(this, CvsFunctionList)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_HEAPALLOCSITE: {
            v := readv(this, CvsHeapAllocSite)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_CONSTANT:fallthrough
        case .S_MANCONSTANT: {
            v := readv(this, CvsConstant)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_UDT: {
            v := readv(this, CvsUDT)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_LPROC32:fallthrough
        case .S_LPROC32_ID:fallthrough
        case .S_LPROC32_DPC:fallthrough
        case .S_LPROC32_DPC_ID:fallthrough
        case .S_GPROC32:fallthrough
        case .S_GPROC32_ID: {
            v := readv(this, CvsProc32)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_INLINESITE_END:fallthrough
        case .S_PROC_ID_END:fallthrough
        case .S_END: log.debugf(".%v@[%v]", cvsHeader.kind, this.offset)
        case .S_DEFRANGE: {
            v := readv(this, cvsHeader.length, CvsDefRange)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_DEFRANGE_SUBFIELD: {
            v := readv(this, cvsHeader.length, CvsDefRangeSubfield)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_DEFRANGE_REGISTER: {
            v := readv(this, cvsHeader.length, CvsDefRangeRegister)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_DEFRANGE_REGISTER_REL: {
            v := readv(this, cvsHeader.length, CvsDefRangeRegisterRel)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_DEFRANGE_SUBFIELD_REGISTER: {
            v := readv(this, cvsHeader.length, CvsDefRangeSubfieldRegister)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_DEFRANGE_FRAMEPOINTER_REL: {
            v := readv(this, cvsHeader.length, CvsDefRangeFramePointerRel)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case .S_DEFRANGE_FRAMEPOINTER_REL_FULL_SCOPE: {
            v := readv(this, CvsDefRangeFramePointerRelFullScope)
            log.debugf(".%v@[%v]: %v", cvsHeader.kind, this.offset, v)
        }
        case: log.warnf("Unhandled %v", cvsHeader.kind)
    }
}
