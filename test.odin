package mainp
import "libpdb"
import "core:fmt"
import "core:os"

main ::proc() {
    pdb_path := "C:/projects/sudoku/pdbReader/build/test.pdb"
    file_content, read_error := os.read_entire_file(pdb_path)
    fmt.printf("read_error: %v\n", read_error)
    
    using libpdb
    sb: SuperBlock
    sb_readSuccess := read_superblock(&sb, file_content)
    fmt.printf("sb_readSuccess: %v\n", sb_readSuccess)
    fmt.printf("superblock: %v\n", sb)
    streamDir := read_stream_dir(&sb, file_content)
    fmt.printf("streamDir: %v\n", streamDir)

    pdbStreamReader := BlocksReader{
        data = file_content, blockSize = cast(uint)sb.blockSize, indices = streamDir.streamBlocks[1],
    }
    headerVersion := PdbStreamVersion(read_u32_from_blocks(&pdbStreamReader))
    fmt.printf("pdbStreamVersion: %v\n", headerVersion)
}
