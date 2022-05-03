//! Module Information Stream, ref: https://llvm.org/docs/PDB/ModiStream.html
package libpdb
import "core:log"

ModStreamHeader :: struct #packed {
    signature : u32le, // == 4
    // symbolsSubStream : [modi.symByteSize-4]byte
    // c11LineInfoSubStream : [c11ByteSize]byte
    // c13LineInfoSubStream : [c13ByteSize]byte
    // globalRefsSize : u32le
    // globalRefs: [globalRefsSize]byte
}

parse_mod_stream :: proc(this: ^BlocksReader, modi: ^DbiModInfo) {
    header := readv(this, ModStreamHeader)
    if header.signature != 4 {
        log.warnf("unrecognized mod stream signature:%v. should be 4", header.signature)
    }
    
    { // symbol substream
        symSubStreamSize := modi.symByteSize - 4
        symSubStreamEnd := this.offset + uint(symSubStreamSize)
        //context.logger.lowest_level = .Warning
        for this.offset < symSubStreamEnd {
            cvsHeader := readv(this, CvsRecordHeader)
            //log.debug(cvsHeader.kind)
            baseOffset := this.offset
            inspect_cvs(this, cvsHeader)
            this.offset = baseOffset+ uint(cvsHeader.length) - size_of(CvsRecordKind)
        }
    }

    // TODO: C13 line info substream
}

