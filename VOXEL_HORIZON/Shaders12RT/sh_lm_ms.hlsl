//#define SHADER_PARAMETER_ATT_LIGHT	1
//#define SHADER_PARAMETER_USE_OIT 1

#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_constant_buffer_default.hlsl"
#include "sh_constant_buffer_material.hlsl"
#include "sh_att_light.hlsl"
#include "sh_lm_common.hlsl"
#include "sh_ms_common.hlsl"
#include "sh_constant_buffer_instance.hlsl"

StructuredBuffer<D3DVLVERTEX> g_Vertices : register(t3);
StructuredBuffer<float2> g_TexCoordVertices : register(t4);

#define MS_THREAD_NUM_PER_GROUP_LM 64

[NumThreads(MS_THREAD_NUM_PER_GROUP_LM, 1, 1)]
[OutputTopology("triangle")]
void msDefault(
    uint threadID : SV_GroupThreadID,
    uint groupID : SV_GroupID,
    in payload Payload payload,
	out indices uint3 pOutTriList[MAX_INDEXED_TRI_NUM_PER_MESHLET_LM],
    out vertices VS_OUTPUT_LM pOutVertexList[MAX_INDEXED_VERTEX_NUM_PER_MESHLET_LM]
)
{
    uint ArrayIndex = 0;
	
// FaceGroup ������ DispatchMesh()�� ȣ��ȴ�.
// ���� ������ ���� ó���� �� �ִ�.
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
	
    SetMeshOutputCounts(meshlet.IndexedVertexNum, meshlet.IndexedTriNum);
    
    uint vertexID = threadID;
    while (vertexID < meshlet.IndexedVertexNum)
    {
        uint baseIndex = (meshlet.IndexedVertexStart + vertexID) * 2;
        uint IndexedVertex = Load16BitIndexedVertex(baseIndex);

		// Vertex Transform
        D3DVLVERTEX vertex = g_Vertices[IndexedVertex];

    	VS_INPUT_LM input = (VS_INPUT_LM)0;
      
        float2 tvertex = g_TexCoordVertices[IndexedVertex];
   	
        input.Pos = float4(vertex.Pos, 1);
        input.Normal = float3(vertex.Normal);
        input.Tangent = float4(vertex.Tangent.xyz, 0);
        input.TexCoordDiffuse = tvertex;
		
        uint ArrayIndex = input.instId % 2;
		float4 PosWorld = mul(input.Pos, g_TrCommon.matWorld); // ������������� ���ؽ� ��ǥ
        float3 NormalWorld = mul(input.Normal, (float3x3)g_TrCommon.matWorld); // ����������� �븻
        float3 TangentWorld = mul(input.Tangent, (float3x3)g_TrCommon.matWorld); // ����������� ź��Ʈ
		// LMMesh���� instancing��� ����. �� �ڵ带 �츮���� RootSignature���� CBV 7���� �����ؾ���. ������ �ν��Ͻ� ���Ұǵ� b7�����ϱ� �Ⱦ �ڵ带 �ּ�ó�� ��.
        //if (g_TrCommon.MeshShaderInstanceCount > 0)
        //{
        //    PosWorld = mul(PosWorld, g_InstanceMatWorldList[InstanceObjID]); // ������������� ���ؽ� ��ǥ
        //    NormalWorld = mul(NormalWorld, (float3x3)g_InstanceMatWorldList[InstanceObjID]); // ����������� �븻
        //    TangentWorld = mul(TangentWorld, (float3x3)g_InstanceMatWorldList[InstanceObjID]); // ����������� �븻
        //}
		float4 PosOut = mul(PosWorld, g_Camera.matViewProjArray[ArrayIndex]); // �������ǵ� ��ǥ.
		pOutVertexList[vertexID].Pos = PosOut;
        pOutVertexList[vertexID].Dist = PosOut.w;
        pOutVertexList[vertexID].PosWorld = PosWorld; // ���� ��ǥ
		pOutVertexList[vertexID].TexCoordDiffuse = input.TexCoordDiffuse;
		pOutVertexList[vertexID].Normal = normalize(NormalWorld); // �ٽ� ��ֶ�����(�������� ������� ��츦 ����ؼ�)
        pOutVertexList[vertexID].Tangent = normalize(TangentWorld); // �ٽ� ��ֶ�����(�������� ������� ��츦 ����ؼ�)
        
        pOutVertexList[vertexID].Diffuse = float4(1, 1, 1, 1);
#ifdef SHOW_MESHLET
        pOutVertexList[vertexID].Diffuse = float4(g_PalettedColor[meshltID % 16], 1);
#endif
        pOutVertexList[vertexID].Clip = dot(float4(PosWorld.xyz, 1), ClipPlane);
        pOutVertexList[vertexID].ArrayIndex = ArrayIndex;
        vertexID += MS_THREAD_NUM_PER_GROUP_LM;
    }
    //GroupMemoryBarrierWithGroupSync();
	
    uint TriIndex = threadID;
    while (TriIndex < meshlet.IndexedTriNum)
    {
		//WORD wGroupVertexIndex = pGlobalIndexedTriList[(pMeshletList[m].dwIndexedTriStart + i) * 3 + j];
        uint baseIndex = (meshlet.IndexedTriStart + TriIndex) * 3 * 2;
        uint3 IndexedTri = Load3x16BitIndexTri(baseIndex);
		
        pOutTriList[TriIndex] = IndexedTri;
        TriIndex += MS_THREAD_NUM_PER_GROUP_LM;
    }
}

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
    // CONSTANT_BUFFER_DEFAULT ����ü�� ����Ѵ�.
    // CONSTANT_BUFFER_SHADOW_CASTER ����ü�� �＼���ϰ� �Ǹ� �ɼ��� �޶� ������ �����.
    //
    uint InstanceObjID = DispatchID / MeshletNumPerFaceGroup;
    uint meshltID = DispatchID % MeshletNumPerFaceGroup;
    
    if (InstanceObjID < MaxInstanceCount && meshltID < MeshletNumPerFaceGroup)
    {
        MESHLET meshlet = g_MeshletBuffer[meshltID];
        float4 SpherePosWorld = mul(float4(meshlet.Bounds.xyz, 1), g_TrCommon.matWorld); // ������������� ���Ǿ� ����
		// LMMesh���� instancing��� ����. �� �ڵ带 �츮���� RootSignature���� CBV 7���� �����ؾ���. ������ �ν��Ͻ� ���Ұǵ� b7�����ϱ� �Ⱦ �ڵ带 �ּ�ó�� ��.
        //if (bUseIntstancing)
        //{
        //    SpherePosWorld = mul(float4(SpherePosWorld.xyz, 1), g_InstanceMatWorldList[InstanceObjID]); // ������������� ���ؽ� ��ǥ
        //}
#ifdef USE_MESHLET_CULLING
        visible = CullSphere(g_FrustumPlanes, SpherePosWorld.xyz, meshlet.Bounds.w) != 0;
#else
        visible = true;
#endif
    }
    // Compact visible meshlets into the export payload array
    if (visible)
    {
    // ���� �����尡 �׽�Ʈ�� meshlet�� �������ٰ� �Ǵܵ� ���, s_Payload�迭�� �ߺ����� ������ �� ���� ���� �ٿ���(packed) ���
        uint index = WavePrefixCountBits(visible);
        s_Payload.MeshletID[index] = meshltID; // write meshlet index to array(packed)
        s_Payload.InstanceID[index] = InstanceObjID; // write InstanceID index to array(packed)
    }
     // Dispatch the required number of MS threadgroups to render the visible meshlets
    uint visibleCount = WaveActiveCountBits(visible);
    DispatchMesh(visibleCount, 1, 1, s_Payload);
}

float4 psDiffuse(VS_OUTPUT_LM input) : SV_Target
{
	float4 outColor = input.Diffuse;

	return outColor;
}
