//! code view type records, reference: https://llvm.org/docs/PDB/CodeViewTypes.html
package libpdb
import "core:log"
import "core:strings"

// |           Unused          | Mode |   Kind   |
// |+32                        |+12   |+8        |+0
TypeIndex :: distinct u32le
CvItemId :: TypeIndex //? Item Id is a stricter typeindex which may referenced from symbol stream.
get_type_kind :: #force_inline proc(this: TypeIndex) -> TypeIndex_Kind {
    bits := u32le(this)
    bits = bits & ((1 << 9) - 1)
    return TypeIndex_Kind(bits)
}

get_type_mode :: #force_inline proc(this: TypeIndex) -> TypeIndex_Mode {
    bits := u32le(this)
    bits = (bits>>8) & ((1 << 5) - 1)
    return TypeIndex_Mode(bits)
}

TypeIndex_Kind :: enum u32le {
    None = 0x0000,          // uncharacterized type (no type)
    Void = 0x0003,          // void
    NotTranslated = 0x0007, // type not translated by cvpack
    HResult = 0x0008,       // OLE/COM HRESULT

    SignedCharacter = 0x0010,   // 8 bit signed
    UnsignedCharacter = 0x0020, // 8 bit unsigned
    NarrowCharacter = 0x0070,   // really a char
    WideCharacter = 0x0071,     // wide char
    Character16 = 0x007a,       // char16_t
    Character32 = 0x007b,       // char32_t
    Character8 = 0x007c,        // char8_t

    SByte = 0x0068,       // 8 bit signed int
    Byte = 0x0069,        // 8 bit unsigned int
    Int16Short = 0x0011,  // 16 bit signed
    UInt16Short = 0x0021, // 16 bit unsigned
    Int16 = 0x0072,       // 16 bit signed int
    UInt16 = 0x0073,      // 16 bit unsigned int
    Int32Long = 0x0012,   // 32 bit signed
    UInt32Long = 0x0022,  // 32 bit unsigned
    Int32 = 0x0074,       // 32 bit signed int
    UInt32 = 0x0075,      // 32 bit unsigned int
    Int64Quad = 0x0013,   // 64 bit signed
    UInt64Quad = 0x0023,  // 64 bit unsigned
    Int64 = 0x0076,       // 64 bit signed int
    UInt64 = 0x0077,      // 64 bit unsigned int
    Int128Oct = 0x0014,   // 128 bit signed int
    UInt128Oct = 0x0024,  // 128 bit unsigned int
    Int128 = 0x0078,      // 128 bit signed int
    UInt128 = 0x0079,     // 128 bit unsigned int

    Float16 = 0x0046,                 // 16 bit real
    Float32 = 0x0040,                 // 32 bit real
    Float32PartialPrecision = 0x0045, // 32 bit PP real
    Float48 = 0x0044,                 // 48 bit real
    Float64 = 0x0041,                 // 64 bit real
    Float80 = 0x0042,                 // 80 bit real
    Float128 = 0x0043,                // 128 bit real

    Complex16 = 0x0056,                 // 16 bit complex
    Complex32 = 0x0050,                 // 32 bit complex
    Complex32PartialPrecision = 0x0055, // 32 bit PP complex
    Complex48 = 0x0054,                 // 48 bit complex
    Complex64 = 0x0051,                 // 64 bit complex
    Complex80 = 0x0052,                 // 80 bit complex
    Complex128 = 0x0053,                // 128 bit complex

    Boolean8 = 0x0030,   // 8 bit boolean
    Boolean16 = 0x0031,  // 16 bit boolean
    Boolean32 = 0x0032,  // 32 bit boolean
    Boolean64 = 0x0033,  // 64 bit boolean
    Boolean128 = 0x0034, // 128 bit boolean
};

TypeIndex_Mode :: enum u32le {
    Direct = 0,        // Not a pointer
    NearPointer = 1,   // Near pointer
    FarPointer = 2,    // Far pointer
    HugePointer = 3,   // Huge pointer
    NearPointer32 = 4, // 32 bit near pointer
    FarPointer32 = 5,  // 32 bit far pointer
    NearPointer64 = 6, // 64 bit near pointer
    NearPointer128 = 7,// 128 bit near pointer
};

CvtRecordHeader :: struct #packed {
    length  : u16le, // record length excluding this 2 byte field
    kind    : CvtRecordKind,
}

CvtRecordKind :: enum u16le {
    LF_POINTER = 0x1002, // CvtlPointer
    LF_MODIFIER = 0x1001, // CvtlModifier
    LF_PROCEDURE = 0x1008, // CvtlProc
    LF_MFUNCTION = 0x1009,
    LF_LABEL = 0x000e,
    LF_ARGLIST = 0x1201, // CvtlArgs
    LF_FIELDLIST = 0x1203, // TODO: proper child enumeration
    LF_ARRAY = 0x1503, // CvtlArray
    LF_CLASS = 0x1504, // CvtlStruct
    LF_STRUCTURE = 0x1505, // CvtlStruct
    LF_INTERFACE = 0x1519, // CvtlStruct
    LF_UNION = 0x1506,
    LF_ENUM = 0x1507, // CvtlEnum
    LF_TYPESERVER2 = 0x1515,
    LF_VFTABLE = 0x151d,
    LF_VTSHAPE = 0x000a,
    LF_BITFIELD = 0x1205,
    LF_FUNC_ID = 0x1601,
    LF_MFUNC_ID = 0x1602,
    LF_BUILDINFO = 0x1603,
    LF_SUBSTR_LIST = 0x1604,
    LF_STRING_ID = 0x1605,
    LF_UDT_SRC_LINE = 0x1606,
    LF_UDT_MOD_SRC_LINE = 0x1607,
    LF_METHODLIST = 0x1206,
    LF_PRECOMP = 0x1509,
    LF_ENDPRECOMP = 0x0014,
    //==== member records, dont describe length
    LF_BCLASS = 0x1400,
    LF_BINTERFACE = 0x151a,
    LF_VBCLASS = 0x1401,
    LF_IVBCLASS = 0x1402,
    LF_VFUNCTAB = 0x1409,
    LF_STMEMBER = 0x150e,
    LF_METHOD = 0x150f,
    LF_MEMBER = 0x150d,
    LF_NESTTYPE = 0x1510,
    LF_ONEMETHOD = 0x1511,
    LF_ENUMERATE = 0x1502,
    LF_INDEX = 0x1404,
    //==== numeric records
    LF_NUMERIC          = 0x8000,
    LF_CHAR             = 0x8000,
    LF_SHORT            = 0x8001,
    LF_USHORT           = 0x8002,
    LF_LONG             = 0x8003,
    LF_ULONG            = 0x8004,
    LF_REAL32           = 0x8005,
    LF_REAL64           = 0x8006,
    LF_REAL80           = 0x8007,
    LF_REAL128          = 0x8008,
    LF_QUADWORD         = 0x8009,
    LF_UQUADWORD        = 0x800a,
    LF_REAL48           = 0x800b,
    LF_COMPLEX32        = 0x800c,
    LF_COMPLEX64        = 0x800d,
    LF_COMPLEX80        = 0x800e,
    LF_COMPLEX128       = 0x800f,
    LF_VARSTRING        = 0x8010,
    LF_OCTWORD          = 0x8017,
    LF_UOCTWORD         = 0x8018,
    LF_DECIMAL          = 0x8019,
    LF_DATE             = 0x801a,
    LF_UTF8STRING       = 0x801b,
    LF_REAL16           = 0x801c,
    //==== padding records
    LF_PAD0 = 0xf0,
    LF_PAD1 = 0xf1,
    LF_PAD2 = 0xf2,
    LF_PAD3 = 0xf3,
    LF_PAD4 = 0xf4,
    LF_PAD5 = 0xf5,
    LF_PAD6 = 0xf6,
    LF_PAD7 = 0xf7,
    LF_PAD8 = 0xf8,
    LF_PAD9 = 0xf9,
    LF_PAD10 = 0xfa,
    LF_PAD11 = 0xfb,
    LF_PAD12 = 0xfc,
    LF_PAD13 = 0xfd,
    LF_PAD14 = 0xfe,
    LF_PAD15 = 0xff,
}

read_int_record :: proc(this: ^BlocksReader) -> i128le {
    numKind := readv(this, CvtRecordKind)
    #partial switch numKind {
    case .LF_CHAR: return cast(i128le)readv(this, i8)
    case .LF_SHORT: return cast(i128le)readv(this, i16le)
    case .LF_USHORT: return cast(i128le)readv(this, u16le)
    case .LF_LONG: return cast(i128le)readv(this, i32le)
    case .LF_ULONG: return cast(i128le)readv(this, u32le)
    case .LF_QUADWORD: return cast(i128le)readv(this, i64le)
    case .LF_UQUADWORD: return cast(i128le)readv(this, u64le)
    case .LF_OCTWORD: return readv(this, i128le)
    case: {
        if uint(numKind) < uint(CvtRecordKind.LF_NUMERIC) {
            return i128le(numKind)
        }
        log.errorf("unsupported record type:%v", numKind)
        assert(false, "unsupported record type. should be a non-overflow integer")
    }
    }
    return -1
}

//====type record for LF_MODIFIER
CvtlModifier :: struct #packed {
    modifiedType : TypeIndex,
    attrs        : CvtlModifier_Type,
}
CvtlModifier_Type :: enum u16le {
    None = 0,
    Const = 1,
    Volatile = 2,
    Unaligned = 4,
}

//====type record for LF_POINTER
// Note that “plain” pointers to primitive types are not represented by LF_POINTER records, they are indicated by special reserved TypeIndex values.
CvtlPointer :: struct #packed {
    referentType: TypeIndex,
    attributes  : CvtlPointer_Attrs,
}

// bit field
// |  Flags  |       Size       |   Modifiers   |  Mode   |      Kind     |
// +0x16     +0x13              +0xD            +0x8      +0x5            +0x0
CvtlPointer_Attrs :: distinct u32le

CvtlPointer_Kind :: enum u8 {
    Near16 = 0x00,                // 16 bit pointer
    Far16 = 0x01,                 // 16:16 far pointer
    Huge16 = 0x02,                // 16:16 huge pointer
    BasedOnSegment = 0x03,        // based on segment
    BasedOnValue = 0x04,          // based on value of base
    BasedOnSegmentValue = 0x05,   // based on segment value of base
    BasedOnAddress = 0x06,        // based on address of base
    BasedOnSegmentAddress = 0x07, // based on segment address of base
    BasedOnType = 0x08,           // based on type
    BasedOnSelf = 0x09,           // based on self
    Near32 = 0x0a,                // 32 bit pointer
    Far32 = 0x0b,                 // 16:32 pointer
    Near64 = 0x0c,                // 64 bit pointer
};

CvtlPointer_Mode :: enum u8 {
    Pointer = 0x00,                 // "normal" pointer
    LValueReference = 0x01,         // "old" reference
    PointerToDataMember = 0x02,     // pointer to data member
    PointerToMemberFunction = 0x03, // pointer to member function
    RValueReference = 0x04,         // r-value reference
};

CvtlPointer_Modifiers :: enum u8 {
    None = 0x00,                    // "normal" pointer
    Flat32 = 0x01,                  // "flat" pointer
    Volatile = 0x02,                // marked volatile
    Const = 0x04,                   // marked const
    Unaligned = 0x08,               // marked unaligned
    Restrict = 0x10,                // marked restrict
};

CvtlPointer_Flags :: enum u8 {
    WinRTSmartPointer = 0x01,       // a WinRT smart pointer
    LValueRefThisPointer = 0x02,    // 'this' pointer of a member function with ref qualifier (e.g. void X::foo() &)
    RValueRefThisPointer = 0x04,    // 'this' pointer of a member function with ref qualifier (e.g. void X::foo() &&)
};

// TODO: member point info
//====type record for LF_BITFIELD
CvtlBitfield :: struct #packed {
    utype : TypeIndex,
    length: u8,
    pos   : u8,
}
//====type record for LF_STRING_ID
CvtlStringId :: struct {
    id : CvItemId, // ID to list of sub string IDs
    name : string,
}
read_cvtlStringId ::proc(this: ^BlocksReader) -> (ret: CvtlStringId) {
    ret.id = readv(this, CvItemId)
    ret.name = read_length_prefixed_name(this)
    return
}
//====type record for LF_FUNC_ID
CvtlFuncId :: struct {
    scopeId  : CvItemId, // parrent scope of the ID, 0 if global
    funcType : TypeIndex,
    name     : string,
}
read_cvtlFuncId ::proc(this: ^BlocksReader) -> (ret: CvtlFuncId) {
    ret.scopeId = readv(this, CvItemId)
    ret.funcType = readv(this, TypeIndex)
    ret.name = read_length_prefixed_name(this)
    return
}
//====type record for LF_MFUNC_ID
CvtlMfuncId :: struct {
    parent   : TypeIndex,
    funcType : TypeIndex,
    name     : string,
}
read_cvtlMfuncId ::proc(this: ^BlocksReader) -> (ret: CvtlMfuncId) {
    ret.parent = readv(this, TypeIndex)
    ret.funcType = readv(this, TypeIndex)
    ret.name = read_length_prefixed_name(this)
    return
}
//====type record for LF_UDT_MOD_SRC_LINE
CvtlUdtModSrcLine :: struct #packed {
    udtType : TypeIndex,
    src : CvItemId, // index into string table where src filename is saved
    line: u32le,
    imod: u16le, // module that contributes this udt def
}
//====type record for LF_BUILDINFO
CvtlBuildInfo :: struct {
    //count : u16le,
    args : []CvItemId,
}
read_cvtlBuildInfo :: proc(this: ^BlocksReader) -> (ret: CvtlBuildInfo) {
    argCount := readv(this, u16le)
    ret.args = make([]CvItemId, argCount)
    for i in 0..<argCount {
        ret.args[i] = readv(this, CvItemId)
    }
    return
}

//====type record for LF_PROCEDURE
CvtlProc :: struct #packed {
    retType     : TypeIndex,
    callType    : u8, //? calling convention
    attrs       : CvtlProc_Attribute,
    paramCount  : u16le,
    argList     : TypeIndex,
}
CvtlProc_Attribute :: enum u8 {
    None = 0,
    CxxReturnUdt = 1 << 0,
    Ctor = 1 << 1,
    Ctorvbase = 1 << 2,
}

//====type record for LF_MFUNCTION
CvtlMFunction :: struct #packed {
    retType   : TypeIndex,
    classType : TypeIndex, // containing class
    thisType  : TypeIndex, // this pointer type (model specific)
    callType  : u8, //? calling convention
    attrs     : CvtlProc_Attribute,
    paramCount: u16le,
    argList   : TypeIndex,
    thisAdjust: u32le,
}

//====type record for LF_ARGLIST, LF_SUBSTR_LIST
CvtlProc_ArgList :: struct {
    //count : u32le,
    args : []TypeIndex,
}
read_cvtfArgList :: proc(this: ^BlocksReader) -> (ret: CvtlProc_ArgList) {
    argCount := readv(this, u32le)
    ret.args = make([]TypeIndex, argCount)
    for i in 0..<argCount {
        ret.args[i] = readv(this, TypeIndex)
    }
    return
}

//====type record for LF_FIELDLIST
// a collection of sub fields.
//====sub LF_BCLASS
CvtField_BClass :: struct {
    attr    : CvtField_Attribute,
    baseType: TypeIndex, // type index of the base class
    offset  : uint, // offset of base within class, stored as a LF_NUMERIC
}
read_cvtfBclass :: proc(this: ^BlocksReader) -> (ret: CvtField_BClass) {
    ret.attr = readv(this, CvtField_Attribute)
    ret.baseType = readv(this, TypeIndex)
    ret.offset = cast(uint)read_int_record(this)
    return
}
//====sub LF_VBCLASS|LF_IVBCLASS
CvtField_Vbclass :: struct {
    attr    : CvtField_Attribute,
    baseType: TypeIndex,
    vbptr   : TypeIndex,
    vbpo    : uint, // virtual base pointer offset from address pointer
    vbo     : uint, // virutal base offset from vbtable
}
read_cvtfVbclass :: proc(this: ^BlocksReader) -> (ret: CvtField_Vbclass) {
    ret.attr = readv(this, CvtField_Attribute)
    ret.baseType = readv(this, TypeIndex)
    ret.vbptr = readv(this, TypeIndex)
    ret.vbpo = cast(uint)read_int_record(this)
    ret.vbo = cast(uint)read_int_record(this)
    return
}
//====sub LF_MEMBER
CvtField_Member :: struct {
    attr    : CvtField_Attribute,
    memType : TypeIndex,
    offset  : uint,
    name    : string,
}
read_cvtfMember :: proc(this: ^BlocksReader) -> (ret: CvtField_Member) {
    ret.attr = readv(this, CvtField_Attribute)
    ret.memType = readv(this, TypeIndex)
    ret.offset = cast(uint)read_int_record(this)
    ret.name = read_length_prefixed_name(this)
    return
}
//====sub LF_ENUMERATE
CvtField_Enumerate :: struct {
    attr : CvtField_Attribute,
    value: uint, //? overflow?
    name: string,
}
read_cvtfEnumerate :: proc(this: ^BlocksReader) -> (ret: CvtField_Enumerate) {
    ret.attr = readv(this, CvtField_Attribute)
    ret.value = cast(uint)read_int_record(this)
    ret.name = read_length_prefixed_name(this)
    return
}
//LF_PADs

//====type record for LF_ARRAY
CvtlArray :: struct {
    elemType : TypeIndex,
    idxType  : TypeIndex,
    size     : uint,
    name      : string,
}
read_cvtlArray :: proc(this: ^BlocksReader) -> (ret: CvtlArray) {
    ret.elemType = readv(this, TypeIndex)
    ret.idxType = readv(this, TypeIndex)
    ret.size = cast(uint)read_int_record(this)
    ret.name = read_length_prefixed_name(this)
    return
}

//====type record for LF_UNION
CvtlUnion :: struct {
    elemCount : u16le,
    props     : CvtlStruct_Prop,
    field     : TypeIndex, // LF_FIELD descriptor list
    size      : uint,
    name      : string,
}
read_cvtlUnion :: proc(this: ^BlocksReader) -> (ret: CvtlUnion) {
    ret.elemCount = readv(this, u16le)
    ret.props = readv(this, CvtlStruct_Prop)
    ret.field = readv(this, TypeIndex)
    ret.size = cast(uint)read_int_record(this)
    ret.name = read_length_prefixed_name(this)
    return
}

//====type record for LF_CLASS, LF_STRUCTURE, LF_INTERFACE
// followed by data describing length of structure in bytes and name
CvtlStruct :: struct {
    elemCount   : u16le,
    props       : CvtlStruct_Prop,
    field       : TypeIndex, // LF_FIELD descriptor list
    derivedFrom : TypeIndex, // derived from list if not zero
    vshape      : TypeIndex, // vshape table
    size        : uint,
    name        : string,
}
read_cvtlStruct :: proc(this: ^BlocksReader) -> (ret: CvtlStruct) {
    ret.elemCount = readv(this, u16le)
    ret.props = readv(this, CvtlStruct_Prop)
    ret.field = readv(this, TypeIndex)
    ret.derivedFrom = readv(this, TypeIndex)
    ret.vshape = readv(this, TypeIndex)
    ret.size = cast(uint)read_int_record(this)
    ret.name = read_length_prefixed_name(this)
    return
}

CvtlStruct_Prop :: enum u16le {
    None = 0,
    Packed = 1 << 0,
    Ctor = 1 << 1, 
    Ovlops = 1 << 2, 
    IsNested = 1 << 3,
    Cnested = 1 << 4, 
    OpAssign = 1 << 5,
    OpCast = 1 << 6,
    FwdRef = 1 << 7,
    Scoped = 1 << 8,
    HasUniqueueName = 1 << 9, 
    Sealed = 1 << 10,
    HFA_Float = u16le(CvtlStruct_HFA.Float) << 11,
    HFA_Double = u16le(CvtlStruct_HFA.Double) << 11,
    HFA_Other = u16le(CvtlStruct_HFA.Other) << 11,
    Intrinsics = 1 << 13, 
    Mocom_Ref = u16le(CvtlStruct_MoCOM_UDT.Ref) << 14,
    Mocom_Value = u16le(CvtlStruct_MoCOM_UDT.Value) << 14,
    Mocom_Interface = u16le(CvtlStruct_MoCOM_UDT.Interface) << 14,
}
CvtlStruct_HFA :: enum u16le {
    None=0, Float=1, Double=2, Other=3,
}
CvtlStruct_MoCOM_UDT :: enum u16le {
    None, Ref, Value, Interface,
}

//====type record for LF_ENUM
CvtlEnum :: struct {
    elemCount   : u16le,
    props       : CvtlStruct_Prop,
    underlyType : TypeIndex,
    fieldList   : TypeIndex, // type index into the LF_FIELD descriptor list
    name        : string,
}
read_cvtlEnum:: proc(this: ^BlocksReader) -> (ret: CvtlEnum) {
    ret.elemCount = readv(this, u16le)
    ret.props = readv(this, CvtlStruct_Prop)
    ret.underlyType = readv(this, TypeIndex)
    ret.fieldList = readv(this, TypeIndex)
    ret.name = read_length_prefixed_name(this)
    return
}

CvtField_Attribute :: enum u16le {
    None = 0,
    Access_Private = 1,
    Access_Protected = 2,
    Access_Public = 3,
    Mprop_Virtual = u16le(CvtMethodProp.Virtual) << 2,
    Mprop_Static = u16le(CvtMethodProp.Static) << 2,
    Mprop_Friend = u16le(CvtMethodProp.Friend) << 2,
    Mprop_Intro = u16le(CvtMethodProp.Intro) << 2,
    Mprop_PureVirt = u16le(CvtMethodProp.PureVirt) << 2,
    Mprop_PureIntro = u16le(CvtMethodProp.PureIntro) << 2,
    Pseudo = 1<<5, // compiler generated function, doesn't exist
    NoInherit = 1<<6, // class cannot be inherited
    NoConstruct = 1<<7, // class cannot be constructed
    CompGenx = 1<<8, // compiler genertaed function, do exist
    Sealed = 1<<9, // function cannot be overriden
}
CvtAccess :: enum u8 {
    Private = 1,
    Protected = 2,
    Public = 3,
}
CvtMethodProp :: enum u8 {
    Vanilla        = 0x00,
    Virtual        = 0x01,
    Static         = 0x02,
    Friend         = 0x03,
    Intro          = 0x04,
    PureVirt       = 0x05,
    PureIntro      = 0x06,
}

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