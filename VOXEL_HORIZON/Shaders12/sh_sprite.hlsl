#include "sh_define.hlsl"
#include "shader_cpp_common.h"

//#define SHADER_PARAMETER_USE_TILED_RESOURCES 1
cbuffer ConstantBufferSprite : register(b0)
{
	matrix	matTex;
	matrix	matPos;
	float	z;
	float	fAlpha;
	int		TexArrayIndex;
	float	w_coord;	// 3DTexture일때 u,v,w중 w좌표
	float4	diffuseColor;
    uint2 TexWidthHeight;
    uint Reserved0;
    uint Reserved1;
}

Texture2D		texDiffuse		: register(t0);
Texture2D<uint>	texDiffuseUint	: register(t0);
Texture3D		texDiffuse3D	: register(t0);
Texture2DArray	texDiffuseArray	: register(t0);

SamplerState	samplerDiffuse	: register(s0);

//--------------------------------------------------------------------------------------
struct VS_INPUT
{
	float4		Pos		 : POSITION;
	float2		TexCoord : TEXCOORD0;
	uint        instId  : SV_InstanceID;
};

struct VS_OUTPUT
{
	float4 Pos : SV_POSITION;
	float4 Color : COLOR;
	float2 TexCoord : TEXCOORD0;
	uint ArrayIndex : BLENDINDICES;
#if (1 == VS_RTV_ARRAY)
	uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};
struct GS_OUTPUT : VS_OUTPUT
{
#if (1 != VS_RTV_ARRAY)
	uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};
struct PS_INPUT : VS_OUTPUT
{
};

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
PS_INPUT vsDefault(VS_INPUT input)
{
	PS_INPUT output = (PS_INPUT)0;

	uint ArrayIndex = input.instId % 2;
	// position
	output.Pos = mul(input.Pos, matPos);
	output.Pos.z = z;

	// tex coord
	output.TexCoord = (float2)mul(float4(input.TexCoord, 1, 1), matTex);
	output.Color = diffuseColor;
	output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif
	return output;
}

[maxvertexcount(3)]
void gsDefault(triangle VS_OUTPUT input[3], inout TriangleStream<GS_OUTPUT> TriStream)
{
	GS_OUTPUT output[3];

	for (uint i = 0; i < 3; i++)
	{
		output[i].Pos = input[i].Pos;
		output[i].Color = input[i].Color;
		output[i].TexCoord = input[i].TexCoord;
		output[i].ArrayIndex = input[i].ArrayIndex;
		output[i].RTVIndex = input[i].ArrayIndex;

		TriStream.Append(output[i]);
	}
}
float4 psDefault(PS_INPUT input) : SV_Target
{
	float4	texColor = texDiffuse.Sample(samplerDiffuse, input.TexCoord);

	float4	outColor = input.Color * texColor;

	return outColor;
}
float4 psTex3D(PS_INPUT input) : SV_Target
{
	float4	texColor = texDiffuse3D.Sample(samplerDiffuse, float3(input.TexCoord,w_coord));
	float4	outColor = input.Color * texColor;

	return outColor;
}


float4 psDiffuseNoAlpha(PS_INPUT input) : SV_Target
{	
	float4	texColor = texDiffuse.Sample(samplerDiffuse, input.TexCoord);
	float4	outColor = float4(input.Color.xyz * texColor.xyz,1);

	return outColor;
}
float4 psDiffuseNoAlphaWithMipLevel(PS_INPUT input) : SV_Target
{	
    
	// TexArrayIndex를 MipLevel로 간주한다.
	//float4	texColor = texDiffuse.Sample(samplerDiffuse, input.TexCoord);
	
	float LOD = (float)TexArrayIndex;
#if (1 == SHADER_PARAMETER_USE_TILED_RESOURCES)
    uint FeedbackVar = 0;
    float4 texColor = texDiffuse.SampleLevel(samplerDiffuse, input.TexCoord, LOD, int2(0, 0), FeedbackVar);
	if (false == CheckAccessFullyMapped(FeedbackVar))
    {
        texColor = float4(1, 0, 0, 1);
    }
#else
	float4 texColor = texDiffuse.SampleLevel(samplerDiffuse, input.TexCoord, LOD, int2(0, 0));
#endif
    
	float4 outColor = float4(input.Color.xyz * texColor.xyz, 1);

	return outColor;
}

float4 psRedToBW(PS_INPUT input) : SV_Target
{
	float4	texColor = texDiffuse.Sample(samplerDiffuse, input.TexCoord);

	float	bw = texColor.r;// * 4.0f;
	float4	outColor = float4(bw,bw,bw,1);

	return outColor;
}
float4 psTiledResourceStatusToRGB1(PS_INPUT input) : SV_Target
{
    float4 outColor = { 0, 0, 0, 1 };
	
	// PageFault(1) | Mip Level(3) | Reserved(4) |  TexID(12) | TilePosY(6) | TilePosX(6)
	//     0/1      |      0-7     |             |   1-4095   |    0-63    |     0-63    |

    uint3 PixelPos = uint3(input.TexCoord * float2(TexWidthHeight), 0);
    uint Prop = texDiffuseUint.Load(PixelPos);
    //uint Prop = texDiffuseUint.SampleLevel(samplerDiffuse, float2(input.TexCoord), 0);
    //uint Prop = asuint(texDiffuse.Sample(samplerDiffuse, input.TexCoord));
	
    uint TexID = (Prop & 0x00FFF000) >> 12; // mask = 0b1111111111111000000000000        
    if (TexID)
    {
        uint PageFault = (Prop & 0x80000000) >> 31;
            
        uint MipLevel = (Prop & 0x70000000) >> 28; // 0 - 7
        uint LayoutType = (Prop & 0x07000000) >> 24; // 0 - 7 , layout 유형. texture크기, 타일 가로세로 개수 유형
      
        uint2 TilePos = uint2(Prop & 0x0000003F, (Prop & 0x00000FC0) >> 6);
		
		/*
		// 컬러출력 
		// R(8) = PageFault(1) | Mip Level(3) | TexID(4)
		outColor.r = ((PageFault << 7) | (MipLevel << 4) | (TexID & 0x0000000f)) / 255.0;
	
		// G(8) = TilePosX(normalized, 0-1)
		outColor.g = (float) TilePos.x / 63.0;
	
		// B(8) = TilePosY(normalized, 0-1)
        outColor.b = (float) TilePos.y / 63.0;
		*/
        outColor.r = ((float)(TexID % 4) / 4.0);
        outColor.g = (float)MipLevel / 7.0;
        outColor.b = (float)LayoutType / 7.0;
    }
    return outColor;

}

float4 psAlphaToBW(PS_INPUT input) : SV_Target
{
	float4	texColor = texDiffuse.Sample(samplerDiffuse, input.TexCoord);

	float	bw = texColor.a;// * 4.0f;
	float4	outColor = float4(bw,bw,bw,1);

	return outColor;
}

float4 psDiffuseToBW(PS_INPUT input) : SV_Target
{
	float3	bwConst = float3(0.3f, 0.59f, 0.11f);
	float4	texColor = texDiffuse.Sample(samplerDiffuse, input.TexCoord);
	float	bwColor = dot((float3)texColor, bwConst);
	float4	outColor = float4(bwColor, bwColor, bwColor, input.Color.a * texColor.a);

	return outColor;
}



float4 psArrayDiffuse(PS_INPUT input) : SV_Target
{
	float3	texCoord = float3(input.TexCoord.xy,TexArrayIndex);
	float4	texColor = texDiffuseArray.Sample(samplerDiffuse, texCoord);

	float4	outColor = texColor;

	return outColor;
}
float4 psArrayRedToBW(PS_INPUT input) : SV_Target
{
	float3	texCoord = float3(input.TexCoord.xy,TexArrayIndex);
	float4	texColor = texDiffuseArray.Sample(samplerDiffuse, texCoord);

	float	bw = texColor.r;// * 4.0f;
	float4	outColor = float4(bw,bw,bw,1);

	return outColor;
}
