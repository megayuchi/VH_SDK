#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"
#include "sh_gen_noise_util.hlsl"

#define GEN_SKY_THREAD_NUM 256

RWTexture2DArray<float4> TexBufferArray : register(u0);

Texture3D PerlinWorleyNoiseLow : register(t0);
Texture3D WorleyNoiseTexHigh : register(t1);
Texture2D CurlNoiseTex : register(t2);
Texture2DArray AtmosphereTexArray : register(t3);
//Texture2D DepthTex : register(t4);


SamplerState	samplerClampLinear	: register(s0);
SamplerState	samplerMirrorLinear	: register(s1);

cbuffer CONSTANT_BUFFER_GEN_SKY_ENV : register(b0)
{
	uint2	Res;
	float2	ResRcp;
	DECOMP_PROJ	DecompProj;
	matrix	matViewInvArray[6];
	
	float4 cameraPosition;
	
	float4 lightDirection;
	float4 lightColor;
	float4 cloudColorTop;
	
	float4 cloudColorBottom;
	float4 skyColorTop;
	float4 skyColorBottom;
	
	float earthRadius;
	float sphereOuterRadius;
	float sphereInnerRadius;
	float iTime;

	float coverage_multiplier;
	float cloudSpeed;
	float crispiness;
	float curliness;

	float absorption;
	float densityFactor;
	float Reserved0;
	float Reserved1;
}

#define BAYER_FACTOR 1.0/16.0
static float bayerFilter[16] = 
{
	0.0 * BAYER_FACTOR, 8.0 * BAYER_FACTOR, 2.0 * BAYER_FACTOR, 10.0 * BAYER_FACTOR,
	12.0 * BAYER_FACTOR, 4.0 * BAYER_FACTOR, 14.0 * BAYER_FACTOR, 6.0 * BAYER_FACTOR,
	3.0 * BAYER_FACTOR, 11.0 * BAYER_FACTOR, 1.0 * BAYER_FACTOR, 9.0 * BAYER_FACTOR,
	15.0 * BAYER_FACTOR, 7.0 * BAYER_FACTOR, 13.0 * BAYER_FACTOR, 5.0 * BAYER_FACTOR
};

#define CLOUDS_AMBIENT_COLOR_TOP cloudColorTop
#define CLOUDS_AMBIENT_COLOR_BOTTOM float3(cloudColorBottom.xyz)

// Cone sampling random offsets
static float3 noiseKernel[6] =
{
	float3(0.38051305,  0.92453449, -0.02111345),
	float3(-0.50625799, -0.03590792, -0.86163418),
	float3(-0.32509218, -0.94557439,  0.01428793),
	float3(0.09026238, -0.27376545,  0.95755165),
	float3(0.28128598,  0.42443639, -0.86065785),
	float3(-0.16852403,  0.14748697,  0.97460106)
};

// Cloud types height density gradients
#define STRATUS_GRADIENT float4(0.0, 0.1, 0.2, 0.3)
#define STRATOCUMULUS_GRADIENT float4(0.02, 0.2, 0.48, 0.625)
#define CUMULUS_GRADIENT float4(0.00, 0.1625, 0.88, 0.98)

#define EARTH_RADIUS earthRadius
#define SPHERE_INNER_RADIUS (EARTH_RADIUS + sphereInnerRadius)			// 5km , 구름 시작 반지름
#define SPHERE_OUTER_RADIUS (SPHERE_INNER_RADIUS + sphereOuterRadius)	// 두께 17km, 구름 끝 반지름 
#define SPHERE_DELTA float(SPHERE_OUTER_RADIUS - SPHERE_INNER_RADIUS)

#define CLOUDS_MIN_TRANSMITTANCE 1e-1
#define CLOUDS_TRANSMITTANCE_THRESHOLD 1.0 - CLOUDS_MIN_TRANSMITTANCE
#define CLOUD_TOP_OFFSET 750.0
#define CLOUD_SCALE crispiness
#define CLOUD_SPEED cloudSpeed

#define SUN_DIR float3(lightDirection.xyz)
#define SUN_COLOR (float3(lightColor.xyz) * float3(1.1, 1.1, 0.95))

static float3 sphereCenter = float3(0.0, -EARTH_RADIUS, 0.0);



static bool enablePowder = false;

float HG(float sundotrd, float g)
{
	float gg = g * g;
	return (1. - gg) / pow(1.0 + gg - 2.0 * g * sundotrd, 1.5);
}

bool intersectCubeMap(float3 o, float3 d, out float3 minT, out float3 maxT)
{
	float3 cubeMin = float3(-0.5, -0.5, -0.5);
	float3 cubeMax = float3(0.5, 1 + cubeMin.y, 0.5);

	// compute intersection of ray with all six bbox planes
	float3 invR = 1.0 / d;
	float3 tbot = invR * (cubeMin - o);
	float3 ttop = invR * (cubeMax - o);
	// re-order intersections to find smallest and largest on each axis
	float3 tmin = min (ttop, tbot);
	float3 tmax = max (ttop, tbot);
	// find the largest tmin and the smallest tmax
	float2 t0 = max (tmin.xx, tmin.yz);
	float tnear = max (t0.x, t0.y);
	t0 = min (tmax.xx, tmax.yz);
	float tfar = min (t0.x, t0.y);

	// check for hit
	bool hit;
	if ((tnear > tfar) || tfar < 0.0)
		hit = false;
	else
		hit = true;

	minT = tnear < 0.0 ? o : o + d * tnear; // if we are inside the bb, start point is cam pos
	maxT = o + d * tfar;

	return hit;
}

bool raySphereintersection(float3 orig, float3 dir, float radius, out float3 startPos)
{

	float t;

	sphereCenter.xz = cameraPosition.xz;

	float rsrs = radius * radius;

	float3 L = orig - sphereCenter;
	float a = dot(dir, dir);
	float b = 2.0 * dot(dir, L);
	float c = dot(L, L) - rsrs;

	float discr = b * b - 4.0 * a * c;
	if (discr < 0.0)
	{
		return false;
	}

	t = max(0.0, (-b + sqrt(discr)) / 2);
	if (t == 0.0)
	{
		return false;
	}
	startPos = orig + dir * t;

	return true;
}

bool raySphereintersection2(float3 orig, float3 dir, float radius, out float3 startPos)
{

	float t;

	sphereCenter.xz = cameraPosition.xz;

	float rsrs = radius * radius;

	float3 L = orig - sphereCenter;
	float a = dot(dir, dir);
	float b = 2.0 * dot(dir, L);
	float c = dot(L, L) - rsrs;

	float discr = b * b - 4.0 * a * c;
	if (discr < 0.0)
	{
		return false;
	}
	t = max(0.0, (-b + sqrt(discr)) / 2);
	if (t == 0.0)
	{
		return false;
	}
	startPos = orig + dir * t;

	return true;
}



float getHeightFraction(float3 inPos)
{
	return (length(inPos - sphereCenter) - SPHERE_INNER_RADIUS) / (SPHERE_OUTER_RADIUS - SPHERE_INNER_RADIUS);
}

float getDensityForCloud(float heightFraction, float cloudType)
{
	float stratusFactor = 1.0 - saturate(cloudType * 2.0);
	float stratoCumulusFactor = 1.0 - abs(cloudType - 0.5) * 2.0;
	float cumulusFactor = saturate(cloudType - 0.5) * 2.0;

	float4 baseGradient = stratusFactor * STRATUS_GRADIENT + stratoCumulusFactor * STRATOCUMULUS_GRADIENT + cumulusFactor * CUMULUS_GRADIENT;

	// gradicent computation (see Siggraph 2017 Nubis-Decima talk)
	//return remap(heightFraction, baseGradient.x, baseGradient.y, 0.0, 1.0) * remap(heightFraction, baseGradient.z, baseGradient.w, 1.0, 0.0);
	return smoothstep(baseGradient.x, baseGradient.y, heightFraction) - smoothstep(baseGradient.z, baseGradient.w, heightFraction);
}

float threshold(const float v, const float t)
{
	return v > t ? v : 0.0;
}



float2 getUVProjection(float3 p)
{
	return p.xz / SPHERE_INNER_RADIUS + 0.5;
}


float sampleCloudDensity(float3 p, bool expensive, float lod)
{
	float3 windDirection = normalize(float3(0.5, 0.0, 0.1));

	float heightFraction = getHeightFraction(p);
	
	float3 animation = heightFraction * windDirection * CLOUD_TOP_OFFSET + windDirection * iTime * CLOUD_SPEED; // orig
	//float3 animation = windDirection * (heightFraction * CLOUD_TOP_OFFSET) + windDirection * (iTime * CLOUD_SPEED);
	
		
	float2 uv = getUVProjection(p);
	float2 moving_uv = getUVProjection(p + animation);


	if (heightFraction < 0.0 || heightFraction > 1.0)
	{
		return 0.0;
	}
	//vec4 low_frequency_noise = textureLod(cloud, vec3(uv*CLOUD_SCALE, heightFraction), lod);
	float4 low_frequency_noise = PerlinWorleyNoiseLow.SampleLevel(samplerMirrorLinear, float3(uv * float2(CLOUD_SCALE, CLOUD_SCALE), heightFraction), lod, int3(0, 0, 0));
	float lowFreqFBM = dot(low_frequency_noise.gba, float3(0.625, 0.25, 0.125));
	float base_cloud = remap(low_frequency_noise.r, -(1.0 - lowFreqFBM), 1., 0.0, 1.0);

	float density = getDensityForCloud(heightFraction, 1.0);
	base_cloud *= (density / heightFraction);

	//vec3 CurlNoise = texture(CurlNoiseTex, moving_uv).rgb;
	float3 CurlNoise = (float3)CurlNoiseTex.SampleLevel(samplerMirrorLinear, moving_uv, lod, int2(0, 0));
	float cloud_coverage = CurlNoise.r * coverage_multiplier;
	float base_cloud_with_coverage = remap(base_cloud, cloud_coverage, 1.0, 0.0, 1.0);
	base_cloud_with_coverage *= cloud_coverage;

	//bool expensive = true;

	//expensive = false;
	if (expensive)
	{
		//vec3 erodeCloudNoise = textureLod(WorleyNoiseTexHigh, vec3(moving_uv*CLOUD_SCALE, heightFraction)*curliness, lod).rgb;
		float3 uv_32 = float3(moving_uv * CLOUD_SCALE, heightFraction) * curliness;
		float3 erodeCloudNoise = (float3)WorleyNoiseTexHigh.SampleLevel(samplerMirrorLinear, uv_32, lod, int3(0, 0, 0));
		float highFreqFBM = dot(erodeCloudNoise.rgb, float3(0.625, 0.25, 0.125));//(erodeCloudNoise.r * 0.625) + (erodeCloudNoise.g * 0.25) + (erodeCloudNoise.b * 0.125);
		float highFreqNoiseModifier = lerp(highFreqFBM, 1.0 - highFreqFBM, saturate(heightFraction * 10.0));

		base_cloud_with_coverage = base_cloud_with_coverage - highFreqNoiseModifier * (1.0 - base_cloud_with_coverage);

		base_cloud_with_coverage = remap(base_cloud_with_coverage * 2.0, highFreqNoiseModifier * 0.2, 1.0, 0.0, 1.0);
	}

	return saturate(base_cloud_with_coverage);
}


float beer(float d)
{
	return exp(-d);
}

float powder(float d)
{
	return (1. - exp(-2. * d));

}

float phase(float3 inLightVec, float3 inViewVec, float g) 
{
	float costheta = dot(inLightVec, inViewVec) / length(inLightVec) / length(inViewVec);
	return HG(costheta, g);
}

 float raymarchToLight(float3 o, float stepSize, float3 lightDir, float originalDensity, float lightDotEye)
 {

	 float3 startPos = o;
	 float ds = stepSize * 6.0;
	 float3 rayStep = lightDir * ds;
	 const float CONE_STEP = 1.0 / 6.0;
	 float coneRadius = 1.0;
	 float density = 0.0;
	 float coneDensity = 0.0;
	 float invDepth = 1.0 / ds;
	 float sigma_ds = -ds * absorption;
	 float3 pos;

	 float T = 1.0;

	 for (uint i = 0; i < 6; i++)
	 {
		 pos = startPos + coneRadius * noiseKernel[i] * float(i);

		 float heightFraction = getHeightFraction(pos);
		 if (heightFraction >= 0)
		 {
			 float cloudDensity = sampleCloudDensity(pos, density > 0.3, i / 16);
			 if (cloudDensity > 0.0)
			 {
				 float Ti = exp(cloudDensity * sigma_ds);
				 T *= Ti;
				 density += cloudDensity;
			 }
		 }
		 startPos += rayStep;
		 coneRadius += CONE_STEP;
	 }

	 //return 2.0*T*powder((originalDensity));//*powder(originalDensity, 0.0);
	 return T;
 }
//float3 ambientlight = float3(255, 255, 235)/255;
//float ambientFactor = 0.5;
//static float3 lc = ambientlight * ambientFactor;// * cloud_bright;

float3 ambient_light(float heightFrac)
{
	return lerp(float3(0.5, 0.67, 0.82), float3(1.0, 1.0, 1.0), heightFrac);
}



float4 raymarchToCloud(uint2 pixel, float3 startPos, float3 endPos, float3 bg, out float4 cloudPos)
{
	float3 path = endPos - startPos;
	float len = length(path);

	//float maxLen = length(planeDim);

	//float volumeHeight = planeMax.y - planeMin.y;

	const int nSteps = 64;//int(mix(48.0, 96.0, clamp( len/SPHERE_DELTA - 1.0,0.0,1.0) ));

	float ds = len / nSteps;
	float3 dir = path / len;
	dir *= ds;
	float4 col = float4(0.0, 0.0, 0.0, 0.0);
	uint2 fragCoord = pixel;
	uint a = uint(fragCoord.x) % 4;
	uint b = uint(fragCoord.y) % 4;
	startPos += dir * bayerFilter[a * 4 + b];
	//startPos += dir*abs(Random2D(float3(a,b,a+b)))*.5;
	float3 pos = startPos;

	float density = 0.0;

	float lightDotEye = dot(normalize(SUN_DIR), normalize(dir));

	float T = 1.0;
	float sigma_ds = -ds * densityFactor;
	bool expensive = true;
	bool entered = false;

	int zero_density_sample = 0;

	for (uint i = 0; i < (uint)nSteps; i++)
	{
		//if( pos.y >= cameraPosition.y - SPHERE_DELTA*1.5 ){

		float density_sample = sampleCloudDensity(pos, true, i / 16);
		if (density_sample > 0.)
		{
			if (!entered)
			{
				cloudPos = float4(pos, 1.0);
				entered = true;
			}
			float height = getHeightFraction(pos);
			float3 ambientLight = CLOUDS_AMBIENT_COLOR_BOTTOM; //mix( CLOUDS_AMBIENT_COLOR_BOTTOM, CLOUDS_AMBIENT_COLOR_TOP, height );
			float light_density = raymarchToLight(pos, ds * 0.1, SUN_DIR, density_sample, lightDotEye);
			float scattering = lerp(HG(lightDotEye, -0.08), HG(lightDotEye, 0.08), saturate(lightDotEye * 0.5 + 0.5));
			//scattering = 0.6;
			scattering = max(scattering, 1.0);
			float powderTerm = powder(density_sample);
			if (!enablePowder)
			{
				powderTerm = 1.0;
			}
			float3 S = 0.6*( lerp( lerp(ambientLight*1.8, bg, 0.2), scattering*SUN_COLOR, powderTerm*light_density)) * density_sample;
			float dTrans = exp(density_sample * sigma_ds);
			float3 Sint = (S - S * dTrans) * (1. / density_sample);
			col.rgb += T * Sint;
			T *= dTrans;

		}

		if (T <= CLOUDS_MIN_TRANSMITTANCE) 
			break;

		pos += dir;
		//}
	}
	//col.rgb += ambientlight*0.02;
	col.a = 1.0 - T;
	
	//col = float4( float3(getHeightFraction(startPos)), 1.0);

	return col;
}


float computeFogAmount(in float3 startPos, in float factor)
{
	float dist = length(startPos - float3(cameraPosition.xyz));
	float radius = (cameraPosition.y - sphereCenter.y) * 0.3;
	float alpha = (dist / radius);
	//v.rgb = mix(v.rgb, ambientColor, alpha*alpha);

	return (1.-exp( -dist*alpha*factor));
}
#define HDR(col, exps) 1.0 - exp(-col * exps)

[numthreads(GEN_SKY_THREAD_NUM, 1, 1)]
void GenerateSkyEnv(uint3 groupID : SV_GroupID, uint3 dispatchThreadId : SV_DispatchThreadID)
{
	float4 fragColor_v, bloom_v, alphaness_v, cloudDistance_v;

	uint ArrayIndex = dispatchThreadId.x / (Res.x * Res.y);
	dispatchThreadId.x = dispatchThreadId.x % (Res.x * Res.y);
	
	if (ArrayIndex >= 5)
		return;

	uint	FaceIndexList[5] = { 0, 1, 2, 4, 5 };
	uint	CubeFaceIndex = FaceIndexList[ArrayIndex];
	uint2	CurPixel = uint2(dispatchThreadId.x % Res.x, dispatchThreadId.x / Res.x);	// 현재 픽셀의 좌표

	uint2	DestCoord = CurPixel;
	// Skip out of bound pixels
	if (CurPixel.y >= Res.y)
		return;

	float4 ray_view = float4(
		(((2.0f * (float)CurPixel.x) / (float)Res.x) - 1.0f) * DecompProj.rcp_m11,
		-(((2.0f * (float)CurPixel.y) / (float)Res.y) - 1.0f) * DecompProj.rcp_m22,
		1.0, 0.0);
	
	float4 ray_world = mul(ray_view, matViewInvArray[CubeFaceIndex]);
	//ray_world.xyz *= (1.0 / 100.0);
	ray_world.xyz = normalize(ray_world.xyz);
	float3 worldDir = ray_world.xyz;
	
	float3 startPos, endPos;
	float4 v = float4(0.0, 0.0, 0.0, 0.0);

	//compute background color
	float3 stub, cubeMapEndPos;
	//intersectCubeMap(float3(0.0, 0.0, 0.0), worldDir, stub, cubeMapEndPos);
	bool hit = raySphereintersectionSkyMap(worldDir, 0.5, cubeMapEndPos);

	//float4 bg = float4(0, 0, 1, 1);// texture(sky, fragCoord / iResolution);
	
	//float3	texCoord = float3(input.TexCoord.xy,TexArrayIndex);
	//float4	texColor = texDiffuseArray.Sample(samplerDiffuse, texCoord);

	float3 bgTexCoord = float3((float2)CurPixel / (float2)Res, CubeFaceIndex);
	float4 bg = AtmosphereTexArray.SampleLevel(samplerClampLinear, bgTexCoord, 0, int2(0, 0));
	float3 red = float3(1, 1, 1);
	
	bg = lerp(lerp(red.rgbr, float4(1, 1, 1, 1), SUN_DIR.y), bg, pow(max(cubeMapEndPos.y + 0.1, .0), 0.2));
	//vec4 bg = vec4( TonemapACES(preetham(worldDir)), 1.0);
	int case_ = 0;
	//compute raymarching starting and ending point
	float3 fogRay;
	if (cameraPosition.y < SPHERE_INNER_RADIUS - EARTH_RADIUS)
	{
		// 카메라 위칙 통상범위, 구름층 아래
		raySphereintersection(float3(cameraPosition.xyz), float3(worldDir.xyz), SPHERE_INNER_RADIUS, startPos);	// 안쪽 반지름과 교차하는 점 - startPos
		raySphereintersection(float3(cameraPosition.xyz), float3(worldDir.xyz), SPHERE_OUTER_RADIUS, endPos);	// 바깥쪽 반지름과 교차하는 점 - endPos
		fogRay = startPos;
	}
	else if (cameraPosition.y > SPHERE_INNER_RADIUS - EARTH_RADIUS && cameraPosition.y < SPHERE_OUTER_RADIUS - EARTH_RADIUS)
	{
		// 카메라 위치가 구름층 min 과 max사이
		startPos = cameraPosition.xyz;
		raySphereintersection(cameraPosition.xyz, worldDir.xyz, SPHERE_OUTER_RADIUS, endPos);
		bool hit = raySphereintersection(cameraPosition.xyz, worldDir.xyz, SPHERE_INNER_RADIUS, fogRay);
		if (!hit)
		{
			fogRay = startPos;
		}
		case_ = 1;
	}
	else
	{
		// 카메라 위치가 구름층 max 위
		raySphereintersection2(cameraPosition.xyz, worldDir.xyz, SPHERE_OUTER_RADIUS, startPos);
		raySphereintersection2(cameraPosition.xyz, worldDir.xyz, SPHERE_INNER_RADIUS, endPos);
		raySphereintersection(cameraPosition.xyz, worldDir.xyz, SPHERE_OUTER_RADIUS, fogRay);
		case_ = 2;
	}

	//compute fog amount and early exit if over a certain value
	float fogAmount = computeFogAmount(fogRay, 0.00006);
	
	fragColor_v = bg;
	bloom_v = float4(getSun(worldDir.xyz, SUN_DIR, 128) * 1.3, 1.0);

	if(fogAmount > 0.965)
	{
		fragColor_v = bg;
		bloom_v = bg;
		
		TexBufferArray[uint3(DestCoord, CubeFaceIndex)] = fragColor_v;
		return;
	}
	
	v = raymarchToCloud(CurPixel, startPos, endPos, bg.rgb, cloudDistance_v);
	cloudDistance_v = float4(distance(cameraPosition.xyz, cloudDistance_v.xyz), 0.0,0.0,0.0);

	float cloudAlphaness = threshold(v.a, 0.2);
	v.rgb = v.rgb*1.8 - 0.1; // contrast-illumination tuning
	
	// apply atmospheric fog to far away clouds
	float3 ambientColor = bg.rgb;

	// use current position distance to center as action radius
    v.rgb = lerp(v.rgb, bg.rgb*v.a, saturate(fogAmount));
	
	// add sun glare to clouds
	float sun = saturate( dot(SUN_DIR,normalize(endPos - startPos)));
	float3 s = 0.8*float3(1.0,0.4,0.2)*pow( sun, 256.0 );
	v.rgb += s*v.a;
	
	// blend clouds and background

	fragColor_v.rgb = bg.rgb*(1.0 - v.a) + v.rgb;
	//fragColor_v.rgb = lerp(bg.rgb, v.rgb, v.a);
	alphaness_v = float4(cloudAlphaness, 0.0, 0.0, 1.0); // alphaness buffer
	
	if(cloudAlphaness > 0.1)
	{ 
		//apply fog to bloom buffer
		float fogAmount = computeFogAmount(startPos, 0.00003);

		float3 cloud = lerp(float3(0, 0, 0), bloom_v.rgb, saturate(fogAmount));
		bloom_v.rgb = bloom_v.rgb*(1.0 - cloudAlphaness) + cloud.rgb;

	}
	fragColor_v.a = alphaness_v.r;

	//imageStore(fragColor, fragCoord, fragColor_v);
	
	TexBufferArray[uint3(DestCoord, CubeFaceIndex)] = fragColor_v;


}