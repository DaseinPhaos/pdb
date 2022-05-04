package test
import "core:fmt"
import "core:intrinsics"
import windows "core:sys/windows"
foreign import ntdll_lib "system:ntdll.lib"

@(default_calling_convention="std")
foreign ntdll_lib {
    RtlCaptureStackBackTrace  :: proc(FramesToSkip : windows.DWORD, FramesToCapture: windows.DWORD, BackTrace: ^rawptr, BackTraceHash: ^windows.DWORD) -> windows.WORD ---
    // TODO: RtlCaptureContext :: proc(ContextRecord : ^windows.CONTEXT) ---
}

_imgBasePtr : rawptr
main ::proc() {
    _imgBasePtr = windows.GetModuleHandleW(nil)
    entryPointAddr := cast(rawptr)main
    pDiff := intrinsics.ptr_sub(cast(^byte)entryPointAddr, cast(^byte)_imgBasePtr)
    fmt.printf("ImageBase: %p, main(): %p, diff: 0x%x[%d]\n", _imgBasePtr, entryPointAddr, pDiff, pDiff)
    x := f0()
}

f0 ::proc() -> int {
    return f1()
}

f1 ::proc() -> int {
    using windows
    backTrace : [3]rawptr
    backTraceHash : DWORD
    frameCaptured := RtlCaptureStackBackTrace(0, 3, &backTrace[0], &backTraceHash)
    fmt.printf("FrameCaptured: %v, hash: 0x%x, imageBase: 0x%p\n", frameCaptured, backTraceHash, _imgBasePtr)
    for i in 0..<frameCaptured {
        baseOffset := intrinsics.ptr_sub(cast(^byte)backTrace[i], cast(^byte)_imgBasePtr)
        fmt.printf("%p, %x[%d]\n", backTrace[i], baseOffset, baseOffset)
    }
    return cast(int)frameCaptured
}
