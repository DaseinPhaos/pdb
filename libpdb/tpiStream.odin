//! tpi or ipi stream, reference: https://llvm.org/docs/PDB/TpiStream.html
package libpdb
import "core:log"

TpiStream_Index :: 2
IpiStream_Index :: 4

TpiStreamHeader :: struct #packed {
    version: TpiStreamVersion, // appears to always be v80
    headerSize: u32le, // == sizeof(TpiStreamHeader)
    typeIndexBegin: TypeIndex, // usually 0x1000(4096), type indices lower are usually reserved
    typeIndexEnd: TypeIndex, // total number of type records = typeIndexEnd-typeIndexBegin
    typeRecordBytes: u32le, // type record data size following the header

    hashStreamIndex: i16le, // -1 means not present, usually always observed to be present
    hashAuxStreamIndex: i16le, // unclear what for
    hashKeySize: u32le, // usually 4 bytes
    numHashBuckets: u32le, // number of buckets used to generate these hash values

    // ?offset and size within the hash stream. HashBufferLength should == numTypeRecords * hashKeySize
    hashValueBufferOffset, hashValueBufferLength: i32le,
    // type index offset buffer pos within the hash stream, which is
    // a list of u32le (typeIndex, offset in type record data)pairs that can be biSearched
    indexOffsetBufferOffset, indexOffsetBufferLength: i32le,
    // a pdb hashTable, with u32le (hash values, type indices) kv pair
    hashAdjBufferOffset, hashAdjBufferLength: i32le,
}

TpiStreamVersion :: enum u32le {
    V40 = 19950410,
    V41 = 19951122,
    V50 = 19961031,
    V70 = 19990903,
    V80 = 20040203,
}

parse_tpi_stream :: proc(this: ^BlocksReader) -> (header: TpiStreamHeader) {
    header = readv_from_blocks(this, TpiStreamHeader)
    assert(header.headerSize == size_of(TpiStreamHeader), "Incorrect header size, mulfunctional stream")
    if header.version != .V80 {
        log.warnf("unrecoginized streamVersion: %v", header.version)
    }

    for this.offset < this.size {
        cvtHeader := readv_from_blocks(this, CvtRecordHeader)
        log.debug(cvtHeader.kind)
        baseOffset := this.offset
        #partial switch  cvtHeader.kind {
        case .LF_POINTER: {
            cvtPtr := readv_from_blocks(this, CvtLeafPointer)
            log.debug(cvtPtr)
        }
        case .LF_PROCEDURE: {
            cvtLeafProc := readv_from_blocks(this, CvtLeafProc)
            log.debug(cvtLeafProc)
        }
        case .LF_ARGLIST: {
            argCount := readv_from_blocks(this, u32le)
            args := make([]TypeIndex, argCount)
            for i in 0..<argCount {
                args[i] = readv_from_blocks(this, TypeIndex)
            }
            log.debug(args)
        }
        case .LF_CLASS:fallthrough
        case .LF_STRUCTURE:fallthrough
        case .LF_INTERFACE: {
            cvtStruct := readv_from_blocks(this, CvtLeafStruct)
            log.debug(cvtStruct)
        }
        case .LF_ENUM: {
            cvtEnum := read_cvtlEnum_from_blocks(this)
            log.debug(cvtEnum)
        }
        }
        this.offset = baseOffset+ uint(cvtHeader.length) - size_of(CvtRecordKind)
    }

    return
}
