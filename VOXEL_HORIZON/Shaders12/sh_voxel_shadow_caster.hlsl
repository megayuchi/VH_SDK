#include "sh_voxel_common.hlsl"
#include "sh_constant_buffer_shadow.hlsl"

struct PS_OUT_TEX_ARRAY
{
    float4 Pos : SV_POSITION; // Projection coord
    uint RTIndex : SV_RenderTargetArrayIndex;
};

struct GS_INPUT
{
    float4 Pos : POSITION;
};

float4 vsShadowCaster(VS_INPUT_VX input) : POSITION
{
    uint cb_BulbOn = 0;
    float cb_VoxelSize = 0;
    uint cb_VoxelObjIndex = 0;
    uint cb_VoxelsPerAxis = 0;
    cb_VoxelsPerAxis = GetVoxelConstFromPackedProperty(cb_BulbOn, cb_VoxelSize, cb_VoxelObjIndex, g_PackedProperty);

    float VoxelSize = cb_VoxelSize;

    uint3 oPos = 0;
    uint3 vPos = 0;
    float4 InputPos = float4(GetPosition(oPos, vPos, input.PackedData, VoxelSize), 1);

    return InputPos;
}

[maxvertexcount(3 * MAX_CASCADE_NUM)]
void gsShadowCaster(triangle GS_INPUT input[3], inout TriangleStream<PS_OUT_TEX_ARRAY> TriStream)
{
    PS_OUT_TEX_ARRAY output[3];
    for (uint i = 0; i < MAX_CASCADE_NUM; i++)
    {
        for (uint j = 0; j < 3; j++)
        {
            output[j].Pos = mul(input[j].Pos, mul(g_matWorldVoxel, g_ShadowCaster.matViewProjList[i]));
            output[j].RTIndex = i;
            TriStream.Append(output[j]);
        }
        TriStream.RestartStrip();
    }
}
