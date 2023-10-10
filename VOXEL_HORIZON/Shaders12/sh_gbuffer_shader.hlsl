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
Texture2DArray	texNormal		: register(t3);
Texture2DArray	texSSAO			: register(t4);
#else
Texture2D	texPrimary		: register(t0);
Texture2D	texDepth		: register(t1);
Texture2D	texNormal		: register(t3);
Texture2D	texSSAO			: register(t4);
#endif
Texture2DArray	texShadowMap	: register(t2);

SamplerState	samplerClampLinear	: register(s0);
SamplerState	samplerClampPoint	: register(s1);
SamplerComparisonState samplerComp  : register(s2);

void CalcIndex(out float OutIndex, in float Dist)
{
	uint	index = MAX_CASCADE_NUM - 1;

	for (uint i = 0; i < MAX_CASCADE_NUM; i++)
	{
		if (Dist <= CascadeConst[i].Dist)
		{
			index = i;
			break;
		}
	}
	OutIndex = index;
}
float3 CalcShadowColor3x3(Texture2DArray texShadowMap, SamplerComparisonState samplerComp, float4 PosWorld, float Dist, uint Type)
{
	float3	shadowColor = float3(1, 1, 1);

	uint	index;

	CalcIndex(index, Dist);

	float	Bias[2] = { ShadowBias.x,ShadowBias.y };
	float3	AmbColor[2] =
	{
		0.75,0.6,0.6,
		0.25,0.25,0.25
	};
	//Type == 0 -> character, Type == 1 -> Map
	float4	PosShadowSpace = mul(PosWorld, matShadowViewProjCascade[index]);
	float4	texCoord = PosShadowSpace / PosShadowSpace.w;

	//float  maxDepthSlope = max( abs( ddx( texCoord.z ) ), abs( ddy( texCoord.z ) ) );
	//float  slopeScaledBias = 0.01f;
	//float  shadowBias = min(slopeScaledBias * maxDepthSlope,Bias[type]);
	//texCoord.z -= shadowBias;

	float	cmp_z = texCoord.z - Bias[Type];

	/*
	float3 shadowCoord = input.SdwCoord.xyz / input.SdwCoord.w;
	float  maxDepthSlope = max( abs( ddx( shadowCoord.z ) ), abs( ddy( shadowCoord.z ) ) );
	float  shadowThreshold = 1.0f;
	float  bias            = 0.01f;
	float  slopeScaledBias = 0.01f;
	float  depthBiasClamp  = 0.1f;
	float  shadowBias = bias + slopeScaledBias * maxDepthSlope;
	shadowBias = min( shadowBias, depthBiasClamp );
	*/

	if (texCoord.x < 0.0f || texCoord.x > 1.0f)
		return shadowColor;

	if (texCoord.y < 0.0f || texCoord.y > 1.0f)
		return shadowColor;

	if (texCoord.z < 0.0f || texCoord.z > 1.0f)
		return shadowColor;

	if (texCoord.z > 1 || texCoord.z < 0)
		return shadowColor;

	float	litSum = 0;
	int2	offset[9] =
	{
		-1,-1,
		0,-1,
		1,-1,
		-1,0,
		0,0,
		1,0,
		-1,1,
		0,1,
		1,1
	};
	[unroll]
	for (int i = 0; i < 9; i++)
	{
		litSum += texShadowMap.SampleCmpLevelZero(samplerComp, float3(texCoord.xy, index), cmp_z, offset[i]);
	}
	float	shadowValue = litSum / 9.0f;

	/*
	for (float y=-1.5; y<=1.5; y += 1.0)
	{
		for (float x=-1.5; x<=1.5; x += 1.0)
		{
//			float4	texDepth = texShadowMap.Sample(samplerBorder,texCoord.xy + float2(x/1024.0f,y/1024.0f));
//			litSum += (PosShadowSpace.z - texDepth.r  <= 0.0f );

			litSum += texShadowMap.SampleCmpLevelZero(samplerComp,texCoord.xy + float2(x/(1024.0f*MAX_CASCADE_NUM),y/1024.0f),texCoord.z );
		}
	}
	float	shadowValue = litSum / 16.0f;
	*/
	shadowColor = lerp(AmbColor[Type], float3(1, 1, 1), shadowValue);
	//shadowColor.r = shadowValue * 0.25f + 0.75f;
	//shadowColor.g = shadowValue * 0.4f + 0.6f;
	//shadowColor.b = shadowValue * 0.4f + 0.6f;
	//shadowColor = shadowValue * 0.5f + float3(0.5,0.5,0.5);

	//if (ID > DYNAMIC_ID)
	//{
	//	shadowColor = shadowValue;
	//}

	return shadowColor;
}

float3 CalcShadowColor3x3_SM40(Texture2DArray texShadowMap, SamplerComparisonState samplerComp, float4 PosWorld, float Dist, uint Type)
{
	float3	shadowColor = float3(1, 1, 1);

	uint	index;

	CalcIndex(index, Dist);

	float	Bias[2] = { ShadowBias.x,ShadowBias.y };
	float3	AmbColor[2] =
	{
		0.75,0.6,0.6,
		0.25,0.25,0.25
	};

	float4	PosShadowSpace = mul(PosWorld, matShadowViewProjCascade[index]);
	float4	texCoord = PosShadowSpace / PosShadowSpace.w;

	//float  maxDepthSlope = max( abs( ddx( texCoord.z ) ), abs( ddy( texCoord.z ) ) );
	//float  slopeScaledBias = 0.01f;
	//float  shadowBias = min(slopeScaledBias * maxDepthSlope,Bias[type]);
	//texCoord.z -= shadowBias;

	float	cmp_z = texCoord.z - Bias[Type];

	/*
	float3 shadowCoord = input.SdwCoord.xyz / input.SdwCoord.w;
	float  maxDepthSlope = max( abs( ddx( shadowCoord.z ) ), abs( ddy( shadowCoord.z ) ) );
	float  shadowThreshold = 1.0f;
	float  bias            = 0.01f;
	float  slopeScaledBias = 0.01f;
	float  depthBiasClamp  = 0.1f;
	float  shadowBias = bias + slopeScaledBias * maxDepthSlope;
	shadowBias = min( shadowBias, depthBiasClamp );
	*/

	if (texCoord.x < 0.0f || texCoord.x > 1.0f)
		return shadowColor;

	if (texCoord.y < 0.0f || texCoord.y > 1.0f)
		return shadowColor;

	if (texCoord.z < 0.0f || texCoord.z > 1.0f)
		return shadowColor;

	if (texCoord.z > 1 || texCoord.z < 0)
		return shadowColor;

	float	litSum = 0;
	int2	offset[9] =
	{
		-1,-1,
		0,-1,
		1,-1,
		-1,0,
		0,0,
		1,0,
		-1,1,
		0,1,
		1,1
	};
	/*
	[unroll]
	for (int i = 0; i < 9; i++)
	{
		litSum += texShadowMap.SampleCmpLevelZero(samplerComp, float3(texCoord.xy,index), cmp_z, offset[i]);
	}
	float	shadowValue = litSum / 9.0f;
	*/
	[unroll]
	for (float y = -1.5; y <= 1.5; y += 1.0)
	{
		[unroll]
		for (float x = -1.5; x <= 1.5; x += 1.0)
		{
			float4	texDepth = texShadowMap.Sample(samplerClampLinear, float3(texCoord.xy, index));
			litSum += (PosShadowSpace.z - texDepth.r <= 0.0f);

			//litSum += texShadowMap.SampleCmpLevelZero(samplerComp,texCoord.%xy + float2(x/(1024.0f*MAX_CASCADE_NUM),y/1024.0f),texCoord.z );
		}
	}
	float	shadowValue = litSum / 16.0f;

	shadowColor = lerp(AmbColor[Type], float3(1, 1, 1), shadowValue);
	//shadowColor.r = shadowValue * 0.25f + 0.75f;
	//shadowColor.g = shadowValue * 0.4f + 0.6f;
	//shadowColor.b = shadowValue * 0.4f + 0.6f;
	//shadowColor = shadowValue * 0.5f + float3(0.5,0.5,0.5);

	//if (ID > DYNAMIC_ID)
	//{
	//	shadowColor = shadowValue;
	//}

	return shadowColor;
}

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

	float3	ShadowColor = 1.0;
	float	ao_default = (float)(1 - IsEnabledSSAO(Prop));
	uint	Type = GetType(Prop);
	float3	NormalWorld = normalize((NormalColor.xyz * 2.0) - 1.0);

	// shadow light방향을 바라보고 있지 않은 면은 그림자를 받지 않도록 한다.
	// 단 캐릭터 오브젝트는 그렇게 처리하면 부자연스러우므로 맵 오브젝트에 한정한다.
	float shadow_cosang = 1.0;	// 디폴트 cos 값은 1로 설정
	if (1 == Type)
	{
		// 맵 오브젝트인 경우 빛방향에 대한 cos값을 구한다.
		shadow_cosang = dot(NormalWorld.xyz, ShadowLightDirInv.xyz);
	}
	if (shadow_cosang > 0.0)
	{
		// 빛 방향에 대해 마주보고 있거나 90도까지의 각을 가지는 픽셀에 대해서만 그림자 처리
		// shadow mask 
		float TexShadowWeight = GetShadowWeight(Prop);
		float ShadowWeight = saturate(0.25 + 0.25 + dot(NormalWorld, (float3)ShadowLightDirInv)) * TexShadowWeight;
	   
		uint	Index;
	#if (DX_FEATURE_LEVEL >= 11)
		ShadowColor = CalcShadowColor3x3(texShadowMap, samplerComp, float4(WorldPos, 1), Dist, Type);
	#else
		ShadowColor = CalcShadowColor3x3_SM40(texShadowMap, samplerComp, float4(WorldPos, 1), Dist, Type);
	#endif
		ShadowColor = lerp(float3(1, 1, 1), ShadowColor, ShadowWeight);
	}

	// SSAO
	float	ao = texSSAO.Sample(samplerClampLinear, texCoord);
	ao = max(ao, ao_default);

	float4	OutColor = float4(PrimaryTexColor.rgb * ShadowColor.rgb * ao, PrimaryTexColor.a);
	
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