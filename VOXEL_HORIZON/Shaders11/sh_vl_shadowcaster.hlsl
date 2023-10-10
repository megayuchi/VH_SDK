#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"
#include "sh_dynamic_physique.hlsl"
#include "sh_constant_buffer_shadow.hlsl"
#include "sh_constant_buffer_instance.hlsl"

struct PS_OUT_TEX_ARRAY
{
    float4 Pos : SV_POSITION; // Projection coord
    uint RTIndex : SV_RenderTargetArrayIndex;
};

struct GS_INPUT
{
    float4 Pos : POSITION;
};

float4 vsShadowCaster(VS_INPUT_VL input) : POSITION
{
#ifdef USE_INSTANCING
    uint InstanceObjID = input.instId;
#endif
    float4 PosLocal = float4(input.Pos.xyz, 1);
    float4 PosWorld = mul(PosLocal, g_TrCommon.matWorld);
#ifdef USE_INSTANCING
    if (g_TrCommon.MeshShaderInstanceCount > 0)
    {
        PosWorld = mul(PosWorld, g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서의 버텍스 좌표
    }
#endif
    return PosWorld;
}
float4 vsShadowCasterPhysique(VS_INPUT_VL_PHYSIQUE input) : POSITION
{
#ifdef USE_INSTANCING
    uint InstanceObjID = input.instId;
#endif
	// 블랜딩된 로컬포지션을 계산
    float4 PosLocal = float4(vsCalcBlendPos(input.Pos, input.BlendIndex, input.BlendWeight), 1);
    float4 PosWorld = mul(PosLocal, g_TrCommon.matWorld);
#ifdef USE_INSTANCING
    if (g_TrCommon.MeshShaderInstanceCount > 0)
    {
        PosWorld = mul(PosWorld, g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서의 버텍스 좌표
    }
#endif
    return PosWorld;
}


[maxvertexcount(3 * MAX_CASCADE_NUM)]
void gsShadowCaster(triangle GS_INPUT input[3], inout TriangleStream<PS_OUT_TEX_ARRAY> TriStream)
{
    PS_OUT_TEX_ARRAY output[3];
    for (uint i = 0; i < MAX_CASCADE_NUM; i++)
    {
        for (uint j = 0; j < 3; j++)
        {
            output[j].Pos = mul(input[j].Pos, g_ShadowCaster.matViewProjList[i]);
            output[j].RTIndex = i;
            TriStream.Append(output[j]);
        }
        TriStream.RestartStrip();
    }
}