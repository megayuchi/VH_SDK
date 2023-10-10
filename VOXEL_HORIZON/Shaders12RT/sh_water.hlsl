#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_constant_buffer_default.hlsl"
#include "sh_constant_buffer_material.hlsl"

// vertexshader constant, pixelshader constant
cbuffer ConstantBufferWater : register(b1)
{
    float4 TimeTick;
    float4 EyePos;
    matrix matReflectTexCoord;
    matrix matRefractTexCoord;
}

Texture2D texDiffuse : register(t0);
Texture2D texNormal : register(t1); // 잔물결
Texture2D texReflect : register(t2); // 수면 반사
Texture2D texRefract : register(t3); // 물 밑 매쉬(굴절)

SamplerState samplerWrap : register(s0);
SamplerState samplerClamp : register(s1);


//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------


struct VS_INPUT_WATER
{
    float4 Pos : POSITION;
    float2 TexCoord : TEXCOORD0;
    uint instId : SV_InstanceID;
};

struct VS_OUTPUT_WATER
{
    float4 Pos : SV_POSITION;
    float4 NormalColor : COLOR0;
    float2 TexCoordDiffuse : TEXCOORD0;
    float4 TexCoordReflect : TEXCOORD1;
    float4 TexCoordRefract : TEXCOORD2;
    float4 PosWorld : TEXCOORD3; // 월드공간에서의 위치
    float Distance : TEXCOORD4; // 거리(w값)
    uint ArrayIndex : BLENDINDICES;
#if (1 == VS_RTV_ARRAY)
	uint    RTVIndex        : SV_RenderTargetArrayIndex;
#endif
};

struct GS_OUTPUT_WATER : VS_OUTPUT_WATER
{
#if (1 != VS_RTV_ARRAY)
    uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};

struct PS_INPUT_WATER : VS_OUTPUT_WATER
{
};


VS_OUTPUT_WATER vsDefault(VS_INPUT_WATER input)
{
    VS_OUTPUT_WATER output = (VS_OUTPUT_WATER)0;

    uint ArrayIndex = input.instId % 2;

    output.Pos = mul(input.Pos, g_Camera.matWorldViewProjArray[ArrayIndex]);
    output.PosWorld = mul(input.Pos, g_TrCommon.matWorld);

	// 노멀을 0에서 1사이로 포화
    output.NormalColor.rgb = float3(0.0f, 1.0f, 0.0f);
    output.NormalColor.a = 1;

    output.Distance = output.Pos.w * 0.000025f;
    output.TexCoordDiffuse = input.TexCoord;
    output.TexCoordReflect = mul(input.Pos, matReflectTexCoord);
    output.TexCoordRefract = mul(input.Pos, matRefractTexCoord);
    output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif
    return output;
}

[maxvertexcount(3)]
void gsDefault(triangle VS_OUTPUT_WATER input[3], inout TriangleStream<GS_OUTPUT_WATER> TriStream)
{
    GS_OUTPUT_WATER output[3];

    for (uint i = 0; i < 3; i++)
    {
        output[i].Pos = input[i].Pos;
        output[i].NormalColor = input[i].NormalColor;
        output[i].TexCoordDiffuse = input[i].TexCoordDiffuse;
        output[i].TexCoordReflect = input[i].TexCoordReflect;
        output[i].TexCoordRefract = input[i].TexCoordRefract;
        output[i].PosWorld = input[i].PosWorld;
        output[i].Distance = input[i].Distance;
        output[i].ArrayIndex = input[i].ArrayIndex;
        output[i].RTVIndex = input[i].ArrayIndex;
        TriStream.Append(output[i]);
    }
}
PS_TARGET psDefault(PS_INPUT_WATER input)
{
    PS_TARGET output = (PS_TARGET)0;

    float4 outColor = 0;

    input.TexCoordReflect /= input.TexCoordReflect.w;
    input.TexCoordRefract /= input.TexCoordRefract.w;

    float2 texCoordWave = input.TexCoordDiffuse.xy + TimeTick.xx;

    float4 texColorNormal = texNormal.Sample(samplerWrap, texCoordWave);

	// y와 z를 바꾸고 0.05를 곱해서 스케일
    float4 texCoordAdj = (texColorNormal.xzyw - 0.5f) * 0.05f;

    float2 texCoordReflect = input.TexCoordReflect.xy + texCoordAdj.xy;
    float2 texCoordDiffuse = input.TexCoordDiffuse.xy + texCoordAdj.xy;
    float2 texCoordRefract = input.TexCoordRefract.xy + (texCoordAdj.xy * 0.25);

    float4 texColorDiffuse = texDiffuse.Sample(samplerWrap, texCoordDiffuse);
    float4 texColorReflect = texReflect.Sample(samplerClamp, texCoordReflect);
    float4 texColorRefract = texRefract.Sample(samplerClamp, texCoordRefract);

	//mov			r10.a,r2.a		; 물밑 장면 텍스쳐 알파 백업
    float Alpha = 1.0; // texColorRefract.a;

	// 프레넬 항 계산
    float4 frnConst = float4(0.02037f, 0.97963f, 0.5f, 1.0f); // 프레넬 상수
    float4 texMapRate = { 0.65f, 0.65f, 0.35f, 1.0f }; // (반사 , 물밑 , 디퓨즈) 비율

	// def		c10, 0.02037, 0.97963 , 0.5 , 1	; 프레넬 상수
	// sub			r6,c13,t3		; eye pos - pos
	// nrm			r4,r6
    float3 Normal = normalize((float3)EyePos - (float3)input.PosWorld);


    float4 frnRate;

    frnRate.z = 1.0f - Normal.y;
    frnRate.z *= frnRate.z;


    frnRate.x = (frnRate.z * frnConst.y) + frnConst.x;
    frnRate.y = 1.0f - frnRate.x;
    frnRate.xy *= texMapRate.xy;


    texColorReflect *= frnRate.x;
    texColorRefract *= frnRate.y;
    texColorDiffuse *= texMapRate.z;

    outColor.rbg = texColorDiffuse.rgb + texColorReflect.rgb + texColorRefract.rgb;
    outColor.a = Alpha;

    float4 NormalColor = float4(input.NormalColor.xyz, (float)Property / 255.0f);
    output.Color0 = outColor;
    output.Color1 = NormalColor;
	

    return output;


	// dp3_sat		r7.a,r4,c1 = Normal.y
	// add			r9.a,c10.a,-r7.a
	// mul			r6.a,r9.a,r9.a
	// mad			r6.x,c10.g,r6.a,c10.r
	// sub			r6.y,c3.a,r6.x
	// mul			r6.xy,r6,c3		; 반사 및 굴절에 할당된 비율
	// mul			r1,r1,r6.x		; 프레넬 항에 근거한 반사비율
	// mul			r2,r2,r6.y		; 프레넬 항에 근거한 굴절비율
	// mul			r5,r5,c3.z		; diffuse 비율

	// add			r3,r2,r5		; 굴절 * diffuse
	// add			r3,r3,r1
	// mov			r3.a,r10.a

	//outColor = texColorReflect;
	//outColor = texColorRefract;


	/*

; 시간값으로 흔든다.
add			r0.xy,t0,c12

; 노말값 (0 - 1)
texld		r5,r0,s0		; bump map
sub			r4,r5,c5		; -0.5


; 기본적으로 0,0,1의 노멀벡터이므로 0,1,0으로 바꾼다.
mov			r5,r4
dp3			r4.y,r5,c14
dp3			r4.z,r5,c15


mul			r2,r4,c2		; 스케일



; 반사맵을 프로젝션해서 읽기 위한 좌표 조정
rcp			r0.w,t1.w
mul			r3,t1,r0.w

add			r3.x,r3,r2

;rcp			r0.w,t1.w
;mul			r4,t2,r0.w
;add			r4.x,r4,r2


; 디퓨즈맵 좌표 조정
add			r5.xy,t0,r2

; 노말맵 좌표 조정
add			r11.xy,t4,r2	;
;mov			r11,r5			; backup

texld		r1,r3,s1		; 반사
;texld		r2,r4,s2		; 굴절
texldp		r2,t2,s2		; 굴절
mov			r10.a,r2.a		; 물밑 장면 텍스쳐 알파 백업
;texldp		r10,t2,s2		;

texld		r5,r5,s3


;mul			r1,r1,c3.x		; 반사 비율
;mul			r2,r2,c3.y		; 굴절 비율

; 프레넬 항 계산

sub			r6,c13,t3		; eye pos - pos
nrm			r4,r6

dp3_sat		r7.a,r4,c1

add			r9.a,c10.a,-r7.a
mul			r6.a,r9.a,r9.a
;mul			r6.a,r6.a,r6.a
;mul			r6.a,r6.a,r9.a
mad			r6.x,c10.g,r6.a,c10.r


sub			r6.y,c3.a,r6.x
mul			r6.xy,r6,c3		; 반사 및 굴절에 할당된 비율

mul			r1,r1,r6.x		; 프레넬 항에 근거한 반사비율
mul			r2,r2,r6.y		; 프레넬 항에 근거한 굴절비율
mul			r5,r5,c3.z		; diffuse 비율

add			r3,r2,r5		; 굴절 * diffuse
add			r3,r3,r1

mov			r3.a,r10.a
*/


//float4	texColor = input.Color;

}
VS_OUTPUT_WATER vsXYZ(VS_INPUT_WATER input)
{
    VS_OUTPUT_WATER output = (VS_OUTPUT_WATER)0;

    uint ArrayIndex = input.instId % 2;

	// 출력버텍스
    output.Pos = mul(input.Pos, g_Camera.matWorldViewProjArray[ArrayIndex]);

    return output;
}
float4 psColor(PS_INPUT_WATER input) : SV_Target
{
    float4 outColor = MtlDiffuse;

    return outColor;
}
/*

; c11 - light dir
; c12 - time
; c13 - eye pos

def		c1,0,1,0,0
def		c2,0.05,0.05,0.05,0.05
;def		c3,0.15,0.4,0.45,1
def		c3,0.65,0.65,0.35,1
def		c5,0.5,0.5,0.5,0

def		c10, 0.02037, 0.97963 , 0.5 , 1	; 프레넬 상수

def		c14, 0, 0, 1, 0
def		c15, 0, 1, 0, 0




dcl_2d	 s0
dcl_2d	 s1
dcl_2d	 s2
dcl_2d	 s3

dcl	v1.xyzw

dcl	t0.xy
dcl	t1.xyzw
dcl	t2.xyzw
dcl t3.xyzw
dcl t4.xy


; 시간값으로 흔든다.
add			r0.xy,t0,c12

; 노말값 (0 - 1)
texld		r5,r0,s0		; bump map
sub			r4,r5,c5		; -0.5


; 기본적으로 0,0,1의 노멀벡터이므로 0,1,0으로 바꾼다.
mov			r5,r4
dp3			r4.y,r5,c14
dp3			r4.z,r5,c15


mul			r2,r4,c2		; 스케일



; 반사맵을 프로젝션해서 읽기 위한 좌표 조정
rcp			r0.w,t1.w
mul			r3,t1,r0.w

add			r3.x,r3,r2

;rcp			r0.w,t1.w
;mul			r4,t2,r0.w
;add			r4.x,r4,r2


; 디퓨즈맵 좌표 조정
add			r5.xy,t0,r2

; 노말맵 좌표 조정
add			r11.xy,t4,r2	;
;mov			r11,r5			; backup

texld		r1,r3,s1		; 반사
;texld		r2,r4,s2		; 굴절
texldp		r2,t2,s2		; 굴절
mov			r10.a,r2.a		; 물밑 장면 텍스쳐 알파 백업
;texldp		r10,t2,s2		;

texld		r5,r5,s3


;mul			r1,r1,c3.x		; 반사 비율
;mul			r2,r2,c3.y		; 굴절 비율

; 프레넬 항 계산

sub			r6,c13,t3		; eye pos - pos
nrm			r4,r6

dp3_sat		r7.a,r4,c1

add			r9.a,c10.a,-r7.a
mul			r6.a,r9.a,r9.a
;mul			r6.a,r6.a,r6.a
;mul			r6.a,r6.a,r9.a
mad			r6.x,c10.g,r6.a,c10.r


sub			r6.y,c3.a,r6.x
mul			r6.xy,r6,c3		; 반사 및 굴절에 할당된 비율

mul			r1,r1,r6.x		; 프레넬 항에 근거한 반사비율
mul			r2,r2,r6.y		; 프레넬 항에 근거한 굴절비율
mul			r5,r5,c3.z		; diffuse 비율

add			r3,r2,r5		; 굴절 * diffuse
add			r3,r3,r1

mov			r3.a,r10.a



; 스페큘러 계산

texld	r0,r11,s0			; 노말맵
sub		r4,r0,c5			; -0.5




; 기본적으로 0,0,1의 노멀벡터이므로 0,1,0으로 바꾼다.
mov			r5,r4
dp3			r4.y,r5,c14
dp3			r4.z,r5,c15


nrm			r2.xyz,r4		;	 노멀라이즈

; eye 벡터
;mov			r5,-c13
sub			r6,c13,t3		; eye pos - pos
nrm			r5,r6

; half vector H
add			r0,-c11,r5		; -LightDir + eye
nrm			r1,r0

; dot (N,H)
dp3			r5.xyz,r2,r1

; pow
mul			r5,r5,r5
mul			r5,r5,r5
mul			r5,r5,r5

add			r3,r3,r5


mov			oC0,r3
mov			oC1,v1


*/