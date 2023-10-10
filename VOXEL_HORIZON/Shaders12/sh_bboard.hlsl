#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_dynamic_common.hlsl"
#include "sh_a_buffer.hlsl"

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
	float   Clip : SV_ClipDistance;
	uint    ArrayIndex  : BLENDINDICES;
#if (1 == VS_RTV_ARRAY)
	uint    RTVIndex    : SV_RenderTargetArrayIndex;
#endif
};

struct GS_OUTPUT_BBOARD : VS_OUTPUT_BBOARD
{
#if (1 != VS_RTV_ARRAY)
	uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};

struct PS_INPUT_BBOARD : VS_OUTPUT_BBOARD
{
};


//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------




PS_INPUT_BBOARD vsDefault(VS_INPUT_BBOARD input)
{
	PS_INPUT_BBOARD output = (PS_INPUT_BBOARD)0;

	uint	ArrayIndex = input.instId % 2;

	output.Pos = mul(input.Pos, g_Camera.matWorldViewProjArray[ArrayIndex]);

	// 클립플레인처리
	output.Clip = dot(mul(input.Pos, g_TrCommon.matWorld), ClipPlane);
	
	// 노말
	output.NormalColor = 0;
	output.Color = MtlDiffuse + MtlAmbient;
	output.TexCoord = input.TexCoord;
	output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif
	return output;
}

[maxvertexcount(3)]
void gsDefault(triangle VS_OUTPUT_BBOARD input[3], inout TriangleStream<GS_OUTPUT_BBOARD> TriStream)
{
	GS_OUTPUT_BBOARD output[3];

	for (uint i = 0; i < 3; i++)
	{
		output[i].Pos = input[i].Pos;
		output[i].Color = input[i].Color;
		output[i].NormalColor = input[i].NormalColor;
		output[i].TexCoord = input[i].TexCoord;
		output[i].Clip = input[i].Clip;
		output[i].ArrayIndex = input[i].ArrayIndex;
		output[i].RTVIndex = input[i].ArrayIndex;
		TriStream.Append(output[i]);
	}
}


#if (1 == SHADER_PARAMETER_USE_OIT)
[earlydepthstencil]
#endif
PS_TARGET psDefault(PS_INPUT_BBOARD input)
{
	PS_TARGET output = (PS_TARGET)0;

	float4 texColor = texDiffuse.Sample(samplerWrap, input.TexCoord);
#if (1 == SHADER_PARAMETER_USE_OIT)
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
#endif
	float4 outColor = texColor * input.Color;
	float4	NormalColor = float4(input.NormalColor.xyz, (float)Property / 255.0f);

	output.Color0 = outColor;
	output.Color1 = NormalColor;
	output.Color2 = float4(0, 0, 0, 0);


#if (1 == SHADER_PARAMETER_USE_OIT)
	uint2	vPos = uint2(input.Pos.xy);
	uint	ScreenIndex = vPos.x + vPos.y*ScreenWidth;

	// Retrieve current pixel count and increase counter
	uint uPixelCount = FLBuffer.IncrementCounter();
	if (uPixelCount >= MaxFLNum)
	{
		uint OldFailCount;
		FailCountBuffer.InterlockedAdd((ScreenIndex & 0x0f) * 4, 1, OldFailCount);
		return output;
	}

	// Exchange offsets in StartOffsetBuffer
	uint uStartOffsetAddress = (ScreenIndex + input.ArrayIndex*ScreenWidth*ScreenHeight) * 4;
	uint uOldStartOffset;
	StartOffsetBuffer.InterlockedExchange(uStartOffsetAddress, uPixelCount, uOldStartOffset);

	// Add new fragment entry in Fragment & Link Buffer
	FLBuffer[uPixelCount].uPixelColor = PackRGBA(outColor);
	FLBuffer[uPixelCount].uNormal_ElementID = Pack_Normal_Property_ElementID_To_UINT(NormalColor.rgb, Property, 0);
	
	FLBuffer[uPixelCount].fDepth = input.Pos.z;
	FLBuffer[uPixelCount].SetNext(uOldStartOffset);
	FLBuffer[uPixelCount].SetAlphaMode(MtlAlphaMode);
	PropertyBuffer.InterlockedOr(uStartOffsetAddress, MtlAlphaMode);
#endif


	return output;
}

/*

; v0 - n*L*diffuse
; c0 - ambient
; c4 - alpha thresold -> (color - alpha thresold) < 0.0f ? kill pixel

ps_2_0

def		c10,0.3,0.59,0.11,1

dcl	t0.xy


dcl_2d	s0
dcl	v0.xyzw
dcl	v1.xyzw


texld	r0,t0,s0

dp3		r4,r0,c10
sub		r5,r4.x,c4.x
texkill	r5*/


