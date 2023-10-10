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
    //CONSTANT_BUFFER_SHADOW_CASTER����ü��CONSTANT_BUFFER_DEFAULT����ü�� ������� �＼�� �ϴ°�?
    //
    uint InstanceObjID = DispatchID / MeshletNumPerFaceGroup;
    uint meshltID = DispatchID % MeshletNumPerFaceGroup;
    
    if (InstanceObjID < MaxInstanceCount && meshltID < MeshletNumPerFaceGroup)
    {
        MESHLET meshlet = g_MeshletBuffer[meshltID];
        float4 SpherePosWorld = mul(float4(meshlet.Bounds.xyz, 1), matWorld); // ������������� ���Ǿ� ����
        if (bUseIntstancing)
        {
            SpherePosWorld = mul(float4(SpherePosWorld.xyz, 1), g_InstanceMatWorldList[InstanceObjID]); // ������������� ���ؽ� ��ǥ
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
    // ���� �����尡 �׽�Ʈ�� meshlet�� �������ٰ� �Ǵܵ� ���, s_Payload�迭�� �ߺ����� ������ �� ���� ���� �ٿ���(packed) ���
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
    
    // instancing����� ���, DispatchID = MeshletNumPerFaceGroup * Instance Cout - 1;
    uint InstanceObjID = DispatchID / MeshletNumPerFaceGroup;
    uint meshltID = DispatchID % MeshletNumPerFaceGroup;
   
    if (meshltID < MeshletNumPerFaceGroup)
    {
        MESHLET meshlet = g_MeshletBuffer[meshltID];
        float4 SpherePosWorld = mul(float4(meshlet.Bounds.xyz, 1), matWorld); // ������������� ���Ǿ� ����
        
        if (g_MeshShaderInstanceCount > 0)
        {
            // �ν��Ͻ� ���
            if (InstanceObjID < g_MeshShaderInstanceCount)
            {
                SpherePosWorld = mul(float4(SpherePosWorld.xyz, 1), g_InstanceMatWorldList[InstanceObjID]); // ������������� ���ؽ� ��ǥ
            }
        }
        else
        {
            // �ν��Ͻ� ������� ����.
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
        // ���� �����尡 �׽�Ʈ�� meshlet�� �������ٰ� �Ǵܵ� ���, s_Payload�迭�� �ߺ����� ������ �� ���� ���� �ٿ���(packed) ���
        uint index = WavePrefixCountBits(visible);
        s_Payload.MeshletID[index] = meshltID; // write meshlet index to array(packed)
        s_Payload.InstanceID[index] = InstanceObjID; // write InstanceID index to array(packed)
    }

    // Dispatch the required number of MS threadgroups to render the visible meshlets
    uint visibleCount = WaveActiveCountBits(visible);
    DispatchMesh(visibleCount, 1, 1, s_Payload);
}
*/