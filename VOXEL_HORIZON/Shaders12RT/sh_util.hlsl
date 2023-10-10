#ifndef SH_UTIL_HLSL
#define SH_UTIL_HLSL

#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"

float3 RGBtoHCV(in float3 rgb)
{
    // RGB [0..1] to Hue-Chroma-Value [0..1]
    // Based on work by Sam Hocevar and Emil Persson
    float4 p = (rgb.g < rgb.b) ? float4(rgb.bg, -1., 2. / 3.) : float4(rgb.gb, 0., -1. / 3.);
    float4 q = (rgb.r < p.x) ? float4(p.xyw, rgb.r) : float4(rgb.r, p.yzx);
    float c = q.x - min(q.w, q.y);
    float h = abs((q.w - q.y) / (6. * c + EPSILON) + q.z);
    return float3(h, c, q.x);
}
float3 RGBtoHSV(in float3 rgb)
{
    // RGB [0..1] to Hue-Saturation-Value [0..1]
    float3 hcv = RGBtoHCV(rgb);
    float s = hcv.y / (hcv.z + EPSILON);
    return float3(hcv.x, s, hcv.z);
}

float3 CalcNormalWithTri(float3 p0, float3 p1, float3 p2)
{
	float3 n;
	float3 r, u, v;

	u = p1 - p0;
	v = p2 - p0;

	r = cross(u, v);
	n = normalize(r);

	return n;
}
void matrix_from_Quaternion(out matrix mat, float4 q)
{
	float xx = q.x*q.x;
	float yy = q.y*q.y;
	float zz = q.z*q.z;

	float xy = q.x*q.y;
	float xz = q.x*q.z;
	float yz = q.y*q.z;

	float wx = q.w*q.x;
	float wy = q.w*q.y;
	float wz = q.w*q.z;


	mat._11 = 1 - 2 * (yy + zz);
	mat._12 = 2 * (xy - wz);
	mat._13 = 2 * (xz + wy);

	mat._21 = 2 * (xy + wz);
	mat._22 = 1 - 2 * (xx + zz);
	mat._23 = 2 * (yz - wx);

	mat._31 = 2 * (xz - wy);
	mat._32 = 2 * (yz + wx);
	mat._33 = 1 - 2 * (xx + yy);

	mat._14 = mat._24 = mat._34 = 0.0f;
	mat._41 = mat._42 = mat._43 = 0.0f;
	mat._44 = 1.0f;

}

float4 ConvertDWORDTofloat(dword Color)
{
	float4 result;

	result.a = (float)((Color & 0xff000000) >> 24) / 255;		// A
	result.r = (float)((Color & 0x00ff0000) >> 16) / 255;		// R
	result.g = (float)((Color & 0x0000ff00) >> 8) / 255;		// G
	result.b = (float)((Color & 0x000000ff)) / 255;				// B


	return result;

}
uint ConvertFloat4ToDWORD(float4 Color)
{
	float4 result;

	uint a = (Color.a * 255);
	uint r = (Color.r * 255);
	uint g = (Color.g * 255);
	uint b = (Color.b * 255);

	uint PackedColor = (a << 24) | (r << 16) | (g << 8) | (b);
	return PackedColor;
}

uint ConvertFloat3ToDWORD(float3 Color, uint alpha)
{
	float4 result;

	uint r = (Color.r * 255);
	uint g = (Color.g * 255);
	uint b = (Color.b * 255);

	uint PackedColor = (alpha << 24) | (r << 16) | (g << 8) | (b);
	return PackedColor;
}


float4 CalcReflectionColor(float3 lightVec, float3 normal, float3 eyePos, float3 pos)
{
	float3 L = -lightVec.xyz;	// 광원벡터
	float3 N = normalize(normal);	// 법선 벡터
	float3 V = normalize(eyePos - pos);	// 시선 벡터
	float3 H = normalize(L + V);	// 하프 벡터

	float NV = dot(N, V);
	float NH = dot(N, H);
	float VH = dot(V, H);
	float NL = dot(N, L);
	float LH = dot(L, H);

	const float m = 0.35f;
	float NH2 = NH * NH;
	float D = exp(-(1 - NH2) / (NH2*m*m)) / (4 * m*m*NH2*NH2);

	// 기하감쇄율
	float G = min(1, min(2 * NH*NV / VH, 2 * NH*NL / VH));

	// 프레넬
	float n = 20.0f;	// 복소굴절률의 실수부
	float g = sqrt(n*n + LH * LH - 1);
	float gpc = g + LH;
	float gnc = g - LH;
	float cgpc = LH * gpc - 1;
	float cgnc = LH * gnc + 1;
	float F = 0.5 * gnc * gnc *(1 + cgpc * cgpc / (cgnc*cgnc)) / (gpc*gpc);

	float reflectColor =  max(0, F*D*G / NV);	// 반영 반사광
	return reflectColor;
}

float fresnelTerm(float3 normal, float3 ViewVec, float R0)
{
	float Reflectivity = 50.0f;
    float fresnel = R0 + (1.0f - R0) * pow(abs(1.0f - dot(normal, ViewVec)), 5.0 );    
	
	return fresnel;
}

// Fresnel reflectance - schlick approximation.
float3 Fresnel2(in float3 F0, in float cos_thetai)
{
	return saturate(F0 + (1 - F0) * pow(1 - cos_thetai, 5));
}
float3 Sample_Fr(in float3 V, out float3 L, in float3 N, in float3 Fo)
{
	L = reflect(-V, N);
	float cos_thetai = dot(N, L);
	return Fresnel2(Fo, cos_thetai);
}

#define TILED_RESOURCE_MIN_WIDTH_HEIGHT 128
uint GetLayoutTypeWithTexWidthHeight(uint WidthHeight)
{
	// WidthHeight - 텍스처의 전체 해상도 가로세 크기 
    // Layout Type Type
    // No. Tex Res      TileSize , Format 
    // 0     128x128       1x1      RGBA
    // 1     256x256       1x1      BC3
    // 2     512x512       2x2      BC3
    // 3    1024x1024      4x4      BC3
    // 4    2048x2048      8x8      BC3
    // 5    4096x4096     16x16     BC3
    // 6    8192x8192     32x32     BC3
    // 7   16384x16384    64x64     BC3
    
    
    uint LayoutType = (uint)log2(WidthHeight) - (uint)log2(TILED_RESOURCE_MIN_WIDTH_HEIGHT);
    return LayoutType;
}
uint CreateTiledResourcStatus(uint TexID, uint2 TexFullSize, uint2 SizePerTile, uint LayoutType, Texture2D texDiffuse, SamplerState samplerDiffuse, float2 texCoord, uint FeedbackVar)
{
	// Tiled Resource Status /////////////////////////////////////////////////////////////////////////////////////////////
	
	// 16384x16384일때 non packed mip level은 0-6까지.
	// 16384x16384 - 0
	// 8192x8192 - 1
	// 4096x4096 - 2
	// 2048x2048 - 3
	// 1024x1024 - 4
	// 512x512 - 5
	// 256x256 - 6
    
    // Property(32 bits)
    // PageFault(1) | Mip Level(3) | Resered(1) | Layout Type(3) |  TexID(12) | TilePosY(6) | TilePosX(6)
    //     0/1      |      0-7     |     0/1    |      0-7       |   1-4095   |    0-63    |     0-63    |
    uint mip_level = (uint)texDiffuse.CalculateLevelOfDetail(samplerDiffuse, texCoord);
    mip_level = min(mip_level, 7); // mip level은 0에서 7까지로 제한. 7부터는 어차피 packed이므로 7- 14까지는 모두 7로 간주해도 된다.
    
    uint2 MipWidthHeight = TexFullSize.xy / pow(2, mip_level); // 이 mip에서의 이미지 사이즈. 
    uint2 TileWidthHeight = TileWidthHeight = max(uint2(1, 1), MipWidthHeight / SizePerTile);
    
    // 텍스처 샘플링 규칙
    // https://learn.microsoft.com/en-us/windows/win32/direct3d10/d3d10-graphics-programming-guide-resources-coordinates
    
    uint2 PixelPos = uint2(floor(saturate(texCoord) * float2(MipWidthHeight))); // 픽셀좌표 계산. (texCoord x mip 크기) 계산 후 소수점 아래 버림
    uint2 TilePos = min(PixelPos / SizePerTile, TileWidthHeight - uint2(1, 1)); // 좌표가 타일의 크기 범위를 넘어가지 않도록

    uint Prop = (mip_level << 28) | (LayoutType << 24) | ((TexID & 0x00000FFF) << 12) | ((TilePos.y & 0x0000003F) << 6) | (TilePos.x & 0x0000003F);
    if (false == CheckAccessFullyMapped(FeedbackVar))
    {
        Prop |= (1 << 31);
    }
    return Prop;
}

/***************************************************************/
// Normal encoding
// Ref: https://knarkowicz.wordpress.com/2014/04/16/octahedron-normal-vector-encoding/
float2 OctWrap(float2 v)
{
	//return (1.0 - abs(v.yx)) * (v.xy >= 0.0 ? 1.0 : -1.0);
    return (1.0 - abs(v.yx)) * select(v.xy >= 0.0 , 1.0 , -1.0);
}

// Converts a 3D unit vector to a 2D vector with <0,1> range. 
float2 EncodeNormal(float3 n)
{
    n /= (abs(n.x) + abs(n.y) + abs(n.z));
    n.xy = n.z >= 0.0 ? n.xy : OctWrap(n.xy);
    n.xy = n.xy * 0.5 + 0.5;
    return n.xy;
}

float3 DecodeNormal(float2 f)
{
    f = f * 2.0 - 1.0;

    // https://twitter.com/Stubbesaurus/status/937994790553227264
    float3 n = float3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
    float t = saturate(-n.z);
	//n.xy += n.xy >= 0.0 ? -t : t;
    n.xy += select(n.xy >= 0.0, -t, t);
    return normalize(n);
}
/***************************************************************/



// Pack [0.0, 1.0] float to 8 bit uint. 
uint Pack_R8_FLOAT(float r)
{
    return clamp(round(r * 255), 0, 255);
}

float Unpack_R8_FLOAT(uint r)
{
    return (r & 0xFF) / 255.0;
}

// pack two 8 bit uint2 into a 16 bit uint.
uint Pack_R8G8_to_R16_UINT(in uint r, in uint g)
{
    return (r & 0xff) | ((g & 0xff) << 8);
}

void Unpack_R16_to_R8G8_UINT(in uint v, out uint r, out uint g)
{
    r = v & 0xFF;
    g = (v >> 8) & 0xFF;
}


// Pack unsigned floating point, where 
// - rgb.rg are in [0, 1] range stored as two 8 bit uints.
// - rgb.b in [0, FLT_16_BIT_MAX] range stored as a 16bit float.
uint Pack_R8G8B16_FLOAT(float3 rgb)
{
    uint r = Pack_R8_FLOAT(rgb.r);
    uint g = Pack_R8_FLOAT(rgb.g) << 8;
    uint b = f32tof16(rgb.b) << 16;
    return r | g | b;
}

float3 Unpack_R8G8B16_FLOAT(uint rgb)
{
    float r = Unpack_R8_FLOAT(rgb);
    float g = Unpack_R8_FLOAT(rgb >> 8);
    float b = f16tof32(rgb >> 16);
    return float3(r, g, b);
}

uint NormalizedFloat3ToByte3(float3 v)
{
    return
        (uint(v.x * 255) << 16) +
        (uint(v.y * 255) << 8) +
        uint(v.z * 255);
}

float3 Byte3ToNormalizedFloat3(uint v)
{
    return float3(
        (v >> 16) & 0xff,
        (v >> 8) & 0xff,
        v & 0xff) / 255;
}

// Encode normal and depth with 16 bits allocated for each.
uint EncodeNormalDepth_N16D16(in float3 normal, in float depth)
{
    float3 encodedNormalDepth = float3(EncodeNormal(normal), depth);
    return Pack_R8G8B16_FLOAT(encodedNormalDepth);
}


// Decoded 16 bit normal and 16bit depth.
void DecodeNormalDepth_N16D16(in uint packedEncodedNormalAndDepth, out float3 normal, out float depth)
{
    float3 encodedNormalDepth = Unpack_R8G8B16_FLOAT(packedEncodedNormalAndDepth);
    normal = DecodeNormal(encodedNormalDepth.xy);
    depth = encodedNormalDepth.z;
}

uint EncodeNormalDepth(in float3 normal, in float depth)
{
    return EncodeNormalDepth_N16D16(normal, depth);
}

void DecodeNormalDepth(in uint encodedNormalDepth, out float3 normal, out float depth)
{
    DecodeNormalDepth_N16D16(encodedNormalDepth, normal, depth);
}

void DecodeNormal(in uint encodedNormalDepth, out float3 normal)
{
    float depthDummy;
    DecodeNormalDepth_N16D16(encodedNormalDepth, normal, depthDummy);
}

void UnpackEncodedNormalDepth(in uint packedEncodedNormalDepth, out float2 encodedNormal, out float depth)
{
    float3 encodedNormalDepth = Unpack_R8G8B16_FLOAT(packedEncodedNormalDepth);
    encodedNormal = encodedNormalDepth.xy;
    depth = encodedNormalDepth.z;
}

// Generates a seed for a random number generator from 2 inputs plus a backoff
uint initRand(uint val0, uint val1, uint backoff = 16)
{
	uint v0 = val0, v1 = val1, s0 = 0;

	[unroll]
	for (uint n = 0; n < backoff; n++)
	{
		s0 += 0x9e3779b9;
		v0 += ((v1 << 4) + 0xa341316c) ^ (v1 + s0) ^ ((v1 >> 5) + 0xc8013ea4);
		v1 += ((v0 << 4) + 0xad90777d) ^ (v0 + s0) ^ ((v0 >> 5) + 0x7e95761e);
	}
	return v0;
}

// Takes our seed, updates it, and returns a pseudorandom float in [0..1]
float nextRand(inout uint s)
{
	s = (1664525u * s + 1013904223u);
	return float(s & 0x00FFFFFF) / float(0x01000000);
}

// Utility function to get a vector perpendicular to an input vector 
//    (from "Efficient Construction of Perpendicular Vectors Without Branching")
float3 getPerpendicularVector(float3 u)
{
	float3 a = abs(u);
	uint xm = ((a.x - a.y)<0 && (a.x - a.z)<0) ? 1 : 0;
	uint ym = (a.y - a.z)<0 ? (1 ^ xm) : 0;
	uint zm = 1 ^ (xm | ym);
	return cross(u, float3(xm, ym, zm));
}


// Get a cosine-weighted random vector centered around a specified normal direction.
float3 getCosHemisphereSample(inout uint randSeed, float3 hitNorm)
{
	// Get 2 random numbers to select our sample with
	float2 randVal = float2(nextRand(randSeed), nextRand(randSeed));

	// Cosine weighted hemisphere sample from RNG
	float3 bitangent = getPerpendicularVector(hitNorm);
	float3 tangent = cross(bitangent, hitNorm);
	float r = sqrt(randVal.x);
	float phi = 2.0 * 3.14159265f * randVal.y;

	// Get our cosine-weighted hemisphere lobe sample direction
	return tangent * (r * cos(phi).x) + bitangent * (r * sin(phi)) + hitNorm.xyz * sqrt(1 - randVal.x);
}


float2 ClipSpaceToTexturePosition(in float4 clipSpacePosition)
{
    float3 NDCposition = clipSpacePosition.xyz / clipSpacePosition.w;   // Perspective divide to get Normal Device Coordinates: {[-1,1], [-1,1], (0, 1]}
    NDCposition.y = -NDCposition.y;                                     // Invert Y for DirectX-style coordinates.
    float2 texturePosition = (NDCposition.xy + 1) * 0.5f;               // [-1,1] -> [0, 1]
    return texturePosition;
}
float DistanceToPlane(float4 vPlane, float3 vPoint)
{
	return dot(float4(vPoint, 1), vPlane);
}

// Frustum cullling on a sphere. Returns > 0 if visible, <= 0 otherwise
uint CullSphere(float4 vPlanes[6], float3 vCenter, float fRadius)
{
	float dist01 = max(DistanceToPlane(vPlanes[0], vCenter), DistanceToPlane(vPlanes[1], vCenter));
	float dist23 = max(DistanceToPlane(vPlanes[2], vCenter), DistanceToPlane(vPlanes[3], vCenter));
	float dist45 = max(DistanceToPlane(vPlanes[4], vCenter), DistanceToPlane(vPlanes[5], vCenter));

	float	dist = max(max(dist01, dist23), dist45) - fRadius;
	uint	visible = dist <= 0.0f;

	return visible;

}
#endif