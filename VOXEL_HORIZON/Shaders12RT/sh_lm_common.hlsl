//#define SHADER_PARAMETER_ATT_LIGHT	1
//#define SHADER_PARAMETER_USE_OIT 1

#include "sh_define.hlsl"
#include "shader_cpp_common.h"

Texture2D texDiffuse : register(t0);
Texture2D texNormal : register(t1);

SamplerState samplerWrap : register(s0);
SamplerState samplerClamp : register(s1);
SamplerState samplerBorder : register(s2);

//--------------------------------------------------------------------------------------
struct VS_INPUT_LM
{
	float4  Pos                 : POSITION;
	float3  Normal              : NORMAL;
	float3  Tangent             : TANGENT;
	float2  TexCoordDiffuse     : TEXCOORD0;
	uint    instId              : SV_InstanceID;
};

struct VS_OUTPUT_LM
{
	float4  Pos                 : SV_POSITION;
	float3  Normal				: NORMAL;
	float3  Tangent				: TANGENT;
	float4	Diffuse				: COLOR0;	// for meshlet Color
	float2  TexCoordDiffuse     : TEXCOORD0;
	float4  PosWorld            : TEXCOORD1;
	float   Dist				: TEXCOORD2;
	float   Clip				: SV_ClipDistance;
	uint    ArrayIndex          : BLENDINDICES;
#if (1 == VS_RTV_ARRAY)
	uint    RTVIndex            : SV_RenderTargetArrayIndex;
#endif
};