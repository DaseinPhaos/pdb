package libpdb

PdbStream_Index :: 1

PdbStreamHeader :: struct #packed {
    version: PdbStreamVersion,
    signature: u32le,
    age: u32le,
    guid: u128le,
}

PdbStreamVersion :: enum u32le {
    VC2 = 19941610,
    VC4 = 19950623,
    VC41 = 19950814,
    VC50 = 19960307,
    VC98 = 19970604,
    VC70Dep = 19990604,
    VC70 = 20000404,
    VC80 = 20030901,
    VC110 = 20091201,
    VC140 = 20140508,
}

PdbNamedStreamMap :: struct {
    strBuf : []byte,
    nameMap: PdbHashTable(u32le),
}

PdbRaw_FeatureSig :: enum u32le {
    VC110 = 20091201,
    VC140 = 20140508,
    NoTypeMerge = 0x4D544F4E,
    MinimalDebugInfo = 0x494E494D,
}
