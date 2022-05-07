package libpdb
import "core:log"
import "core:os"
import "core:slice"
import "core:strings"
import "core:intrinsics"
import "core:runtime"
import "core:fmt"
import windows "core:sys/windows"
foreign import ntdll_lib "system:ntdll.lib"

@(default_calling_convention="std")
foreign ntdll_lib {
    RtlCaptureStackBackTrace  :: proc(FramesToSkip : DWORD, FramesToCapture: DWORD, BackTrace: ^rawptr, BackTraceHash: ^DWORD) -> WORD ---
    RtlCaptureContext :: proc(ContextRecord : ^CONTEXT) ---
    RtlLookupFunctionEntry :: proc(ControlPc : DWORD64, ImageBase: ^DWORD64, HistoryTable: ^UNWIND_HISTORY_TABLE) -> ^RUNTIME_FUNCTION ---
    RtlVirtualUnwind :: proc(
        HandlerType : DWORD,
        ImageBase: DWORD64,
        ControlPC: DWORD64,
        FunctionEntry: ^RUNTIME_FUNCTION,
        ContextRecord: ^CONTEXT,
        HandlerData: ^rawptr, 
        EstablisherFrame: ^DWORD64, 
        ContextPointers: ^KNONVOLATILE_CONTEXT_POINTERS,
    ) -> EXCEPTION_ROUTINE ---
}

RUNTIME_FUNCTION :: struct {
    BeginAddress : DWORD,
    EndAddress   : DWORD,
    using _dummyU: struct #raw_union {
        UnwindData : DWORD,
        UnwindInfoAddress : DWORD,
    },
}
BYTE    :: windows.BYTE
WORD    :: windows.WORD
DWORD   :: windows.DWORD
DWORD64 :: u64
NEON128 :: struct {Low: u64, High: i64,}
ARM64_MAX_BREAKPOINTS :: 8
ARM64_MAX_WATCHPOINTS :: 1
M128A :: struct #align 16 #raw_union {
    using _base : struct { Low: u64, High: i64, },
    _v128 : i128,
}
EXCEPTION_ROUTINE :: #type proc "stdcall" (ExceptionRecord: ^windows.EXCEPTION_RECORD, EstablisherFrame: rawptr, ContextRecord: ^CONTEXT, DispatcherContext: rawptr) -> windows.EXCEPTION_DISPOSITION
UNWIND_HISTORY_TABLE_SIZE :: 12
CONTEXT :: _AMD64_CONTEXT
KNONVOLATILE_CONTEXT_POINTERS :: _AMD64_KNONVOLATILE_CONTEXT_POINTERS
UNWIND_HISTORY_TABLE :: _AMD64_UNWIND_HISTORY_TABLE
UNWIND_HISTORY_TABLE_ENTRY :: _AMD64_UNWIND_HISTORY_TABLE_ENTRY

_AMD64_CONTEXT :: struct #align 16 {
    // register parameter home addresses
    P1Home,P2Home,P3Home,P4Home,P5Home,P6Home: DWORD64,
    // control flags
    ContextFlags,MxCsr: DWORD,
    // segment registers and processor flags
    SegCs,SegDs,SegEs,SegFs,SegGs,SegSs: WORD, EFlags: DWORD,
    // debug registers
    Dr0,Dr1,Dr2,Dr3,Dr6,Dr7: DWORD64,
    // integer registers
    Rax,Rcx,Rdx,Rbx,Rsp,Rbp,Rsi,Rdi,R8,R9,R10,R11,R12,R13,R14,R15: DWORD64,
    // program counter
    Rip: DWORD64,
    // Floating point state
    using _dummyU : struct #raw_union {
        FltSave: XMM_SAVE_AREA32,
        using _dummyS : struct {
            Header: [2]M128A,
            Legacy: [8]M128A,
            Xmm0,Xmm1,Xmm2,Xmm3,Xmm4,Xmm5,Xmm6,Xmm7,Xmm8,Xmm9,Xmm10,Xmm11,Xmm12,Xmm13,Xmm14,Xmm15: M128A,
        },
    },
    // Vector registers
    VectorRegister: [26]M128A, VectorControl: DWORD64,
    // special debug control registers
    DebugControl,LastBranchToRip,LastBranchFromRip,LastExceptionToRip,LastExceptionFromRip: DWORD64,
}
XMM_SAVE_AREA32 :: struct #align 16 { // _XSAVE_FORMAT
    ControlWord : WORD,
    StatusWord : WORD,
    TagWord : BYTE,
    Reserved1 : BYTE,
    ErrorOpcode : WORD,
    ErrorOffset : DWORD,
    ErrorSelector : WORD,
    Reserved2 : WORD,
    DataOffset : DWORD,
    DataSelector : WORD,
    Reserved3 : WORD,
    MxCsr : DWORD,
    MxCsr_Mask : DWORD,
    FloatRegisters : [8]M128A,

    XmmRegisters : [16]M128A,
    Reserved4 : [96]BYTE,
}
_AMD64_KNONVOLATILE_CONTEXT_POINTERS :: struct {
    using _dummyU        : struct #raw_union {
        FloatingContext  : [16]^M128A,
        using _dummyS    : struct {
            Xmm0, Xmm1, Xmm2, Xmm3,
            Xmm4, Xmm5, Xmm6, Xmm7,
            Xmm8, Xmm9, Xmm10,Xmm11,
            Xmm12,Xmm13,Xmm14,Xmm15: ^M128A,
        },
    },
    using _dummyU2       : struct #raw_union {
        IntegerContext   : [16]^u64,
        using _dummyS2   : struct {
            Rax, Rcx, Rdx, Rbx,
            Rsp, Rbp, Rsi, Rdi,
            R8,  R9,  R10, R11,
            R12, R13, R14, R15 : ^u64,
        },
    },
}
_AMD64_UNWIND_HISTORY_TABLE :: struct {
    Count       : DWORD,
    LocalHint   : BYTE,
    GlobalHint  : BYTE,
    Search      : BYTE,
    Once        : BYTE,
    LowAddress  : DWORD64,
    HighAddress : DWORD64,
    Entry       : [UNWIND_HISTORY_TABLE_SIZE]_AMD64_UNWIND_HISTORY_TABLE_ENTRY,
}
_AMD64_UNWIND_HISTORY_TABLE_ENTRY :: struct {
    ImageBase     : DWORD64,
    FunctionEntry : ^RUNTIME_FUNCTION,
}

// TODO: arm bindings
// _ARM64_NT_CONTEXT :: struct {
//     ContextFlags      : DWORD,
//     Cpsr              : DWORD,
//     using _dummyU     : struct #raw_union {
//         X             : [31]DWORD64,
//         using _dummyS : struct {
//             X0, X1, X2, X3, X4, X5, X6, X7,   
//             X8, X9, X10,X11,X12,X13,X14,X15,  
//             X16,X17,X18,X19,X20,X21,X22,X23,  
//             X24,X25,X26,X27,X28,Fp, Lr : DWORD64,
//         },
//     },
//     Sp                : DWORD64,
//     Pc                : DWORD64,
//     V                 : [32]NEON128,
//     Fpcr              : DWORD,
//     Fpsr              : DWORD,
//     Bcr               : [ARM64_MAX_BREAKPOINTS]DWORD,
//     Bvr               : [ARM64_MAX_BREAKPOINTS]DWORD64,
//     Wcr               : [ARM64_MAX_WATCHPOINTS]DWORD,
//     Wvr               : [ARM64_MAX_WATCHPOINTS]DWORD64,
// }

StackFrame :: struct {
    progCounter : uintptr, // instruction pointer
    imgBaseAddr : uintptr,
    funcBegin   : u32,  // rva marking the beginning of the function
    funcEnd     : u32,  // rva marking the end of the function
}

capture_stack_trace :: #force_no_inline proc "contextless" (traceBuf: []StackFrame) -> (count : uint) {
    fImgBase : DWORD64
    ctx : CONTEXT
    RtlCaptureContext(&ctx)
    handlerData : rawptr
    establisherFrame : DWORD64
    // skip current frame
    rtFunc := RtlLookupFunctionEntry(ctx.Rip, &fImgBase, nil)
    RtlVirtualUnwind(0, fImgBase, ctx.Rip, rtFunc, &ctx, &handlerData, &establisherFrame, nil)
    
    for count = 0; count < len(traceBuf); count+=1 {
        rtFunc = RtlLookupFunctionEntry(ctx.Rip, &fImgBase, nil)
        if rtFunc == nil do break
        pst := &traceBuf[count]
        pst.progCounter = cast(uintptr)ctx.Rip
        pst.imgBaseAddr = cast(uintptr)fImgBase
        pst.funcBegin   = rtFunc.BeginAddress
        pst.funcEnd     = rtFunc.EndAddress
        RtlVirtualUnwind(0, fImgBase, ctx.Rip, rtFunc, &ctx, &handlerData, &establisherFrame, nil)
    }
    return
}

capture_strack_trace_from_context :: proc "contextless" (ctx: ^CONTEXT, traceBuf: []StackFrame) -> (count : uint) {
    fImgBase : DWORD64
    handlerData : rawptr
    establisherFrame : DWORD64
    for count = 0; count < len(traceBuf); count+=1 {
        rtFunc := RtlLookupFunctionEntry(ctx.Rip, &fImgBase, nil)
        if rtFunc == nil do break
        pst := &traceBuf[count]
        pst.progCounter = cast(uintptr)ctx.Rip
        pst.imgBaseAddr = cast(uintptr)fImgBase
        pst.funcBegin   = rtFunc.BeginAddress
        pst.funcEnd     = rtFunc.EndAddress
        RtlVirtualUnwind(0, fImgBase, ctx.Rip, rtFunc, ctx, &handlerData, &establisherFrame, nil)
    }
    return
}

_PEModuleInfo :: struct {
    filePath     : string,
    pdbPath      : string,
    streamDir    : StreamDirectory,
    namesStream  : BlocksReader,
    dbiData      : SlimDbiData,
}

parse_stack_trace :: proc(stackTrace: []StackFrame) -> (srcCodeLocs :[]runtime.Source_Code_Location) {
    srcCodeLocs = make([]runtime.Source_Code_Location, len(stackTrace))
    miMap := make(map[uintptr]_PEModuleInfo, 8, context.temp_allocator)
    mdMap := make(map[uintptr]SlimModData, 8, context.temp_allocator)
    for stackFrame, i in stackTrace {
        mi, ok := miMap[stackFrame.imgBaseAddr]
        if !ok {
            // PEModuleInfo not found for this module, load them in
            defer miMap[stackFrame.imgBaseAddr] = mi
            nameBuf : [windows.MAX_PATH]u16
            pBuf := &nameBuf[0]
            nameLen := windows.GetModuleFileNameW(windows.HMODULE(stackFrame.imgBaseAddr), pBuf, len(nameBuf))
            mi.filePath = windows.wstring_to_utf8(pBuf, cast(int)nameLen)
            // TODO(opt): we don't need to load the entire file.
            peFileContent, peFileOk := os.read_entire_file(mi.filePath)
            if !peFileOk { // ? what else can be done?
                continue
            }
            // fetch info from PE file
            peReader := make_dummy_reader(peFileContent)
            coffHdr, optHdr, dataDirs, sectionTable := parse_pe_file(&peReader)
            if dataDirs.debug.size > 0 {
                ddEntrys := slice.from_ptr(
                    (^PEDebugDirEntry)((stackFrame.imgBaseAddr) + uintptr(dataDirs.debug.rva)),
                    int(dataDirs.debug.size / size_of(PEDebugDirEntry)),
                )
                for dde in ddEntrys {
                    if dde.debugType != .CodeView do continue
                    // because image is supposed to beloaded, we can just look at the struct in memory
                    // if we're dealing with rvas from another process this wouldn't work
                    pPdbBase := (^PECodeViewInfoPdb70Base)((stackFrame.imgBaseAddr) + uintptr(dde.rawDataAddr))
                    if pPdbBase.cvSignature != PECodeView_Signature_RSDS {
                        log.warnf("unrecognized CV_INFO signature: %x", pPdbBase.cvSignature)
                        continue
                    }
                    pPdbPath := (^byte)(uintptr(pPdbBase) + cast(uintptr)size_of(PECodeViewInfoPdb70Base))
                    mi.pdbPath = strings.string_from_nul_terminated_ptr(pPdbPath, int(dde.dataSize-size_of(PECodeViewInfoPdb70Base)))
                    break
                }
            }
            // TODO: if pdbPath is still not found by now, we should look into other possible symbol locations for them
            // TODO(opt): we shouldn't read the entire pdb file here at once
            if pdbContent, pdbOk := os.read_entire_file(mi.pdbPath); pdbOk {
                if sb, sbOk := read_superblock(pdbContent); sbOk {
                    mi.streamDir = read_stream_dir(&sb, pdbContent)
                    pdbSr := get_stream_reader(&mi.streamDir, PdbStream_Index)
                    pdbHeader, nameMap, pdbFeatures := parse_pdb_stream(&pdbSr)
                    mi.namesStream = get_stream_reader(&mi.streamDir, find_named_stream(nameMap, NamesStream_Name))
                    mi.dbiData = find_dbi_stream(&mi.streamDir)
                }
            }
        }
        pcRva := u32le(stackFrame.progCounter - stackFrame.imgBaseAddr)
        funcRva := u32le(stackFrame.funcBegin)
        if sci := search_for_section_contribution(&mi.dbiData, funcRva); sci >= 0 {
            sc := mi.dbiData.contributions[sci]
            modi := mi.dbiData.modules[sc.module]
            funcOffset := PESectionOffset {
                offset = funcRva - mi.dbiData.sections[sc.secIdx-1].vAddr,
                secIdx = sc.secIdx,
            }
            // address of module's first mc in memory. This should be unique
            // per module across the whole process, making it the perfect
            // hash key for our modData map
            mdAddress := stackFrame.imgBaseAddr + uintptr(mi.dbiData.sections[modi.secContrOffset.secIdx-1].vAddr) + uintptr(modi.secContrOffset.offset)
            modData, modDataOk := mdMap[mdAddress]
            if !modDataOk {
                modData = resolve_mod_stream(&mi.streamDir, &modi)
                mdMap[mdAddress] = modData
            }
            p, lb, l := locate_pc(&modData, funcOffset, pcRva-funcRva)
            if p != nil {
                srcCodeLocs[i].procedure = p.name
                srcCodeLocs[i].line = i32(l.lineStart)
                srcCodeLocs[i].column = i32(l.colStart)
            }
            if lb != nil && lb.nameOffset > 0 {
                mi.namesStream.offset = uint(lb.nameOffset)
                srcCodeLocs[i].file_path = read_length_prefixed_name(&mi.namesStream)
            } else {
                srcCodeLocs[i].file_path = modi.moduleName
            }
        } else {
            srcCodeLocs[i].file_path = mi.filePath // pdb failed to provide us with a valid source file name, fallback to filePath provided by the image
        }
    }
    return
}

dump_stack_trace_on_exception :: proc "stdcall" (ExceptionInfo: ^windows.EXCEPTION_POINTERS) -> windows.LONG {
    context = runtime.default_context() // TODO: use another allocator
    ctxt := cast(^CONTEXT)ExceptionInfo.ContextRecord
    traceBuf : [32]StackFrame
    traceCount := capture_strack_trace_from_context(ctxt, traceBuf[:])
    // TODO: exception information should be printed here as well.
    fmt.printf("Stacktrack[%d]:\n", traceCount)
    srcCodeLines := parse_stack_trace(traceBuf[:traceCount])
    for scl in srcCodeLines {
        fmt.printf("%v:%d:%d: %v()\n", scl.file_path, scl.line, scl.column, scl.procedure)
    }
    return 0 // EXCEPTION_CONTINUE_SEARCH
}
