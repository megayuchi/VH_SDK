#ifndef SH_MS_COMMON_HLSL
#define SH_MS_COMMON_HLSL

#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"

static float3 g_PalettedColor[16] =
{
    float3(1, 0, 0),
	float3(0, 1, 0),
	float3(0, 0, 1),
	float3(1, 1, 0),
	float3(0, 1, 1),
	float3(1, 0, 1),
	float3(0.5, 0, 0),
	float3(0, 0.5, 0),
	float3(0, 0, 0.5),
	float3(0.5, 0, 0.5),
	float3(0.5, 0.5, 0),
	float3(0, 0.5, 0.5),
	float3(0.5, 1, 0),
	float3(0, 0.5, 1),
	float3(1, 0.5, 0),
	float3(0, 1, 0.5)
};

struct MESHLET
{
    uint IndexedTriNum;
    uint IndexedTriStart;
    uint IndexedVertexNum;
    uint IndexedVertexStart;
    float4 Bounds; // render_typedef.h에서 BOUNDING_SPHERE
};

ByteAddressBuffer g_IndexedVertexBuffer : register(t5);
ByteAddressBuffer g_IndexedTriBuffer : register(t6);
StructuredBuffer<MESHLET> g_MeshletBuffer : register(t7);



//uint baseIndex = PrimitiveIndex() * g_TriangleIndexStride;
//uint3 indices = Load3x16BitIndices(baseIndex);

// Load three 16 bit indices.
static uint Load16BitIndexedVertex(uint offsetBytes)
{
	// ByteAdressBuffer loads must be aligned at a 4 byte boundary.
    const uint dwordAlignedOffset = offsetBytes & ~3;
	
    uint index = g_IndexedVertexBuffer.Load(dwordAlignedOffset);
	//           |  4 bytes  ||  4 bytes  ||  4 bytes  ||  4 bytes  |
	//			 |  0  |  1  ||  2  |  3  ||  4  |  5  ||  6  |  7  |
	// LOAD 0 - (index & 0x0000ffff)
	// LOAD 1 - (index & 0xffff0000) >> 16
	
	// Aligned:
    if (dwordAlignedOffset == offsetBytes)
    {
        index &= 0xffff;
    }
    else // Notaligned:
    {
        index = (index & 0xffff0000) >> 16;
    }
    return index;
}

// Load three 16 bit indices.
static uint3 Load3x16BitIndexTri(uint offsetBytes)
{
    uint3 indices;

	// ByteAdressBuffer loads must be aligned at a 4 byte boundary.
	// Since we need to read three 16 bit indices: { 0, 1, 2 } 
	// aligned at a 4 byte boundary as: { 0 1 } { 2 0 } { 1 2 } { 0 1 } ...
	// we will load 8 bytes (~ 4 indices { a b | c d }) to handle two possible index triplet layouts,
	// based on first index's offsetBytes being aligned at the 4 byte boundary or not:
	//  Aligned:     { 0 1 | 2 - }
	//  Not aligned: { - 0 | 1 2 }
    const uint dwordAlignedOffset = offsetBytes & ~3;
    const uint2 four16BitIndices = g_IndexedTriBuffer.Load2(dwordAlignedOffset);

	// Aligned: { 0 1 | 2 - } => retrieve first three 16bit indices
    if (dwordAlignedOffset == offsetBytes)
    {
        indices.x = four16BitIndices.x & 0xffff;
        indices.y = (four16BitIndices.x >> 16) & 0xffff;
        indices.z = four16BitIndices.y & 0xffff;
    }
    else // Notaligned: { - 0 | 1 2 } => retrieve last three 16bit indices
    {
        indices.x = (four16BitIndices.x >> 16) & 0xffff;
        indices.y = four16BitIndices.y & 0xffff;
        indices.z = (four16BitIndices.y >> 16) & 0xffff;
    }

    return indices;
}

// payload max = 16KB, uint 4096 units
// AS하나당 32개의 meshlet을 launch -> 32 x 4(index) = shared memory 128 Bytes
// 65536개의 meshlet을 처리하려면 65536/32 = 2049 AS group이 필요

struct Payload
{
    uint MeshletID[AS_GROUP_SIZE];
    uint InstanceID[AS_GROUP_SIZE];
};

//#define USE_SHARED_MEMORY
#define SHOW_MESHLET

#endif