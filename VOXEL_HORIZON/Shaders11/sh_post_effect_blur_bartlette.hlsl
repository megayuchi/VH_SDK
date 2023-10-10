#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_post_effect_common.hlsl"

#ifdef STEREO_RENDER
Texture2DArray	texPrimary	: register(t0);
#else
Texture2D		texPrimary	: register(t0);
#endif

float4 ps9SampleBartletteBlur(PS_INPUT input) : SV_Target
{
	// 가운데 점(1픽셀)
#ifdef STEREO_RENDER
	float3 texCoord = float3(input.cpPos.zw, input.ArrayIndex);
#else
	float2 texCoord = float2(input.cpPos.zw);
#endif
	float4 Center = texPrimary.Sample(samplerClampLinear, texCoord);

	float4	ColorSum = Center;

	// 주변 점(8픽셀)의 합
	for (int i = 0; i < 8; i++)
	{
#ifdef STEREO_RENDER
		float3 texCoordSide = float3(input.cpPos.zw + texCoordOffset9Sample[i].xy, input.ArrayIndex);
#else
		float2 texCoordSide = float2(input.cpPos.zw + texCoordOffset9Sample[i].xy);
#endif

		ColorSum += texPrimary.Sample(samplerClampLinear,texCoordSide);
	}
	float4	OutColor = ColorSum * (1.0f / 9.0f);


	return OutColor;
}