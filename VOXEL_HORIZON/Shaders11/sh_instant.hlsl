#include "sh_define.hlsl"
#include "sh_typedef.hlsl"


#ifdef STEREO_RENDER
#define VIEW_PROJ_ARRAY_COUNT 2
#else
#define VIEW_PROJ_ARRAY_COUNT 1
#endif

cbuffer ConstantBufferInstance : register(b0)
{
	matrix matViewInvCommon;
	matrix matWorldViewProjArray[VIEW_PROJ_ARRAY_COUNT];
	float QuadWidth;
	float QuadHeight;
	float Reserved0;
	float Reserved1;
	float4 WorldPos;
}

Texture2D texDiffuse : register(t0);
SamplerState samplerClampLinear : register(s0);


struct VS_OUTPUT
{
	float4  Position     : SV_Position; // vertex position 
	float4  cpPos        : TEXCOORD0;
	uint    ArrayIndex   : BLENDINDICES;
#if (1 == VS_RTV_ARRAY)
	uint    RTVIndex     : SV_RenderTargetArrayIndex;
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

static const float4 arrBasePos[4] =
{
	float4(-1.0, 1.0, 0.0, 0.0),
	float4(1.0, 1.0, 1.0, 0.0),
	float4(-1.0, -1.0, 0.0, 1.0),
	float4(1.0, -1.0, 1.0, 1.0),
};

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------

PS_INPUT vsQuad(uint VertexID : SV_VertexID, uint instId : SV_InstanceID)
{
	VS_OUTPUT output;

	uint   ArrayIndex = instId % 2;
	float2 width_height = float2(QuadWidth, QuadHeight);
	float4 camPos = mul(float4(0, 0, 0, 1), matViewInvCommon);

	float4 worldPos = mul(float4(arrBasePos[VertexID].xy * width_height, 0, 1), matViewInvCommon);
	worldPos.xyz -= camPos.xyz;
	worldPos.xyz += WorldPos.xyz;

	output.Position = mul(float4(worldPos.xyz, 1), matWorldViewProjArray[ArrayIndex]);
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


float4 psDefault(PS_INPUT input) : SV_Target
{
	//; c0 - focus_dist, scale0, scale1 ,0
	float4 diffuse = texDiffuse.Sample(samplerClampLinear, float2(input.cpPos.zw));
	return diffuse;
}