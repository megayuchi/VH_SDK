#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"

TextureCube texEnv : register(t0);

SamplerState	samplerClampLinear	: register(s0);

cbuffer CONSTANT_BUFFER_SCREEN_SPACE : register(b0)
{
	uint2	Res;
	float2	ResRcp;
	matrix	matViewInvArray[2];
	DECOMP_PROJ	DecompProj[2];
}

struct VS_OUTPUT
{
	float4  Position    : SV_Position; // vertex position 
	float4  cpPos       : TEXCOORD0;
	uint    ArrayIndex  : BLENDINDICES;
#if (1 == VS_RTV_ARRAY)
	uint    RTVIndex : SV_RenderTargetArrayIndex;
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



VS_OUTPUT vsDefault(uint VertexID : SV_VertexID, uint instId : SV_InstanceID)
{
	VS_OUTPUT output;

	//output.Position = float4( arrBasePos[VertexID].xy, 0.0, 1.0);
	//output.cpPos = output.Position.xy;
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


float4 psDefault(PS_INPUT input) : SV_Target
{
	//; c0 - focus_dist, scale0, scale1 ,0
#ifdef  STEREO_RENDER
	int4	location = int4(input.Position.xy,input.ArrayIndex,0);
#else
	int3	location = int3(input.Position.xy,0);
#endif

	//input.ArrayIndex
	float4 ray_view = float4(
		(((2.0f * (float)location.x) / (float)Res.x) - 1.0f) * DecompProj[input.ArrayIndex].rcp_m11,
		-(((2.0f * (float)location.y) / (float)Res.y) - 1.0f) * DecompProj[input.ArrayIndex].rcp_m22,
		1.0, 0.0);
	
	float4 ray_world = mul(ray_view, matViewInvArray[input.ArrayIndex]);
	float3 worldDir = normalize(ray_world.xyz);
	
	float4 envColor = texEnv.SampleLevel(samplerClampLinear, (float3)worldDir, 0);

	
	return envColor;
}