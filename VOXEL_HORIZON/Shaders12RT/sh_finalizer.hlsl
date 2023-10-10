#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"


cbuffer ConstantBufferFinal : register (b0)
{
	PROJ_CONSTANT	ProjConst;
	DECOMP_PROJ		DecompProj[2];
	float4			GenericConst;
};
#ifdef STEREO_RENDER
Texture2DArray	texPrimary	: register(t0);
Texture2DArray	texDepth	: register(t1);
Texture2DArray	texOutLine	: register(t2);
Texture2DArray	texBlur		: register(t3);
Texture2DArray	texGlow		: register(t4);
Texture2D		texNormal	: register(t5);
#else
Texture2D		texPrimary		: register(t0);
Texture2D		texDepth		: register(t1);
Texture2D		texOutLine		: register(t2);
Texture2D		texBlur			: register(t3);
Texture2D		texGlow			: register(t4);
Texture2D		texNormal		: register(t5);
#endif

SamplerState	samplerClampLinear	: register(s0);
SamplerState	samplerClampPoint	: register(s1);



struct VS_OUTPUT
{
	float4  Position    : SV_Position; // vertex position 
	float4  cpPos       : TEXCOORD0;
	uint    ArrayIndex  : BLENDINDICES;
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

float4 psFinalOutLine(PS_INPUT input) : SV_Target
{
#ifdef STEREO_RENDER
	int4	location = int4(input.Position.xy, input.ArrayIndex, 0);
#else
	int3	location = int3(input.Position.xy,0);
#endif

	// 원본 백버퍼 
	float4	PrimaryTexColor = texPrimary.Load(location);

	// 아웃라인
	float4	OutLineTexColor = texOutLine.Load(location);

	/*
	float4	DepthAndID = texDepthAndID.Sample(samplerClamp,input.TexCoord);	// 원본의 뎁스
	float	OutLineDepth = OutLineTexColor.g;		// 아웃라인의 뎁스

	if (DepthAndID.r < OutLineDepth)
	{
		OutLineTexColor.r = 1.0f;
	}
	*/
	//	float4	outColor = float4(DepthAndID.rrr,1);
	//float4	outColor = float4(Depth,Depth,Depth,1);

	float4	outColor = PrimaryTexColor*OutLineTexColor.r;
	outColor.a = 1.0f;



	return outColor;
}
float4 psFinalGlow(PS_INPUT input) : SV_Target
{
	//; c0 - focus_dist, scale0, scale1 ,0

#ifdef STEREO_RENDER
	int4	location = int4(input.Position.xy, input.ArrayIndex, 0);
	float3	texCoord = float3(input.cpPos.zw, input.ArrayIndex);
#else
	int3	location = int3(input.Position.xy,0);
	float2	texCoord = float2(input.cpPos.zw);
#endif

	// 원본 백버퍼 
	float4	PrimaryTexColor = texPrimary.Load(location);

	// glow 텍스쳐
	float4	GlowTexColor = texGlow.Sample(samplerClampLinear, texCoord);

	float4	OutColor = float4(PrimaryTexColor.rgb + GlowTexColor.rgb,PrimaryTexColor.a);

	return OutColor;
}

float4 psFinalGlowOutLine(PS_INPUT input) : SV_Target
{
	//; c0 - focus_dist, scale0, scale1 ,0

#ifdef STEREO_RENDER
	int4	location = int4(input.Position.xy, input.ArrayIndex, 0);
	float3	texCoord = float3(input.cpPos.zw, input.ArrayIndex);
#else
	int3	location = int3(input.Position.xy,0);
	float2	texCoord = float2(input.cpPos.zw);
#endif

	// 원본 백버퍼 
	float4	PrimaryTexColor = texPrimary.Load(location);

	// 아웃라인
	float4	OutLineTexColor = texOutLine.Load(location);

	// glow 텍스쳐
	float4	GlowTexColor = texGlow.Sample(samplerClampLinear, texCoord);

	// 원본 텍셀에 아웃라인 적용
	PrimaryTexColor *= OutLineTexColor.r;

	float4	OutColor = float4(PrimaryTexColor.rgb + GlowTexColor.rgb,PrimaryTexColor.a);

	return OutColor;
}

float4 psFinalGlowDof(PS_INPUT input) : SV_Target
{
	//; c0 - focus_dist, scale0, scale1 ,0

#ifdef STEREO_RENDER
	int4	location = int4(input.Position.xy, input.ArrayIndex, 0);
	float3	texCoord = float3(input.cpPos.zw, input.ArrayIndex);
#else
	int3	location = int3(input.Position.xy,0);
	float2	texCoord = float2(input.cpPos.zw);
#endif

	// 원본 백버퍼 
	float4	PrimaryTexColor = texPrimary.Load(location);

	// 깊이
	float	Depth = texDepth.Load(location).r;			// depth
	float	Dist = DecompProj[input.ArrayIndex].m43 / (Depth - DecompProj[input.ArrayIndex].m33);

	float	LinearDepth = Dist * ProjConst.fFarRcp;	// NormalCenter = normal.xyz | Dist(0-1)

	// 블러링된 텍스쳐
	float4	BlurTexColor = texBlur.Sample(samplerClampLinear, texCoord);

	// glow 텍스쳐
	float4	GlowTexColor = texGlow.Sample(samplerClampLinear, texCoord);

	// 노말, 구름은 노말값이 0, 구름에 DOF를 적용하지 않기위해 노말값을 사용한다.
	float3 Normal = (float3)texNormal.Load(location);
	float NormalLen = length(Normal);

	float DepthDiff = LinearDepth - GenericConst.x;

	DepthDiff *= GenericConst.y;	// apply major scale
	DepthDiff *= DepthDiff;			// 제곱
	DepthDiff = saturate(DepthDiff * GenericConst.z);	// apply minor scale

	DepthDiff *= NormalLen;		// 구름에 DOF를 적용하지 않기위해 노말값을 사용한다.
	//DepthDiff = 0.0f;

	float4	OutColor = float4(lerp(PrimaryTexColor.rgb, BlurTexColor.rgb, DepthDiff) + GlowTexColor.rgb, PrimaryTexColor.a);

	return OutColor;
}

float4 psFinalOutLineDof(PS_INPUT input) : SV_Target
{
	//; c0 - focus_dist, scale0, scale1 ,0

#ifdef STEREO_RENDER
	int4	location = int4(input.Position.xy, input.ArrayIndex, 0);
	float3	texCoord = float3(input.cpPos.zw, input.ArrayIndex);
#else
	int3	location = int3(input.Position.xy,0);
	float2	texCoord = float2(input.cpPos.zw);
#endif

	// 원본 백버퍼 
	float4	PrimaryTexColor = texPrimary.Load(location);

	// 아웃라인
	float4	OutLineTexColor = texOutLine.Load(location);

	// 깊이
	float	Depth = texDepth.Load(location).r;			// depth
	float	Dist = DecompProj[input.ArrayIndex].m43 / (Depth - DecompProj[input.ArrayIndex].m33);
	float	LinearDepth = Dist * ProjConst.fFarRcp;	// NormalCenter = normal.xyz | Dist(0-1)

	// 블러링된 텍스쳐
	float4	BlurTexColor = texBlur.Sample(samplerClampLinear,texCoord);

	// 노말, 구름은 노말값이 0, 구름에 DOF를 적용하지 않기위해 노말값을 사용한다.
	float3 Normal = (float3)texNormal.Load(location);
	float NormalLen = length(Normal);
	
	// 원본 텍셀에 아웃라인 적용
	PrimaryTexColor *= OutLineTexColor.r;

	float DepthDiff = LinearDepth - GenericConst.x;

	DepthDiff *= GenericConst.y;	// apply major scale
	DepthDiff *= DepthDiff;			// 제곱
	DepthDiff = saturate(DepthDiff * GenericConst.z);	// apply minor scale

	DepthDiff *= NormalLen;		// 구름에 DOF를 적용하지 않기위해 노말값을 사용한다.

	float4	OutColor = float4(lerp(PrimaryTexColor.rgb, BlurTexColor.rgb, DepthDiff), PrimaryTexColor.a);

	return OutColor;
}

float4 psFinalGlowOutLineDof(PS_INPUT input) : SV_Target
{
	//; c0 - focus_dist, scale0, scale1 ,0

#ifdef STEREO_RENDER
	int4	location = int4(input.Position.xy, input.ArrayIndex, 0);
	float3	texCoord = float3(input.cpPos.zw, input.ArrayIndex);
#else
	int3	location = int3(input.Position.xy,0);
	float2	texCoord = float2(input.cpPos.zw);
#endif

	// 원본 백버퍼 
	float4	PrimaryTexColor = texPrimary.Load(location);

	// 아웃라인
	float4	OutLineTexColor = texOutLine.Load(location);

	// 깊이
	float	Depth = texDepth.Load(location).r;			// depth
	float	Dist = DecompProj[input.ArrayIndex].m43 / (Depth - DecompProj[input.ArrayIndex].m33);
	float	LinearDepth = Dist * ProjConst.fFarRcp;	// NormalCenter = normal.xyz | Dist(0-1)

	// 블러링된 텍스쳐
	float4	BlurTexColor = texBlur.Sample(samplerClampLinear, texCoord);

	// glow 텍스쳐
	float4	GlowTexColor = texGlow.Sample(samplerClampLinear, texCoord);

	// 노말, 구름은 노말값이 0, 구름에 DOF를 적용하지 않기위해 노말값을 사용한다.
	float3 Normal = (float3)texNormal.Load(location);
	float NormalLen = length(Normal);

	// 원본 텍셀에 아웃라인 적용
	PrimaryTexColor *= OutLineTexColor.r;

	float DepthDiff = LinearDepth - GenericConst.x;

	DepthDiff *= GenericConst.y;	// apply major scale
	DepthDiff *= DepthDiff;			// 제곱
	DepthDiff = saturate(DepthDiff * GenericConst.z);	// apply minor scale

	DepthDiff *= NormalLen;		// 구름에 DOF를 적용하지 않기위해 노말값을 사용한다.

	float4	OutColor = float4(lerp(PrimaryTexColor.rgb, BlurTexColor.rgb, DepthDiff) + GlowTexColor.rgb, PrimaryTexColor.a);

	return OutColor;
}

float4 psFinalDof(PS_INPUT input) : SV_Target
{
	//; c0 - focus_dist, scale0, scale1 ,0

#ifdef STEREO_RENDER
	int4	location = int4(input.Position.xy, input.ArrayIndex, 0);
	float3	texCoord = float3(input.cpPos.zw, input.ArrayIndex);
#else
	int3	location = int3(input.Position.xy,0);
	float2	texCoord = float2(input.cpPos.zw);
#endif

	// 원본 백버퍼 
	float4	PrimaryTexColor = texPrimary.Load(location);

	// 깊이
	float	Depth = texDepth.Load(location).r;			// depth
	float	Dist = DecompProj[input.ArrayIndex].m43 / (Depth - DecompProj[input.ArrayIndex].m33);
	float	LinearDepth = Dist * ProjConst.fFarRcp;	// NormalCenter = normal.xyz | Dist(0-1)

	// 블러링된 텍스쳐
	float4	BlurTexColor = texBlur.Sample(samplerClampLinear,texCoord);

	// 노말, 구름은 노말값이 0, 구름에 DOF를 적용하지 않기위해 노말값을 사용한다.
	float3 Normal = (float3)texNormal.Load(location);
	float NormalLen = length(Normal);

	float DepthDiff = LinearDepth - GenericConst.x;

	DepthDiff *= GenericConst.y;	// apply major scale
	DepthDiff *= DepthDiff;			// 제곱
	DepthDiff = saturate(DepthDiff * GenericConst.z);	// apply minor scale

	DepthDiff *= NormalLen;		// 구름에 DOF를 적용하지 않기위해 노말값을 사용한다.
	//DepthDiff = 0.0f;

	float4	OutColor = float4(lerp(PrimaryTexColor.rgb, BlurTexColor.rgb, DepthDiff), PrimaryTexColor.a);

	return OutColor;
}
float4 psFinalDefault(PS_INPUT input) : SV_Target
{
	int3	location3 = int3(input.Position.xy,0);

	// 원본 백버퍼 

#ifdef STEREO_RENDER
	int4	location = int4(input.Position.xy, input.ArrayIndex, 0);
#else
	int3	location = int3(input.Position.xy,0);
#endif

	float4	PrimaryTexColor = texPrimary.Load(location);

	//PrimaryTexColor.a = 1.0f;

	return PrimaryTexColor;

}
