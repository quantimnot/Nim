discard """
matrix: "; --checks:off"
targets: "c js"
description: "Comprehensive numeric handling test for all backends including BigInt arithmetic, edge cases"
"""

import std/[math, hashes]

# Test configuration based on backend
const
  usingBigInts = defined(js) # BigInt operations are most relevant for JS
  usingRangeChecks = compileOption("rangeChecks") # range checks are enabled by default
  usingOverflowChecks = compileOption("overflowChecks")
    # overflow checks are enabled by default
  usingFloatChecks = compileOption("floatChecks") # float checks are enabled by default
  usingNanChecks = compileOption("nanChecks") # nan checks are enabled by default
  usingInfChecks = compileOption("infChecks") # inf checks are enabled by default

block integer_sizes:
  # Test int8
  var i8_max: int8 = 127
  var i8_min: int8 = -128

  when not usingRangeChecks and not usingOverflowChecks:
    # Test that both backends handle integer overflow consistently when all checks are off
    # This should wrap around for both C and JS backends
    doAssert i8_max + 1 == -128 # Should wrap from 127 to -128
    doAssert i8_min - 1 == 127 # Should wrap from -128 to 127
  else:
    # With range or overflow checks enabled, both backends behave consistently
    doAssert i8_max == 127
    doAssert i8_min == -128

  # Test uint8
  var u8_max: uint8 = 255
  var u8_min: uint8 = 0

  when not usingRangeChecks and not usingOverflowChecks:
    # Both C and JS wrap uint8 the same way when checks are off
    doAssert u8_max + 1 == 0
    doAssert u8_min - 1 == 255
  else:
    doAssert u8_max == 255
    doAssert u8_min == 0

  # Test int16
  var i16_max: int16 = 32767
  var i16_min: int16 = -32768

  when not usingRangeChecks and not usingOverflowChecks:
    # Test that both backends handle integer overflow consistently when checks are off
    doAssert i16_max + 1 == -32768
    doAssert i16_min - 1 == 32767
  else:
    doAssert i16_max == 32767
    doAssert i16_min == -32768

  # Test uint16
  var u16_max: uint16 = 65535
  var u16_min: uint16 = 0

  when not usingRangeChecks and not usingOverflowChecks:
    # Both C and JS wrap uint16 the same way when checks are off
    doAssert u16_max + 1 == 0
    doAssert u16_min - 1 == 65535
  else:
    doAssert u16_max == 65535
    doAssert u16_min == 0

  # Test int32
  var i32_max: int32 = 2147483647
  var i32_min: int32 = -2147483648
  doAssert i32_max == 2147483647
  doAssert i32_min == -2147483648

  # Test uint32
  var u32_max: uint32 = 4294967295'u32
  var u32_min: uint32 = 0'u32
  doAssert u32_max == 4294967295'u32
  doAssert u32_min == 0'u32

block test_64bit_operations:
  # Basic 64-bit values
  var i64_large: int64 = 9223372036854775807'i64
  var i64_small: int64 = -9223372036854775808'i64
  var u64_large: uint64 = 18446744073709551615'u64

  doAssert i64_large == 9223372036854775807'i64
  doAssert i64_small == -9223372036854775808'i64
  doAssert u64_large == 18446744073709551615'u64

  # Arithmetic operations
  var a64: int64 = 1000000000000'i64
  var b64: int64 = 2000000000000'i64
  doAssert a64 + b64 == 3000000000000'i64
  doAssert b64 - a64 == 1000000000000'i64
  doAssert a64 * 2 == 2000000000000'i64
  doAssert b64 div 2 == 1000000000000'i64
  doAssert b64 mod a64 == 0'i64

  # Unsigned operations
  var ua64: uint64 = 10000000000000'u64
  var ub64: uint64 = 20000000000000'u64
  doAssert ua64 + ub64 == 30000000000000'u64
  doAssert ub64 - ua64 == 10000000000000'u64
  doAssert ua64 * 2'u64 == 20000000000000'u64
  doAssert ub64 div 2'u64 == 10000000000000'u64
  doAssert ub64 mod ua64 == 0'u64

block bitwise_operations:
  # Test patterns for different sizes
  block test8bit:
    var a: uint8 = 0b10101010
    var b: uint8 = 0b11110000
    doAssert (a and b) == 0b10100000
    doAssert (a or b) == 0b11111010
    doAssert (a xor b) == 0b01011010
    doAssert (not a) == 0b01010101
    doAssert (a shl 1) == 0b01010100
    doAssert (a shr 1) == 0b01010101

  block test16bit:
    var a: uint16 = 0b1010101010101010
    var b: uint16 = 0b1111000011110000
    doAssert (a and b) == 0b1010000010100000
    doAssert (a or b) == 0b1111101011111010
    doAssert (a xor b) == 0b0101101001011010
    doAssert (a shl 1) == 0b0101010101010100
    doAssert (a shr 1) == 0b0101010101010101

  block test32bit:
    var a: uint32 = 0x12345678'u32
    var b: uint32 = 0x87654321'u32
    doAssert (a and b) == 0x02244220'u32
    doAssert (a or b) == 0x97755779'u32
    doAssert (a xor b) == 0x95511559'u32
    doAssert (a shl 4) == 0x23456780'u32
    doAssert (a shr 4) == 0x01234567'u32

  when usingBigInts:
    block test64bit:
      var a: uint64 = 0x123456789ABCDEF0'u64
      var b: uint64 = 0xFEDCBA9876543210'u64
      doAssert (a and b) == 0x1214121812141210'u64
      doAssert (a or b) == 0xFEFCFEF8FEFCFEF0'u64
      doAssert (a xor b) == 0xECE8ECE0ECE8ECE0'u64
      doAssert (a shl 4) == 0x23456789ABCDEF00'u64
      doAssert (a shr 4) == 0x0123456789ABCDEF'u64

block type_conversions:
  # Test all combinations of size conversions
  block narrowingConversions:
    var large64: int64 = 0x123456789ABCDEF0'i64

    # Test truncation behavior
    var to32: int32 = cast[int32](large64)
    var to16: int16 = cast[int16](large64)
    var to8: int8 = cast[int8](large64)

    # Values should be truncated to lower bits
    doAssert to32 == cast[int32](0x9ABCDEF0'u32)
    doAssert to16 == cast[int16](0xDEF0'u16)
    doAssert to8 == cast[int8](0xF0'u8)

  block wideningConversions:
    var small8: int8 = -1
    var small16: int16 = -1
    var small32: int32 = -1

    # Sign extension should occur
    doAssert int16(small8) == -1'i16
    doAssert int32(small16) == -1'i32
    doAssert int64(small32) == -1'i64

  block unsignedConversions:
    var uval: uint32 = 0xFFFFFFFF'u32
    var sval: int32 = cast[int32](uval)
    doAssert sval == -1

    var negative: int32 = -1
    var as_unsigned: uint32 = cast[uint32](negative)
    doAssert as_unsigned == 0xFFFFFFFF'u32

block floating_point:
  # Basic float32 operations
  var f32a: float32 = 1.5
  var f32b: float32 = 2.5
  doAssert abs(float(f32a + f32b) - 4.0) < 1e-10
  doAssert abs(float(f32a * f32b) - 3.75) < 1e-10

  # Float64 operations
  var f64a: float64 = 1.5
  var f64b: float64 = 2.5
  doAssert abs((f64a + f64b) - 4.0) < 1e-10
  doAssert abs((f64a * f64b) - 3.75) < 1e-10

  # Special values
  var inf = Inf
  var ninf = -Inf
  var nan = NaN

  doAssert classify(inf) == fcInf
  doAssert classify(ninf) == fcNegInf
  doAssert classify(nan) == fcNaN

  # Operations with special values
  doAssert classify(inf + 1.0) == fcInf
  doAssert classify(inf * 2.0) == fcInf
  doAssert classify(nan + 1.0) == fcNaN

  # Precision tests
  var precision_test = 0.1 + 0.2
  # This is a well-known floating point precision issue
  doAssert abs(precision_test - 0.3) < 1e-15

block float_checks_tests:
  # Test NaN and Inf handling with different check settings
  when not usingNanChecks:
    # NaN checks disabled - operations with NaN should proceed and produce NaN
    var nan_result = NaN + 1.0
    doAssert classify(nan_result) == fcNaN

    var nan_mult = NaN * 2.0
    doAssert classify(nan_mult) == fcNaN

    var nan_div = 0.0 / 0.0
    doAssert classify(nan_div) == fcNaN

    when not usingFloatChecks:
      # All float checks disabled - should still produce correct NaN results
      var complex_nan = (NaN + 5.0) * 3.0
      doAssert classify(complex_nan) == fcNaN

  when not usingInfChecks:
    # Inf checks disabled - operations with Inf should proceed and produce Inf
    var inf_result = Inf * 2.0
    doAssert classify(inf_result) == fcInf

    var inf_add = Inf + 100.0
    doAssert classify(inf_add) == fcInf

    var neg_inf = -Inf
    doAssert classify(neg_inf) == fcNegInf

    var inf_from_div = 1.0 / 0.0
    doAssert classify(inf_from_div) == fcInf

    when not usingFloatChecks:
      # All float checks disabled - should still produce correct Inf results
      var complex_inf = (Inf + 10.0) / 2.0
      doAssert classify(complex_inf) == fcInf

  # Test NaN propagation in calculations
  when not usingNanChecks and not usingFloatChecks:
    var nan_prop = sqrt(-1.0)  # Should produce NaN
    doAssert classify(nan_prop) == fcNaN

    var nan_chain = nan_prop + 5.0 - 3.0 * 2.0
    doAssert classify(nan_chain) == fcNaN

  # Test Inf arithmetic
  when not usingInfChecks and not usingFloatChecks:
    var inf_minus_inf = Inf - Inf  # Should produce NaN
    doAssert classify(inf_minus_inf) == fcNaN

    var inf_div_inf = Inf / Inf    # Should produce NaN
    doAssert classify(inf_div_inf) == fcNaN

  # Basic float operations that should work regardless of check settings
  var safe_float = 3.14159
  doAssert safe_float > 3.0
  doAssert safe_float < 4.0

  # Test that normal arithmetic still works with checks disabled
  when not usingFloatChecks:
    var normal_calc = 2.5 * 4.0 + 1.5
    doAssert normal_calc == 11.5

block hash_functions:
  # Test hashing different integer types
  var i8val: int8 = 127
  var i16val: int16 = 32767
  var i32val: int32 = 2147483647
  var i64val: int64 = 9223372036854775807'i64

  # Just ensure they don't crash
  doAssert hash(i8val) is int
  doAssert hash(i16val) is int
  doAssert hash(i32val) is int
  doAssert hash(i64val) is int

  # Test hashing unsigned types
  var u8val: uint8 = 255
  var u16val: uint16 = 65535
  var u32val: uint32 = 4294967295'u32
  var u64val: uint64 = 18446744073709551615'u64

  doAssert hash(u8val) is int
  doAssert hash(u16val) is int
  doAssert hash(u32val) is int
  doAssert hash(u64val) is int

  # Test hashing floats
  var f32val: float32 = 3.14159
  var f64val: float64 = 3.14159265358979323846

  doAssert hash(f32val) is int
  doAssert hash(f64val) is int

  # Test that equal values hash the same
  var a: int64 = 1000
  var b: int64 = 1000
  doAssert hash(a) == hash(b)

block arithmetic_edge_cases:
  # Division edge cases
  var a: int = 100
  var b: int = 3
  doAssert a div b == 33
  doAssert a mod b == 1

  # Negative division
  var neg: int = -100
  doAssert neg div b == -33
  doAssert neg mod b == -1

  # Powers of 2
  var pow2: int = 1024
  doAssert pow2 div 2 == 512
  doAssert pow2 mod 2 == 0

  # Large number arithmetic
  when usingBigInts:
    var large1: int64 = 999999999999999999'i64
    var large2: int64 = 1'i64
    doAssert large1 + large2 == 1000000000000000000'i64

block comparison_operations:
  # Test all comparison operators
  var a: int = 100
  var b: int = 200
  var c: int = 100

  doAssert a < b
  doAssert b > a
  doAssert a <= b
  doAssert a <= c
  doAssert b >= a
  doAssert c >= a
  doAssert a == c
  doAssert a != b

  # Test with different sizes
  var small: int8 = 100
  var large: int64 = 100
  doAssert int64(small) == large

  # Unsigned comparisons
  var ua: uint32 = 4294967295'u32
  var ub: uint32 = 0'u32
  doAssert ua > ub
  doAssert ub < ua

block js_bigint_specific:
  when usingBigInts:
    # Test BigInt arithmetic that's specific to JS
    var bigint_val: int64 = 9007199254740992'i64 # Beyond JS Number.MAX_SAFE_INTEGER
    var result = bigint_val + 1'i64
    doAssert result == 9007199254740993'i64

    # Additional BigInt arithmetic tests from tbigint.nim
    var a: uint64 = 10000000000000'u64
    var b: uint64 = 20000000000000'u64

    let sum = a + b
    doAssert sum == 30000000000000'u64

    let diff = b - a
    doAssert diff == 10000000000000'u64

    let prod = a * 2'u64
    doAssert prod == 20000000000000'u64

    let quot = b div 2'u64
    doAssert quot == 10000000000000'u64

    let modulo = b mod a
    doAssert modulo == 0'u64

    # Test conversion of large uint64 to int
    var large: uint64 = 11160318154034397263'u64
    let converted {.used.}: int = int(large)
    # This should wrap around properly without throwing errors

    # Test shift operations with BigInt
    var shift_a: uint64 = 0x123456789ABCDEF0'u64

    let left_shifted = shift_a shl 4
    doAssert left_shifted == 0x23456789ABCDEF00'u64

    let right_shifted = shift_a shr 4
    doAssert right_shifted == 0x0123456789ABCDEF'u64

    # Test with int64
    var shift_b: int64 = 0x123456789ABCDEF0'i64
    let signed_shift = shift_b shr 4
    doAssert signed_shift == 0x0123456789ABCDEF'i64

    # Test bitwise operations with BigInt
    var bit_a: uint64 = 0x123456789ABCDEF0'u64
    var bit_b: uint64 = 0xFEDCBA9876543210'u64

    let and_result = bit_a and bit_b
    doAssert and_result == 0x1214121812141210'u64

    let or_result = bit_a or bit_b
    doAssert or_result == 0xFEFCFEF8FEFCFEF0'u64

    let xor_result = bit_a xor bit_b
    doAssert xor_result == 0xECE8ECE0ECE8ECE0'u64

    let not_result = not bit_a
    doAssert not_result == 0xEDCBA9876543210F'u64
