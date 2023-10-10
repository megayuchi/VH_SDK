#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"
#include "sh_constant_buffer_shadow.hlsl"
#include "sh_constant_buffer_material.hlsl"
#include "sh_constant_buffer_instance.hlsl"
#include "sh_dynamic_physique.hlsl"
#include "sh_vl_ms_common.hlsl"
#include "sh_util.hlsl"

struct VS_OUTPUT_SHADOW
{
    float4 Pos : SV_POSITION; // Projection coord
};

struct PRIMITIVE
{
    uint RTIndex : SV_RenderTargetArrayIndex;
    //bool cull : SV_CullPrimitive;
};

#ifdef USE_SHARED_MEMORY
#if (1 == SHADER_PARAMETER_PHYSIQUE)
    groupshared D3DVLVERTEX_PHYSIQUE g_groupMemVertexList[MAX_INDEXED_VERTEX_NUM_PER_MESHLET_SHADOW_CASTER_VL];
#else
    groupshared D3DVLVERTEX g_groupMemVertexList[MAX_INDEXED_VERTEX_NUM_PER_MESHLET_SHADOW_CASTER_VL];
#endif

[NumThreads(MS_THREAD_NUM_PER_GROUP_VL, 1, 1)]
[OutputTopology("triangle")]
void msShadowCaster(
    uint threadID : SV_GroupThreadID,
    uint groupID : SV_GroupID,
    in payload Payload payload,
	out indices uint3 pOutTriList[MAX_INDEXED_TRI_NUM_PER_MESHLET_SHADOW_CASTER_VL],
    out primitives PRIMITIVE pOutPrimitiveList[MAX_INDEXED_TRI_NUM_PER_MESHLET_SHADOW_CASTER_VL],
    out vertices VS_OUTPUT_SHADOW pOutVertexList[MAX_INDEXED_VERTEX_NUM_PER_MESHLET_SHADOW_CASTER_VL]
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
	
    SetMeshOutputCounts(meshlet.IndexedVertexNum * MAX_CASCADE_NUM, meshlet.IndexedTriNum * MAX_CASCADE_NUM);
	
	// Load vertex data
    uint vertexID = threadID;
    while (vertexID < meshlet.IndexedVertexNum)
    {
        uint baseIndex = (meshlet.IndexedVertexStart + vertexID) * 2;
        uint IndexedVertex = Load16BitIndexedVertex(baseIndex);
        
        g_groupMemVertexList[vertexID] = g_Vertices[IndexedVertex];
        vertexID += MS_THREAD_NUM_PER_GROUP_VL;
    }
    GroupMemoryBarrierWithGroupSync();
	
    vertexID = threadID;
    while (vertexID < meshlet.IndexedVertexNum)
    {
        float3 PosLocal;
#if (1 == SHADER_PARAMETER_PHYSIQUE)
        VS_INPUT input;
        input.Pos = float4(g_groupMemVertexList[vertexID].Pos, 1);
        input.BlendIndex[0] = (g_groupMemVertexList[vertexID].BoneIndex & 0x000000ff);
        input.BlendIndex[1] = (g_groupMemVertexList[vertexID].BoneIndex & 0x0000ff00) >> 8;
        input.BlendIndex[2] = (g_groupMemVertexList[vertexID].BoneIndex & 0x00ff0000) >> 16;
        input.BlendIndex[3] = (g_groupMemVertexList[vertexID].BoneIndex & 0xff000000) >> 24;
        input.BlendWeight[0] = g_groupMemVertexList[vertexID].BoneWeight4.x;
        input.BlendWeight[1] = g_groupMemVertexList[vertexID].BoneWeight4.y;
        input.BlendWeight[2] = g_groupMemVertexList[vertexID].BoneWeight4.z;
        input.BlendWeight[3] = g_groupMemVertexList[vertexID].BoneWeight4.w;
        PosLocal = vsCalcBlendPos(input.Pos, input.BlendIndex, input.BlendWeight); // 블랜딩된 로컬포지션을 계산
#else
        PosLocal = g_groupMemVertexList[vertexID].Pos;
#endif
        float4 PosWorld = mul(float4(PosLocal, 1), g_TrCommon.matWorld); // 월드공간에서의 버텍스 좌표
        if (g_TrCommon.MeshShaderInstanceCount > 0)
        {            
            PosWorld = mul(PosWorld, g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서의 버텍스 좌표
        }
        for (uint i = 0; i < MAX_CASCADE_NUM; i++)
        {
            uint vertex_offset = i * meshlet.IndexedVertexNum;

            float4 PosOut = mul(PosWorld, g_ShadowCaster.matViewProjList[i]); // 프로젝션된 좌표.
            pOutVertexList[vertex_offset + vertexID].Pos = PosOut;
        }
        vertexID += MS_THREAD_NUM_PER_GROUP_VL;
    }
    //GroupMemoryBarrierWithGroupSync();
	
    uint TriIndex = threadID;
    while (TriIndex < meshlet.IndexedTriNum)
    {
        uint baseIndex = (meshlet.IndexedTriStart + TriIndex) * 3 * 2;
        uint3 IndexedTri = Load3x16BitIndexTri(baseIndex);
        for (uint i = 0; i < MAX_CASCADE_NUM; i++)
        {
            uint vertex_offset = i * meshlet.IndexedVertexNum;
            uint tri_offset = i * meshlet.IndexedTriNum;
        
            pOutTriList[tri_offset + TriIndex] = IndexedTri + uint3(vertex_offset, vertex_offset, vertex_offset);
            pOutPrimitiveList[tri_offset + TriIndex].RTIndex = i;
        }
        TriIndex += MS_THREAD_NUM_PER_GROUP_VL;
    }
}
#else
[NumThreads(MS_THREAD_NUM_PER_GROUP_VL, 1, 1)]
[OutputTopology("triangle")]
void msShadowCaster(
    uint threadID : SV_GroupThreadID,
    uint groupID : SV_GroupID,
    in payload Payload payload,
	out indices uint3 pOutTriList[MAX_INDEXED_TRI_NUM_PER_MESHLET_SHADOW_CASTER_VL],
    out primitives PRIMITIVE pOutPrimitiveList[MAX_INDEXED_TRI_NUM_PER_MESHLET_SHADOW_CASTER_VL],
    out vertices VS_OUTPUT_SHADOW pOutVertexList[MAX_INDEXED_VERTEX_NUM_PER_MESHLET_SHADOW_CASTER_VL]
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
	
    SetMeshOutputCounts(meshlet.IndexedVertexNum * MAX_CASCADE_NUM, meshlet.IndexedTriNum * MAX_CASCADE_NUM);
	
	// Load vertex data
    uint vertexID = threadID;
    while (vertexID < meshlet.IndexedVertexNum)
    {
        uint baseIndex = (meshlet.IndexedVertexStart + vertexID) * 2;
        uint IndexedVertex = Load16BitIndexedVertex(baseIndex);
#if (1 == SHADER_PARAMETER_PHYSIQUE)
        D3DVLVERTEX_PHYSIQUE vertex = g_Vertices[IndexedVertex];
#else
        D3DVLVERTEX vertex = g_Vertices[IndexedVertex];
#endif
        float3 PosLocal;
#if (1 == SHADER_PARAMETER_PHYSIQUE)
        VS_INPUT input;
        input.Pos = float4(vertex.Pos, 1);
        input.BlendIndex[0] = (vertex.BoneIndex & 0x000000ff);
        input.BlendIndex[1] = (vertex.BoneIndex & 0x0000ff00) >> 8;
        input.BlendIndex[2] = (vertex.BoneIndex & 0x00ff0000) >> 16;
        input.BlendIndex[3] = (vertex.BoneIndex & 0xff000000) >> 24;
        input.BlendWeight[0] = vertex.BoneWeight4.x;
        input.BlendWeight[1] = vertex.BoneWeight4.y;
        input.BlendWeight[2] = vertex.BoneWeight4.z;
        input.BlendWeight[3] = vertex.BoneWeight4.w;
        PosLocal = vsCalcBlendPos(input.Pos, input.BlendIndex, input.BlendWeight); // 블랜딩된 로컬포지션을 계산
#else
        PosLocal = vertex.Pos;
#endif
        float4 PosWorld = mul(float4(PosLocal, 1), g_TrCommon.matWorld); // 월드공간에서의 버텍스 좌표
        if (g_TrCommon.MeshShaderInstanceCount > 0)
        {
            PosWorld = mul(PosWorld, g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서의 버텍스 좌표
        }
        for (uint i = 0; i < MAX_CASCADE_NUM; i++)
        {
            uint vertex_offset = i * meshlet.IndexedVertexNum;

            float4 PosOut = mul(PosWorld, g_ShadowCaster.matViewProjList[i]); // 프로젝션된 좌표.
            pOutVertexList[vertex_offset + vertexID].Pos = PosOut;
        }
        vertexID += MS_THREAD_NUM_PER_GROUP_VL;
    }
    //GroupMemoryBarrierWithGroupSync();
	
    uint TriIndex = threadID;
    while (TriIndex < meshlet.IndexedTriNum)
    {
        uint baseIndex = (meshlet.IndexedTriStart + TriIndex) * 3 * 2;
        uint3 IndexedTri = Load3x16BitIndexTri(baseIndex);
        for (uint i = 0; i < MAX_CASCADE_NUM; i++)
        {
            uint vertex_offset = i * meshlet.IndexedVertexNum;
            uint tri_offset = i * meshlet.IndexedTriNum;
        
            pOutTriList[tri_offset + TriIndex] = IndexedTri + uint3(vertex_offset, vertex_offset, vertex_offset);
            pOutPrimitiveList[tri_offset + TriIndex].RTIndex = i;
        }
        TriIndex += MS_THREAD_NUM_PER_GROUP_VL;
    }
}
#endif

// The groupshared payload data to export to dispatched mesh shader threadgroups
groupshared Payload s_Payload;

[NumThreads(AS_GROUP_SIZE, 1, 1)]
void asDefault(uint gtid : SV_GroupThreadID, uint DispatchID : SV_DispatchThreadID, uint groupID : SV_GroupID)
{
    bool visible = false;
 
    bool bUseIntstancing = false;
    uint MaxInstanceCount = g_TrCommon.MeshShaderInstanceCount;
    if (MaxInstanceCount > 0)
    {
        bUseIntstancing = true;
    }
    else
    {
        MaxInstanceCount = 1;
    }
    //
    // CONSTANT_BUFFER_SHADOW_CASTER 구조체를 사용한다.
    // CONSTANT_BUFFER_DEFAULT 구조체를 억세스하게 되면 옵셋이 달라서 문제가 생긴다.
    //
    uint InstanceObjID = DispatchID / MeshletNumPerFaceGroup;
    uint meshltID = DispatchID % MeshletNumPerFaceGroup;
    
    if (InstanceObjID < MaxInstanceCount && meshltID < MeshletNumPerFaceGroup)
    {
        MESHLET meshlet = g_MeshletBuffer[meshltID];
        float4 SpherePosWorld = mul(float4(meshlet.Bounds.xyz, 1), g_TrCommon.matWorld); // 월드공간에서의 스피어 중점
        if (bUseIntstancing)
        {
            SpherePosWorld = mul(float4(SpherePosWorld.xyz, 1), g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서의 버텍스 좌표
        }
#ifdef USE_MESHLET_CULLING
        for (uint i = 0; i < MAX_CASCADE_NUM; i++)
        {
            visible |= CullSphere(g_ShadowFrustumPlanes[i], SpherePosWorld.xyz, meshlet.Bounds.w) != 0;
        }
#else
        visible = true;
#endif
    }
    // Compact visible meshlets into the export payload array
    if (visible)
    {
    // 현재 스레드가 테스트한 meshlet이 보여진다고 판단된 경우, s_Payload배열에 중복없이 원소의 빈 공간 없이 붙여서(packed) 기록
        uint index = WavePrefixCountBits(visible);
        s_Payload.MeshletID[index] = meshltID; // write meshlet index to array(packed)
        s_Payload.InstanceID[index] = InstanceObjID; // write InstanceID index to array(packed)
    }
     // Dispatch the required number of MS threadgroups to render the visible meshlets
    uint visibleCount = WaveActiveCountBits(visible);
    DispatchMesh(visibleCount, 1, 1, s_Payload);
}
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
