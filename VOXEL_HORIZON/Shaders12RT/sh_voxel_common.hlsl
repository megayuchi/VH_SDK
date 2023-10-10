#ifndef SH_VOXEL_COMMON_HLSL
#define SH_VOXEL_COMMON_HLSL

#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_util.hlsl"

#define MIN_VOXEL_SIZE 50.0
#define MAX_VOXELS_PER_AXIS 8
#define VERTEX_COUNT_PER_PLANE		(3*2)	// triangle(3) * 2trinagls per plane(2)
#define VERTEX_COUNT_PER_VOXEL		(3*2*6)	// triangle(3) * 2trinagls per plane(2) * plane_count(6)
#define TEX_WIDTH_DEPTH_HEIGHT_PER_VOXEL_OBJECT (MAX_VOXELS_PER_AXIS*2)


cbuffer CONSTANT_BUFFER_VOXELBOX : register(b1)
{
    matrix g_matWorldVoxel;
    uint g_PackedProperty; // Reserved | Bulb On/Off | VoxelsPerAxis | MaterialPreset | VoxelObjIndex 
    float g_VoxelScale; // x = fVoxel Scale
	//uint2	VoxelsPerAxis_Size;		// x= Number of Voxels per axis, y = Size of Voxel
    uint g_Reserved0;
    uint g_Reserved1;
    uint4 g_Palette[(MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS) / 16];
};

struct VS_INPUT_VX
{
    uint PackedData : BLENDINDICES;
    uint instId : SV_InstanceID;
};

#define VOXEL_OBJ_INDEX_MASK		uint(0x000fffff)		//	               1111 1111 1111 1111 1111
#define MATERIAL_PRESET_MASK		uint(0x000000ff << 20)	//	0000 1111 1111 0000 0000 0000 0000 0000
#define VOXELS_PER_AXIS_POW_CONST	uint(0x00000003 << 28)	//	0011 0000 0000 0000 0000 0000 0000 0000
#define BULB_ON_MASK (1 << 30)								//  0100 0000 0000 0000 0000 0000 0000 0000

uint GetMtlPresetFromPackedProperty(uint PackedValue)
{
	// Reserved | Bulb On/Off | VoxelsPerAxis | MaterialPreset | VoxelObjIndex 
	//	1 bits |      1 bits |		  2 bits |	  	   8 bits |	      20 bits
	// 
    uint mtl_preset = (PackedValue & MATERIAL_PRESET_MASK) >> 20;
    return mtl_preset;
}
uint GetVoxelConstFromPackedProperty(out uint OutBulbOn, out float OutVoxelSize, out uint OutVoxelObjIndex, uint PackedValue)
{
	// Reserved | Bulb On/Off | VoxelsPerAxis | MaterialPreset | VoxelObjIndex 
	//	1 bits |      1 bits |		  2 bits |	  	   8 bits |	      20 bits
	// 
    OutVoxelObjIndex = PackedValue & VOXEL_OBJ_INDEX_MASK; // 0b11111111111111111111
    uint pow_const = (PackedValue & VOXELS_PER_AXIS_POW_CONST) >> 28; // 0b11	- 0, 1, 2, 3
    uint voxels_per_axis = exp2(pow_const); // 1 , 2, 4, 8
    OutVoxelSize = (MIN_VOXEL_SIZE * MAX_VOXELS_PER_AXIS) / (float)voxels_per_axis; // 400 , 200, 100, 50
    OutBulbOn = (PackedValue & BULB_ON_MASK) != 0;

    return voxels_per_axis;
}

#define X_MASK 3			// 00000011
#define POSITIVE_X_MASK 1	// 00000001
#define NEGATIVE_X_MASK 2	// 00000010

#define Y_MASK 12			// 00001100
#define POSITIVE_Y_MASK 4	// 00000100
#define NEGATIVE_Y_MASK 8	// 00001000


#define Z_MASK 48			// 00110000
#define POSITIVE_Z_MASK 16	// 00010000
#define NEGATIVE_Z_MASK 32	// 00100000

uint ConvertFloatNormalToByteNormal(float3 normal)
{
    uint value = 0;

	// Set X
    if (normal.x > 0.95f && normal.x < 1.05f)
    {
        value |= POSITIVE_X_MASK;
    }
    else if (normal.x < -0.95f && normal.x > -1.05f)
    {
        value |= NEGATIVE_X_MASK;
    }

	// Set Y
    if (normal.y > 0.95f && normal.y < 1.05f)
    {
        value |= POSITIVE_Y_MASK;
    }
    else if (normal.y < -0.95f && normal.y > -1.05f)
    {
        value |= NEGATIVE_Y_MASK;
    }
	// Set Z
    if (normal.z > 0.95f && normal.z < 1.05f)
    {
        value |= POSITIVE_Z_MASK;
    }
    else if (normal.z < -0.95f && normal.z > -1.05f)
    {
        value |= NEGATIVE_Z_MASK;
    }
    return value;
}
float3 ConvertByteNormalToFloatNormal(uint value)
{
    float3 normal = float3(0, 0, 0);

	// Get X
    if (value & POSITIVE_X_MASK)
    {
        normal.x = 1.0f;
    }
    else if (value & NEGATIVE_X_MASK)
    {
        normal.x = -1.0f;
    }

	// Get Y
    if (value & POSITIVE_Y_MASK)
    {
        normal.y = 1.0f;
    }
    else if (value & NEGATIVE_Y_MASK)
    {
        normal.y = -1.0f;
    }

	// Get Z
    if (value & POSITIVE_Z_MASK)
    {
        normal.z = 1.0f;
    }
    else if (value & NEGATIVE_Z_MASK)
    {
        normal.z = -1.0f;
    }
    return normal;
}

float3 ConvertByteNormalToFloatNormalAndAxis(out uint axis, uint value)
{
    float3 normal = float3(0, 0, 0);

	// Get X
    if (value & POSITIVE_X_MASK)
    {
        axis = 0;
        normal.x = 1.0f;
    }
    else if (value & NEGATIVE_X_MASK)
    {
        axis = 1;
        normal.x = -1.0f;
    }

	// Get Y
    if (value & POSITIVE_Y_MASK)
    {
        axis = 2;
        normal.y = 1.0f;
    }
    else if (value & NEGATIVE_Y_MASK)
    {
        axis = 3;
        normal.y = -1.0f;
    }

	// Get Z
    if (value & POSITIVE_Z_MASK)
    {
        axis = 4;
        normal.z = 1.0f;
    }
    else if (value & NEGATIVE_Z_MASK)
    {
        axis = 5;
        normal.z = -1.0f;
    }
    return normal;
}

void ConvertAxisIndexToFloatNormal(out float3 Normal, uint axis_index)
{
    Normal = float3(0, 0, 0);
    switch (axis_index)
    {
        case 0:
            Normal.x = 1.0f;
            break;
        case 1:
            Normal.x = -1.0f;
            break;
        case 2:
            Normal.y = 1.0f;
            break;
        case 3:
            Normal.y = -1.0f;
            break;
        case 4:
            Normal.z = 1.0f;
            break;
        case 5:
            Normal.z = -1.0f;
            break;
    }
}
void ConvertAxisIndexToFloatNormalAndTangent(out float3 Normal, out float3 Tangent, uint axis_index)
{
    Normal = float3(0, 0, 0);
    Tangent = float3(0, 0, 0);
    switch (axis_index)
    {
        case 0:
            Normal.x = 1;
            Tangent.z = 1;
            break;
        case 1:
            Normal.x = -1;
            Tangent.z = -1;
            break;
        case 2:
            Normal.y = 1;
            Tangent.x = 1;
            break;
        case 3:
            Normal.y = -1;
            Tangent.x = -1;
            break;
        case 4:
            Normal.z = 1;
            Tangent.x = -1;
            break;
        case 5:
            Normal.z = -1;
            Tangent.x = 1;
            break;
    }
}
uint GetPaletteIndex(int3 pos)
{
    uint cb_BulbOn = 0;
    float cb_VoxelSize = 0;
    uint cb_VoxelObjIndex = 0;
    uint cb_VoxelsPerAxis = 0;
    cb_VoxelsPerAxis = GetVoxelConstFromPackedProperty(cb_BulbOn, cb_VoxelSize, cb_VoxelObjIndex, g_PackedProperty);

	// uint	g_PackedProperty;			// Reserved | Bulb On/Off | VoxelsPerAxis | MaterialPreset | VoxelObjIndex 
	// uint2	VoxelsPerAxis_Size;		// x= Number of Voxels per axis, y = Size of Voxel

    uint byte_index = pos.x + pos.z * cb_VoxelsPerAxis + pos.y * cb_VoxelsPerAxis * cb_VoxelsPerAxis;

	// | 00 | 01 | 02 | 03 | 04 | 05 | 06 | 07 | 08 | 09 | 10 | 11 | 12 | 13 | 14 | 15 |

	// byte_index = 5
	// qdword_index = byte_index / 16; ->	5 / 16 = 0;
	// byte_index_in_128 = byte_index - (qdword_index*16); -> 5 - 0 = 5
	// dword_index = byte_index_in_128 / 4; -> 5 /4 = 1
	// byte_index_in_dword = byte_index_in_128 - dword_index*4; -> 1

	// dword value = | 04 | 05 | 06 | 07 |
	// byte_value = (dword_value & (0x000000ff << byte_index_in_dword)) >> byte_index_in_dword; -> 5

    uint qdword_index = byte_index / 16;
    uint byte_index_in_128 = byte_index - (qdword_index * 16);
    uint dword_index = byte_index_in_128 / 4;
    uint byte_index_in_dword = byte_index_in_128 - dword_index * 4;

    uint palette_value[4] =
    {
        g_Palette[qdword_index].x,
		g_Palette[qdword_index].y,
		g_Palette[qdword_index].z,
		g_Palette[qdword_index].w
    };
    uint dword_value = palette_value[dword_index];
    uint shift = byte_index_in_dword * 8;
    uint value = (dword_value & ((uint)0x000000ff << shift)) >> shift;
    return value;
}
uint3 GetPosInObject(uint PackedData)
{
	//*pOutX = PackedData & 0b111;				//	000 000	111
	//*pOutY = (PackedData & 0b111000) >> 3;		//	000	111 000
	//*pOutZ = (PackedData & 0b111000000) >> 6;	//	111 000 000
    uint3 Pos;
    Pos.x = PackedData & 0x7; //	000 000	111
    Pos.y = (PackedData & 0x38) >> 3; //	000	111 000
    Pos.z = (PackedData & 0x1C0) >> 6; //	111 000 000
    return Pos;
}

uint3 GetPosInVoxel(uint PackedData)
{
	//*pOutX = (PackedData & 0b001000000000) >> 9;	//	001 000 000 000
	//*pOutY = (PackedData & 0b010000000000) >> 10;	//  010 000 000 000
	//*pOutZ = (PackedData & 0b100000000000) >> 11;	//	100 000 000 000

    uint3 Pos;
    Pos.x = (PackedData & 0x200) >> 9; //	001 000 000 000
    Pos.y = (PackedData & 0x400) >> 10; //  010 000 000 000
    Pos.z = (PackedData & 0x800) >> 11; //	100 000 000 000

    return Pos;
}

float3 GetNormal(out uint AxisIndex, uint PackedData)
{
	//DWORD	AxisIndex = (PackedData & 0b111000000000000) >> 12;
    AxisIndex = (PackedData & 0x7000) >> 12; // 111000000000000

    float3 Normal;
    ConvertAxisIndexToFloatNormal(Normal, AxisIndex);

    return Normal;
}

float3 GetNormalAndTangent(out float3 Tangent, out uint AxisIndex, uint PackedData)
{
	//DWORD	AxisIndex = (PackedData & 0b111000000000000) >> 12;
    AxisIndex = (PackedData & 0x7000) >> 12; // 111000000000000

    float3 Normal;
    ConvertAxisIndexToFloatNormalAndTangent(Normal, Tangent, AxisIndex);

    return Normal;
}
uint GetQuadIndex(uint PackedData)
{
	//DWORD QuadIndex = (PackedData & 0b1111111111000000000000000) >> 15;
    uint QuadIndex = (PackedData & 0x1FF8000) >> 15; // 1111111111000000000000000
    return QuadIndex;
}
float2 GetPosInQuad(uint PackedData)
{
	//*pOutU = (PackedData & 0b010000000000000000000000000) >> 25;
	//*pOutV = (PackedData & 0b100000000000000000000000000) >> 26;
    float2 Pos;
    Pos.x = (PackedData & 0x2000000) >> 25; // 010000000000000000000000000
    Pos.y = (PackedData & 0x4000000) >> 26; // 100000000000000000000000000
    return Pos;
}
uint GetPosBitsInQuad(uint PackedData)
{
    uint Bits = (PackedData & 0x6000000) >> 25; // 110000000000000000000000000
    return Bits;
}
float3 GetPosition(out uint3 oPos, out uint3 vPos, uint PackedData, float VoxelSize)
{
    float3 ObjMinPos =
    {
		MIN_VOXEL_SIZE * MAX_VOXELS_PER_AXIS * -0.5,
		MIN_VOXEL_SIZE * MAX_VOXELS_PER_AXIS * -0.5,
		MIN_VOXEL_SIZE * MAX_VOXELS_PER_AXIS * -0.5
    };

    oPos = GetPosInObject(PackedData);
    vPos = GetPosInVoxel(PackedData);

    float3 Pos = ObjMinPos + (float3)(oPos + vPos) * VoxelSize;
	//Pos.x = ObjMinPos.x + (float)(oPos.x + vPos.x) * VoxelSize;
	//Pos.y = ObjMinPos.y + (float)(oPos.y + vPos.y) * VoxelSize;
	//Pos.z = ObjMinPos.z + (float)(oPos.z + vPos.z) * VoxelSize;

    return Pos;
}
float3 GetVoxelCenterPosition(uint3 oPos, float VoxelSize, float VoxelSizeHalf)
{
    float3 ObjMinPos =
    {
		MIN_VOXEL_SIZE * MAX_VOXELS_PER_AXIS * -0.5,
		MIN_VOXEL_SIZE * MAX_VOXELS_PER_AXIS * -0.5,
		MIN_VOXEL_SIZE * MAX_VOXELS_PER_AXIS * -0.5
    };
    float3 Pos = ObjMinPos + (float3)oPos * VoxelSize + float3(VoxelSizeHalf, VoxelSizeHalf, VoxelSizeHalf);
	//float3 Pos = 
	//Pos.x = ObjMinPos.x + (float)oPos.x * VoxelSize + VoxelSizeHalf;
	//Pos.y = ObjMinPos.y + (float)oPos.y * VoxelSize + VoxelSizeHalf;
	//Pos.z = ObjMinPos.z + (float)oPos.z * VoxelSize + VoxelSizeHalf;

    return Pos;
}
float2 GetVoxelPaletteTexCoord(uint PaletteIndex, uint AxisIndex, uint3 oPos, uint3 vPos, uint WidthDepthHeight)
{
    float2 TexCoord = 0;

	// 타일 한칸 크기 64x64
    float TILE_WIDTH_HEIGHT = 64;

	// 팔레트에서 타일 개수 - 가로 : 16칸, 세로 16칸
    float TILE_WIDTH_COUNT = 16;
    float TILE_HEIGHT_COUNT = 16;

	// 타일 팔레트 텍스처 전체크기 1024x256
    float TILE_PALETTE_TEX_WIDTH = TILE_WIDTH_HEIGHT * TILE_WIDTH_COUNT;
    float TILE_PALETTE_TEX_HEIGHT = TILE_WIDTH_HEIGHT * TILE_HEIGHT_COUNT;

    float tex_adj_u = 0.5 / TILE_PALETTE_TEX_WIDTH;
    float tex_adj_v = 0.5 / TILE_PALETTE_TEX_HEIGHT;

    int tile_y = PaletteIndex / TILE_WIDTH_COUNT;
    int tile_x = PaletteIndex % TILE_WIDTH_COUNT;
    int px = tile_x * TILE_WIDTH_HEIGHT;
    int py = tile_y * TILE_WIDTH_HEIGHT;

    float pixels_per_voxel = TILE_WIDTH_HEIGHT / WidthDepthHeight; // 각 축에 대한 복셀 한칸당 텍스처의 픽셀수
	
    switch (AxisIndex)
    {
        case 0:
        case 1:
			//Normal.x = 1.0f || Normal.x = -1.0f;
            px += (oPos.z + vPos.z) * pixels_per_voxel;
            py += (oPos.y + vPos.y) * pixels_per_voxel;
            break;
        case 2:
        case 3:
			//Normal.y = 1.0f || Normal.y = -1.0f;
            px += (oPos.x + vPos.x) * pixels_per_voxel;
            py += (oPos.z + vPos.z) * pixels_per_voxel;
            break;
        case 4:
        case 5:
			//Normal.z = 1.0f || Normal.z = -1.0f;
            px += (oPos.x + vPos.x) * pixels_per_voxel;
            py += (oPos.y + vPos.y) * pixels_per_voxel;
            break;
    }
	
	//TexCoord.x = (px / TILE_PALETTE_TEX_WIDTH);
	//TexCoord.y = (py / TILE_PALETTE_TEX_HEIGHT);
    TexCoord.x = ((px + tex_adj_u) / TILE_PALETTE_TEX_WIDTH);
    TexCoord.y = ((py + tex_adj_v) / TILE_PALETTE_TEX_HEIGHT);
	
    return TexCoord;
}
float2 GetVoxelPaletteTexCoordN(uint PaletteIndex, float3 NormalWorld, uint3 oPos, uint3 vPos, uint WidthDepthHeight)
{
    float2 TexCoord = 0;

	// 타일 한칸 크기 32x32
    float TILE_WIDTH_HEIGHT = 32;

	// 팔레트에서 타일 개수 - 가로 : 32칸, 세로 8칸
    float TILE_WIDTH_COUNT = 32;
    float TILE_HEIGHT_COUNT = 8;

	// 타일 팔레트 텍스처 전체크기 1024x256
    float TILE_PALETTE_TEX_WIDTH = TILE_WIDTH_HEIGHT * TILE_WIDTH_COUNT;
    float TILE_PALETTE_TEX_HEIGHT = TILE_WIDTH_HEIGHT * TILE_HEIGHT_COUNT;

    float tex_adj_u = 0.5 / TILE_PALETTE_TEX_WIDTH;
    float tex_adj_v = 0.5 / TILE_PALETTE_TEX_HEIGHT;

    int tile_y = PaletteIndex / TILE_WIDTH_COUNT;
    int tile_x = PaletteIndex % TILE_WIDTH_COUNT;
    int px = tile_x * TILE_WIDTH_HEIGHT;
    int py = tile_y * TILE_WIDTH_HEIGHT;

    float pixels_per_voxel = TILE_WIDTH_HEIGHT / WidthDepthHeight; // 각 축에 대한 복셀 한칸당 텍스처의 픽셀수

    if (NormalWorld.x > 0.5 || NormalWorld.x < -0.5)
    {
		// N = (1,0,0), (-1,0,0)
        px += (oPos.z + vPos.z) * pixels_per_voxel;
        py += (oPos.y + vPos.y) * pixels_per_voxel;
    }
    if (NormalWorld.y > 0.5 || NormalWorld.y < -0.5)
    {
		// N = (0,1,0), (0,-1,0)
        px += (oPos.x + vPos.x) * pixels_per_voxel;
        py += (oPos.z + vPos.z) * pixels_per_voxel;
    }
    else if (NormalWorld.z > 0.5 || NormalWorld.z < -0.5)
    {
		// N = (0,0,1), (0,0,-1)
        px += (oPos.x + vPos.x) * pixels_per_voxel;
        py += (oPos.y + vPos.y) * pixels_per_voxel;
    }
    TexCoord.x = (px / TILE_PALETTE_TEX_WIDTH); // +tex_adj_u;
    TexCoord.y = (py / TILE_PALETTE_TEX_HEIGHT); // +tex_adj_v;

    return TexCoord;
}


#endif