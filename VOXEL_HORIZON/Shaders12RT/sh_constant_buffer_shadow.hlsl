#ifndef SH_CONSTANT_BUFFER_SHADOW_HLSL
#define SH_CONSTANT_BUFFER_SHADOW_HLSL

#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"

cbuffer CONSTANT_BUFFER_SHADOW_CASTER : register(b0)
{
    TRANSFORM_COMMON g_TrCommon;	// shader�������� ����� �����̹Ƿ� cguffer�� ���� �տ� ��ġ�ؾ��Ѵ�.
    
    // ���� CONSTANT_BUFFER_SHADOW_CASTER ��������
    SHADOW_CASTER_MATRIX g_ShadowCaster;
    float4 g_ShadowFrustumPlanes[MAX_CASCADE_NUM][6];    // view-frustum planes in world space (normals face out)
}

#endif