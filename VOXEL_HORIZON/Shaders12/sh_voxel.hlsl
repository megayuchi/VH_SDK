#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_constant_buffer_default.hlsl"
#include "sh_dynamic_common.hlsl"
#include "sh_voxel_common.hlsl"
#include "sh_att_light.hlsl"
#include "bxdf.hlsl"

//#define SHADER_PARAMETER_SPHEREMAP 1

Texture2D texLight : register(t1);
Texture2D texSphereMap : register(t2);

struct VS_OUTPUT_VX
{
    float4 Pos : SV_POSITION;
    float4 PaletteTexCoord : TEXCOORD0; // Palette Tex Coord
    float2 LightTexCoord : TEXCOORD1; // Light Tex Coord
    float4 PosWorld : TEXCOORD2;
    float NdotL[8] : TEXCOORD3;
    float4 Diffuse : COLOR0;
    float4 NormalColor : COLOR1;
    float Clip : SV_ClipDistance;
    uint BulbOn : BLENDINDICES0;
    uint ArrayIndex : BLENDINDICES1;
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

    uint2 LightTexSize = g_VoxelLightTexSize;
    uint VoxelQuadWidthInTex = VOXEL_LIGHT_TEXTURE_WIDTH / TexWidthHeightPerQuad; // 텍스쳐 한 라인에 들어가는 사각형 개수

    uint qy = (QuadIndex / VoxelQuadWidthInTex) * TexWidthHeightPerQuad;
    uint qx = (QuadIndex % VoxelQuadWidthInTex) * TexWidthHeightPerQuad;
    uint2 LightTexPos = uint2(qx, qy);

    if (PosBits & 0x01)
    {
        LightTexPos.x += TexWidthHeightPerQuad;
    }
    if (PosBits & 0x02)
    {
        LightTexPos.y += TexWidthHeightPerQuad;
    }
    LightTexPos.y += g_Scale_TexOffset_V;
    output.LightTexCoord = (float2)LightTexPos / (float2)LightTexSize;

    float4 PosWorld = mul(InputPos, g_matWorldVoxel); // 월드공간에서의 버텍스 좌표

    uint AxisIndex = 0;
    float3 NormalLocal = GetNormal(AxisIndex, input.PackedData);
    float3 NormalWorld = mul(NormalLocal, (float3x3)g_matWorldVoxel);
    NormalWorld = normalize(NormalWorld);
    
	//output.Pos = mul(InputPos, mul(g_matWorldVoxel, matViewProjArray[ArrayIndex]));	// 프로젝션된 좌표. 위에서 월드좌표(PosWorld)를 구해놨으니 mul(g_matWorldVoxel, matViewProjArray[ArrayIndex])는 필요없다.
    output.Pos = mul(PosWorld, g_Camera.matViewProjArray[ArrayIndex]); // 프로젝션된 좌표.
    output.Clip = dot(PosWorld, ClipPlane);
    output.PosWorld = PosWorld;

	// N*L계산
    float cosang = dot(NormalWorld, (float3)(-LightDir));
    float L = cosang * 0.5 + 0.5;
    float4 Diffuse = float4(1, 1, 1, 1);
    output.Diffuse = float4(L * Diffuse.rgb, Diffuse.a);
    output.NormalColor.rgb = (NormalWorld * 0.5f) + 0.5f;
    output.NormalColor.a = 1;

	// Palette Index
    uint PaletteIndex = GetPaletteIndex(int3(oPos.x, oPos.y, oPos.z));
    output.PaletteTexCoord.xy = GetVoxelPaletteTexCoord(PaletteIndex, AxisIndex, oPos, vPos, WidthDepthHeight);
	//output.PaletteTexCoord.x = ((float)PaletteIndex / 255) + (0.5 / 255);
	//output.PaletteTexCoord.y = 0.5;

#if (1 == SHADER_PARAMETER_SPHEREMAP)
	//float3	sphereNormal = normalize(mul((InputPos.xyz - VoxelCenter), matViewArray[ArrayIndex]));
	float3	sphereNormal = normalize(mul(InputPos.xyz, g_Camera.matViewArray[ArrayIndex]));
	output.PaletteTexCoord.zw = (sphereNormal.xy * 0.5) + float2(0.5, 0.5);// +float2(TimeSinValueX, TimeSinValueY);
#endif
    for (int i = 0; i < iAttLightNum; i++)
    {
        float3 LightVec = normalize((AttLight[i].Pos.xyz - PosWorld.xyz));
        output.NdotL[i] = dot(NormalWorld, LightVec);
    }
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
        output[i].LightTexCoord = input[i].LightTexCoord;
        output[i].Diffuse = input[i].Diffuse;
        output[i].NormalColor = input[i].NormalColor;
        output[i].Clip = input[i].Clip;
        output[i].PosWorld = input[i].PosWorld;
        output[i].ArrayIndex = input[i].ArrayIndex;
        output[i].BulbOn = input[i].BulbOn;
        output[i].RTVIndex = input[i].ArrayIndex;
        for (uint j = 0; j < 8; j++)
        {
            output[i].NdotL[j] = input[i].NdotL[j];
        }
        TriStream.Append(output[i]);
    }
}

PS_TARGET psDefault(PS_INPUT_VX input)
{
    PS_TARGET OutColor = (PS_TARGET)0;

    float4 texColorDiffuse = texDiffuse.Sample(samplerClamp, input.PaletteTexCoord.xy);
    float4 texColorLightMap = texLight.Sample(samplerClamp, input.LightTexCoord);
	
	// 전구에 불 켜진 상태
    texColorDiffuse.rgb += (texColorDiffuse.rgb * input.BulbOn);

	//float3	NormalWorld = normalize((input.NormalColor * 2.0) - 1.0);
	//float3	ViewVec = normalize((float3)GlobalEyePos - input.PosWorld);
	//float fresnel = fresnelTerm(NormalWorld, ViewVec, 0.0);


	// 라이트맵 컬러값 보정
    texColorLightMap.rgb *= LightMapConst.rgb;
#if (1 == SHADER_PARAMETER_SPHEREMAP)
	float4	texColorSphereMap = texSphereMap.Sample(samplerWrap, input.PaletteTexCoord.zw);
	texColorDiffuse.rgb = lerp(texColorDiffuse.rgb, texColorSphereMap, 0.5) + texColorSphereMap * 0.25;

#endif

	// 최종 컬러는 (라이트맵*2)*디퓨즈테텍스쳐
    OutColor.Color0 = float4(texColorDiffuse.rgb * texColorLightMap.rgb, 1);

	// 다이나믹 라이트 적용
    if (iAttLightNum > 0)
    {
        OutColor.Color0.xyz += CalcAttLightColorWithNdotL(input.PosWorld.xyz, input.NdotL, iAttLightNum);
    }

    OutColor.Color1 = float4(input.NormalColor.xyz, (float)Property / 255.0f);
    OutColor.Color2 = float4(0, 0, 0, 0);
    return OutColor;
}
/*
PS_TARGET psDefault(PS_INPUT_VX input)
{
	PS_TARGET OutColor = (PS_TARGET)0;

	float4	texColorDiffuse = texDiffuse.Sample(samplerClamp, input.PaletteTexCoord.xy);
	float4	texColorLightMap = texLight.Sample(samplerClamp, input.LightTexCoord);
	
	// 전구에 불 켜진 상태
	texColorDiffuse.rgb += (texColorDiffuse.rgb * input.BulbOn);

	//float3	NormalWorld = normalize((input.NormalColor * 2.0) - 1.0);
	//float3	ViewVec = normalize((float3)GlobalEyePos - input.PosWorld);
	//float fresnel = fresnelTerm(NormalWorld, ViewVec, 0.0);


	// 라이트맵 컬러값 보정
	texColorLightMap.rgb *= LightMapConst.rgb;
#if (1 == SHADER_PARAMETER_SPHEREMAP)
	float4	texColorSphereMap = texSphereMap.Sample(samplerWrap, input.PaletteTexCoord.zw);
	texColorDiffuse.rgb = lerp(texColorDiffuse.rgb, texColorSphereMap, 0.5) + texColorSphereMap * 0.25;

#endif

	//float3 Shade(
 //           in int materialType,
 //           in float3 Albedo,
 //           in float3 Fo,
 //           in float3 Radiance,
 //           in bool inShadow,
 //           in float Roughness,
 //           in float3 N,
 //           in float3 V,
 //           in float3 L)
	float AmbientIntensity = 0.25;
	float3 WorldPos = input.PosWorld;
	float3 WorldDir = normalize(WorldPos.xyz - GlobalEyePos.xyz);
	float3 WorldNormal = (input.NormalColor.xyz * 2.0) - float3(1, 1, 1);

	float3 rayDir = WorldDir;

	int materialType = MaterialType::Default;
	float3 Kd = texColorDiffuse.rgb;
	float3 Ks = float3(0.25, 0.25, 0.25);
	//float3 Ks = float3(1.0, 1.0, 1.0);
	float3 LightColor = float3(1.5, 1.5, 1.5);
	bool bIsInShadow = false;
	float roughness = 0.0;
	float3 N = WorldNormal;
	float3 V = -rayDir;
	float3 wi = LightDir.xyz * -1;
	//float3 wi = normalize(float3(0.5, -1, 0.5)) * -1;
	
	float bw = texColorLightMap.r * 0.3 + texColorLightMap.g * 0.59 + texColorLightMap.b * 0.11;
	if (bw < 0.1)
	{
		bIsInShadow = true;
	}

	//rayPayload.radiance = ShadeOnGBuffer(rayPayload, WorldNormal, WorldNormal, WorldPos, WorldDir, material, ShadowWeight, shadingType);
	float3 L = BxDF::DirectLighting::Shade(materialType,
						Kd,
						Ks,
						LightColor,
						bIsInShadow,
						roughness,
						N,
						V,
						wi);
	//
	
	L += AmbientIntensity * Kd;
	//float3 outColor = L * texColorLightMap.rgb + AmbientIntensity;
	// 최종 컬러는 (라이트맵*2)*디퓨즈테텍스쳐
	//OutColor.Color0 = float4(texColorDiffuse.rgb * texColorLightMap.rgb, 1);
	//OutColor.Color0 = float4(L * texColorLightMap.rgb, 1);
	OutColor.Color0 = float4(L, 1);
	//OutColor.Color0 = float4(outColor, 1);

	// 다이나믹 라이트 적용
	if (iAttLightNum > 0)
	{
		OutColor.Color0.xyz += CalcAttLightColorWithNdotL(input.PosWorld.xyz, input.NdotL, iAttLightNum);
	}

	OutColor.Color1 = float4(input.NormalColor.xyz, (float)Property / 255.0f);
	OutColor.Color2 = float4(0, 0, 0, 0);
	return OutColor;
}
*/

float4 psDefaultWaterBottom(PS_INPUT_VX input) : SV_Target
{
    float4 texColorDiffuse = texDiffuse.Sample(samplerClamp, input.PaletteTexCoord.xy);
    float4 texColorLightMap = texLight.Sample(samplerClamp, input.LightTexCoord);
	
	// 라이트맵 컬러값 보정
    texColorLightMap.rgb *= LightMapConst.rgb;
#if (1 == SHADER_PARAMETER_SPHEREMAP)
	float4	texColorSphereMap = texSphereMap.Sample(samplerWrap, input.PaletteTexCoord.zw);
	texColorDiffuse.rgb = lerp(texColorDiffuse.rgb, texColorSphereMap, 0.5) + texColorSphereMap * 0.25;

#endif
    float Alpha = saturate((Height - input.PosWorld.y) * RcpFadeDistance);
    float4 OutColor = float4(texColorDiffuse.rgb * texColorLightMap.rgb, Alpha);
	
    return OutColor;
}

	/*float Alpha = saturate((Height - input.PosWorld.y) * RcpFadeDistance);
	outColor.a *= Alpha;*/
PS_TARGET psColor(PS_INPUT_VX input)
{
    PS_TARGET OutColor = (PS_TARGET)0;

    float4 texColorDiffuse = texDiffuse.Sample(samplerClamp, input.PaletteTexCoord.xy);
    float4 texColorLightMap = texLight.Sample(samplerClamp, input.LightTexCoord);

	// 라이트맵 컬러값 보정
    texColorLightMap.rgb *= LightMapConst.rgb;
    OutColor.Color0 = float4(MtlDiffuse.rgb * texColorLightMap.rgb, 1);
    OutColor.Color1 = float4(input.NormalColor.xyz, (float)Property / 255.0f);
    OutColor.Color2 = float4(0, 0, 0, 0);

    return OutColor;
}


PS_TARGET psInnerSphere(PS_INPUT_VX input)
{
	// 툴에서 사용하기 위해 스피어 영역만큼만 렌더링
	// 스피어영역은 AttLight[0]을 사용

    PS_TARGET output = (PS_TARGET)0;


    float3 SpherePos = float3(PublicConst[0].x, PublicConst[0].y, PublicConst[0].z);
    float Rs = PublicConst[0].w;

    float dist = distance(SpherePos, input.PosWorld.xyz);
    clip(Rs - dist);

    output.Color0 = MtlDiffuse;
    output.Color1 = float4(input.NormalColor.xyz, (float)Property / 255.0f);
    output.Color2 = float4(0, 0, 0, 0);

    return output;
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

/*
vs
def c11,0,0,-1,0.5
; 화면 좌표계로 변환
m4x4	r0,v0,c4

; 0,0,0위치의 구가 입력되므로 점의 위치는 방향벡터이기도 하다.
; 노말 변환
m3x3	r7.xyz,v0,c0
nrm		r8.xyz,r7.xyz

; 노말을 프로젝션->알파값으로 변환
m3x3	r6.xyz,v0.xyz,c16
nrm		r5.xyz,r6.xyz
mov		oT1,r5.xyz

; 포그값 산출 - z값 기준
mul		r1.x,r0.w,c12.y
add		r1.x,r1.x,c12.x

; 포그값 산출 - 높이 기준
; 월드좌표 기준 y좌표만 구한다.
dp4		r2.y,v0,c1

mul		r3.x,r2.y,c12.w
add		r3.x,r3.x,c12.z

; 포그 설정
max		oFog,r1.x,r3.x

; 출력 정점
mov		oPos,r0

mov oD0,c10					; 디퓨즈로 받은 컬러값 그대로 세팅

; sphere map
m3x3 oT0.xyz, r8, c13 ; normal to tex coord for sphere map


// ps
; 버텍스 라이트 디폴트
;
; c0 - ambient
; v0 - diffuse

; t0 - spheremap texcoord
; t1 - normal vector
ps_2_0

dcl		v0.xyzw
dcl		t0.xy
dcl		t1.xyz
dcl_2d	s0

def		c11,0,0,-1,0

texld	r0,t0,s0		; spheremap
mov		r1,c0
add		r1,v0,r1		; diffuse + ambient

nrm		r3.xyz,t1
dp3		r2,c11,r3		; Projtect Normal * (0,0,-1)
mul		r2,r2,r2		; 급격하게 꺽어주기 위해 제곱

mad		r3,r1,r0,r0		; (diffuse * spheremap) + spheremap
mul		r3.a,v0.a,r2.x
mov		oC0,r3
*/

