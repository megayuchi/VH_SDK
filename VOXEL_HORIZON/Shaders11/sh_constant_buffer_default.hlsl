#ifndef SH_CONSTANT_BUFFER_DEFAULT_HLSL
#define SH_CONSTANT_BUFFER_DEFAULT_HLSL

#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"

cbuffer CONSTANT_BUFFER_DEFAULT : register(b0)
{
	TRANSFORM_COMMON g_TrCommon;	// shader공통으로 사용할 영역이므로 cbuffer의 가장 앞에 위치해야한다.
	
	// 이하 CONSTANT_BUFFER_DEFAULT 고유 영역
    CAMERA_MATRIX	g_Camera;
	float4			g_FrustumPlanes[6];    // view-frustum planes in world space (normals face out)
	
	float4				GlobalEyePos;
	float4				LightMapConst;
	float4				LightDir;
	float4				LightColor;
	float4				ShadowLightDirInv;
	float4				ClipPlane;		// a,b,c,d = x,y,z,w
	PROJ_CONSTANT		ProjConstant;

	int					iAttLightNum;
	uint				Property;
	float				TimeSinValueX;
	float				TimeSinValueY;
	ATT_LIGHT			AttLight[MAX_ATT_LIGHT_NUM];

	// Water Bottom 
	float		Height;
	float		RcpFadeDistance;
	float		FadeDistance;
	float		Reserved;

	float4		WorldMinMax[2];
	float4		WorldSize;

	// public
	float4		PublicConst[MAX_PUBLIC_CONST_NUM];
}
#endif