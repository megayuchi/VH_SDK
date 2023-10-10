#ifndef RAYTRACING_UTIL_HLSL
#define RAYTRACING_UTIL_HLSL

#include "sh_define.hlsl"
#include "sh_typedef.hlsl"
#include "BxDF.hlsl"
#include "sh_util.hlsl"
#include "Raytracing_typedef.hlsl"

// Global Root Parameter
RWTexture2D<float4> g_OutputDiffuse : register(u0);
RWTexture2D<float> g_OutAO_CoEfficient : register(u1);
RWTexture2D<float> g_OutAO_Distance : register(u2);
RWTexture2D<uint> g_OutNormalDepth : register(u3);
RWTexture2D<float> g_OutLinearDepth : register(u4);
RWTexture2D<float2> g_OutMotionVector : register(u5);
RWTexture2D<uint> g_OutReprojectedNormalDepth : register(u6);
RWTexture2D<float4> g_OutputDepth : register(u7);
RWTexture2D<float4> g_OutputNormal : register(u8);
RWTexture2D<float4> g_OutputElementID : register(u9);

Texture2D		g_texGBufferDiffuse : register(t1);
Texture2D		g_texGBufferNormal : register(t2);
Texture2D		g_texGBufferDepth : register(t3);
Texture2D		g_texGBufferProperty : register(t4);
StructuredBuffer<RAY_TRACING_MATERIAL>	g_MtlTable : register(t5);
StructuredBuffer<uint>	g_PropertyTypeTable : register(t6);
StructuredBuffer<RAY_TRACING_VOXEL_COLOR_TABLE>	g_VoxelColorTable : register(t7);
Texture2D		g_texVoxelPaletteTex : register(t8);
Texture2D<uint>	g_texVoxelPaletteMtl : register(t9);
//Texture2D		g_texToonTable : register(t10);
TextureCube		g_texSkyEnv : register(t11);
StructuredBuffer<RAY_TRACING_RENDER_OPTION>		g_RenderOptionTable : register(t12);
StructuredBuffer<PROPERTY_PER_SHADING_TYPE>		g_PropertyPerShadingTable : register(t13);


RaytracingAccelerationStructure Scene : register(t0, space0);
//SamplerState	samplerWrap			: register(s0);
//SamplerState	samplerClamp		: register(s1);

// Local Root Parameter
ConstantBuffer<CONSTANT_BUFFER_RAY_GEOM> l_rayGeomCB : register(b0, space1);
StructuredBuffer<D3DVLVERTEX> l_Vertices : register(t0, space1);				// for triangle
StructuredBuffer<PAKCED_VOXEL_VERTEX> l_VoxelVertices : register(t1, space1);	// for voxel
StructuredBuffer<TVERTEX> l_TVertices : register(t2, space1);
ByteAddressBuffer l_Indices : register(t3, space1);
Texture2D<float4> l_texDiffuse : register(t4, space1);
Texture2D<float4> l_texNormal : register(t5, space1);

float3 HitAttribute(float3 vertexAttribute[3], BuiltInTriangleIntersectionAttributes attr)
{
	return vertexAttribute[0] +
		attr.barycentrics.x * (vertexAttribute[1] - vertexAttribute[0]) +
		attr.barycentrics.y * (vertexAttribute[2] - vertexAttribute[0]);
}
float2 HitAttribute(float2 vertexAttribute[3], BuiltInTriangleIntersectionAttributes attr)
{
    return vertexAttribute[0] +
        attr.barycentrics.x * (vertexAttribute[1] - vertexAttribute[0]) +
        attr.barycentrics.y * (vertexAttribute[2] - vertexAttribute[0]);
}
float3 CalcWorldPos(float2 csPos, float depth, out float dist, uint ArrayIndex)
{
	// csPos - Clip Space Postion -1 ~ +1


	//xp,yp,zp 는 프로젝션 된 점 (-1 - 1)

	// 일반적인 경우 - m21,m31,m32가 0인 경우
	// z = m43 / (zp - m33)
	// y = z*yp / m22
	// x = z*xp / m11

	// m21,m31,m32가 유효할 경우
	// z = m43 / (zp - m33)
	// y = (z*yp - z*m32) / m22
	// x = (z*xp - y*m21 - z*m31) / m11

	float z = g_DecompProj[ArrayIndex].m43 / (depth - g_DecompProj[ArrayIndex].m33);
	float y = ((z * csPos.y) - (z * g_DecompProj[ArrayIndex].m32)) * g_DecompProj[ArrayIndex].rcp_m22;
	float x = ((z * csPos.x) - (y * g_DecompProj[ArrayIndex].m21) - (z * g_DecompProj[ArrayIndex].m31)) * g_DecompProj[ArrayIndex].rcp_m11;
	float4 position = float4(x, y, z, 1);
	dist = z;

	return mul(position, g_ViewInvArray[ArrayIndex]).xyz;
}
// Retrieve hit world position.
float3 HitWorldPosition()
{
	return WorldRayOrigin() + RayTCurrent() * WorldRayDirection();
}
// Load three 16 bit indices.
static uint3 Load3x16BitIndices(uint offsetBytes)
{
	uint3 indices;

	// ByteAdressBuffer loads must be aligned at a 4 byte boundary.
	// Since we need to read three 16 bit indices: { 0, 1, 2 } 
	// aligned at a 4 byte boundary as: { 0 1 } { 2 0 } { 1 2 } { 0 1 } ...
	// we will load 8 bytes (~ 4 indices { a b | c d }) to handle two possible index triplet layouts,
	// based on first index's offsetBytes being aligned at the 4 byte boundary or not:
	//  Aligned:     { 0 1 | 2 - }
	//  Not aligned: { - 0 | 1 2 }
	const uint dwordAlignedOffset = offsetBytes & ~3;
	const uint2 four16BitIndices = l_Indices.Load2(dwordAlignedOffset);

	// Aligned: { 0 1 | 2 - } => retrieve first three 16bit indices
	if (dwordAlignedOffset == offsetBytes)
	{
		indices.x = four16BitIndices.x & 0xffff;
		indices.y = (four16BitIndices.x >> 16) & 0xffff;
		indices.z = four16BitIndices.y & 0xffff;
	}
	else // Notaligned: { - 0 | 1 2 } => retrieve last three 16bit indices
	{
		indices.x = (four16BitIndices.x >> 16) & 0xffff;
		indices.y = four16BitIndices.y & 0xffff;
		indices.z = (four16BitIndices.y >> 16) & 0xffff;
	}

	return indices;
	//return uint3(95, 41, 39);
}

void AntiAliasSpecular(inout float3 texNormal, inout float gloss)
{
    float normalLenSq = dot(texNormal, texNormal);
    float invNormalLen = rsqrt(normalLenSq);
    texNormal *= invNormalLen;
    gloss = lerp(1, gloss, rcp(invNormalLen));
}

// Apply fresnel to modulate the specular albedo
void FSchlick(inout float3 specular, inout float3 diffuse, float3 lightDir, float3 halfVec)
{
    float fresnel = pow(1.0 - saturate(dot(lightDir, halfVec)), 5.0);
    specular = lerp(specular, 1, fresnel);
    diffuse = lerp(diffuse, 0, fresnel);
}

float3 ApplyAmbientLight(
    float3    diffuse,    // Diffuse albedo
    float    ao,            // Pre-computed ambient-occlusion
    float3    lightColor    // Radiance of ambient light
)
{
    return ao * diffuse * lightColor;
}
float3 ApplyLightCommon(
    float3    diffuseColor,    // Diffuse albedo
    float3    specularColor,    // Specular albedo
    float    specularMask,    // Where is it shiny or dingy?
    float    gloss,            // Specular power
    float3    normal,            // World-space normal
    float3    viewDir,        // World-space vector from eye to point
    float3    lightDir,        // World-space vector from point to light
    float3    lightColor        // Radiance of directional light
)
{
    float3 halfVec = normalize(lightDir - viewDir);
    float nDotH = saturate(dot(halfVec, normal));

    FSchlick(diffuseColor, specularColor, lightDir, halfVec);

    float specularFactor = specularMask * pow(nDotH, gloss) * (gloss + 2) / 8;

    float nDotL = saturate(dot(normal, lightDir));

    return nDotL * lightColor * (diffuseColor + specularFactor * specularColor);
}
float3 ApplyLightCommon_Toon(
    float3    diffuseColor,    // Diffuse albedo
    float3    specularColor,    // Specular albedo
    float    specularMask,    // Where is it shiny or dingy?
    float    gloss,            // Specular power
    float3    normal,            // World-space normal
    float3    viewDir,        // World-space vector from eye to point
    float3    lightDir,        // World-space vector from point to light
    float3    lightColor        // Radiance of directional light
)
{
    float3 halfVec = normalize(lightDir - viewDir);
    float nDotH = saturate(dot(halfVec, normal));

    FSchlick(diffuseColor, specularColor, lightDir, halfVec);

    float specularFactor = specularMask * pow(nDotH, gloss) * (gloss + 2) / 8;

    float nDotL = saturate(dot(normal, lightDir));

	float2	toonTexCoord = float2(nDotL, 0.5);
	float4	toonColor = g_texToonTable.SampleLevel(samplerClamp, toonTexCoord, 0);

	return toonColor.rgb * lightColor.rgb * (diffuseColor.rgb + specularColor.rgb * specularFactor);
}
float3 ApplyPointLight(
    float3    diffuseColor,    // Diffuse albedo
    float3    specularColor,    // Specular albedo
    float    specularMask,    // Where is it shiny or dingy?
    float    gloss,            // Specular power
    float3    normal,            // World-space normal
    float3    viewDir,        // World-space vector from eye to point
    float3    worldPos,        // World-space fragment position
    float3    lightPos,        // World-space light position
    float    lightRadiusSq,
    float3    lightColor,        // Radiance of directional light
	uint ShadingType
)
{
    float3 lightDir = lightPos - worldPos;
    float lightDistSq = dot(lightDir, lightDir);
    float invLightDist = rsqrt(lightDistSq);
    lightDir *= invLightDist;

    // modify 1/d^2 * R^2 to fall off at a fixed radius
    // (R/d)^2 - d/R = [(1/d^2) - (1/R^2)*(d/R)] * R^2
    float distanceFalloff = lightRadiusSq * (invLightDist * invLightDist);
    distanceFalloff = max(0, distanceFalloff - rsqrt(distanceFalloff));

	if (SHADING_TYPE_TOON == ShadingType)
	{
		return distanceFalloff * ApplyLightCommon_Toon(
			diffuseColor,
			specularColor,
			specularMask,
			gloss,
			normal,
			viewDir,
			lightDir,
			lightColor
		);
	}
	else
	{
		return distanceFalloff * ApplyLightCommon(
			diffuseColor,
			specularColor,
			specularMask,
			gloss,
			normal,
			viewDir,
			lightDir,
			lightColor
		);
	}
}
float3 ApplyPointLight_Toon(
    float3    diffuseColor,    // Diffuse albedo
    float3    specularColor,    // Specular albedo
    float    specularMask,    // Where is it shiny or dingy?
    float    gloss,            // Specular power
    float3    normal,            // World-space normal
    float3    viewDir,        // World-space vector from eye to point
    float3    worldPos,        // World-space fragment position
    float3    lightPos,        // World-space light position
    float    lightRadiusSq,
    float3    lightColor        // Radiance of directional light
)
{
    float3 lightDir = lightPos - worldPos;
    float lightDistSq = dot(lightDir, lightDir);
    float invLightDist = rsqrt(lightDistSq);
    lightDir *= invLightDist;

    // modify 1/d^2 * R^2 to fall off at a fixed radius
    // (R/d)^2 - d/R = [(1/d^2) - (1/R^2)*(d/R)] * R^2
    float distanceFalloff = lightRadiusSq * (invLightDist * invLightDist);
    distanceFalloff = max(0, distanceFalloff - rsqrt(distanceFalloff));

    return distanceFalloff * ApplyLightCommon(
        diffuseColor,
        specularColor,
        specularMask,
        gloss,
        normal,
        viewDir,
        lightDir,
        lightColor
    );
}

uint GetPaletteIndex(uint3 pos, uint VoxelsPerAxis, uint InstanceID)
{
	uint byte_index = pos.x + pos.z * VoxelsPerAxis + pos.y * VoxelsPerAxis * VoxelsPerAxis;

	// | 00 | 01 | 02 | 03 | 04 | 05 | 06 | 07 | 08 | 09 | 10 | 11 | 12 | 13 | 14 | 15 |

	// byte_index = 5
	// qdword_index = byte_index / 16; ->	5 / 16 = 0;
	// byte_index_in_128 = byte_index - (qdword_index*16); -> 5 - 0 = 5
	// dword_index = byte_index_in_128 / 4; -> 5 /4 = 1
	// byte_index_in_dword = byte_index_in_128 - dword_index*4; -> 1

	// dword value = | 04 | 05 | 06 | 07 |
	// byte_value = (dword_value & (0x000000ff << byte_index_in_dword)) >> byte_index_in_dword; -> 5

	uint qdword_index = byte_index / 16;
	uint byte_index_in_128 = byte_index - (qdword_index * 16);
	uint dword_index = byte_index_in_128 / 4;
	uint byte_index_in_dword = byte_index_in_128 - dword_index * 4;

	uint	palette_value[4] =
	{
		g_VoxelColorTable[InstanceID].Palette[qdword_index].x,
		g_VoxelColorTable[InstanceID].Palette[qdword_index].y,
		g_VoxelColorTable[InstanceID].Palette[qdword_index].z,
		g_VoxelColorTable[InstanceID].Palette[qdword_index].w
	};
	uint	dword_value = palette_value[dword_index];
	uint	shift = byte_index_in_dword * 8;
	uint	value = (dword_value & ((uint)0x000000ff << shift)) >> shift;
	return value;
}

// Calculate a texture space motion vector from previous to current frame.
float2 CalculateMotionVector(in float3 WorldPos, out float depth, in float2 CurPixelCoord, uint ArrayIndex)
{
	float4 ProjPos = mul(float4(WorldPos, 1), g_PrvViewProj[ArrayIndex]);
	float linear_depth = (ProjPos.w - g_Near) / (g_Far - g_Near);
	depth = linear_depth;
	    
    float2 PrvPixelCoord = ClipSpaceToTexturePosition(ProjPos);

    return CurPixelCoord - PrvPixelCoord;
}
#endif // RAYTRACING_UTIL_HLSL
