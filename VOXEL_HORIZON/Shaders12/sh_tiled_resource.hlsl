#ifndef SH_TILED_RESOURCE
#define SH_TILED_RESOURCE

#include "sh_define.hlsl"
#include "shader_cpp_common.h"

#define USE_SHARED_MEMORY_CACHE

#define THREAD_WIDTH_PER_GROUP 32
#define THREAD_HEIGHT_PER_GROUP 32


//0) 64*64 = 4096 / 8	 = 512 -> 128 in UINT
//1) 32*32 = 1024 / 8	 = 128 -> 32 in UINT
//2) 16*16 = 256 / 8	 = 32 -> 8 in UINT
//3) 8*8 = 64 / 8		 = 8 -> 1 in UINT
//4) 4*4 = 16 / 8 = 2 -> = 4 -> 1 in UINT
//5) 2*2 = 4 / 8 = 0 ->	 = 4 -> 1 in UINT
//6) 1*1 = 1 / 8 = 1 ->	 = 4 -> 1 in UINT
//7) 0*0 = 0 / 8 = 0 ->	 = 4 -> 1 in UINT , mip 7 >= 은 이쪽에 쓴다.
//----------------------------------------------
//				           696

#define BIT_TABLE_SIZE (512 + 128 + 32 + 8 + 4 + 4 + 4 + 4)
#define BIT_TABLE_UINT_COUNT (BIT_TABLE_SIZE / 4)

#define MAX_TILE_WIDTH 64   // Tiled Resource 에서 타일의 가로 최대 개수, 16384x16384일때 한 타일 사이즈는 256x256, 타일 개수는 64x64
#define MAX_TILE_HEIGHT 64  // Tiled Resource 에서 타일의 세로 최대 개수, 16384x16384일때 한 타일 사이즈는 256x256, 타일 개수는 64x64

#define MAX_TILED_RESOURCE_MIP_COUNT 16

// [TexID - 2 slots][Mip Level 8 slots][TileY 4 slots][TileX 4 slots] <- 가장 빠름
#define CACHE_SLOT_COUNT_TEX_ID 2
#define CACHE_SLOT_COUNT_MIP_LEVEL 8
#define CACHE_SLOT_COUNT_TILE_POS 4

// [TexID - 2 slots][Mip Level 2 slots][TileY 8 slots][TileX 8 slots]
//#define CACHE_SLOT_COUNT_TEX_ID 2
//#define CACHE_SLOT_COUNT_MIP_LEVEL 2
//#define CACHE_SLOT_COUNT_TILE_POS 8

// [TexID - 4 slots][Mip Level 4 slots][TileY 4 slots][TileX 4 slots]
//#define CACHE_SLOT_COUNT_TEX_ID 4
//#define CACHE_SLOT_COUNT_MIP_LEVEL 4
//#define CACHE_SLOT_COUNT_TILE_POS 4

#define GROUP_CACHE_UINT_COUNT (CACHE_SLOT_COUNT_TEX_ID * CACHE_SLOT_COUNT_MIP_LEVEL * CACHE_SLOT_COUNT_TILE_POS * CACHE_SLOT_COUNT_TILE_POS) 

//groupshared uint groupMemory[CACHE_SLOT_COUNT_TEX_ID][CACHE_SLOT_COUNT_MIP_LEVEL][CACHE_SLOT_COUNT_TILE_Y][CACHE_SLOT_COUNT_TILE_X];
#ifdef USE_SHARED_MEMORY_CACHE
groupshared uint groupMemory[GROUP_CACHE_UINT_COUNT];
#endif


struct INSPECT_MIP_DATA
{
    uint TileWidthHeight;
    uint Packed;
    uint BitTableOffset;
    uint TileOffset;
};
// 텍스처 해상도에 따른 INSPECT_MIP_DATA참조 테이블
struct MIP_DATA_LAYOUT
{
    uint BitTableSize;
    uint TileCount;
    uint TexWidthHeight;
    uint TileTexelSize;
    uint MipCount;
    uint Reserved0;
    uint Reserved1;
    uint Reserved2;
    INSPECT_MIP_DATA MipData[MAX_TILED_RESOURCE_MIP_COUNT]; // 0 - 7번 Mip까지 해상도와 bit table offset / tile offset
};
cbuffer CONSTANT_BUFFER_INSPECT_TILED_RESOURCE : register(b6)
{
    uint g_StrideOfTexID;       // 4bytes단위 Tiled texture의 bit table 오프셋. 실질적으로는 16384x16384해상도일때 bit table의 최대 사이즈
    uint g_MaxTiledResourceNum;
    uint2 g_SrcTexSize; // 실질적으로 화면 사이즈
    MIP_DATA_LAYOUT g_MipDataLayout[8]; // 해상도 유형별로 Mip Data layout 테이블
}

Texture2D<uint> TiledResourceBuffer : register(t0);
RWStructuredBuffer<uint> UAV_TiledResourceStatusData : register(u0); // RW

// group별 bit table
//groupshared uint groupMemory[BIT_TABLE_UINT_COUNT]; // BitTable Memory ( mip 0 - mip 7) + PageFault(uint)


void SetTilePosBitTableToSharedMemory(uint BaseOffset, uint index)
{
    /*
    //uint TexID_Offset = (TexID - 1) * g_StrideOfTexID;
    //uint BitTableOffset = g_MipDataLayout[LayoutType].MipData[MipLevel].BitTableOffset;
    
    uint dword_index = index >> 5;
    uint bit_index = index - (dword_index << 5);

    uint bit_mask = 1 << bit_index;

    uint old_value;
    InterlockedOr(groupMemory[BaseOffset + dword_index], bit_mask, old_value);
    */
}

void SetTilePosBitTableToUAV(uint BaseOffset, uint index)
{
    uint dword_index = index >> 5;
    uint bit_index = index - (dword_index << 5);

    uint bit_mask = 1 << bit_index;

    uint old_value;
    InterlockedOr(UAV_TiledResourceStatusData[BaseOffset + dword_index], bit_mask, old_value);
}

uint GetTilePosFromSharedMemory(uint BaseOffset, uint index)
{
    /*
    //uint TexID_Offset = (TexID - 1) * g_StrideOfTexID;
    //uint BitTableOffset = g_MipDataLayout[LayoutType].MipData[MipLevel].BitTableOffset;
    
    uint dword_index = index >> 5;
    uint bit_index = index - (dword_index << 5);

    uint bit_mask = 1 << bit_index;
    uint value = groupMemory[BaseOffset + dword_index] & bit_mask;
    value = value >> bit_index;

    return value;
    */
    return 0;
}

[numthreads(THREAD_WIDTH_PER_GROUP, THREAD_HEIGHT_PER_GROUP, 1)]
void csInspectTiledResourceStatus(uint3 GroupId : SV_GroupID,
	uint3 GroupThreadID : SV_GroupThreadID,
	uint3 DispatchThreadId : SV_DispatchThreadID,
	uint GroupIndex : SV_GroupIndex)
{
	// SV_GroupIndex - 그룹 안에서의 선형 인덱스
	// SV_DispatchThreadID - 그룹 안에서의 스레드 인덱스(x,y,z)
	// SV_GroupThreadID - 그룹 안에서의 스레드 인덱스
	// SV_GroupID - 그룹 x,y,z인덱스
    uint sx = DispatchThreadId.x;
    uint sy = DispatchThreadId.y;
    
#ifdef USE_SHARED_MEMORY_CACHE
    // Clear Shared Memory 
    uint IndexInGroup = GroupThreadID.x + GroupThreadID.y * (THREAD_WIDTH_PER_GROUP);
    while (IndexInGroup < GROUP_CACHE_UINT_COUNT)
    {
        groupMemory[IndexInGroup] = 0;
        IndexInGroup += (THREAD_WIDTH_PER_GROUP * THREAD_HEIGHT_PER_GROUP);
    }
    GroupMemoryBarrierWithGroupSync();
#endif    
    
    if (sx < g_SrcTexSize.x && sy < g_SrcTexSize.y)
    {
		// get integer pixel coordinates
		// u, v, array index, mip-level
        uint3 nCoords = uint3(sx, sy, 0);
        uint Prop = TiledResourceBuffer.Load(nCoords);
        // PageFault(1) | Mip Level(3) | Resered(1) | Layout Type(3) |  TexID(12) | TilePosY(6) | TilePosX(6)
        //     0/1      |      0-7     |     0/1    |      0-7       |   1-4095   |    0-63    |     0-63    |
  
        uint TexID = (Prop & 0x00FFF000) >> 12; // mask = 0b1111111111111000000000000        
        if (TexID)
        {
            uint PageFault = (Prop & 0x80000000) >> 31; 
            
            uint MipLevel = (Prop & 0x70000000) >> 28;  // 0 - 7
            uint LayoutType = (Prop & 0x07000000) >> 24; // 0 - 7 , layout 유형. texture크기, 타일 가로세로 개수 유형
                        
            uint TexID_Offset = (TexID - 1) * g_StrideOfTexID;
            uint BitTableOffset = TexID_Offset + g_MipDataLayout[LayoutType].MipData[MipLevel].BitTableOffset;
            uint2 TileWidthHeight = uint2(g_MipDataLayout[LayoutType].MipData[MipLevel].TileWidthHeight, g_MipDataLayout[LayoutType].MipData[MipLevel].TileWidthHeight);
        
            uint2 TilePos = uint2(Prop & 0x0000003F, (Prop & 0x00000FC0) >> 6);
            uint TileIndex = TilePos.x + TilePos.y * TileWidthHeight.x;
                        
#ifdef USE_SHARED_MEMORY_CACHE
            // cache에 기록하는 동시에 Cache기록된 이전 값을 확인, 현재 써넣고자 하는 값과 캐시의 이전 값이 같으면 스킵. 다르면 UAV에 업데이트
            //#define GROUP_CACHE_UINT_COUNT (CACHE_SLOT_COUNT_TEX_ID * CACHE_SLOT_COUNT_MIP_LEVEL * CACHE_SLOT_COUNT_TILE_Y * CACHE_SLOT_COUNT_TILE_X) 
            //groupshared uint groupMemory[CACHE_SLOT_COUNT_TEX_ID][CACHE_SLOT_COUNT_MIP_LEVEL][CACHE_SLOT_COUNT_TILE_Y][CACHE_SLOT_COUNT_TILE_X];
            //groupshared uint groupMemory[GROUP_CACHE_UINT_COUNT];
            uint cache_tex_id = TexID % CACHE_SLOT_COUNT_TEX_ID;            // TexID를 0-3 사이로 맵핑
            uint cache_mip_level = MipLevel % CACHE_SLOT_COUNT_MIP_LEVEL;   // MipLevel을 0-3 사이로 맵핑
            uint2 cache_tile_pos = TilePos.xy % CACHE_SLOT_COUNT_TILE_POS; // 타일 좌표x,y를 각각 0-3 사이로 맵핑       
            
            uint cache_index = cache_tile_pos.x + (cache_tile_pos.y * CACHE_SLOT_COUNT_TILE_POS) + (cache_mip_level * CACHE_SLOT_COUNT_TILE_POS * CACHE_SLOT_COUNT_TILE_POS) + (cache_tex_id * CACHE_SLOT_COUNT_MIP_LEVEL * CACHE_SLOT_COUNT_TILE_POS * CACHE_SLOT_COUNT_TILE_POS);
            
            uint CacheValue = Prop | 0x80000000; // cache사용할때 uint 4bytes항목에서 Page Fault는 무조건 0이나 1로 설정할것. cache초기값이 0이므로 0을 대입하면 기존에 이미 처리된 것으로 인식된다. 따라서 CacheValue의 PageFault플래그는 1로 설정한다.
            uint PrvCacheValue = 0;
            
            InterlockedExchange(groupMemory[cache_index], CacheValue, PrvCacheValue);
            if (PrvCacheValue != CacheValue)
            {
                // 새로 캐시에 저장한 값이 이전에 저장된 값과 다를 경우 UAV에 업데이트.
                SetTilePosBitTableToUAV(BitTableOffset, TileIndex);
                
                // 캐시 miss
                //uint PrvValue = 0;
                //InterlockedAdd(UAV_TiledResourceStatusData[1], 1, PrvValue);
            }
            else
            {
                // 캐시 hit
                //uint PrvValue = 0;
                //InterlockedAdd(UAV_TiledResourceStatusData[0], 1, PrvValue);
            }
#else
            // UAV에 바로 기록
            SetTilePosBitTableToUAV(BitTableOffset, TileIndex);
#endif
        }
    }
/*    
    if (DispatchThreadId.x == 0 && DispatchThreadId.y == 0)
    {

//struct MIP_DATA_LAYOUT
//{
//    uint BitTableSize;
//    uint TileCount;
//    uint TexWidthHeight;
//    uint TileTexelSize;
//    uint MipCount;
//    uint Reserved0;
//    uint Reserved1;
//    uint Reserved2;
//    INSPECT_MIP_DATA MipData[MAX_TILED_RESOURCE_MIP_COUNT]; // 0 - 7번 Mip까지 해상도와 bit table offset / tile offset
//}
        
//struct INSPECT_MIP_DATA
//{
//    uint TileWidthHeight;
//    uint Packed;
//    uint BitTableOffset;
//    uint TileOffset;
//};
        // constant buffer - layout 체크
        //uint MipDataLayoutOffset = 288 / 4;
        //for (uint i = 0; i < 8; i++)
        //{
        //    uint layout_base = i * MipDataLayoutOffset;
        //    UAV_TiledResourceStatusData[layout_base + 0] = g_MipDataLayout[i].BitTableSize;
        //    UAV_TiledResourceStatusData[layout_base + 1] = g_MipDataLayout[i].TileCount;
        //    UAV_TiledResourceStatusData[layout_base + 2] = g_MipDataLayout[i].TexWidthHeight;
        //    UAV_TiledResourceStatusData[layout_base + 3] = g_MipDataLayout[i].TileTexelSize;
        //    UAV_TiledResourceStatusData[layout_base + 4] = g_MipDataLayout[i].MipCount;
        //    UAV_TiledResourceStatusData[layout_base + 5] = 0;
        //    UAV_TiledResourceStatusData[layout_base + 6] = 0;
        //    UAV_TiledResourceStatusData[layout_base + 7] = 0;
        //    uint mip_data_base = layout_base + 8;
        //    for (uint j = 0; j < MAX_TILED_RESOURCE_MIP_COUNT; j++)
        //    {
        //        UAV_TiledResourceStatusData[mip_data_base + j * (16 / 4) + 0] = g_MipDataLayout[i].MipData[j].TileWidthHeight;
        //        UAV_TiledResourceStatusData[mip_data_base + j * (16 / 4) + 1] = g_MipDataLayout[i].MipData[j].Packed;
        //        UAV_TiledResourceStatusData[mip_data_base + j * (16 / 4) + 2] = g_MipDataLayout[i].MipData[j].BitTableOffset;
        //        UAV_TiledResourceStatusData[mip_data_base + j * (16 / 4) + 3] = g_MipDataLayout[i].MipData[j].TileOffset;
        //    }
        //}
        
        // constant buffer 체크
        //for (uint i = 0; i < g_MaxTiledResourceNum; i++)
        //{
        //    UAV_TiledResourceStatusData[i * g_StrideOfTexID + 0] = g_SrcTexSize.x;
        //    UAV_TiledResourceStatusData[i * g_StrideOfTexID + 1] = g_SrcTexSize.y;
        //}
            
        //UAV_TiledResourceStatusData[1 * g_StrideOfTexID] = g_StrideOfTexID;
        /*
        g_StrideOfTexID
        for (uint i = 0; i < BIT_TABLE_UINT_COUNT; i++)
        {
            UAV_TiledResourceStatusData[i] = groupMemory[i];
            
        }
        for (uint i = 0; i < 8; i++)
        {
            SetPageFaultPerMipToUAV(i, 1);
        }
    }
*/
}

#endif