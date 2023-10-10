#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_post_effect_common.hlsl"

#ifdef STEREO_RENDER
Texture2DArray	texPrimary	: register(t0);
#else
Texture2D		texPrimary	: register(t0);
#endif

float4 ps9SampleGlow(PS_INPUT input) : SV_Target
{
	// 가운데 점(1픽셀)
	/*
	float4	Center = texPrimary.Sample(samplerClampLinear,input.TexCoord);

	float4	ColorSum = Center;

	// 주변 점(8픽셀)의 합
	for (int i=0; i<8; i++)
	{
		float2 texCoordSide = input.TexCoord.xy + texCoordSampleOffset[i].xy;
		ColorSum += texPrimary.Sample(samplerClampLinear,texCoordSide);
	}
	float4	Color = ColorSum * (1.0f / 9.0f);
	*/
#ifdef STEREO_RENDER
	float3 texCoord = float3(input.cpPos.zw, input.ArrayIndex);
#else
	float2 texCoord = float2(input.cpPos.zw);
#endif
	float4	Color = texPrimary.Sample(samplerClampLinear, texCoord);

	//log r7.x, r0.x
	//log r7.y, r0.y
	//log r7.z, r0.z
	//log r7.w, r0.w
	//mul r2, r7, c0.x
	//exp r9.x, r2.x
	//exp r9.y, r2.y
	//exp r9.z, r2.z
	//exp r9.w, r2.w

	float	pow_const = 32;
	float4	OutColor = pow(Color,pow_const);

	//float4	log_color = log(Color);
	//float4	mul_log_color = mul(log_color,pow_const);
	//float4	OutColor = exp(mul_log_color);

	//OutColor.a = 1.0f;


	return OutColor;
}

/*

;def c0, 32, 0, 0, 0

dcl t0.xy
dcl_2d s0


texld r0, t0, s0
log r7.x, r0.x
log r7.y, r0.y
log r7.z, r0.z
log r7.w, r0.w
mul r2, r7, c0.x
exp r9.x, r2.x
exp r9.y, r2.y
exp r9.z, r2.z
exp r9.w, r2.w
mov oC0, r9
*/
