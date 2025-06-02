#ifndef COMPUTE_SHADER_UTILS_HLSL
#define COMPUTE_SHADER_UTILS_HLSL

//https://stackoverflow.com/questions/53981196/is-it-possible-to-write-to-a-non-4-bytes-aligned-address-with-hlsl-compute-shade
void StoreByte(in RWByteAddressBuffer buffer,in uint byteOffset, in uint value) {
    // Calculate the address of the 4-byte-slot in which index_of_byte resides

    uint addrAlign4 = byteOffset&(~3);
    
    // Calculate which byte within the 4-byte-slot it is
    uint location = byteOffset % 4;

    // Shift bits to their proper location within its 4-byte-slot
    value = value << ((3 - location) * 8); // big endian??

    // Write value to buffer
    buffer.InterlockedOr(addrAlign4, value);
}

void StoreFloat(in RWByteAddressBuffer buffer,in uint byteOffset, in float value) {

    // Write value to buffer
    buffer.Store(byteOffset, asuint(value));
}

void StoreFloat2(in RWByteAddressBuffer buffer,in uint byteOffset, in float2 value) {

    // Write value to buffer
    buffer.Store2(byteOffset, asuint(value));
}

void StoreFloat3(in RWByteAddressBuffer buffer,in uint byteOffset, in float3 value) {

    // Write value to buffer
    buffer.Store3(byteOffset, asuint(value));
}

#endif