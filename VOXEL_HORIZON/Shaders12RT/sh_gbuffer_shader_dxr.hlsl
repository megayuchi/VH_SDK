#include "sh_gbuffer_shader_common.hlsl"

cbuffer ConstantBufferGBufferShader : register (b0)
{
	float4	ShadowLightDirInv;
	matrix	ViewInvArray[2];
	matrix	matShadowViewProjCascade[MAX_CASCADE_NUM];
	CASCADE_CONSTANT	CascadeConst[MAX_CASCADE_NUM];
	float4	ShadowBias;	// x : Dynamic , y : Static , z : 0 , w : 0
	DECOMP_PROJ	DecompProj[2];
};
#ifdef STEREO_RENDER
Texture2DArray	texPrimary		: register(t0);
Texture2DArray	texDepth		: register(t1);
Texture2DArray	texNormal		: register(t2);
Texture2DArray	texSSAO			: register(t3);
#else
Texture2D	texPrimary		: register(t0);
Texture2D	texDepth		: register(t1);
Texture2D	texNormal		: register(t2);
Texture2D	texSSAO			: register(t3);
#endif

SamplerState	samplerClampLinear	: register(s0);
SamplerState	samplerClampPoint	: register(s1);
SamplerComparisonState samplerComp  : register(s2);

float ConvertZToLinearDepth(float depth, uint ArrayIndex)
{
	float linearDepth = DecompProj[ArrayIndex].m43 / (depth - DecompProj[ArrayIndex].m33);
	return linearDepth;
}
float3 CalcWorldPos(float2 csPos, float depth, out float dist, uint ArrayIndex)
{
	// csPos - Clip Space Postion -1 ~ +1


	//xp,yp,zp 는 프로젝션 된 점 (-1 - 1)

	// 일반적인 경우 - m21,m31,m32가 0인 경우
	// z = m43 / (zp - m33)
	// y = z*yp / m22
	// x = z*xp / m11

	// m21,m31,m32가 유효할 경우
	// z = m43 / (zp - m33)
	// y = (z*yp - z*m32) / m22
	// x = (z*xp - y*m21 - z*m31) / m11

	float z = DecompProj[ArrayIndex].m43 / (depth - DecompProj[ArrayIndex].m33);
	float y = ((z * csPos.y) - (z * DecompProj[ArrayIndex].m32)) * DecompProj[ArrayIndex].rcp_m22;
	float x = ((z * csPos.x) - (y * DecompProj[ArrayIndex].m21) - (z * DecompProj[ArrayIndex].m31)) * DecompProj[ArrayIndex].rcp_m11;
	float4 position = float4(x, y, z, 1);
	dist = z;

	return mul(position, ViewInvArray[ArrayIndex]).xyz;
}

float4 psDefault(PS_INPUT input) : SV_Target
{
	//; c0 - focus_dist, scale0, scale1 ,0
#ifdef  STEREO_RENDER
	int4	location = int4(input.Position.xy,input.ArrayIndex,0);
	float3	texCoord = float3(input.cpPos.zw, input.ArrayIndex);
#else
	int3	location = int3(input.Position.xy,0);
	float2	texCoord = float2(input.cpPos.zw);
#endif
	float	Depth = texDepth.Load(location).r;

	float	Dist;	// 카메라로부터의 거리
	float3	WorldPos = CalcWorldPos(input.cpPos.xy,Depth,Dist,input.ArrayIndex);

	// 원본 백버퍼 
	float4	PrimaryTexColor = texPrimary.Load(location);
	float4	NormalColor = texNormal.Load(location);

	uint	Prop = (uint)(NormalColor.a * 255.0 + ADJ_RCP_256);
	NormalColor.a = 0;

	float	ao_default = (float)(1 - IsEnabledSSAO(Prop));
	uint	Type = GetType(Prop);
	float3	NormalWorld = normalize((NormalColor.xyz * 2.0) - 1.0);

	// SSAO
	float	ao = texSSAO.Sample(samplerClampLinear, texCoord);
	ao = max(ao, ao_default);

	float4	OutColor = float4(PrimaryTexColor.rgb * ao, PrimaryTexColor.a);
	
	return OutColor;
}

/*
float ConvertZToLinearDepth(float depth, uint ArrayIndex)
{
	float linearDepth = PerspectiveConstArray[ArrayIndex].z / (depth + PerspectiveConstArray[ArrayIndex].w);
	return linearDepth;
}

float3 CalcWorldPos(float2 csPos, float depth, out float dist, uint ArrayIndex)
{
	// csPos - Clip Space Postion -1 ~ +1
	float4 position;

	//xp,yp,zp 는 프로젝션 된 점 (-1 - 1)

	// 일반적인 경우 - m21,m31,m32가 0인 경우
	// z = m43 / (zp - m33)
	// y = z*yp / m22
	// x = z*xp / m11

	// m21,m31,m32가 유효할 경우
	// z = m43 / (zp - m33)
	// y = (z*yp - z*m32) / m22
	// x = (x*xp - y*m21 - z*m31) / m11

	//pConstantBuffer->v4PerspectiveConst.x = 1.0f / pMatProj->_11;
	//pConstantBuffer->v4PerspectiveConst.y = 1.0f / pMatProj->_22;
	//pConstantBuffer->v4PerspectiveConst.z = pMatProj->_43;
	//pConstantBuffer->v4PerspectiveConst.w = -pMatProj->_33;

	//float	xs = pv3ScreenCoordList[i].x;
	//float	ys = pv3ScreenCoordList[i].y;
	//float	zs = pv3ScreenCoordList[i].z;
	//zc = pMatProj->_43 / (zs - pMatProj->_33);
	//xc = (xs * zc) / pMatProj->_11;
	//yc = (ys * zc) / pMatProj->_22;

	// float linearDepth = PerspectiveConst.z / (depth + PerspectiveConst.w);
	// -> float linearDepth = pMatProj->_43 / (depth + -pMatProj->_33) == zc = pMatProj->_43 / (zs - pMatProj->_33);

	// position.x = csPos.x * PerspectiveConst.x * linearDepth;
	// -> position.x = csPos.x * 1.0f / pMatProj->_11 * linearDepth;
	// -> position.x = csPos.x * linearDepth / pMatProj->_11
	// == xc = (xs * zc) / pMatProj->_11;

	// position.y = csPos.y * PerspectiveConst.y * linearDepth;
	// -> position.y = csPos.y * 1.0f / pMatProj->_22 * linearDepth;
	// -> position.y = csPos.y * linearDepth / pMatProj->_22;
	// == yc = (ys * zc) / pMatProj->_22;
	float	linearDepth = PerspectiveConstArray[ArrayIndex].z / (depth + PerspectiveConstArray[ArrayIndex].w);
	position.xy = csPos.xy * PerspectiveConstArray[ArrayIndex].xy * float2(linearDepth, linearDepth);
	position.z = linearDepth;
	position.w = 1.0;

	dist = linearDepth;

	return mul(position, ViewInvArray[ArrayIndex]).xyz;
}
*/