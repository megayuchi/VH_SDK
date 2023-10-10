#ifndef SH_BLOCK_BUFFER
#define SH_BLOCK_BUFFER

#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_block_common.hlsl"

#define MAX_SORT_NUM 10
#define INVALID_A_BUFFRE_OFFSET_VALUE 0x7fffffff // 01111111 11111111 11111111 11111111
#define A_BUFFRE_OFFSET_MASK 0x7fffffff // 01111111 11111111 11111111 11111111


RWTexture3D<float4> BlockBuffer : register(u0); // W

#define THREAD_NUM 1024

[numthreads(THREAD_NUM, 1, 1)]
void csClearBlockBuffer(uint3 groupID : SV_GroupID, uint3 dispatchThreadId : SV_DispatchThreadID)
{
	float4 Color = 0;

	uint CurIndex = dispatchThreadId.x;
	uint BlockWidthHeight = BlockWidth*BlockHeight;
	uint BlockWidthHeightDepth = BlockWidthHeight*BlockDepth;

	while (CurIndex < BlockWidthHeightDepth)
	{
		uint z = CurIndex / (BlockWidthHeight);
		uint xy = CurIndex % (BlockWidthHeight);
		uint y = xy / (BlockWidth);
		uint x = xy % (BlockWidth);

		uint3	CurPixel = uint3(x, y, z);	// ÇöÀç ÇÈ¼¿ÀÇ ÁÂÇ¥
		BlockBuffer[CurPixel] = Color;

		CurIndex += THREAD_NUM;
	}
}
#endif