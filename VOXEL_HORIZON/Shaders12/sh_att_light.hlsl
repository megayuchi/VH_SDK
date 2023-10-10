#ifndef SH_ATT_LIGHT_HLSL
#define SH_ATT_LIGHT_HLSL

#include "sh_constant_buffer_default.hlsl"
#include "sh_util.hlsl"

float3 CalcAttLightColor(float3 Pos, int AttLightNum)
{
	float3		LightColorSum = 0;

	for (int i = 0; i < AttLightNum; i++)
	{
		float3		LightVec = (AttLight[i].Pos.xyz - Pos.xyz);
		float		LightVecDot = dot(LightVec, LightVec);
		float		Dist = sqrt(LightVecDot);
		float		RsSubDist = AttLight[i].Rs - Dist;

		if (RsSubDist < 0.0f)
		{
			continue;
		}
		float4	ColorCenter = ConvertDWORDTofloat(AttLight[i].ColorCenter);
		float4	ColorSide = ConvertDWORDTofloat(AttLight[i].ColorSide);

		float	NrmDist = (Dist / AttLight[i].Rs);
		float	FallOff = (RsSubDist*RsSubDist) * AttLight[i].RcpRsRs;
		float3	LightColor = lerp(ColorCenter.rgb, ColorSide.rgb, NrmDist) * FallOff;

		LightColorSum += LightColor;
	}
	return LightColorSum;
}
float3 CalcAttLightColorWithNdotL(float3 Pos, float NdotL[8], int AttLightNum)
{

	float3		LightColorSum = 0;

	for (int i = 0; i < AttLightNum; i++)
	{
		if (NdotL[i] <= 0.0f)
		{
			continue;
		}

		float3		LightVec = (AttLight[i].Pos.xyz - Pos.xyz);
		float		LightVecDot = dot(LightVec, LightVec);
		float		Dist = sqrt(LightVecDot);
		float		RsSubDist = AttLight[i].Rs - Dist;

		if (RsSubDist < 0.0f)
		{
			continue;
		}
		float4	ColorCenter = ConvertDWORDTofloat(AttLight[i].ColorCenter);
		float4	ColorSide = ConvertDWORDTofloat(AttLight[i].ColorSide);

		float	NrmDist = (Dist / AttLight[i].Rs);
		float	FallOff = (RsSubDist*RsSubDist) * AttLight[i].RcpRsRs;
		float3	LightColor = lerp(ColorCenter.rgb, ColorSide.rgb, NrmDist) * FallOff;

		LightColorSum += LightColor;
	}
	return LightColorSum;
}
#endif