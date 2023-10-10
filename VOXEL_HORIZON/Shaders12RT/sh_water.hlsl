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
Texture2D texNormal : register(t1); // �ܹ���
Texture2D texReflect : register(t2); // ���� �ݻ�
Texture2D texRefract : register(t3); // �� �� �Ž�(����)

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
    float4 PosWorld : TEXCOORD3; // ������������� ��ġ
    float Distance : TEXCOORD4; // �Ÿ�(w��)
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

	// ����� 0���� 1���̷� ��ȭ
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

	// y�� z�� �ٲٰ� 0.05�� ���ؼ� ������
    float4 texCoordAdj = (texColorNormal.xzyw - 0.5f) * 0.05f;

    float2 texCoordReflect = input.TexCoordReflect.xy + texCoordAdj.xy;
    float2 texCoordDiffuse = input.TexCoordDiffuse.xy + texCoordAdj.xy;
    float2 texCoordRefract = input.TexCoordRefract.xy + (texCoordAdj.xy * 0.25);

    float4 texColorDiffuse = texDiffuse.Sample(samplerWrap, texCoordDiffuse);
    float4 texColorReflect = texReflect.Sample(samplerClamp, texCoordReflect);
    float4 texColorRefract = texRefract.Sample(samplerClamp, texCoordRefract);

	//mov			r10.a,r2.a		; ���� ��� �ؽ��� ���� ���
    float Alpha = 1.0; // texColorRefract.a;

	// ������ �� ���
    float4 frnConst = float4(0.02037f, 0.97963f, 0.5f, 1.0f); // ������ ���
    float4 texMapRate = { 0.65f, 0.65f, 0.35f, 1.0f }; // (�ݻ� , ���� , ��ǻ��) ����

	// def		c10, 0.02037, 0.97963 , 0.5 , 1	; ������ ���
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
	// mul			r6.xy,r6,c3		; �ݻ� �� ������ �Ҵ�� ����
	// mul			r1,r1,r6.x		; ������ �׿� �ٰ��� �ݻ����
	// mul			r2,r2,r6.y		; ������ �׿� �ٰ��� ��������
	// mul			r5,r5,c3.z		; diffuse ����

	// add			r3,r2,r5		; ���� * diffuse
	// add			r3,r3,r1
	// mov			r3.a,r10.a

	//outColor = texColorReflect;
	//outColor = texColorRefract;


	/*

; �ð������� ����.
add			r0.xy,t0,c12

; �븻�� (0 - 1)
texld		r5,r0,s0		; bump map
sub			r4,r5,c5		; -0.5


; �⺻������ 0,0,1�� ��ֺ����̹Ƿ� 0,1,0���� �ٲ۴�.
mov			r5,r4
dp3			r4.y,r5,c14
dp3			r4.z,r5,c15


mul			r2,r4,c2		; ������



; �ݻ���� ���������ؼ� �б� ���� ��ǥ ����
rcp			r0.w,t1.w
mul			r3,t1,r0.w

add			r3.x,r3,r2

;rcp			r0.w,t1.w
;mul			r4,t2,r0.w
;add			r4.x,r4,r2


; ��ǻ��� ��ǥ ����
add			r5.xy,t0,r2

; �븻�� ��ǥ ����
add			r11.xy,t4,r2	;
;mov			r11,r5			; backup

texld		r1,r3,s1		; �ݻ�
;texld		r2,r4,s2		; ����
texldp		r2,t2,s2		; ����
mov			r10.a,r2.a		; ���� ��� �ؽ��� ���� ���
;texldp		r10,t2,s2		;

texld		r5,r5,s3


;mul			r1,r1,c3.x		; �ݻ� ����
;mul			r2,r2,c3.y		; ���� ����

; ������ �� ���

sub			r6,c13,t3		; eye pos - pos
nrm			r4,r6

dp3_sat		r7.a,r4,c1

add			r9.a,c10.a,-r7.a
mul			r6.a,r9.a,r9.a
;mul			r6.a,r6.a,r6.a
;mul			r6.a,r6.a,r9.a
mad			r6.x,c10.g,r6.a,c10.r


sub			r6.y,c3.a,r6.x
mul			r6.xy,r6,c3		; �ݻ� �� ������ �Ҵ�� ����

mul			r1,r1,r6.x		; ������ �׿� �ٰ��� �ݻ����
mul			r2,r2,r6.y		; ������ �׿� �ٰ��� ��������
mul			r5,r5,c3.z		; diffuse ����

add			r3,r2,r5		; ���� * diffuse
add			r3,r3,r1

mov			r3.a,r10.a
*/


//float4	texColor = input.Color;

}
VS_OUTPUT_WATER vsXYZ(VS_INPUT_WATER input)
{
    VS_OUTPUT_WATER output = (VS_OUTPUT_WATER)0;

    uint ArrayIndex = input.instId % 2;

	// ��¹��ؽ�
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

def		c10, 0.02037, 0.97963 , 0.5 , 1	; ������ ���

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


; �ð������� ����.
add			r0.xy,t0,c12

; �븻�� (0 - 1)
texld		r5,r0,s0		; bump map
sub			r4,r5,c5		; -0.5


; �⺻������ 0,0,1�� ��ֺ����̹Ƿ� 0,1,0���� �ٲ۴�.
mov			r5,r4
dp3			r4.y,r5,c14
dp3			r4.z,r5,c15


mul			r2,r4,c2		; ������



; �ݻ���� ���������ؼ� �б� ���� ��ǥ ����
rcp			r0.w,t1.w
mul			r3,t1,r0.w

add			r3.x,r3,r2

;rcp			r0.w,t1.w
;mul			r4,t2,r0.w
;add			r4.x,r4,r2


; ��ǻ��� ��ǥ ����
add			r5.xy,t0,r2

; �븻�� ��ǥ ����
add			r11.xy,t4,r2	;
;mov			r11,r5			; backup

texld		r1,r3,s1		; �ݻ�
;texld		r2,r4,s2		; ����
texldp		r2,t2,s2		; ����
mov			r10.a,r2.a		; ���� ��� �ؽ��� ���� ���
;texldp		r10,t2,s2		;

texld		r5,r5,s3


;mul			r1,r1,c3.x		; �ݻ� ����
;mul			r2,r2,c3.y		; ���� ����

; ������ �� ���

sub			r6,c13,t3		; eye pos - pos
nrm			r4,r6

dp3_sat		r7.a,r4,c1

add			r9.a,c10.a,-r7.a
mul			r6.a,r9.a,r9.a
;mul			r6.a,r6.a,r6.a
;mul			r6.a,r6.a,r9.a
mad			r6.x,c10.g,r6.a,c10.r


sub			r6.y,c3.a,r6.x
mul			r6.xy,r6,c3		; �ݻ� �� ������ �Ҵ�� ����

mul			r1,r1,r6.x		; ������ �׿� �ٰ��� �ݻ����
mul			r2,r2,r6.y		; ������ �׿� �ٰ��� ��������
mul			r5,r5,c3.z		; diffuse ����

add			r3,r2,r5		; ���� * diffuse
add			r3,r3,r1

mov			r3.a,r10.a



; ����ŧ�� ���

texld	r0,r11,s0			; �븻��
sub		r4,r0,c5			; -0.5




; �⺻������ 0,0,1�� ��ֺ����̹Ƿ� 0,1,0���� �ٲ۴�.
mov			r5,r4
dp3			r4.y,r5,c14
dp3			r4.z,r5,c15


nrm			r2.xyz,r4		;	 ��ֶ�����

; eye ����
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