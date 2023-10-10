#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_constant_buffer_default.hlsl"
#include "sh_constant_buffer_material.hlsl"
#include "sh_constant_buffer_instance.hlsl"
#include "sh_util.hlsl"
#include "sh_vl_ms_common.hlsl"

// The groupshared payload data to export to dispatched mesh shader threadgroups
groupshared Payload s_Payload;

[NumThreads(AS_GROUP_SIZE, 1, 1)]
void asDefault(uint gtid : SV_GroupThreadID, uint DispatchID : SV_DispatchThreadID, uint groupID : SV_GroupID)
{
    bool visible = false;
 
    bool bUseIntstancing = false;
    uint MaxInstanceCount = g_MeshShaderInstanceCount;
    if (MaxInstanceCount > 0)
    {
        bUseIntstancing = true;
    }
    else
    {
        MaxInstanceCount = 1;
    }
    //
    //CONSTANT_BUFFER_SHADOW_CASTER구조체와CONSTANT_BUFFER_DEFAULT구조체중 어느쪽을 억세스 하는가?
    //
    uint InstanceObjID = DispatchID / MeshletNumPerFaceGroup;
    uint meshltID = DispatchID % MeshletNumPerFaceGroup;
    
    if (InstanceObjID < MaxInstanceCount && meshltID < MeshletNumPerFaceGroup)
    {
        MESHLET meshlet = g_MeshletBuffer[meshltID];
        float4 SpherePosWorld = mul(float4(meshlet.Bounds.xyz, 1), matWorld); // 월드공간에서의 스피어 중점
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
/*

[NumThreads(AS_GROUP_SIZE, 1, 1)]
void asDefault(uint gtid : SV_GroupThreadID, uint DispatchID : SV_DispatchThreadID, uint groupID : SV_GroupID)
{
    bool visible = false;
    
    // instancing사용할 경우, DispatchID = MeshletNumPerFaceGroup * Instance Cout - 1;
    uint InstanceObjID = DispatchID / MeshletNumPerFaceGroup;
    uint meshltID = DispatchID % MeshletNumPerFaceGroup;
   
    if (meshltID < MeshletNumPerFaceGroup)
    {
        MESHLET meshlet = g_MeshletBuffer[meshltID];
        float4 SpherePosWorld = mul(float4(meshlet.Bounds.xyz, 1), matWorld); // 월드공간에서의 스피어 중점
        
        if (g_MeshShaderInstanceCount > 0)
        {
            // 인스턴싱 사용
            if (InstanceObjID < g_MeshShaderInstanceCount)
            {
                SpherePosWorld = mul(float4(SpherePosWorld.xyz, 1), g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서의 버텍스 좌표
            }
        }
        else
        {
            // 인스턴싱 사용하지 않음.
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
*/