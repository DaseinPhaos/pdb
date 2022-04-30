package libpdb

PdbStreamHeader :: struct {
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
