//! tpi or ipi stream, reference: https://llvm.org/docs/PDB/TpiStream.html
package libpdb
import "core:log"

TpiStream_Index :MsfStreamIdx: 2
IpiStream_Index :MsfStreamIdx: 4

TpiStreamHeader :: struct #packed {
    version             : TpiStreamVersion, // appears to always be v80
    headerSize          : u32le, // == sizeof(TpiStreamHeader)
    typeIndexBegin      : TypeIndex, // usually 0x1000(4096), type indices lower are usually reserved
    typeIndexEnd        : TypeIndex, // total number of type records = typeIndexEnd-typeIndexBegin
    typeRecordBytes     : u32le, // type record data size following the header

    hashStreamIndex     : MsfStreamIdx, // -1 means not present, usually always observed to be present
    hashAuxStreamIndex  : MsfStreamIdx, // unclear what for
    hashKeySize         : u32le, // usually 4 bytes
    numHashBuckets      : u32le, // number of buckets used to generate these hash values

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

seek_for_tpi :: proc(using this: TpiIndexOffsetBuffer, ti : TypeIndex, tpiStream: ^BlocksReader) -> (ok: bool) {
    // bisearch then linear seaarch proc
    lo, hi := 0, (len(buf)-1)
    if hi < 0 || buf[lo].ti > ti || buf[hi].ti < ti do return false
    // ti in range, do a bisearch
    for lo <= hi {
        //log.debugf("Find block [%v, %v) for ti%v", lo,hi, ti)
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
    //log.debugf("Find block [%v, %v) for ti%v", lo,lo+1, ti)
    // now a linear search from lo to high
    tIdx := buf[lo].ti
    tpiStream.offset = cast(uint)buf[lo].offset
    endOffset := tpiStream.size
    if lo+1 < len(buf) do endOffset = cast(uint)buf[lo+1].offset
    for ;tpiStream.offset < endOffset && tIdx != ti; tIdx+=1 {
        cvtHeader := readv(tpiStream, CvtRecordHeader)
        tpiStream.offset += cast(uint)cvtHeader.length - size_of(CvtRecordKind)
    }
    //log.debugf("Block offset: %v", tpiStream.offset)
    return true
}

parse_tpi_stream :: proc(this: ^BlocksReader, dir: ^StreamDirectory) -> (header: TpiStreamHeader, tiob: TpiIndexOffsetBuffer) {
    header = readv(this, TpiStreamHeader)
    assert(header.headerSize == size_of(TpiStreamHeader), "Incorrect header size, mulfunctional stream")
    if header.version != .V80 {
        log.warnf("unrecoginized tpiVersion: %v", header.version)
    }

    if header.hashStreamIndex >= 0 {
        hashStream := get_stream_reader(dir, header.hashStreamIndex)
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
    //log.debug(tiob)

    // //context.logger.lowest_level = .Warning
    // ti := header.typeIndexBegin
    // for this.offset < this.size {
    //     cvtHeader := readv(this, CvtRecordHeader)
    //     log.debug(cvtHeader.kind)
    //     baseOffset := this.offset
    //     defer this.offset = baseOffset+ uint(cvtHeader.length) - size_of(CvtRecordKind)
    //     log.debugf("TypeIndex%x(%v): %v", ti, ti, cvtHeader)
    //     ti+=1
    //     //inspect_cvt(this, cvtHeader)
    // }
    return
}

// TODO: cleanup
inspect_cvt :: proc(this: ^BlocksReader, cvtHeader : CvtRecordHeader) {
    #partial switch  cvtHeader.kind {
        case .LF_POINTER: {
            cvtPtr := readv(this, CvtPointer)
            log.debug(cvtPtr)
        }
        case .LF_PROCEDURE: {
            CvtProc := readv(this, CvtProc)
            log.debug(CvtProc)
        }
        case .LF_ARGLIST:fallthrough
        case .LF_SUBSTR_LIST: {
            args := readv(this, CvtProc_ArgList)
            log.debug(args)
        }
        case .LF_CLASS:fallthrough
        case .LF_STRUCTURE:fallthrough
        case .LF_INTERFACE: {
            cvtStruct := readv(this, CvtStruct)
            log.debug(cvtStruct)
        }
        case .LF_ENUM: {
            cvtEnum := readv(this, CvtEnum)
            log.debug(cvtEnum)
        }
        case .LF_ARRAY: {
            cvtArray := readv(this, CvtArray)
            log.debug(cvtArray)
        }
        case .LF_UNION: {
            cvtUnion := readv(this, CvtUnion)
            log.debug(cvtUnion)
        }
        case .LF_MODIFIER: {
            cvt := readv(this, CvtModifier)
            log.debug(cvt)
        }
        case .LF_MFUNCTION: {
            cvt := readv(this, CvtMFunction)
            log.debug(cvt)
        }
        case .LF_BITFIELD: {
            cvt := readv(this, CvtBitfield)
            log.debug(cvt)
        }
        case .LF_STRING_ID: {
            cvt := readv(this, CvtStringId)
            log.debug(cvt)
        }
        case .LF_FUNC_ID: {
            cvt := readv(this, CvtFuncId)
            log.debug(cvt)
        }
        case .LF_MFUNC_ID: {
            cvt := readv(this, CvtMfuncId)
            log.debug(cvt)
        }
        case .LF_UDT_MOD_SRC_LINE: {
            cvt := readv(this, CvtUdtModSrcLine)
            log.debug(cvt)
        }
        case .LF_BUILDINFO: {
            args := readv(this, CvtBuildInfo)
            log.debug(args)
        }
        case .LF_FIELDLIST: {
            endOffset := this.offset + uint(cvtHeader.length) - size_of(CvtRecordKind)
            for this.offset < endOffset {
                for ;this.offset<endOffset;this.offset+=1 {
                    if this.data[this.offset] < u8(CvtRecordKind.LF_PAD0) {
                        break
                    }
                }
                subLf := readv(this, CvtRecordKind)
                #partial switch (subLf) {
                case .LF_BCLASS: {
                    cvt := readv(this, CvtField_BClass)
                    log.debug(cvt)
                }
                case .LF_VBCLASS:fallthrough
                case .LF_IVBCLASS: {
                    cvt := readv(this, CvtField_Vbclass)
                    log.debug(cvt)
                }
                case .LF_MEMBER: {
                    cvt := readv(this, CvtField_Member)
                    log.debug(cvt)
                }
                case .LF_ENUMERATE: {
                    cvt := readv(this, CvtField_Enumerate)
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
