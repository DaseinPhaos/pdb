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
    header = readv(this, TpiStreamHeader)
    assert(header.headerSize == size_of(TpiStreamHeader), "Incorrect header size, mulfunctional stream")
    if header.version != .V80 {
        log.warnf("unrecoginized streamVersion: %v", header.version)
    }
    context.logger.lowest_level = .Warning
    for this.offset < this.size {
        cvtHeader := readv(this, CvtRecordHeader)
        log.debug(cvtHeader.kind)
        baseOffset := this.offset
        #partial switch  cvtHeader.kind {
        case .LF_POINTER: {
            cvtPtr := readv(this, CvtlPointer)
            log.debug(cvtPtr)
        }
        case .LF_PROCEDURE: {
            CvtlProc := readv(this, CvtlProc)
            log.debug(CvtlProc)
        }
        case .LF_ARGLIST:fallthrough
        case .LF_SUBSTR_LIST: {
            args := read_cvtfArgList(this)
            log.debug(args)
        }
        case .LF_CLASS:fallthrough
        case .LF_STRUCTURE:fallthrough
        case .LF_INTERFACE: {
            cvtStruct := read_cvtlStruct(this)
            log.debug(cvtStruct)
        }
        case .LF_ENUM: {
            cvtEnum := read_cvtlEnum(this)
            log.debug(cvtEnum)
        }
        case .LF_ARRAY: {
            cvtArray := read_cvtlArray(this)
            log.debug(cvtArray)
        }
        case .LF_UNION: {
            cvtUnion := read_cvtlUnion(this)
            log.debug(cvtUnion)
        }
        case .LF_MODIFIER: {
            cvt := readv(this, CvtlModifier)
            log.debug(cvt)
        }
        case .LF_MFUNCTION: {
            cvt := readv(this, CvtlMFunction)
            log.debug(cvt)
        }
        case .LF_BITFIELD: {
            cvt := readv(this, CvtlBitfield)
            log.debug(cvt)
        }
        case .LF_STRING_ID: {
            cvt := read_cvtlStringId(this)
            log.debug(cvt)
        }
        case .LF_FUNC_ID: {
            cvt := read_cvtlFuncId(this)
            log.debug(cvt)
        }
        case .LF_MFUNC_ID: {
            cvt := read_cvtlMfuncId(this)
            log.debug(cvt)
        }
        case .LF_UDT_MOD_SRC_LINE: {
            cvt := readv(this, CvtlUdtModSrcLine)
            log.debug(cvt)
        }
        case .LF_BUILDINFO: {
            args := read_cvtlBuildInfo(this)
            log.debug(args)
        }
        case .LF_FIELDLIST: {
            endOffset := baseOffset+ uint(cvtHeader.length) - size_of(CvtRecordKind)
            for this.offset < endOffset {
                for ;this.offset<endOffset;this.offset+=1 {
                    if get_byte(this, this.offset) < u8(CvtRecordKind.LF_PAD0) {
                        break
                    }
                }
                subLf := readv(this, CvtRecordKind)
                #partial switch (subLf) {
                case .LF_BCLASS: {
                    cvt := read_cvtfBclass(this)
                    log.debug(cvt)
                }
                case .LF_VBCLASS:fallthrough
                case .LF_IVBCLASS: {
                    cvt := read_cvtfVbclass(this)
                    log.debug(cvt)
                }
                case .LF_MEMBER: {
                    cvt := read_cvtfMember(this)
                    log.debug(cvt)
                }
                case .LF_ENUMERATE: {
                    cvt := read_cvtfEnumerate(this)
                    log.debug(cvt)
                }
                case: { //?
                    log.debugf("unrecognized: %v", subLf)
                }
                }
            }
        }
        case .LF_VTSHAPE: // TODO:
        case .LF_METHODLIST:  //?
        case: log.warnf("Unhandled %v", cvtHeader.kind)
        }
        this.offset = baseOffset+ uint(cvtHeader.length) - size_of(CvtRecordKind)
    }

    return
}
