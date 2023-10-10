
//#define SHADER_PARAMETER_ATT_LIGHT	1
//#define SHADER_PARAMETER_PHYSIQUE		1
//#define SHADER_PARAMETER_LIGHT_PRB	1
//#define SHADER_PARAMETER_USE_OIT		1
//#define SHADER_PARAMETER_USE_TILED_RESOURCES 1
//#define LIGHTING_TYPE	0	//(vlmesh에서 LIGHTING_TYPE이 0인 경우는 없다.)
#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_dynamic_common.hlsl"
#include "sh_constant_buffer_default.hlsl"
#include "sh_constant_buffer_instance.hlsl"
#include "sh_att_light.hlsl"
#include "sh_vl_ms_common.hlsl"

StructuredBuffer<float2> g_TexCoordVertices : register(t4);

#ifdef USE_SHARED_MEMORY
#if (1 == SHADER_PARAMETER_PHYSIQUE)
    groupshared D3DVLVERTEX_PHYSIQUE g_groupMemVertexList[MAX_INDEXED_VERTEX_NUM_PER_MESHLET_VL];
#else
groupshared D3DVLVERTEX g_groupMemVertexList[MAX_INDEXED_VERTEX_NUM_PER_MESHLET_VL];
#endif
groupshared float2 g_groupMemTexCoordVertexList[MAX_INDEXED_VERTEX_NUM_PER_MESHLET_VL];

[NumThreads(MS_THREAD_NUM_PER_GROUP_VL, 1, 1)]
[OutputTopology("triangle")]
void msDynamicVL(
    uint threadID : SV_GroupThreadID,
    uint groupID : SV_GroupID,
    in payload Payload payload,
	out indices uint3 pOutTriList[MAX_INDEXED_TRI_NUM_PER_MESHLET_VL],
    out vertices VS_OUTPUT pOutVertexList[MAX_INDEXED_VERTEX_NUM_PER_MESHLET_VL]
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
	
    SetMeshOutputCounts(meshlet.IndexedVertexNum, meshlet.IndexedTriNum);
	
	// Load vertex data
    uint vertexID = threadID;
    while (vertexID < meshlet.IndexedVertexNum)
    {
        uint baseIndex = (meshlet.IndexedVertexStart + vertexID) * 2;
        uint IndexedVertex = Load16BitIndexedVertex(baseIndex);
        
        g_groupMemVertexList[vertexID] = g_Vertices[IndexedVertex];
        g_groupMemTexCoordVertexList[vertexID] = g_TexCoordVertices[IndexedVertex];
        vertexID += MS_THREAD_NUM_PER_GROUP_VL;
    }
    GroupMemoryBarrierWithGroupSync();
	
    vertexID = threadID;
    while (vertexID < meshlet.IndexedVertexNum)
    {
        VS_INPUT input;
	
        float3 PosLocal;
        float3 NormalLocal;
        float3 TangentLocal;

        input.Pos = float4(g_groupMemVertexList[vertexID].Pos, 1);
        input.Normal = float3(g_groupMemVertexList[vertexID].Normal);
        input.Tangent = float4(g_groupMemVertexList[vertexID].Tangent.xyz, 0);
        input.TexCoord = g_groupMemTexCoordVertexList[vertexID];

#if (1 == SHADER_PARAMETER_PHYSIQUE)
        input.BlendIndex[0] = (g_groupMemVertexList[vertexID].BoneIndex & 0x000000ff);
        input.BlendIndex[1] = (g_groupMemVertexList[vertexID].BoneIndex & 0x0000ff00) >> 8;
        input.BlendIndex[2] = (g_groupMemVertexList[vertexID].BoneIndex & 0x00ff0000) >> 16;
        input.BlendIndex[3] = (g_groupMemVertexList[vertexID].BoneIndex & 0xff000000) >> 24;
        input.BlendWeight[0] = g_groupMemVertexList[vertexID].BoneWeight4.x;
        input.BlendWeight[1] = g_groupMemVertexList[vertexID].BoneWeight4.y;
        input.BlendWeight[2] = g_groupMemVertexList[vertexID].BoneWeight4.z;
        input.BlendWeight[3] = g_groupMemVertexList[vertexID].BoneWeight4.w;
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
        float3 NormalWorld = mul(NormalLocal, (float3x3)g_TrCommon.matWorld); // 월드공간에서 노말
        float3 TangentWorld = mul(TangentLocal, (float3x3)g_TrCommon.matWorld); // 월드공간에서 노말
        if (g_TrCommon.MeshShaderInstanceCount > 0)
        {
            PosWorld = mul(PosWorld, g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서의 버텍스 좌표
            NormalWorld = mul(NormalWorld, (float3x3)g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서 노말
            TangentWorld = mul(TangentWorld, (float3x3)g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서 노말
        }
        NormalWorld = normalize(NormalWorld); // 다시 노멀라이즈(스케일이 들어있을 경우를 대비해서)
        TangentWorld = normalize(TangentWorld); // 다시 노멀라이즈(스케일이 들어있을 경우를 대비해서)
        float4 PosOut = mul(PosWorld, g_Camera.matViewProjArray[ArrayIndex]); // 프로젝션된 좌표.

        pOutVertexList[vertexID].Pos = PosOut;
        pOutVertexList[vertexID].Dist = PosOut.w;
        pOutVertexList[vertexID].PosWorld = PosWorld; // 월드 좌표
        pOutVertexList[vertexID].Clip = dot(PosWorld, ClipPlane); // 클립플레인처리        
		
	    // 노멀을 0에서 1사이로 포화
        pOutVertexList[vertexID].NormalColor = float4((NormalWorld * 0.5f) + 0.5f, 0);
        pOutVertexList[vertexID].TexCoordDiffuse = input.TexCoord;
#if (0 == LIGHTING_TYPE)
		// MtlDiffuse + MtlAmbient
		//pOutVertexList[vertexID].Diffuse = float4(MtlDiffuse.rgb + MtlAmbient.rgb,MtlDiffuse.a);
		pOutVertexList[vertexID].Diffuse = float4(1, 1, 1, 1);
#else
        float cosang = saturate(dot(NormalWorld, (float3)(-LightDir)));
        cosang = max(MinNdotL.a, cosang);
        pOutVertexList[vertexID].Diffuse = float4(cosang, cosang, cosang, 1);
#endif
#ifdef SHOW_MESHLET
        pOutVertexList[vertexID].Diffuse = float4(g_PalettedColor[meshltID % 16], 1);
#endif
        uint Property = g_groupMemVertexList[vertexID].Property;
		
		//float ElementColor = (float)((Property & 0x000000ff)) / 255.0;
		//Diffuse = float4(ElementColor, ElementColor, ElementColor, 1);
        pOutVertexList[vertexID].Property = Property;
#if (1 == SHADER_PARAMETER_ATT_LIGHT)
		// 다이나믹 라이트가 있는 경우
		for (int i = 0; i < iAttLightNum; i++)
		{
			float3		LightVec = normalize((AttLight[i].Pos.xyz - PosWorld.xyz));
			pOutVertexList[vertexID].NdotL[i] = dot(NormalWorld, LightVec);
		}
#endif        
        pOutVertexList[vertexID].ArrayIndex = ArrayIndex;
        vertexID += MS_THREAD_NUM_PER_GROUP_VL;
    }
    //GroupMemoryBarrierWithGroupSync();
	
    uint TriIndex = threadID;
    while (TriIndex < meshlet.IndexedTriNum)
    {
		//WORD wGroupVertexIndex = pGlobalIndexedTriList[(pMeshletList[m].dwIndexedTriStart + i) * 3 + j];
        uint baseIndex = (meshlet.IndexedTriStart + TriIndex) * 3 * 2;
        uint3 IndexedTri = Load3x16BitIndexTri(baseIndex);
		
        pOutTriList[TriIndex] = IndexedTri;
        TriIndex += MS_THREAD_NUM_PER_GROUP_VL;
    }
}
#else
[NumThreads(MS_THREAD_NUM_PER_GROUP_VL, 1, 1)]
[OutputTopology("triangle")]
void msDynamicVL(
    uint threadID : SV_GroupThreadID,
    uint groupID : SV_GroupID,
    in payload Payload payload,
	out indices uint3 pOutTriList[MAX_INDEXED_TRI_NUM_PER_MESHLET_VL],
    out vertices VS_OUTPUT pOutVertexList[MAX_INDEXED_VERTEX_NUM_PER_MESHLET_VL]
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
	
    SetMeshOutputCounts(meshlet.IndexedVertexNum, meshlet.IndexedTriNum);
    
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
        float2 tvertex = g_TexCoordVertices[IndexedVertex];

    	VS_INPUT input = (VS_INPUT)0;
        input.Pos = float4(vertex.Pos, 1);
        input.Normal = float3(vertex.Normal);
        input.Tangent = float4(vertex.Tangent.xyz, 0);
        input.TexCoord = tvertex;
        
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
        float3 NormalWorld = mul(NormalLocal, (float3x3)g_TrCommon.matWorld); // 월드공간에서 노말
        float3 TangentWorld = mul(TangentLocal, (float3x3)g_TrCommon.matWorld); // 월드공간에서 탄젠트
        if (g_TrCommon.MeshShaderInstanceCount > 0)
        {
            PosWorld = mul(PosWorld, g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서의 버텍스 좌표
            NormalWorld = mul(NormalWorld, (float3x3)g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서 노말
            TangentWorld = mul(TangentWorld, (float3x3)g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서 탄젠트
        }
        
        NormalWorld = normalize(NormalWorld); // 다시 노멀라이즈(스케일이 들어있을 경우를 대비해서)
        TangentWorld = normalize(TangentWorld); // 다시 노멀라이즈(스케일이 들어있을 경우를 대비해서)
        float4 PosOut = mul(PosWorld, g_Camera.matViewProjArray[ArrayIndex]); // 프로젝션된 좌표.

        pOutVertexList[vertexID].Pos = PosOut;
        pOutVertexList[vertexID].Dist = PosOut.w;
        pOutVertexList[vertexID].PosWorld = PosWorld; // 월드 좌표
        pOutVertexList[vertexID].Clip = dot(PosWorld, ClipPlane); // 클립플레인처리        
		
	    // 노멀을 0에서 1사이로 포화
        pOutVertexList[vertexID].NormalColor = float4((NormalWorld * 0.5f) + 0.5f, 0);
        pOutVertexList[vertexID].TexCoordDiffuse = input.TexCoord;
#if (0 == LIGHTING_TYPE)
		// MtlDiffuse + MtlAmbient
		//pOutVertexList[vertexID].Diffuse = float4(MtlDiffuse.rgb + MtlAmbient.rgb,MtlDiffuse.a);
		pOutVertexList[vertexID].Diffuse = float4(1, 1, 1, 1);
#else
        float cosang = saturate(dot(NormalWorld, (float3)(-LightDir)));
        cosang = max(MinNdotL.a, cosang);
        pOutVertexList[vertexID].Diffuse = float4(cosang, cosang, cosang, 1);
#endif
#ifdef SHOW_MESHLET
        pOutVertexList[vertexID].Diffuse = float4(g_PalettedColor[meshltID % 16], 1);
#endif
        uint Property = vertex.Property;
		
		//float ElementColor = (float)((Property & 0x000000ff)) / 255.0;
		//Diffuse = float4(ElementColor, ElementColor, ElementColor, 1);
        pOutVertexList[vertexID].Property = Property;
#if (1 == SHADER_PARAMETER_ATT_LIGHT)
		// 다이나믹 라이트가 있는 경우
		for (int i = 0; i < iAttLightNum; i++)
		{
			float3		LightVec = normalize((AttLight[i].Pos.xyz - PosWorld.xyz));
			pOutVertexList[vertexID].NdotL[i] = dot(NormalWorld, LightVec);
		}
#endif        
        pOutVertexList[vertexID].ArrayIndex = ArrayIndex;
        vertexID += MS_THREAD_NUM_PER_GROUP_VL;
    }
    //GroupMemoryBarrierWithGroupSync();
	
    uint TriIndex = threadID;
    while (TriIndex < meshlet.IndexedTriNum)
    {
		//WORD wGroupVertexIndex = pGlobalIndexedTriList[(pMeshletList[m].dwIndexedTriStart + i) * 3 + j];
        uint baseIndex = (meshlet.IndexedTriStart + TriIndex) * 3 * 2;
        uint3 IndexedTri = Load3x16BitIndexTri(baseIndex);
		
        pOutTriList[TriIndex] = IndexedTri;
        TriIndex += MS_THREAD_NUM_PER_GROUP_VL;
    }
}
#endif

PS_TARGET psDefault(PS_INPUT input)
{
    PS_TARGET output = (PS_TARGET)0;


    float4 texColor = texDiffuse.Sample(samplerWrap, input.TexCoordDiffuse);

    float4 outColor;
    float3 NormalWorld = (input.NormalColor.rgb * 2.0) - 1.0;
    float4 NearColor = float4(1, 1, 1, 1);

//output.Color0 = texColor;
//output.Color0 = input.Diffuse;
    output.Color0 = input.Diffuse * texColor;
//output.Color0 = float4(input.Diffuse.xyz * input.NormalColor.xyz, 1);
//output.Color0 = float4(input.NormalColor.xyz, 0);//input.Diffuse;
    output.Color1 = float4(input.NormalColor.xyz, 0);
    output.Color2 = float4(0, 0, 0, 1);
    output.Color3 = 0;
	
    return output;
}

// 처음에는 shadow caster shader와 Amplification Shader 코드를 공유했었다.
// 그러나 Amplification Shader만 적용하면 그림자가 인스턴스가 0번 빼고 몽땅 출력 안되는 현상이 발생했다.
// 이는 asDefault shader에서 sh_constant_buffer_default.hlsl을 include했고 따라서 CONSTANT_BUFFER_DEFAULT구조체를 사용하고 있었기 때문. 
// shadow caster shader에선 sh_constant_buffer_shadow.hlsl의 CONSTANT_BUFFER_SHADOW_CASTER구조체를 사용해야 한다.

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
    // CONSTANT_BUFFER_DEFAULT 구조체를 사용한다.
    // CONSTANT_BUFFER_SHADOW_CASTER 구조체를 억세스하게 되면 옵셋이 달라서 문제가 생긴다.
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
        visible = CullSphere(g_FrustumPlanes, SpherePosWorld.xyz, meshlet.Bounds.w) != 0;
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