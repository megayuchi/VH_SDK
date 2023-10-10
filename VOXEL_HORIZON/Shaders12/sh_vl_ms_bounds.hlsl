
//#define SHADER_PARAMETER_ATT_LIGHT	1
//#define SHADER_PARAMETER_PHYSIQUE		1
//#define SHADER_PARAMETER_LIGHT_PRB	1
//#define SHADER_PARAMETER_USE_OIT		1
//#define SHADER_PARAMETER_USE_TILED_RESOURCES 1
//#define LIGHTING_TYPE	0	//(vlmesh에서 LIGHTING_TYPE이 0인 경우는 없다.)
#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_dynamic_common.hlsl"
#include "sh_typedef.hlsl"
#include "sh_util.hlsl"
#include "sh_constant_buffer_default.hlsl"
#include "sh_constant_buffer_instance.hlsl"
#include "sh_vl_ms_common.hlsl"

#define BOUNDS_AS_STATIC
#define BOUNDS_AS_DYNAMIC

#ifdef BOUNDS_AS_DYNAMIC
#undef BOUNDS_AS_STATIC
#endif

groupshared INT_AABB g_groupMeshletAABB;
groupshared float4 g_groupMeshletVertexList[8];

[NumThreads(MS_THREAD_NUM_PER_GROUP_VL, 1, 1)]
[OutputTopology("triangle")]
void msDynamicVL(
    uint threadID : SV_GroupThreadID,
    uint groupID : SV_GroupID,
    in payload Payload payload,
	out indices uint3 pOutTriList[12],
    out vertices VS_OUTPUT pOutVertexList[36]
)
{
    uint ArrayIndex = 0;
	
// FaceGroup 단위로 DispatchMesh()가 호출된다.
// 따라서 다음과 같이 처리할 수 있다.
// instacne Count = 2
// Meshlet count of FaceGroup[0] = 3
// Meshlet count of FaceGroup[1] = 2
// Meshlet count of FaceGroup[2] = 4
//              |     DispatchMesh(3*2)   |     DispatchMesh(2*2)   |     DispatchMesh(4*2)       |
//              | Instance 0 | Instance 1 | Instance 0 | Instance 1 |  Instance 0  |  Instance 1  |
//              |FaceGroup0-0|FaceGroup0-1|FaceGroup1-0|FaceGroup1-1| FaceGroup2-0 | FaceGroup2-1 |
//GroupID       |   0  1  2  |   3  4  5  |    0  1    |    2  3    |   0  1  2  3 |  4  5  6  7  |
//MeshletID     |   0  1  2  |   0  1  2  |    0  1    |    0  1    |   0  1  2  3 |  0  1  2  3  |
#ifdef USE_AMPLIFICATION_SHADER
    uint InstanceObjID = payload.InstanceID[groupID];
    uint meshltID = payload.MeshletID[groupID];
#else
        uint InstanceObjID = groupID / MeshletNumPerFaceGroup;
        uint meshltID = groupID % MeshletNumPerFaceGroup;
#endif
    
    if (meshltID >= MeshletNumPerFaceGroup)
        return;

    MESHLET meshlet = g_MeshletBuffer[meshltID];
	
    SetMeshOutputCounts(36, 12);
    
#ifdef BOUNDS_AS_DYNAMIC
    if (0 == threadID)
    {
        g_groupMeshletAABB.Min = int4(INT_MAX, INT_MAX, INT_MAX, INT_MAX);
        g_groupMeshletAABB.Max = int4(INT_MIN, INT_MIN, INT_MIN, INT_MIN);
    }
    GroupMemoryBarrierWithGroupSync();
#endif
    
    // calc AABB per Meshlet
    uint vertexID = threadID;
    while (vertexID < meshlet.IndexedVertexNum)
    {
        uint baseIndex = (meshlet.IndexedVertexStart + vertexID) * 2;
        uint IndexedVertex = Load16BitIndexedVertex(baseIndex);

    // Vertex Transform
#if (1 == SHADER_PARAMETER_PHYSIQUE)
        D3DVLVERTEX_PHYSIQUE vertex = g_Vertices[IndexedVertex];
#else
        D3DVLVERTEX vertex = g_Vertices[IndexedVertex];
#endif

    	VS_INPUT input = (VS_INPUT)0;
        input.Pos = float4(vertex.Pos, 1);
        input.Normal = float3(vertex.Normal);
        input.Tangent = float4(vertex.Tangent.xyz, 0);
        input.TexCoord = float2(0, 0);
        
        float3 PosLocal;
        float3 NormalLocal;
        float3 TangentLocal;
#if (1 == SHADER_PARAMETER_PHYSIQUE)
        input.BlendIndex[0] = (vertex.BoneIndex & 0x000000ff);
        input.BlendIndex[1] = (vertex.BoneIndex & 0x0000ff00) >> 8;
        input.BlendIndex[2] = (vertex.BoneIndex & 0x00ff0000) >> 16;
        input.BlendIndex[3] = (vertex.BoneIndex & 0xff000000) >> 24;
        input.BlendWeight[0] = vertex.BoneWeight4.x;
        input.BlendWeight[1] = vertex.BoneWeight4.y;
        input.BlendWeight[2] = vertex.BoneWeight4.z;
        input.BlendWeight[3] = vertex.BoneWeight4.w;
#endif

#if (1 == SHADER_PARAMETER_PHYSIQUE)
        PosLocal = vsCalcBlendPos(input.Pos, input.BlendIndex, input.BlendWeight); // 블랜딩된 로컬포지션을 계산
        NormalLocal = vsCalcBlendNormal(input.Normal, input.BlendIndex, input.BlendWeight); // 블랜딩된 로컬노멀을 계산.
        TangentLocal = vsCalcBlendNormal(input.Tangent.xyz, input.BlendIndex, input.BlendWeight); // 블랜딩된 탄젠트를 계산.
#else
        PosLocal = (float3)input.Pos;
        NormalLocal = input.Normal;
        TangentLocal = input.Tangent.xyz;
#endif
        float4 PosWorld = mul(float4(PosLocal, 1), g_TrCommon.matWorld); // 월드공간에서의 버텍스 좌표
        if (g_TrCommon.MeshShaderInstanceCount > 0)
        {
            PosWorld = mul(PosWorld, g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서의 버텍스 좌표
        }
#ifdef BOUNDS_AS_DYNAMIC
        // 현재 프레임의 meshlet에서 AABB를 구한다.
        uint3 OldMin, OldMax;
        InterlockedMax(g_groupMeshletAABB.Max.x, (int)PosWorld.x, OldMax.x);
        InterlockedMax(g_groupMeshletAABB.Max.y, (int)PosWorld.y, OldMax.y);
        InterlockedMax(g_groupMeshletAABB.Max.z, (int)PosWorld.z, OldMax.z);
        
        InterlockedMin(g_groupMeshletAABB.Min.x, (int)PosWorld.x, OldMin.x);
        InterlockedMin(g_groupMeshletAABB.Min.y, (int)PosWorld.y, OldMin.y);
        InterlockedMin(g_groupMeshletAABB.Min.z, (int)PosWorld.z, OldMin.z);
#endif
        vertexID += MS_THREAD_NUM_PER_GROUP_VL;
    }

    
    if (threadID < 8)
    {
    #if defined(BOUNDS_AS_STATIC)
        float rs = meshlet.Bounds.w;
        float4 PosWorld = mul(float4(meshlet.Bounds.xyz + (g_boxVertexList[threadID].xyz * rs), 1), g_TrCommon.matWorld); // 월드공간에서의 버텍스 좌표
        if (g_TrCommon.MeshShaderInstanceCount > 0)
        {
            PosWorld = mul(PosWorld, g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서의 버텍스 좌표
        }
    #elif defined(BOUNDS_AS_DYNAMIC)
        //
        // AABB를 8개의 점으로 변환
        //
        
        //float3 boxVertexList[8] =
        //{
        //    float3(g_groupMeshletAABB.Min.x, g_groupMeshletAABB.Max.y, g_groupMeshletAABB.Max.z), //float3(-1, 1, 1),
	       // float3(g_groupMeshletAABB.Min.x, g_groupMeshletAABB.Min.y, g_groupMeshletAABB.Max.z), //float3(-1, -1, 1),
	       // float3(g_groupMeshletAABB.Max.x, g_groupMeshletAABB.Min.y, g_groupMeshletAABB.Max.z), //float3(1, -1, 1),
        //    float3(g_groupMeshletAABB.Max.x, g_groupMeshletAABB.Max.y, g_groupMeshletAABB.Max.z), //float3(1, 1, 1),
	       // float3(g_groupMeshletAABB.Min.x, g_groupMeshletAABB.Max.y, g_groupMeshletAABB.Min.z), //float3(-1, 1, -1),
	       // float3(g_groupMeshletAABB.Min.x, g_groupMeshletAABB.Min.y, g_groupMeshletAABB.Min.z), //float3(-1, -1, -1),
        //    float3(g_groupMeshletAABB.Max.x, g_groupMeshletAABB.Min.y, g_groupMeshletAABB.Min.z), //float3(1, -1, -1),
	       // float3(g_groupMeshletAABB.Max.x, g_groupMeshletAABB.Max.y, g_groupMeshletAABB.Min.z) //float3(1, 1, -1)
        //};
        float4 PosWorld = float4(
                                    g_groupMeshletAABB.Min.x * g_AABB_To_VertexList_Filter[threadID][0].x + g_groupMeshletAABB.Max.x * g_AABB_To_VertexList_Filter[threadID][0].y,
                                    g_groupMeshletAABB.Min.y * g_AABB_To_VertexList_Filter[threadID][1].x + g_groupMeshletAABB.Max.y * g_AABB_To_VertexList_Filter[threadID][1].y,
                                    g_groupMeshletAABB.Min.z * g_AABB_To_VertexList_Filter[threadID][2].x + g_groupMeshletAABB.Max.z * g_AABB_To_VertexList_Filter[threadID][2].y,
                                    1
        );
        
    #endif
        g_groupMeshletVertexList[threadID] = PosWorld;
    }
    GroupMemoryBarrierWithGroupSync();
    
    // 삼각형의 인덱스 리스트와 참조할 정점 위치를 출력
    if (threadID < 12)
    {
        uint3 IndexedTri = g_boxIndexList[threadID];
        float4 PosWorld[3] =
        {
            g_groupMeshletVertexList[IndexedTri.x],
            g_groupMeshletVertexList[IndexedTri.y],
            g_groupMeshletVertexList[IndexedTri.z]
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
		    
            // 노멀을 0에서 1사이로 포화
            pOutVertexList[BoundsVertexID].NormalColor = float4((N * 0.5f) + 0.5f, 0);
            pOutVertexList[BoundsVertexID].TexCoordDiffuse = float2(0.5, 0.5);
            //pOutVertexList[BoundsVertexID].Diffuse = float4(1, 1, 1, 1);
            //pOutVertexList[BoundsVertexID].Diffuse = float4(g_PalettedColor[meshltID % 16], 1);
            pOutVertexList[BoundsVertexID].Diffuse = float4(g_PalettedColor[meshltID % 16].xyz* cosang, 1);
            
            pOutVertexList[BoundsVertexID].Property = 0;
            pOutVertexList[BoundsVertexID].ArrayIndex = ArrayIndex;
        }
        pOutTriList[threadID] = uint3(threadID * 3 + 0, threadID * 3 + 1, threadID * 3 + 2);
    }
}
PS_TARGET psDefault(PS_INPUT input)
{
    PS_TARGET output = (PS_TARGET)0;

    float4 outColor;
    float3 NormalWorld = (input.NormalColor.rgb * 2.0) - 1.0;
    float4 NearColor = float4(1, 1, 1, 1);
    
    output.Color0 = input.Diffuse;
    output.Color1 = float4(input.NormalColor.xyz, 0);
    output.Color2 = float4(0, 0, 0, 1);
    output.Color3 = 0;
	
    return output;
}