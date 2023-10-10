#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"

cbuffer ConstantBufferPostEffect : register (b0)
{
	PROJ_CONSTANT	ProjConst;
	DECOMP_PROJ		DecompProj[2];
	float4			texCoordOffset9Sample[8];	// FOR 9 samples
	float4			texCoordOffset7Sample[6];	// FOR 7 samples
};

SamplerState	samplerClampLinear	: register(s0);
SamplerState	samplerClampPoint	: register(s1);



struct VS_OUTPUT
{
	float4 Position : SV_Position; // vertex position 
	float4 cpPos    : TEXCOORD0;
	uint ArrayIndex : BLENDINDICES;
#if (1 == VS_RTV_ARRAY)
	uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};
struct GS_OUTPUT : VS_OUTPUT
{
#if (1 != VS_RTV_ARRAY)
	uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};
struct PS_INPUT : VS_OUTPUT
{
};

static const float4 arrBasePos[4] = {
	float4(-1.0, 1.0, 0.0, 0.0),
	float4(1.0, 1.0, 1.0, 0.0),
	float4(-1.0, -1.0, 0.0, 1.0),
	float4(1.0, -1.0, 1.0, 1.0),
};

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------

VS_OUTPUT vsDefault(uint VertexID : SV_VertexID, uint instId : SV_InstanceID)
{
	VS_OUTPUT output;

	uint ArrayIndex = instId % 2;

	output.Position = float4(arrBasePos[VertexID].xy, 0.0, 1.0);
	output.cpPos = arrBasePos[VertexID];

	output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif
	return output;
}

[maxvertexcount(3)]
void gsDefault(triangle VS_OUTPUT input[3], inout TriangleStream<GS_OUTPUT> TriStream)
{
	GS_OUTPUT output[3];

	for (uint i = 0; i < 3; i++)
	{
		output[i].Position = input[i].Position;
		output[i].cpPos = input[i].cpPos;
		output[i].ArrayIndex = input[i].ArrayIndex;
		output[i].RTVIndex = input[i].ArrayIndex;
		TriStream.Append(output[i]);
	}
}