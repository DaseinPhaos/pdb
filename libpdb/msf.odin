//! reference: https://llvm.org/docs/PDB/MsfFile.html https://llvm.org/docs/PDB/index.html
package libpdb
import "core:fmt"
import "core:strings"
import "core:mem"
// SuperBlock|FPM1|FPM2|DataBlocks[BlockSize-3]|FPM1|FPM2|DataBlocks[BlockSize-3])+

FileMagic :string= "Microsoft C/C++ MSF 7.00\r\n\x1a\x44\x53\x00\x00\x00"
SuperBlock :: struct {
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
}

read_superblock :: proc(using this : ^SuperBlock, data: []byte) -> (success: bool) {
    if len(data)  < len(FileMagic) + size_of(SuperBlock) {
        //fmt.println("bytes too small")
        return false
    }

    if strings.compare(strings.string_from_ptr(&data[0], len(FileMagic)), FileMagic) != 0 {
        // fmt.println("FileMagic mismatch")
        // fmt.print("SRC: ")
        // for c in data[:len(FileMagic)] {
        //     fmt.printf("%x ", c)
        // }
        // fmt.print("\nDST: ")
        // for c in transmute([]byte)FileMagic {
        //     fmt.printf("%x ", c)
        // }
        // fmt.print("\n")
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

    sd.numStreams = read_u32_from_blocks(&breader)
    //fmt.printf("number of streams %v\n", sd.numStreams)
    sd.streamSizes = make([]u32le, sd.numStreams)
    sd.streamBlocks = make([][]u32le, sd.numStreams)
    for i in 0..<sd.numStreams {
        sd.streamSizes[i] = read_u32_from_blocks(&breader)
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
            streamBlock[j] = read_u32_from_blocks(&breader)
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
}

get_byte_from_blocks :: proc(using this: ^BlocksReader, at: uint) -> byte {
    bii := at / blockSize
    iib := at - (bii * blockSize)
    bi := cast(uint)indices[bii]
    //fmt.printf("read byte at %v in block#%v[%v]: 0x%x\n", at, bii, bi, data[bi*blockSize + iib])
    return data[bi*blockSize + iib]
}

read_u32_from_blocks :: proc(using this: ^BlocksReader) -> (ret:u32le) {
    when true {
        bii := offset /blockSize
        iib := offset - (bii * blockSize)
        if iib + 3 < blockSize {
            ret = (cast(^u32le)&data[uint(indices[bii])*blockSize+iib])^
        } else {
            b0 := u32le(data[uint(indices[bii])*blockSize+iib]) //b0 := u32le(get_byte_from_blocks(this, offset))
            b1 := u32le(get_byte_from_blocks(this, offset+1))
            b2 := u32le(get_byte_from_blocks(this, offset+2))
            b3 := u32le(get_byte_from_blocks(this, offset+3))
            ret = (b3 << 24) | (b2 << 16) | (b1 << 8) | b0
        }   
    } else {
        b0 := u32le(get_byte_from_blocks(this, offset))
        b1 := u32le(get_byte_from_blocks(this, offset+1))
        b2 := u32le(get_byte_from_blocks(this, offset+2))
        b3 := u32le(get_byte_from_blocks(this, offset+3))
        ret = (b3 << 24) | (b2 << 16) | (b1 << 8) | b0
    }
    //fmt.printf("read u32le at offset[%v]: 0X%X\n", offset, ret)
    offset+=4
    return
}

@private
ceil_div :: #force_inline proc(a: u32le, b: u32le) -> u32le {
    ret := a / b
    if b * ret != a do ret += 1
    return ret
}
