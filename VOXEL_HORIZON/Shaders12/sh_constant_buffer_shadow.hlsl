#ifndef SH_CONSTANT_BUFFER_SHADOW_HLSL
#define SH_CONSTANT_BUFFER_SHADOW_HLSL

#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"

cbuffer CONSTANT_BUFFER_SHADOW_CASTER : register(b0)
{
    TRANSFORM_COMMON g_TrCommon;	// shader공통으로 사용할 영역이므로 cguffer의 가장 앞에 위치해야한다.
    
    // 이하 CONSTANT_BUFFER_SHADOW_CASTER 고유영역
    SHADOW_CASTER_MATRIX g_ShadowCaster;
    float4 g_ShadowFrustumPlanes[MAX_CASCADE_NUM][6];    // view-frustum planes in world space (normals face out)
}

#endif