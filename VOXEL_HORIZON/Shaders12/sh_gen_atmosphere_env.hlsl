#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"
#include "sh_gen_noise_util.hlsl"

cbuffer CONSTANT_BUFFER_GEN_ATMOSPHERE_ENV : register(b0)
{
	uint2	Res;
	float2	ResRcp;

	matrix	matViewInvArray[6];
	DECOMP_PROJ	DecompProj;
	float4 lightDirection;
	float4 skyColorTop;
	float4 skyColorBottom;
}

struct VS_OUTPUT
{
	float4  Position    : SV_Position; // vertex position 
	float4  cpPos       : TEXCOORD0;
	uint    ArrayIndex  : BLENDINDICES;
};

struct GS_OUTPUT : VS_OUTPUT
{
	uint RTVIndex : SV_RenderTargetArrayIndex;
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


#define SUN_DIR float3(lightDirection.xyz)
//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------



float4 colorCubeMap(float3 endPos, const float3 d)
{
    // background sky     
	//float3 col = float3(0.6,0.71,0.85) - endPos.y*0.2*float3(1.0,0.5,1.0) + 0.15*0.5;
	float3 col = lerp(skyColorBottom, skyColorTop, saturate(1 - exp(8.5 - 17. * saturate(normalize(d).y * 0.5 + 0.5))));
	
	col += getSun(d, SUN_DIR, 350.0);

	return float4(col, 1.0);
}

VS_OUTPUT vsDefault(uint VertexID : SV_VertexID, uint instId : SV_InstanceID)
{
	VS_OUTPUT output;

	//output.Position = float4( arrBasePos[VertexID].xy, 0.0, 1.0);
	//output.cpPos = output.Position.xy;
	output.Position = float4(arrBasePos[VertexID].xy, 0.0, 1.0);
	output.cpPos = arrBasePos[VertexID];
	output.ArrayIndex = instId;
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
	int4	location = int4(input.Position.xy,input.ArrayIndex,0);
	float4 ray_view = float4(
		(((2.0f * (float)location.x) / (float)Res.x) - 1.0f) * DecompProj.rcp_m11,
		-(((2.0f * (float)location.y) / (float)Res.y) - 1.0f) * DecompProj.rcp_m22,
		1.0, 0.0);
	
	float4 ray_world = mul(ray_view, matViewInvArray[input.ArrayIndex]);
	//ray_world.xyz *= (1.0 / 100.0);
	ray_world.xyz = normalize(ray_world.xyz);
	float3 worldDir = ray_world.xyz;
	

	float3 startPos, endPos;
	float4 v = float4(0, 0, 0, 0);

	//compute background color
	float3 cubeMapEndPos;
	//intersectCubeMap(vec3(0.0, 0.0, 0.0), worldDir, stub, cubeMapEndPos);
	raySphereintersectionSkyMap(worldDir, 0.5, cubeMapEndPos);
	
	float4 bg = colorCubeMap(cubeMapEndPos, worldDir);
	float4	OutColor = float4(bg.rgb, 1);
	
	return OutColor;
}