//! reference: https://llvm.org/docs/PDB/MsfFile.html https://llvm.org/docs/PDB/index.html
package libpdb
import "core:fmt"
import "core:strings"
import "core:mem"
import "core:log"
import "core:intrinsics"
import "core:runtime"

// SuperBlock|FPM1|FPM2|DataBlocks[BlockSize-3]|FPM1|FPM2|DataBlocks[BlockSize-3])+

FileMagic :string= "Microsoft C/C++ MSF 7.00\r\n\x1a\x44\x53\x00\x00\x00"
SuperBlock :: struct #packed {
    //fileMagic : [len(SuperBlock_FileMagic)]byte, // == SuperBlock_FileMagic
    blockSize : u32le, // block size of the internal file system == 4096
    freeBlockMapBlock : u32le, // index of a block which contains a bitfield indicating free blocks in the file. This index can only be 1/2. ????A file has two FPM to support incremental and atomic updates of the underlying MSF file: while writing, if active FPM is 1, you can write to free blocks indicated by FPM2, and vice-versa.??????
    numBlocks : u32le, // total number of blocks in file, NumBlocks * BlockSize should == size of the file on disk
    numDirectoryBytes : u32le, // size of the StreamDirectory
    unknown : u32le,
    blockMapAddr: u32le, // index of a block within the MSF file, which stores an array of u32le, listing the blocks that the stream directory resides on, because the stream directory might occupy more than one block. array length given by ceil(NumDirectoryBytes/blockSize)
}

// root to other streams in an MSF file, total bytes occupied by this struct in file is stored in superBlock.numDirectoryBytes
StreamDirectory :: struct {
    numStreams : u32le,
    streamSizes : []u32le, // len == numStreams. size of each stream in bytes
    streamBlocks : [][]u32le, // blockIndices = StreamBlocks[streamIdx]. len(blockIndices) == ceil(streamSizes[streamIdx]/superBlock.blockSize)
    data: []byte, 
    blockSize: u32le,
}

get_stream_reader :: #force_inline proc(using this: ^StreamDirectory, streamIdx : u32le) -> BlocksReader {
    return BlocksReader{
        data = data, blockSize = cast(uint)blockSize, indices = streamBlocks[streamIdx], size = cast(uint)streamSizes[streamIdx],
    }
}

read_superblock :: proc(using this : ^SuperBlock, data: []byte) -> (success: bool) {
    if len(data)  < len(FileMagic) + size_of(SuperBlock) {
        log.debug("data len too small")
        return false
    }

    if strings.compare(strings.string_from_ptr(&data[0], len(FileMagic)), FileMagic) != 0 {
        log.debug("FileMagic mismatch")
        return false
    }

    this^ = (cast(^SuperBlock)&data[len(FileMagic)])^

    return true
}

read_stream_dir :: proc(using this: ^SuperBlock, data: []byte) -> (sd: StreamDirectory) {
    sdmOffset := blockMapAddr * blockSize
    sdmSize := ceil_div(numDirectoryBytes, blockSize)
    breader := BlocksReader{
        data = data, blockSize = uint(blockSize), indices = transmute([]u32le)mem.Raw_Slice{&data[sdmOffset],cast(int)sdmSize},
    }

    sd.numStreams = readv(&breader, u32le)
    //fmt.printf("number of streams %v\n", sd.numStreams)
    sd.streamSizes = make([]u32le, sd.numStreams)
    sd.streamBlocks = make([][]u32le, sd.numStreams)
    sd.data = data
    sd.blockSize = blockSize
    for i in 0..<sd.numStreams {
        sd.streamSizes[i] = readv(&breader, u32le)
        if sd.streamSizes[i] == 0xffff_ffff {
            sd.streamSizes[i] = 0 //? clear invalid streamSizes?
        }
        //fmt.printf("reading stream#%v size %v\n", i, sd.streamSizes[i])
        sd.streamBlocks[i] = make([]u32le, ceil_div(sd.streamSizes[i], blockSize))
    }
    
    for i in 0..<sd.numStreams {
        streamBlock := sd.streamBlocks[i]
        //fmt.printf("reading stream#%v indices...\n", i)
        for j in 0..< len(streamBlock) {
            streamBlock[j] = readv(&breader, u32le)
        }
    }
    return
}

//@private
BlocksReader :: struct {
    data: []byte,
    blockSize: uint,
    indices: []u32le,
    offset : uint,
    size : uint,
}
_dummy_indices :[]u32le = {0,}
make_dummy_reader :: proc(data: []byte) -> BlocksReader {
    return BlocksReader{
        data = data,
        blockSize = len(data),
        indices = _dummy_indices,
        offset = 0,
        size = len(data),
    }
}

get_byte :: proc(using this: ^BlocksReader, at: uint) -> byte {
    bii := at / blockSize
    iib := at - (bii * blockSize)
    bi := cast(uint)indices[bii]
    //fmt.printf("read byte at %v in block#%v[%v]: 0x%x\n", at, bii, bi, data[bi*blockSize + iib])
    return data[bi*blockSize + iib]
}

@private
_can_read_packed :: proc ($T: typeid) -> bool {
    if intrinsics.type_is_struct(T) {
        ti := cast(^runtime.Type_Info_Struct)type_info_of(T)
        return ti.is_packed
    }
    return true
}

MsfNotPackedMarker :: struct {}

read_packed :: proc(using this: ^BlocksReader, $T: typeid) -> (ret: T)
    where !intrinsics.type_has_field(T, "_base"),
    !intrinsics.type_is_subtype_of(T, MsfNotPackedMarker) {
        when ODIN_DEBUG==true {
            //log.errorf("Type %v cannot be read", type_info_of(T))
            assert(_can_read_packed(T), "type cannot be read") // I wish this could've been constexpred
        }    
        tsize := cast(uint)size_of(T)
        assert(size == 0 || offset + tsize <= size, "block overflow")
        bii := offset /blockSize
        iib := offset - (bii * blockSize)
        when true {
            pret := cast(^byte)&ret
            psrc := &data[uint(indices[bii])*blockSize+iib]
            blockLeft := blockSize-iib
            mem.copy_non_overlapping(pret, psrc, cast(int)min(tsize, blockLeft))
            if tsize > blockLeft {
                tsize -= blockLeft
                assert(tsize <= blockSize, "when don't support reading a single struct across >2 blocks for now")
                pret = mem.ptr_offset(pret, blockLeft)
                psrc = &data[indices[bii+1]]
                mem.copy_non_overlapping(pret, psrc, cast(int)tsize)
            }
        } else {
            if iib + tsize <= blockSize {
                ret = (cast(^T)&data[uint(indices[bii])*blockSize+iib])^
            } else {
                pret := cast(^byte)&ret
                for i in 0..<tsize {
                    mem.ptr_offset(pret, i)^ = get_byte(this, offset+i)
                }
            }
        }
        
        offset += cast(uint)size_of(T)
        return
}

read_with_trailing_name :: #force_inline proc(this: ^BlocksReader, $T: typeid) -> (ret: T)
    where intrinsics.type_has_field(T, "_base"), 
          intrinsics.type_has_field(T, "name"),
          intrinsics.type_field_index_of(T, "name") == 1,
          intrinsics.type_struct_field_count(T) == 2 {
    ret._base = read_packed(this, type_of(ret._base))
    ret.name = read_length_prefixed_name(this)
    return ret
}

read_with_size_and_trailing_name :: #force_inline proc(this: ^BlocksReader, $T: typeid) -> (ret: T)
    where intrinsics.type_has_field(T, "_base"), 
          intrinsics.type_has_field(T, "name"),
          intrinsics.type_has_field(T, "size"),
          intrinsics.type_field_index_of(T, "size") == 1,
          intrinsics.type_field_index_of(T, "name") == 2,
          intrinsics.type_struct_field_count(T) == 3 {
    ret._base = read_packed(this, type_of(ret._base))
    ret.size = cast(uint)read_int_record(this)
    ret.name = read_length_prefixed_name(this)
    return
}

readv :: proc { read_packed, read_with_trailing_name, read_with_size_and_trailing_name, read_with_trailing_rag, read_cvtlBuildInfo, read_cvtlUnion, read_cvtfArgList, read_cvtfBclass, read_cvtfVbclass, read_cvtfMember, read_cvtfEnumerate, read_dbiModInfo, read_dbiFileInfos, read_cvsFunctionList,}

read_length_prefixed_name :: proc(this: ^BlocksReader) -> (ret: string) {
    //nameLen := cast(int)readv(this, u8) //? this is a fucking lie?
    nameLen :int = 0
    for i in this.offset..<this.size {
        if get_byte(this, i) == 0 do break
        nameLen+=1
    }
    defer this.offset+=1 // eat trailing \0
    if nameLen == 0 do return ""
    //nameLen := cast(int)read_int_record(this)
    a := make([]byte, nameLen)
    for i in 0..<nameLen {
        a[i] = readv(this, byte)
    }
    return strings.string_from_ptr(&a[0], nameLen)
}

@private
ceil_div :: #force_inline proc(a: u32le, b: u32le) -> u32le {
    ret := a / b
    if b * ret != a do ret += 1
    return ret
}
