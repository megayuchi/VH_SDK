#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"
#include "sh_block_common.hlsl"
#include "sh_constant_buffer_shadow.hlsl"

Texture3D<uint>	texBlocks			: register(t0);

struct PS_OUT_TEX_ARRAY
{
	float4	Pos			:	SV_POSITION;     // Projection coord
	uint	RTIndex		:	SV_RenderTargetArrayIndex;
};

[maxvertexcount(36*MAX_CASCADE_NUM)]
void gsShadowCaster(point GS_INPUT_BLOCK input[1], inout TriangleStream<PS_OUT_TEX_ARRAY> TriStream)
{
	PS_OUT_TEX_ARRAY	output = (PS_OUT_TEX_ARRAY)0;

	//
	// input[0].Pos <- 0 base,  local ÁÂÇ¥
	//
	float half_block_size = BlockSize * 0.5;
	float3 SpaceSize = float3((float)BlockWidth*BlockSize, (float)BlockHeight*BlockSize, (float)BlockDepth*BlockSize);
	float3 rel_coord = input[0].Normal;
	int4 block_tex_coord = int4((int)(rel_coord.x * (float)BlockWidth), (int)(rel_coord.y * (float)BlockHeight), (int)(rel_coord.z * (float)BlockDepth), 0);
	
	//int			BlockWidth;
	//int			BlockHeight;
	//int			BlockDepth;
	//float		BlockSize;
	//float4		PosForBlock;
	//float4		MinPosForBlock;
	//int3		BlockTexStartPos;
	//int			Reserved1;

	block_tex_coord.xyz += BlockTexStartPos;

	uint packedColor = asuint(texBlocks.Load(block_tex_coord).r);

	float bw = (float)((packedColor & 0xff000000) >> 24) / 255.0;
	float g = (float)((packedColor & 0x00ff0000) >> 16) / 255.0;
	float r = (float)((packedColor & 0x0000ff00) >> 8) / 255.0;
	float b = (float)(packedColor & 0x000000ff) / 255.0;

	float4 BlockTexColor = float4(r, g, b, bw);
//	float4 BlockTexColor = texBlocks.Load(block_tex_coord);
	if (BlockTexColor.a < 0.0001)
		return;

	float4	WorldVertexPos = float4(input[0].Pos.xyz + PosForBlock.xyz, 1);

	uint		Index[36] =
	{
		// +z
		3,0,1,
		3,1,2,

		// -z
		4,7,6,
		4,6,5,

		// -x
		0,4,5,
		0,5,1,

		// +x
		7,3,2,
		7,2,6,

		// +y
		0,3,7,
		0,7,4,

		// -y
		2,1,5,
		2,5,6
	};
	
	float3	WorldPos[8];
	WorldPos[0] = WorldVertexPos.xyz + float3(-half_block_size, half_block_size, half_block_size);
	WorldPos[1] = WorldVertexPos.xyz + float3(-half_block_size, -half_block_size, half_block_size);
	WorldPos[2] = WorldVertexPos.xyz + float3(half_block_size, -half_block_size, half_block_size);
	WorldPos[3] = WorldVertexPos.xyz + float3(half_block_size, half_block_size, half_block_size);
	WorldPos[4] = WorldVertexPos.xyz + float3(-half_block_size, half_block_size, -half_block_size);
	WorldPos[5] = WorldVertexPos.xyz + float3(-half_block_size, -half_block_size, -half_block_size);
	WorldPos[6] = WorldVertexPos.xyz + float3(half_block_size, -half_block_size, -half_block_size);
	WorldPos[7] = WorldVertexPos.xyz + float3(half_block_size, half_block_size, -half_block_size);

	
	for (uint c = 0; c < MAX_CASCADE_NUM; c++)
	{
		uint	VertexIndex = 0;
		for (uint i = 0; i < 6; i++)
		{
			for (uint j = 0; j < 2; j++)
			{
				for (uint k = 0; k < 3; k++)
				{

					float4	PosWorld = float4(WorldPos[Index[VertexIndex]], 1);
					output.Pos = mul(PosWorld, g_ShadowCaster.matViewProjList[c]);
					output.RTIndex = c;
					TriStream.Append(output);
					VertexIndex++;
				}
				TriStream.RestartStrip();
			}
		}
	}
}
/*
void gsShadowCaster(triangle GS_INPUT input[3], inout TriangleStream<PS_OUT_TEX_ARRAY> TriStream)
{
	PS_OUT_TEX_ARRAY	output[3];
	for (uint i = 0; i < MAX_CASCADE_NUM; i++)
	{
		for (uint j = 0; j < 3; j++)
		{
			output[j].Pos = mul(input[j].Pos, matWorldViewProjList[i]);
			output[j].RTIndex = i;
			TriStream.Append(output[j]);
		}
		TriStream.RestartStrip();
	}
}
*/
