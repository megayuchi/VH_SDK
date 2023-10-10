#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_dynamic_common.hlsl"
#include "sh_a_buffer.hlsl"
#include "sh_block_common.hlsl"

RWTexture3D<uint> BlockedBuffer : register(u7); // W
//#define SHADER_PARAMETER_USE_OIT	1

//--------------------------------------------------------------------------------------
struct VS_INPUT_BBOARD
{
	float4  Pos         : POSITION;
	float2  TexCoord    : TEXCOORD0;
	uint    instId      : SV_InstanceID;
};

struct VS_OUTPUT_BBOARD
{
	float4  Pos         : SV_POSITION;
	float4  Color       : COLOR0;
	float4  NormalColor : COLOR1;
	float2  TexCoord    : TEXCOORD0;
	float4	PosWorld	: TRXCOORD1;
	float   Clip : SV_ClipDistance;
	uint    ArrayIndex  : BLENDINDICES;
};
struct GS_OUTPUT_BBOARD_VP : VS_OUTPUT_BBOARD
{
	uint VPIndex : SV_ViewportArrayIndex;
};

struct PS_INPUT_BBOARD : VS_OUTPUT_BBOARD
{
};

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------




VS_OUTPUT_BBOARD vsWriteToBlockBuffer(VS_INPUT_BBOARD input)
{
	VS_OUTPUT_BBOARD output = (VS_OUTPUT_BBOARD)0;

	float4	PosWorld = mul(input.Pos, g_TrCommon.matWorld);
	output.PosWorld = PosWorld;

	// 클립플레인처리
	output.Clip = dot(PosWorld, ClipPlane);
	
	// 노말
	output.NormalColor = 0;
	output.Color = MtlDiffuse + MtlAmbient;
	output.TexCoord = input.TexCoord;
	output.ArrayIndex = input.instId;
	return output;
}

[maxvertexcount(9)]
void gsWriteToBlockBuffer(triangle VS_OUTPUT_BBOARD input[3], inout TriangleStream<GS_OUTPUT_BBOARD_VP> TriStream)
{
	GS_OUTPUT_BBOARD_VP output = (GS_OUTPUT_BBOARD_VP)0;

	for (uint f = 0; f < 3; f++)
	{
		for (uint i = 0; i < 3; i++)
		{
			output.Pos = mul(input[i].PosWorld, matOrtho[f]);
			output.Color = input[i].Color;
			output.NormalColor = input[i].NormalColor;
			output.TexCoord = input[i].TexCoord;
			output.Clip = input[i].Clip;
			output.ArrayIndex = f;
			output.VPIndex = f;
			TriStream.Append(output);
		}
		TriStream.RestartStrip();
	}
}
PS_TARGET psWriteToBlockBuffer(PS_INPUT_BBOARD input)
{
	PS_TARGET output = (PS_TARGET)0;

	float4	outColor = 0;

	// for blocked mesh /////////////////////////////
	float3 SpaceSize = float3((float)BlockWidth*BlockSize, (float)BlockHeight*BlockSize, (float)BlockDepth* BlockSize);
	float3 local_pos = (input.PosWorld.xyz - PosForBlock.xyz - MinPosForBlock.xyz);
	float3 rel_coord = local_pos / SpaceSize.xyz;

	int3 coord = 0;
	switch (input.ArrayIndex)
	{
		case 0:	// XY
			coord = int3(input.Pos.x, BlockHeight - input.Pos.y, input.Pos.z * (float)BlockDepth);
			break;
		case 1:	// ZY
			coord = int3(input.Pos.z * (float)BlockWidth, input.Pos.y, input.Pos.x);
			break;
		case 2:	// XZ
			coord = uint3(input.Pos.x, input.Pos.z * (float)BlockHeight, input.Pos.y);
			//coord = int3(pos.x, BlockHeight - pos.y, 0);
			break;
	}

	if (coord.x < 0 || coord.x >= BlockWidth)
		discard;

	if (coord.y < 0 || coord.y >= BlockHeight)
		discard;

	if (coord.z < 0 || coord.z >= BlockDepth)
		discard;

	coord += BlockTexStartPos;

	
	float4 texColor = texDiffuse.Sample(samplerWrap, input.TexCoord);
	if (MtlAlphaMode)
	{
		const float3	bwConst = float3(0.3f, 0.59f, 0.11f);
		float	bwColor = dot(texColor.rgb, bwConst);
		if (bwColor < ALPHA_TEST_THRESHOLD_ADD)
			discard;
	}
	else
	{
		if (texColor.a < ALPHA_TEST_THRESHOLD_TRANSP)
			discard;
	}
	
	outColor = texColor * input.Color;

	// 가장 밝은 픽셀을 선택하기 위해 최상위 8비트에 밝기값을 배치한다. 민감한 green을 그 다음에 배치한다.
	float bw = outColor.r * 0.3 + outColor.g * 0.59 + outColor.b * 0.11;
	uint a = (uint)(saturate(bw) * 255.0);
	uint r = (uint)(saturate(outColor.r) * 255.0);
	uint g = (uint)(saturate(outColor.g) * 255.0);
	uint b = (uint)(saturate(outColor.b) * 255.0);

	uint packedColor = (a << 24) | (g << 16) | (r << 8) | b;
	uint oldColor;
	InterlockedMax(BlockedBuffer[coord], packedColor, oldColor);
	discard;

	return output;
}