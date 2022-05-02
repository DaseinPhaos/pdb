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

TpiIndexOffsetBuffer :: struct {
    buf : []TpiIndexOffsetPair,
}
TpiIndexOffsetPair :: struct #packed {ti: TypeIndex, offset: u32le,}

// TODO: test this method...
find_index_offset :: proc(using this: TpiIndexOffsetBuffer, ti : TypeIndex, tpiStream: ^BlocksReader) -> (tOffset: u32le) {
    // bisearch then linear seaarch proc
    tOffset = 0xffff_ffff
    lo, hi := 0, (len(buf)-1)
    if hi < 0 || buf[lo].ti > ti || buf[hi].ti < ti do return
    // ti in range, do a bisearch
    for lo <= hi {
        log.debugf("Find block [%v, %v) for ti%v", lo,hi, ti)
        mid := lo + ((hi-lo)>>1)
        mv := buf[mid].ti
        if mv == ti {
            lo = mid + 1
            break
        }
        else if mv > ti do hi = mid - 1
        else do lo = mid + 1
    }
    if lo > 0 do lo -= 1
    log.debugf("Find block [%v, %v) for ti%v", lo,lo+1, ti)
    // now a linear search from lo to high
    tIdx := buf[lo].ti
    tpiStream.offset = cast(uint)buf[lo].offset
    endOffset := tpiStream.size
    if lo+1 < len(buf) do endOffset = cast(uint)buf[lo+1].offset
    for ;tpiStream.offset < endOffset && tIdx != ti; tIdx+=1 {
        cvtHeader := readv(tpiStream, CvtRecordHeader)
        tpiStream.offset += cast(uint)cvtHeader.length - size_of(CvtRecordKind)
    }
    log.debugf("Block offset: %v", tpiStream.offset)
    return u32le(tpiStream.offset)
}

parse_tpi_stream :: proc(this: ^BlocksReader, dir: ^StreamDirectory) -> (header: TpiStreamHeader, tiob: TpiIndexOffsetBuffer) {
    header = readv(this, TpiStreamHeader)
    assert(header.headerSize == size_of(TpiStreamHeader), "Incorrect header size, mulfunctional stream")
    if header.version != .V80 {
        log.warnf("unrecoginized streamVersion: %v", header.version)
    }

    if header.hashStreamIndex >= 0 {
        hashStream := get_stream_reader(dir, cast(uint)header.hashStreamIndex)
        iobLen := header.indexOffsetBufferLength / size_of(TpiIndexOffsetPair)
        tiob.buf = make([]TpiIndexOffsetPair, iobLen)
        hashStream.offset = uint(header.indexOffsetBufferOffset) //?
        for i in 0..<iobLen {
            tiob.buf[i] = readv(&hashStream, TpiIndexOffsetPair)
            tiob.buf[i].offset += u32le(this.offset) // apply header offset here as well.
        }
    } else {
        // fallback
        tiob.buf = make([]TpiIndexOffsetPair, 1)
        tiob.buf[0] = TpiIndexOffsetPair{ti = header.typeIndexBegin}
    }
    log.debug(tiob)

    // context.logger.lowest_level = .Warning
    // for this.offset < this.size {
    //     cvtHeader := readv(this, CvtRecordHeader)
    //     log.debug(cvtHeader.kind)
    //     baseOffset := this.offset
    //     inspect_cvt(this, cvtHeader, baseOffset)
    //     this.offset = baseOffset+ uint(cvtHeader.length) - size_of(CvtRecordKind)
    // }

    {
        tOffset := find_index_offset(tiob, 14529, this)
        if tOffset == 0xffff_ffff {
            log.warn("type not found")
        } else {
            this.offset = uint(tOffset)
            cvtHeader := readv(this, CvtRecordHeader)
            log.debug(cvtHeader.kind)
            baseOffset := this.offset
            inspect_cvt(this, cvtHeader, baseOffset)
        }
    }

    return
}

inspect_cvt :: proc(this: ^BlocksReader, cvtHeader : CvtRecordHeader, baseOffset: uint) {
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
}
