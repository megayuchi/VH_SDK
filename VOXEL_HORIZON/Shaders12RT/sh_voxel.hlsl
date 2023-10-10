#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_constant_buffer_default.hlsl"
#include "sh_dynamic_common.hlsl"
#include "sh_voxel_common.hlsl"
#include "sh_att_light.hlsl"

//Texture2D		texDiffuse		: register(t0) - voxel palette(tex) - texDiffuse
Texture2D<uint> texVoxelPaletteMtl : register(t1); // voxel palette(mtl)
struct VS_OUTPUT_VX
{
    float4 Pos : SV_POSITION;
    float4 PaletteTexCoord : TEXCOORD0; // Palette Tex Coord
    float4 PosWorld : TEXCOORD1;
    float3 Normal : NORMAL;
    float3 Tangent : TANGENT;
    float Clip : SV_ClipDistance;
    uint BulbOn : BLENDINDICES0;
    uint PaletteIndex : BLENDINDICES1;
    uint ArrayIndex : BLENDINDICES2;
#if (1 == VS_RTV_ARRAY)
	uint    RTVIndex     : SV_RenderTargetArrayIndex;
#endif

};
struct GS_OUTPUT_VX : VS_OUTPUT_VX
{
#if (1 != VS_RTV_ARRAY)
    uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};

struct PS_INPUT_VX : VS_OUTPUT_VX
{
};

VS_OUTPUT_VX vsDefault(VS_INPUT_VX input)
{
    VS_OUTPUT_VX output = (VS_OUTPUT_VX)0;

    uint cb_BulbOn = 0;
    float cb_VoxelSize = 0;
    uint cb_VoxelObjIndex = 0;
    uint cb_VoxelsPerAxis = 0;
    cb_VoxelsPerAxis = GetVoxelConstFromPackedProperty(cb_BulbOn, cb_VoxelSize, cb_VoxelObjIndex, g_PackedProperty);

	// uint	g_PackedProperty;			// Reserved | Bulb On/Off | VoxelsPerAxis | MaterialPreset | VoxelObjIndex 
	// uint2	VoxelsPerAxis_Size;		// x= Number of Voxels per axis, y = Size of Voxel

    uint ArrayIndex = input.instId % 2;

    uint WidthDepthHeight = cb_VoxelsPerAxis;
    uint TexWidthHeightPerQuad = TEX_WIDTH_DEPTH_HEIGHT_PER_VOXEL_OBJECT / WidthDepthHeight;
    float VoxelSize = cb_VoxelSize;
    float VoxelSizeHalf = VoxelSize * 0.5f;

    uint3 oPos = 0;
    uint3 vPos = 0;
    float4 InputPos = float4(GetPosition(oPos, vPos, input.PackedData, VoxelSize), 1);
    float3 VoxelCenter = GetVoxelCenterPosition(oPos, VoxelSize, VoxelSizeHalf);

    InputPos.xyz = ((InputPos.xyz - VoxelCenter.xyz) * g_VoxelScale) + VoxelCenter.xyz;
    uint QuadIndex = GetQuadIndex(input.PackedData);
    uint PosBits = GetPosBitsInQuad(input.PackedData);


    float4 PosWorld = mul(InputPos, g_matWorldVoxel); // 월드공간에서의 버텍스 좌표

    uint AxisIndex = 0;
    float3 TangentWorld;
    float3 NormalWorld = GetNormalAndTangent(TangentWorld, AxisIndex, input.PackedData);
	//output.Pos = mul(InputPos, mul(g_matWorldVoxel, matViewProjArray[ArrayIndex]));	// 프로젝션된 좌표. 위에서 월드좌표(PosWorld)를 구해놨으니 mul(g_matWorldVoxel, matViewProjArray[ArrayIndex])는 필요없다.
    output.Pos = mul(PosWorld, g_Camera.matViewProjArray[ArrayIndex]); // 프로젝션된 좌표.
    output.Clip = dot(PosWorld, ClipPlane);
    output.PosWorld = PosWorld;

    output.Normal = NormalWorld;
    output.Tangent = TangentWorld;

	// Palette Index
    uint PaletteIndex = GetPaletteIndex(int3(oPos.x, oPos.y, oPos.z));
    output.PaletteTexCoord.xy = GetVoxelPaletteTexCoord(PaletteIndex, AxisIndex, oPos, vPos, WidthDepthHeight);
    output.PaletteIndex = PaletteIndex;
	//output.PaletteTexCoord.x = ((float)PaletteIndex / 255) + (0.5 / 255);
	//output.PaletteTexCoord.y = 0.5;

    output.BulbOn = cb_BulbOn;
    output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif

    return output;
}

[maxvertexcount(3)]
void gsDefault(triangle VS_OUTPUT_VX input[3], inout TriangleStream<GS_OUTPUT_VX> TriStream)
{
    GS_OUTPUT_VX output[3];

	[unroll]
    for (uint i = 0; i < 3; i++)
    {
        output[i].Pos = input[i].Pos;
        output[i].PaletteTexCoord = input[i].PaletteTexCoord;
        output[i].Normal = input[i].Normal;
        output[i].Tangent = input[i].Tangent;
        output[i].PaletteIndex = input[i].PaletteIndex;
        output[i].Clip = input[i].Clip;
        output[i].PosWorld = input[i].PosWorld;
        output[i].ArrayIndex = input[i].ArrayIndex;
        output[i].BulbOn = input[i].BulbOn;
        output[i].RTVIndex = input[i].ArrayIndex;
        TriStream.Append(output[i]);
    }
}
PS_TARGET psDefault(PS_INPUT_VX input)
{
    PS_TARGET OutColor = (PS_TARGET)0;

    float4 texColorDiffuse = texDiffuse.Sample(samplerClamp, input.PaletteTexCoord.xy);
	// 전구에 불 켜진 상태
    texColorDiffuse.rgb += (texColorDiffuse.rgb * input.BulbOn);

	//uint4	nCoords = uint4(sx, sy, f, 0);
    uint3 mtlCoord = uint3(input.PaletteIndex, 0, 0);
    uint mtlPresetIndex = texVoxelPaletteMtl.Load(mtlCoord).r;
	// texColorDiffuse.a에 MtlPresetIndex가 들어있다.
	//uint mtlPresetIndex = texColorDiffuse.a * 255.0;
	
    float3 texNormal = float3(0.5, 0.5, 1);

    float3 binormal = cross(input.Tangent, input.Normal);
    float3 tan_normal = texNormal * 2 - 1;
    float3 surfaceNormal = (tan_normal.xxx * input.Tangent) + (tan_normal.yyy * binormal) + (tan_normal.zzz * input.Normal);
	
    OutColor.Color0 = float4(texColorDiffuse.rgb, 1);
    OutColor.Color1 = float4(surfaceNormal * 0.5 + 0.5, (float)Property / 255.0f);
	//OutColor.Color2 = float4(0, (float)mtlPresetIndex / 255.0, (float)ShadingType / 255.0, 0);
    OutColor.Color2 = float4(0, (float)mtlPresetIndex / 255, (float)g_TrCommon.ShadingType / 255.0, 0); // mtlPresetIndex -> 255를 곱해서 OutColor에 써넣을때 다시 255로 나눌것이므로 아예 normalized된 값으로 전달한다.
    return OutColor;
}


struct PS_INPUT_DEPTH
{
    float4 Pos : SV_POSITION;
    float Depth : ZDEPTH;
};

PS_INPUT_DEPTH vsDepthDist(VS_INPUT_VX input)
{
    PS_INPUT_DEPTH output = (PS_INPUT_DEPTH)0;

    uint cb_BulbOn = 0;
    float cb_VoxelSize = 0;
    uint cb_VoxelObjIndex = 0;
    uint cb_VoxelsPerAxis = 0;
    cb_VoxelsPerAxis = GetVoxelConstFromPackedProperty(cb_BulbOn, cb_VoxelSize, cb_VoxelObjIndex, g_PackedProperty);

    float VoxelSize = cb_VoxelSize;
    uint3 oPos = 0;
    uint3 vPos = 0;
    float4 InputPos = float4(GetPosition(oPos, vPos, input.PackedData, VoxelSize), 1);


    output.Pos = mul(InputPos, mul(g_matWorldVoxel, g_Camera.matViewProjCommon));
    output.Depth = output.Pos.w * ProjConstant.fFarRcp;


    return output;
}

float4 psDepthDist(PS_INPUT_DEPTH input) : SV_Target
{
    float4 outColor = float4(input.Depth, input.Depth, input.Depth, 1);
    return outColor;
}