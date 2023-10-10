#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_dynamic_common.hlsl"
#include "sh_typedef.hlsl"
#include "sh_util.hlsl"
#include "sh_constant_buffer_default.hlsl"
#include "sh_constant_buffer_instance.hlsl"
#include "sh_vl_ms_common.hlsl"

groupshared float4 g_groupVertexList[8];

[NumThreads(MS_THREAD_NUM_PER_GROUP_VL, 1, 1)]
[OutputTopology("triangle")]
void msBox(
    uint threadID : SV_GroupThreadID,
    uint groupID : SV_GroupID,
	out indices uint3 pOutTriList[12],
    out vertices VS_OUTPUT pOutVertexList[36]
)
{
    uint ArrayIndex = 0;

    SetMeshOutputCounts(36, 12);
    
    if (threadID < 8)
    {
        float4 PosBase = float4(0, 0, 0, 1);
        float WidthDepthHeight = 25.0;
        float4 PosWorld = mul(PosBase, g_TrCommon.matWorld) + float4(g_boxVertexList[threadID].xyz * WidthDepthHeight, 0);
        g_groupVertexList[threadID] = PosWorld;
    }
    GroupMemoryBarrierWithGroupSync();
    
    // 삼각형의 인덱스 리스트와 참조할 정점 위치를 출력
    if (threadID < 12)
    {
        uint3 IndexedTri = g_boxIndexList[threadID];
        float4 PosWorld[3] =
        {
            g_groupVertexList[IndexedTri.x],
            g_groupVertexList[IndexedTri.y],
            g_groupVertexList[IndexedTri.z]
        };
        float3 N = CalcNormalWithTri((float3)PosWorld[0], (float3)PosWorld[1], (float3)PosWorld[2]);
        
        float cosang = saturate(dot(N, (float3)(-LightDir)));
        cosang = max(MinNdotL.a, cosang);
        
        for (uint i = 0; i < 3; i++)
        {
            uint BoundsVertexID = threadID * 3 + i;
            
            float4 PosOut = mul(PosWorld[i], g_Camera.matViewProjArray[ArrayIndex]); // 프로젝션된 좌표.
            pOutVertexList[BoundsVertexID].Pos = PosOut;
            pOutVertexList[BoundsVertexID].Dist = PosOut.w;
            pOutVertexList[BoundsVertexID].PosWorld = PosWorld[i]; // 월드 좌표
            pOutVertexList[BoundsVertexID].Clip = dot(PosWorld[i], ClipPlane); // 클립플레인처리        
            pOutVertexList[BoundsVertexID].NormalColor = float4((N * 0.5f) + 0.5f, 0);
            pOutVertexList[BoundsVertexID].TexCoordDiffuse = float2(0.5, 0.5);
            pOutVertexList[BoundsVertexID].Diffuse = float4(float3(3, 0.5, 0.25) * cosang, 1);
            //pOutVertexList[BoundsVertexID].Diffuse = float4(g_PalettedColor[meshltID % 16].xyz* cosang, 1);
            pOutVertexList[BoundsVertexID].Property = 0;
            pOutVertexList[BoundsVertexID].ArrayIndex = ArrayIndex;
        }
        pOutTriList[threadID] = uint3(threadID * 3 + 0, threadID * 3 + 1, threadID * 3 + 2);
    }
}