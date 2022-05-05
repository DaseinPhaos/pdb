package test
import "core:fmt"
import "core:intrinsics"
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

_ARM64_NT_CONTEXT :: struct {
    ContextFlags      : DWORD,
    Cpsr              : DWORD,
    using _dummyU     : struct #raw_union {
        X             : [31]DWORD64,
        using _dummyS : struct {
            X0, X1, X2, X3, X4, X5, X6, X7,   
            X8, X9, X10,X11,X12,X13,X14,X15,  
            X16,X17,X18,X19,X20,X21,X22,X23,  
            X24,X25,X26,X27,X28,Fp, Lr : DWORD64,
        },
    },
    Sp                : DWORD64,
    Pc                : DWORD64,
    V                 : [32]NEON128,
    Fpcr              : DWORD,
    Fpsr              : DWORD,
    Bcr               : [ARM64_MAX_BREAKPOINTS]DWORD,
    Bvr               : [ARM64_MAX_BREAKPOINTS]DWORD64,
    Wcr               : [ARM64_MAX_WATCHPOINTS]DWORD,
    Wvr               : [ARM64_MAX_WATCHPOINTS]DWORD64,
}

_imgBasePtr : rawptr
main ::proc() {
    fmt.print("stuff a")
    ep()
    fmt.print("stuff b")
}

ep :: proc() {
    _imgBasePtr = windows.GetModuleHandleW(nil)
    entryPointAddr := cast(rawptr)main
    pDiff := intrinsics.ptr_sub(cast(^byte)entryPointAddr, cast(^byte)_imgBasePtr)
    fmt.printf("ImageBase: %p, main(): %p, diff: 0x%x[%d]\n", _imgBasePtr, entryPointAddr, pDiff, pDiff)
    f0()
}

f0 ::proc() -> int {
    ctxRec : CONTEXT
    RtlCaptureContext(&ctxRec)
    fImgBase : DWORD64
    //fUnwindTable : UNWIND_HISTORY_TABLE
    rtFunc := RtlLookupFunctionEntry(ctxRec.Rip, &fImgBase, nil)
    fmt.printf("%x(%v)\n", fImgBase, fImgBase)
    fmt.printf("Current Rip: oBase: %x(%v)\n", ctxRec.Rip-fImgBase, ctxRec.Rip-fImgBase)
    //fmt.printf("%v\n", fUnwindTable)
    fmt.printf("rtFunc: %v\n", rtFunc)
    ctxPrev : CONTEXT=ctxRec
    handlerData : rawptr
    establisherFrame : DWORD64
    ctxPtrs : KNONVOLATILE_CONTEXT_POINTERS
    RtlVirtualUnwind(0, fImgBase, ctxRec.Rip, rtFunc, &ctxPrev, &handlerData, &establisherFrame, nil)

    rtFuncPrev := RtlLookupFunctionEntry(ctxPrev.Rip, &fImgBase, nil)
    fmt.printf("%x(%v)\n", fImgBase, fImgBase)
    fmt.printf("Prev Rip: oBase: %x(%v)\n", ctxPrev.Rip-fImgBase, ctxPrev.Rip-fImgBase)
    //fmt.printf("%v\n", fUnwindTable)
    fmt.printf("rtFuncPrev: %v\n", rtFuncPrev)
    if (fImgBase & 0x1 == 0x1) {
        return f1()
    }
    return f2()
}

f2 ::proc()-> int {
    return f1()
}

StackTrace :: struct {
    progCounter : uint, // instruction pointer
    imgBase     : uint,
    funcBegin   : u32,
    funcEnd     : u32,
}
StackTrace_Cap :: 16

stack_walk :: #force_no_inline proc() -> (stacktraces: [StackTrace_Cap]StackTrace, count : u8) {
    fImgBase : DWORD64
    ctx : CONTEXT
    RtlCaptureContext(&ctx)
    handlerData : rawptr
    establisherFrame : DWORD64
    // skip current frame
    rtFunc := RtlLookupFunctionEntry(ctx.Rip, &fImgBase, nil)
    RtlVirtualUnwind(0, fImgBase, ctx.Rip, rtFunc, &ctx, &handlerData, &establisherFrame, nil)
    
    for count = 0; count < StackTrace_Cap; count+=1 {
        rtFunc = RtlLookupFunctionEntry(ctx.Rip, &fImgBase, nil)
        if rtFunc == nil do break
        pst := &stacktraces[count]
        pst.progCounter = cast(uint)ctx.Rip
        pst.imgBase     = cast(uint)fImgBase
        pst.funcBegin   = rtFunc.BeginAddress
        pst.funcEnd     = rtFunc.EndAddress
        RtlVirtualUnwind(0, fImgBase, ctx.Rip, rtFunc, &ctx, &handlerData, &establisherFrame, nil)
    }
    return
}

f1 ::proc() -> int {
    using windows
    backTrace : [8]rawptr
    backTraceHash : DWORD
    frameCaptured := RtlCaptureStackBackTrace(0, 8, &backTrace[0], &backTraceHash)
    fmt.printf("FrameCaptured: %v, hash: 0x%x, imageBase: 0x%p\n", frameCaptured, backTraceHash, _imgBasePtr)
    for i in 0..<frameCaptured {
        baseOffset := intrinsics.ptr_sub(cast(^byte)backTrace[i], cast(^byte)_imgBasePtr)
        fmt.printf("%p, %x[%d]\n", backTrace[i], baseOffset, baseOffset)
    }
    stacktraces, strackTracesCount := stack_walk()
    for i in 0..<frameCaptured {
        baseOffset := stacktraces[i].progCounter - stacktraces[i].imgBase
        fmt.printf("%X:%X offset: %x(0d%d), func[%x-%x]\n", stacktraces[i].progCounter,stacktraces[i].imgBase, baseOffset, baseOffset, stacktraces[i].funcBegin, stacktraces[i].funcEnd)
    }
    return cast(int)frameCaptured
}
