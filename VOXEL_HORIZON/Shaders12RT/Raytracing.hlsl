#ifndef RAYTRACING_HLSL
#define RAYTRACING_HLSL

#include "sh_define.hlsl"
#include "sh_typedef.hlsl"
#include "sh_voxel_common.hlsl"
#include "Raytracing_util.hlsl"
#include "BxDF.hlsl"
#include "sh_util.hlsl"


static const float T_OFFSET = 5.0;
//static const float3 DEFAULT_LIGHT_COLOR = float3(0.55, 0.75, 1.0);
//static const float3 DEFAULT_LIGHT_COLOR = float3(0.55, 0.75, 1.0) * 1.5;
static const float3 DEFAULT_LIGHT_COLOR = float3(1.0, 1.0, 1.0);
//static const float3 DEFAULT_LIGHT_COLOR = float3(1.0, 0.5, 0.25);
static const float DEFAULT_GLOSS = 4.0;

// for RTAO
static const float g_exponentialFalloffDecayConstant = 4.0;
static const int g_approximateInterreflections = 1;
static const int g_applyExponentialFalloff = 1;
static const float g_diffuseReflectanceScale = 0.5;
static const float RayHitDistanceOnMiss = 0;
static const float InvalidAOCoefficientValue = -1;

// Encodes a smooth logarithmic gradient for even distribution of precision natural to vision
float LinearToLogLuminance( float x, float gamma = 4.0 )
{
    return log2(lerp(1, exp2(gamma), x)) / gamma;
}

// This assumes the default color gamut found in sRGB and REC709.  The color primaries determine these
// coefficients.  Note that this operates on linear values, not gamma space.
float RGBToLuminance( float3 x )
{
    return dot( x, float3(0.212671, 0.715160, 0.072169) );        // Defined by sRGB/Rec.709 gamut
}

float MaxChannel(float3 x)
{
    return max(x.x, max(x.y, x.z));
}

// This is the same as above, but converts the linear luminance value to a more subjective "perceived luminance",
// which could be called the Log-Luminance.
float RGBToLogLuminance( float3 x, float gamma = 4.0 )
{
    return LinearToLogLuminance( RGBToLuminance(x), gamma );
}

bool HasAORayHitAnyGeometry(in float tHit)
{
	return tHit != RayHitDistanceOnMiss;
}

// Trace an AO ray and return true if it hits any geometry.
bool TraceAORayAndReportIfHit(out float tHit, in float3 orig, in float3 dir, in float minT, in float maxT, in float3 surfaceNormal)
{
	// Initialize shadow ray payload.
	// Set the initial value to a hit at TMax. 
	// Miss shader will set it to HitDistanceOnMiss.
	// This way closest and any hit shaders can be skipped if true tHit is not needed. 
	//ShadowPayload shadowPayload = { TMax };
	
    RayDesc rayDesc;
    // Nudge the origin along the surface normal a bit to avoid 
    // starting from behind the surface
    // due to float calculations imprecision.
	rayDesc.Origin = orig;
	rayDesc.Direction = dir;

    // Set the ray's extents.
	rayDesc.TMin = minT; // 0
	rayDesc.TMax = maxT;

    // Initialize shadow ray payload.
    // Set the initial value to a hit at TMax. 
    // This way closest and any hit shaders can be skipped if true tHit is not needed. 
    ShadowPayload shadowPayload = { maxT };


	uint rayFlags = RAY_FLAG_CULL_NON_OPAQUE;             // ~skip transparent objects
	//uint rayFlags = RAY_FLAG_FORCE_OPAQUE;
	TraceRay(Scene,
			 rayFlags,
			 ~0,
			 1,
			 2,
			 1,
			 rayDesc, shadowPayload);

    tHit = shadowPayload.tHit;

    // Report a hit if Miss Shader didn't set the value to HitDistanceOnMiss.
    return HasAORayHitAnyGeometry(tHit);
}
float CalculateAO(out float tHit, in float3 orig, in float3 dir, in float3 surfaceNormal, in float3 surfaceAlbedo, float MinAmbientIllumination, float MaxTheoreticalAORayHitTime, in float tMin, in float tMax)
{
    float ambientCoef = 1;
	if (TraceAORayAndReportIfHit(tHit, orig, dir, tMin, tMax, surfaceNormal))
    {
        float occlusionCoef = 1;
        if (g_applyExponentialFalloff)
        {
            float theoreticalTMax = MaxTheoreticalAORayHitTime;
            float t = tHit / theoreticalTMax;
            float lambda = g_exponentialFalloffDecayConstant;
            occlusionCoef = exp(-lambda * t * t);
        }
        ambientCoef = 1 - (1 - MinAmbientIllumination) * occlusionCoef;

        // Approximate interreflections of light from blocking surfaces which are generally not completely dark and tend to have similar radiance.
        // Ref: Ch 11.3.3 Accounting for Interreflections, Real-Time Rendering (4th edition).
        // The approximation assumes:
        //      o All surfaces' incoming and outgoing radiance is the same 
        //      o Current surface color is the same as that of the occluders
        // Since this sample uses scalar ambient coefficient, it usse the scalar luminance of the surface color.
        // This will generally brighten the AO making it closer to the result of full Global Illumination, including interreflections.
        if (g_approximateInterreflections)
        {
            float kA = ambientCoef;
            float rho = g_diffuseReflectanceScale * RGBToLuminance(surfaceAlbedo);

            ambientCoef = kA / (1 - rho * (1 - kA));
        }
    }

    return ambientCoef;
}


RadiancePayload TraceRadianceRay(in Ray ray, in uint CurRayRecursionDepth, in uint MaxRecursionDepth, float tMin, float tMax, bool cullNonOpaque, bool cullBackFace, bool CalcAO)
{
	RadiancePayload rayPayload = (RadiancePayload)0;

	rayPayload.rayRecursionDepth = CurRayRecursionDepth + 1;
	rayPayload.radiance = 0;
	
#if defined(RTAO_IN_TRACE_RAY)
	// rtao
	rayPayload.ao.RTAOEnabled = CalcAO;
	rayPayload.ao.AO_CoEfficient = 1.0;
	rayPayload.ao.AO_Distance = INVALID_AO_DISTNACE;
	rayPayload.ao.NormalDepth = EncodeNormalDepth(float3(0, 0, 0), 1.0);
	rayPayload.ao.ReprojectedNormalDepth = EncodeNormalDepth(float3(0, 0, 0), 1.0);
	rayPayload.ao.LinearDepth = 1.0;
	rayPayload.ao.MotionVector = 1e3f;
#endif
	if (CurRayRecursionDepth >= MaxRecursionDepth)
	{
		rayPayload.radiance = g_ColorOverRecusionDepth.rgb;
		return rayPayload;
	}

	// Set the ray's extents.
	RayDesc rayDesc;
	rayDesc.Origin = ray.origin;
	rayDesc.Direction = ray.direction;
	rayDesc.TMin = tMin;
	rayDesc.TMax = tMax;

	uint rayFlags = 0;
	if (cullNonOpaque)
	{
		rayFlags |= RAY_FLAG_CULL_NON_OPAQUE;
	}
	if (cullBackFace)
	{
		rayFlags |= RAY_FLAG_CULL_BACK_FACING_TRIANGLES;
	}
	// TraceRay(Scene, rayFlags, ~0, 1, 2, 1, rayDesc, shadowPayload); // shadow
	// TraceRay(Scene, rayFlags, ~0, 0, 2, 0, rayDesc, rayPayload); // radiance
		
	//	TraceRay(Scene, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, ~0, 0, 1, 0, ray, payload);
	//	TraceRay(g_scene, rayFlags, TraceRayParameters::InstanceMask, TraceRayParameters::HitGroup::Offset[PathtracerRayType::Shadow], TraceRayParameters::HitGroup::GeometryStride, TraceRayParameters::MissShader::Offset[PathtracerRayType::Shadow], rayDesc, shadowPayload);
	TraceRay(Scene, rayFlags, ~0, 0, 2, 0, rayDesc, rayPayload);

	return rayPayload;
}
// Returns radiance of the traced reflected ray.
float3 TraceReflectedGBufferRay(in float3 hitPosition, in float3 wi, in float3 N, in float3 objectNormal, inout RadiancePayload rayPayload, in float TMax, in uint MaxRecursionDepth)
{
	// Here we offset ray start along the ray direction instead of surface normal 
	// so that the reflected ray projects to the same screen pixel. 
	// Offsetting by surface normal would result in incorrect mappating in temporally accumulated buffer. 
	float tOffset = T_OFFSET;
	float3 offsetAlongRay = tOffset * wi;

	float3 adjustedHitPosition = hitPosition + offsetAlongRay;

	Ray ray = { adjustedHitPosition,  wi };

	float tMin = 10.0;
	float tMax = TMax;

	bool cullNonOpaque = false;
	bool cullBackFace = true;
	rayPayload = TraceRadianceRay(ray, rayPayload.rayRecursionDepth, MaxRecursionDepth, tMin, tMax, cullNonOpaque, cullBackFace, false);

	//if (rayPayload.AOGBuffer.tHit != HitDistanceOnMiss)
	//{
	//    // Get the current planar mirror in the previous frame.
	//    float3x4 _mirrorBLASTransform = g_prevFrameBottomLevelASInstanceTransform[InstanceIndex()];
	//    float3 _mirrorHitPosition = mul(_mirrorBLASTransform, float4(HitObjectPosition(), 1));

	//    // Pass the virtual hit position reflected across the current mirror surface upstream 
	//    // as if the ray went through the mirror to be able to recursively reflect at correct ray depths and then projecting to the screen.
	//    // Skipping normalization as it's not required for the uses of the transformed normal here.
	//    float3 _mirrorNormal = mul((float3x3)_mirrorBLASTransform, objectNormal);

	//    rayPayload.AOGBuffer._virtualHitPosition = ReflectFrontPointThroughPlane(rayPayload.AOGBuffer._virtualHitPosition, _mirrorHitPosition, _mirrorNormal);

	//    // Add current thit and the added offset to the thit of the traced ray.
	//    rayPayload.AOGBuffer.tHit += RayTCurrent() + tOffset;
	//}

	return rayPayload.radiance;
}
// Returns radiance of the traced refracted ray.
float3 TraceRefractedGBufferRay(in float3 hitPosition, in float3 wt, in float3 N, in float3 objectNormal, inout RadiancePayload rayPayload, in float TMax, in uint MaxRecursionDepth)
{
    // Here we offset ray start along the ray direction instead of surface normal 
    // so that the reflected ray projects to the same screen pixel. 
    // Offsetting by surface normal would result in incorrect mappating in temporally accumulated buffer. 
    float tOffset = 0.001f;
    float3 offsetAlongRay = tOffset * wt;

    float3 adjustedHitPosition = hitPosition + offsetAlongRay;

    Ray ray = { adjustedHitPosition,  wt };

    float tMin = 0.1; 
    float tMax = TMax; 

    // TRADEOFF: Performance vs visual quality
    // Cull transparent surfaces when casting a transmission ray for a transparent surface.
    // Spaceship in particular has multiple layer glass causing a substantial perf hit 
    // with multiple bounces along the way.
    // This can cause visual pop ins however, such as in a case of looking at the spaceship's
    // glass cockpit through a window in the house. The cockpit will be skipped in this case.
    bool cullNonOpaque = false;	// 나뭇잎등은 NonOpaque이므로 이걸 non opazue매쉬를 컬링하면 나뭇잎 모서리 알파 문제가 생긴다.
	bool cullBackFace = true;
	rayPayload = TraceRadianceRay(ray, rayPayload.rayRecursionDepth, MaxRecursionDepth, tMin, tMax, cullNonOpaque, cullBackFace, false);

    //if (rayPayload.AOGBuffer.tHit != HitDistanceOnMiss)
    //{
    //    // Add current thit and the added offset to the thit of the traced ray.
    //    rayPayload.AOGBuffer.tHit += RayTCurrent() + tOffset;
    //}

    return rayPayload.radiance;
}
// Trace a shadow ray and return true if it hits any geometry.
bool TraceShadowRayAndReportIfHitC(out float tHit, in Ray ray, in uint CurRayRecursionDepth, in uint MaxRecursionDepth, in bool retrieveTHit, in float TMax)
{
	if (CurRayRecursionDepth >= MaxRecursionDepth)
	{
		return false;
	}
	
	

	// Set the ray's extents.
	RayDesc rayDesc;
	rayDesc.Origin = ray.origin;
	rayDesc.Direction = ray.direction;
	rayDesc.TMin = 1.0;
	rayDesc.TMax = TMax;

	// Initialize shadow ray payload.
	// Set the initial value to a hit at TMax. 
	// Miss shader will set it to HitDistanceOnMiss.
	// This way closest and any hit shaders can be skipped if true tHit is not needed. 
	//ShadowPayload shadowPayload = { TMax };
	ShadowPayload shadowPayload = { 0 };

	uint rayFlags = RAY_FLAG_CULL_NON_OPAQUE;             // ~skip transparent objects
	bool acceptFirstHit = !retrieveTHit;
	if (acceptFirstHit)
	{
		// Performance TIP: Accept first hit if true hit is not neeeded,
		// or has minimal to no impact. The peformance gain can
		// be substantial.
		rayFlags |= RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH;
	}

	// Skip closest hit shaders of tHit time is not needed.
	if (!retrieveTHit)
	{
		rayFlags |= RAY_FLAG_SKIP_CLOSEST_HIT_SHADER;
	}
	rayFlags = 0;// RAY_FLAG_CULL_BACK_FACING_TRIANGLES;

	// TraceRay(Scene, rayFlags, ~0, 1, 2, 1, rayDesc, shadowPayload); // shadow
	// TraceRay(Scene, rayFlags, ~0, 0, 2, 0, rayDesc, rayPayload); // radiance
		
	TraceRay(Scene,
			 rayFlags,
			 ~0,
			 1,
			 2,
			 1,
			 rayDesc, shadowPayload);
	//TraceRay(g_scene,
	//		 rayFlags,
	//		 TraceRayParameters::InstanceMask,
	//		 TraceRayParameters::HitGroup::Offset[PathtracerRayType::Shadow],
	//		 TraceRayParameters::HitGroup::GeometryStride,
	//		 TraceRayParameters::MissShader::Offset[PathtracerRayType::Shadow],
	//		 rayDesc, shadowPayload);
	// Report a hit if Miss Shader didn't set the value to HitDistanceOnMiss.
	tHit = shadowPayload.tHit;

	return shadowPayload.tHit > 0;
}
bool TraceShadowRayAndReportIfHitB(out float tHit, in Ray ray, in float3 N, in uint CurRayRecursionDepth, in uint MaxRecursionDepth, in bool retrieveTHit, in float TMax)
{
	// Only trace if the surface is facing the target.
	if (dot(ray.direction, N) > 0)
	{
		return TraceShadowRayAndReportIfHitC(tHit, ray, CurRayRecursionDepth, MaxRecursionDepth, retrieveTHit, TMax);
	}
	return false;
}

bool TraceShadowRayAndReportIfHitA(in float3 hitPosition, in float3 direction, in float3 N, in RadiancePayload rayPayload, in float TMax, in uint MaxRecursionDepth)
{
	float tOffset = T_OFFSET;
	Ray visibilityRay = { hitPosition + tOffset * N, direction };
	float dummyTHit;
	return TraceShadowRayAndReportIfHitB(dummyTHit, visibilityRay, N, rayPayload.rayRecursionDepth, MaxRecursionDepth, false, TMax);
}
float3 Shade(inout RadiancePayload rayPayload, in float3 N, in float3 objectNormal, in float3 hitPosition, in RAY_TRACING_MATERIAL material, uint shadingType)
{
	uint MaxRadianceRecursionDepth = g_MaxRadianceRayRecursionDepth;
	
	if (MaterialType::Effect == material.type)
	{
		MaxRadianceRecursionDepth = g_MaxEffectRadianceRayRecursionDepth;
	}

	float3 V = -WorldRayDirection();
	float pdf;
	float3 indirectContribution = 0;
	float3 L = 0;

	const float3 Kd = material.Kd;
	const float3 Ks = material.Ks * g_Ks_Mul_Const;
	const float3 Kr = material.Kr * g_Kr_Mul_Const;
	const float3 Kt = material.Kt;
	const float roughness = material.roughness;

	// Direct illumination
   //rayPayload.AOGBuffer.diffuseByte3 = NormalizedFloat3ToByte3(Kd);
	if (!BxDF::IsBlack(material.Kd) || !BxDF::IsBlack(material.Ks))
	{
		for (uint i = 0; i < g_RTLightNum; i++)
		{
			float3 LightColor = g_RTLightList[i].Color;
			float3 LightPos = g_RTLightList[i].Pos;
			float3 LightDir = LightPos - hitPosition;

			if (RTLIGHT_TYPE_DIRECTIONAL == g_RTLightList[i].Type)
			{
				// g_RTLightList[i].Pos은 빛방향 * -1, 즉 위에서 내려쬐는 빛이면 y성분이 +
				float3 LightDirN = g_RTLightList[i].Pos;
				LightDir = LightDirN * g_RTLightList[i].Rs;
				LightPos = hitPosition + LightDir;
			}
			float LightDistDist = dot(LightDir, LightDir);
			float LightDist = sqrt(LightDistDist);

			if (RTLIGHT_TYPE_POINT == g_RTLightList[i].Type)
			{
				if (LightDist >  g_RTLightList[i].Rs)
					continue;
			}
			
			// LightPos - hitPosition 미리 계산해서 distnace와 normalize의 최적화 가능. 나중에 최적화할것
			float3 wi = LightDir / LightDist;
			float LightRsRs = (g_RTLightList[i].Rs * g_RTLightList[i].Rs);	// constant buffer로 뺀다.
			float tMax = LightDist;

			// Raytraced shadows.
			//bool TraceShadowRayAndReportIfHitA(in float3 hitPosition, in float3 direction, in float3 N, in RadiancePayload rayPayload, in float TMax = 10000)
			bool isInShadow = false;
			if (g_RTLightList[i].ShadowEnabled)
			{
				isInShadow = TraceShadowRayAndReportIfHitA(hitPosition, wi, N, rayPayload, tMax, g_MaxShadowRayRecursionDepth);
			}
			if (RTLIGHT_TYPE_POINT == g_RTLightList[i].Type)
			{
				if (!isInShadow)
				{
					L += ApplyPointLight(Kd, Ks, 1, DEFAULT_GLOSS, N, V, hitPosition, LightPos, LightRsRs, LightColor, shadingType);
				}
			}
			else
			{
				if (SHADING_TYPE_TOON == shadingType)
				{

					L += BxDF::DirectLighting::Shade_Toon(
						material.type,
						Kd,
						Ks,
						LightColor.rgb,
						isInShadow,
						roughness,
						N,
						V,
						wi);
				}
				else
				{
					L += BxDF::DirectLighting::Shade(
						material.type,
						Kd,
						Ks,
						LightColor.rgb,
						isInShadow,
						roughness,
						N,
						V,
						wi);
				}
			}
		}
	}
	// Ambient Indirect Illumination
	// Add a default ambient contribution to all hits. 
	// This will be subtracted for hitPositions with 
	// calculated Ambient coefficient in the composition pass.
	L += material.AmbientIntensity * Kd;

	// Specular Indirect Illumination
	bool isReflective = !BxDF::IsBlack(Kr);
	bool isTransmissive = !BxDF::IsBlack(Kt);

	// Handle cases where ray is coming from behind due to imprecision,
	// don't cast reflection rays in that case.
	float smallValue = 1e-6f;
	isReflective = dot(V, N) > smallValue ? isReflective : false;

	if (isReflective || isTransmissive)
	{
		if (isReflective
			&& (BxDF::Specular::Reflection::IsTotalInternalReflection(V, N)
			|| material.type == MaterialType::Mirror))
		{
			RadiancePayload reflectedRayPayLoad = rayPayload;
			float3 wi = reflect(-V, N);

			L += Kr * TraceReflectedGBufferRay(hitPosition, wi, N, objectNormal, reflectedRayPayLoad, FAR_PLANE, MaxRadianceRecursionDepth);
			//UpdateAOGBufferOnLargerDiffuseComponent(rayPayload, reflectedRayPayLoad, Kr);
		}
		else // No total internal reflection
		{
			float3 Fo = Ks;
			if (isReflective)
			{
				// Radiance contribution from reflection.
				float3 wi;
				float3 Fr = Kr * BxDF::Specular::Reflection::Sample_Fr(V, wi, N, Fo);    // Calculates wi

				RadiancePayload reflectedRayPayLoad = rayPayload;
				// Ref: eq 24.4, [Ray-tracing from the Ground Up]
				L += Fr * TraceReflectedGBufferRay(hitPosition, wi, N, objectNormal, reflectedRayPayLoad, FAR_PLANE, MaxRadianceRecursionDepth);
				//UpdateAOGBufferOnLargerDiffuseComponent(rayPayload, reflectedRayPayLoad, Fr);
			}

			if (isTransmissive)
			{
				// Radiance contribution from refraction.
				float3 wt;
				float3 Ft = Kt * BxDF::Specular::Transmission::Sample_Ft(V, wt, N, Fo);    // Calculates wt

				RadiancePayload refractedRayPayLoad = rayPayload;

				L += Ft * TraceRefractedGBufferRay(hitPosition, wt, N, objectNormal, refractedRayPayLoad, FAR_PLANE, MaxRadianceRecursionDepth);
				//UpdateAOGBufferOnLargerDiffuseComponent(rayPayload, refractedRayPayLoad, Ft);
			}
		}
	}

	return L;
}
float3 ShadeNoLight(inout RadiancePayload rayPayload, in float3 N, in float3 objectNormal, in float3 hitPosition, in RAY_TRACING_MATERIAL material)
{
	uint MaxRadianceRecursionDepth = g_MaxRadianceRayRecursionDepth;
	
	if (MaterialType::Effect == material.type)
	{
		MaxRadianceRecursionDepth = g_MaxEffectRadianceRayRecursionDepth;
	}
	float3 V = -WorldRayDirection();
	float3 L = 0;

	const float3 Kd = material.Kd;
	const float3 Ks = material.Ks;
	const float3 Kt = material.Kt;
	
	L = Kd;
	L += material.AmbientIntensity * Kd;
	bool isTransmissive = !BxDF::IsBlack(Kt);

	if (isTransmissive)
	{
		float3 Fo = Ks;
		// Radiance contribution from refraction.
		float3 wt;
		float3 Ft = Kt * BxDF::Specular::Transmission::Sample_Ft(V, wt, N, Fo);    // Calculates wt
		
		RadiancePayload refractedRayPayLoad = rayPayload;

		L += Ft * TraceRefractedGBufferRay(hitPosition, wt, N, objectNormal, refractedRayPayLoad, FAR_PLANE, MaxRadianceRecursionDepth);
	}

	return L;
}
float3 ShadeOnGBuffer(inout RadiancePayload rayPayload, in float3 N, in float3 objectNormal, in float3 hitPosition, in float3 rayDir, in RAY_TRACING_MATERIAL material, float ShadowWeight, uint shadingType)
{
	uint MaxRadianceRecursionDepth = g_MaxRadianceRayRecursionDepth;
	if (MaterialType::Effect == material.type)
	{
		MaxRadianceRecursionDepth = g_MaxEffectRadianceRayRecursionDepth;
	}

	float3 V = -rayDir;
	float pdf;
	float3 indirectContribution = 0;
	float3 L = 0;

	const float3 Kd = material.Kd;
	const float3 Ks = material.Ks * g_Ks_Mul_Const;
	const float3 Kr = material.Kr * g_Kr_Mul_Const;
	const float3 Kt = material.Kt;
	const float roughness = material.roughness;

	// Direct illumination
   //rayPayload.AOGBuffer.diffuseByte3 = NormalizedFloat3ToByte3(Kd);
	if (!BxDF::IsBlack(material.Kd) || !BxDF::IsBlack(material.Ks))
	{
		for (uint i = 0; i < g_RTLightNum; i++)
		{
			float3 LightColor = g_RTLightList[i].Color;
			float3 LightPos = g_RTLightList[i].Pos;
			float3 LightDir = LightPos - hitPosition;

			if (RTLIGHT_TYPE_DIRECTIONAL == g_RTLightList[i].Type)
			{
				// g_RTLightList[i].Pos은 빛방향 * -1, 즉 위에서 내려쬐는 빛이면 y성분이 +
				float3 LightDirN = g_RTLightList[i].Pos;
				LightDir = LightDirN * g_RTLightList[i].Rs;
				LightPos = hitPosition + LightDir;
			}
			float LightDistDist = dot(LightDir, LightDir);
			float LightDist = sqrt(LightDistDist);

			if (RTLIGHT_TYPE_POINT == g_RTLightList[i].Type)
			{
				if (LightDist >  g_RTLightList[i].Rs)
					continue;
			}
			
			float3 wi = LightDir / LightDist;
			float LightRsRs = (g_RTLightList[i].Rs * g_RTLightList[i].Rs);	// constant buffer로 뺀다.
			float tMax = LightDist;
			
			// Raytraced shadows.
			//bool TraceShadowRayAndReportIfHitA(in float3 hitPosition, in float3 direction, in float3 N, in RadiancePayload rayPayload, in float TMax = 10000)
			bool isInShadow = false;
			if (g_RTLightList[i].ShadowEnabled && ShadowWeight > 0.5)
			{
				isInShadow = TraceShadowRayAndReportIfHitA(hitPosition, wi, N, rayPayload, tMax, MaxRadianceRecursionDepth);
			}
			if (RTLIGHT_TYPE_POINT == g_RTLightList[i].Type)
			{
				if (!isInShadow)
				{
					L += ApplyPointLight(Kd, Ks, 1, DEFAULT_GLOSS, N, V, hitPosition, LightPos, LightRsRs, LightColor, shadingType);
				}
			}
			else
			{
				if (SHADING_TYPE_TOON == shadingType)
				{
					L += BxDF::DirectLighting::Shade_Toon(
						material.type,
						Kd,
						Ks,
						LightColor.rgb,
						isInShadow,
						roughness,
						N,
						V,
						wi
					);
				}
				else
				{
					L += BxDF::DirectLighting::Shade(
						material.type,
						Kd,
						Ks,
						LightColor.rgb,
						isInShadow,
						roughness,
						N,
						V,
						wi);
				}
			}
		}
	}
	// Ambient Indirect Illumination
	// Add a default ambient contribution to all hits. 
	// This will be subtracted for hitPositions with 
	// calculated Ambient coefficient in the composition pass.
	L += material.AmbientIntensity * Kd;

	// Specular Indirect Illumination
	bool isReflective = !BxDF::IsBlack(Kr);
	bool isTransmissive = !BxDF::IsBlack(Kt);

	// Handle cases where ray is coming from behind due to imprecision,
	// don't cast reflection rays in that case.
	float smallValue = 1e-6f;
	isReflective = dot(V, N) > smallValue ? isReflective : false;

	if (isReflective || isTransmissive)
	{
		if (isReflective
			&& (BxDF::Specular::Reflection::IsTotalInternalReflection(V, N)
			|| material.type == MaterialType::Mirror))
		{
			RadiancePayload reflectedRayPayLoad = rayPayload;
			float3 wi = reflect(-V, N);

			L += Kr * TraceReflectedGBufferRay(hitPosition, wi, N, objectNormal, reflectedRayPayLoad, FAR_PLANE, MaxRadianceRecursionDepth);
			//UpdateAOGBufferOnLargerDiffuseComponent(rayPayload, reflectedRayPayLoad, Kr);
		}
		else // No total internal reflection
		{
			float3 Fo = Ks;
			if (isReflective)
			{
				// Radiance contribution from reflection.
				float3 wi;
				float3 Fr = Kr * BxDF::Specular::Reflection::Sample_Fr(V, wi, N, Fo);    // Calculates wi

				RadiancePayload reflectedRayPayLoad = rayPayload;
				// Ref: eq 24.4, [Ray-tracing from the Ground Up]
				L += Fr * TraceReflectedGBufferRay(hitPosition, wi, N, objectNormal, reflectedRayPayLoad, FAR_PLANE, MaxRadianceRecursionDepth);
				//UpdateAOGBufferOnLargerDiffuseComponent(rayPayload, reflectedRayPayLoad, Fr);
			}

			if (isTransmissive)
			{
				// Radiance contribution from refraction.
				float3 wt;
				float3 Ft = Kt * BxDF::Specular::Transmission::Sample_Ft(V, wt, N, Fo);    // Calculates wt

				RadiancePayload refractedRayPayLoad = rayPayload;

				L += Ft * TraceRefractedGBufferRay(hitPosition, wt, N, objectNormal, refractedRayPayLoad, FAR_PLANE, MaxRadianceRecursionDepth);
				//UpdateAOGBufferOnLargerDiffuseComponent(rayPayload, refractedRayPayLoad, Ft);
			}
		}
	}

	return L;
}
float3 ShadeNoLightOnGBuffer(inout RadiancePayload rayPayload, in float3 N, in float3 objectNormal, in float3 hitPosition, in float3 rayDir, in RAY_TRACING_MATERIAL material)
{
	uint MaxRadianceRecursionDepth = g_MaxRadianceRayRecursionDepth;
	if (MaterialType::Effect == material.type)
	{
		MaxRadianceRecursionDepth = g_MaxEffectRadianceRayRecursionDepth;
	}

	float3 V = -rayDir;
	float3 L = 0;

	const float3 Kd = material.Kd;
	const float3 Ks = material.Ks;
	const float3 Kt = material.Kt;

	L = Kd;
	L += material.AmbientIntensity * Kd;
	bool isTransmissive = !BxDF::IsBlack(Kt);

	if (isTransmissive)
	{
		float3 Fo = Ks;
		// Radiance contribution from refraction.
		float3 wt;
		float3 Ft = Kt * BxDF::Specular::Transmission::Sample_Ft(V, wt, N, Fo);    // Calculates wt

		RadiancePayload refractedRayPayLoad = rayPayload;

		L += Ft * TraceRefractedGBufferRay(hitPosition, wt, N, objectNormal, refractedRayPayLoad, FAR_PLANE, MaxRadianceRecursionDepth);
	}
	return L;
}

[shader("raygeneration")]
void MyRaygenShader_RadianceRay_GBuffer()
{
	uint ArrayIndex = 0;

	uint2 launchIndex = DispatchRaysIndex().xy;
	uint2 launchDim   = DispatchRaysDimensions().xy;

	float depth = g_texGBufferDepth[launchIndex].r;
	float4 texDiffuse = g_texGBufferDiffuse[launchIndex];

	if (depth >= 1.0)
	{
		// 빈공간. 원래 GBuffer의 diffuse 내용을 그대로 써넣는다.
		g_OutputDiffuse[launchIndex.xy] = texDiffuse;
		g_OutAO_CoEfficient[launchIndex] = 1.0;
		g_OutAO_Distance[launchIndex] = INVALID_AO_DISTNACE;
		g_OutNormalDepth[launchIndex] = EncodeNormalDepth(float3(0, 0, 0), 1.0);
		g_OutReprojectedNormalDepth[launchIndex] = EncodeNormalDepth(float3(0, 0, 0), 1.0);
		g_OutLinearDepth[launchIndex] = 1.0;
		g_OutMotionVector[launchIndex] = 1e3f;
		return;
	}

	float2 PixelCenter = ((float2)launchIndex.xy + float2(0.5f, 0.5f)) / (float2)launchDim.xy;
	float2 csPos = float2(2, -2) * PixelCenter + float2(-1, 1); // ndc

	float dist;	// 카메라로부터의 거리
	float3 WorldPos = CalcWorldPos(csPos, depth, dist, ArrayIndex);
	float3 WorldDir = normalize(WorldPos.xyz - g_CaemraPosition.xyz);
	float4 NormalColor = g_texGBufferNormal[launchIndex];
	float3 WorldNormal = NormalColor.rgb * float3(2,2,2) - float3(1,1,1);
	if (dot(WorldDir, WorldNormal) > 0)
	{
		WorldNormal = -WorldNormal;
	}
	uint Prop = (uint)(NormalColor.a * 255.0 + ADJ_RCP_256);
	// 캐릭터의 shadowWeight는 쓰지 않는 것으로. 2021.06.19
	//float ShadowWeight = GetShadowWeight(Prop);	// 0이면 그림자 안받음, 1이면 그림자 100%
	float ShadowWeight = 1;
	bool bUseAOPerPixel = IsEnabledSSAO(Prop);
	float4 ElementColor = g_texGBufferProperty[launchIndex];
	uint MtlPreset = (uint)(ElementColor.g * 255.0 + ADJ_RCP_256);
	uint shadingType = (uint)(ElementColor.b * 255.0 + ADJ_RCP_256);
	//shadingType = min(shadingType, SHADING_TYPE_NUM - 1);
	//shadingType = max(shadingType, 0);
	// 
	//g_OutputDiffuse[launchIndex.xy] = Diffuse;
	//g_OutputDiffuse[launchIndex.xy] = float4(NormalColor, 1);
	//g_OutputDiffuse[launchIndex.xy] = float4(depth, depth, depth, 1);
	
	RadiancePayload rayPayload = (RadiancePayload)0;


	//if (CurRayRecursionDepth >= 2)//g_cb.g_MaxRadianceRayRecursionDepth
	//{
	//	rayPayload.radiance = float3(133, 161, 179) / 255.0;
	//	return rayPayload;
	//}
  
	//if (g_cb.useNormalMaps && material.hasNormalTexture)
	//{
	//    normal = NormalMap(normal, texCoord, vertices, material, attr);
	//}
	// ex) material
	// 투명일때 opacity = float3(0, 0, 0) , 불투명일때 float3(1, 1, 1)
	// 반사 없을때
	// roughness	0.2
	// kt = float3(0.0, 0.0, 0.0)
	// eta = float3(1.0, 1.0, 1.0)
	// type	Matte 
	// 반사할때 
	// roughness	0.01
	// kt = float3(0.7, 0.7, 0.7)
	// eta = float3(1.5, 1.5, 1.5)
	// type	Default 

	
	RAY_TRACING_MATERIAL material = g_MtlTable[MtlPreset];
	/*
	RAY_TRACING_MATERIAL material;
	material.Kd = float3(0.5, 0.5, 0.5);	// diffuse
	material.hasDiffuseTexture = true;
	material.Ks = float3(0.5, 0.5, 0.5);	// specular
	material.roughness = 0.01;
	material.Kr = float3(0.5, 0.5, 0.5);	// reflection
	//material.Kr = float3(0.0, 0.0, 0.0);	// reflection
	material.hasNormalTexture = false;
	//material.Kt = float3(0.7, 0.7, 0.7);	// transmissive
	material.Kt = float3(0.0, 0.0, 0.0);	// transmissive
	material.hasPerVertexTangents = false;

	material.opacity = float3(0, 0, 0);
	material.type = MaterialType::Default;
	//material.eta = float3(1.5, 1.5, 1.5);
	material.eta = float3(1.0, 1.0, 1.0);
	*/

	material.Kd = texDiffuse.rgb * material.opacity;
	if (MaterialType::Effect == material.type)
	{
		if (ALPHA_TRANSP == material.AlphaType)
		{
			material.Kd = texDiffuse.rgb * texDiffuse.a;
			material.Kt = 1 - texDiffuse.a;
		}
		else if (ALPHA_ADD == material.AlphaType)
		{
			float alpha = dot(texDiffuse.rgb, BW_CONST);
			if (alpha < RT_ALPHA_TEST_THRESHOLD)
			{
				material.Kd = 0;
				material.Kt = 1;
			}
		}
		rayPayload.radiance = ShadeNoLightOnGBuffer(rayPayload, WorldNormal, WorldNormal, WorldPos, WorldDir, material);
		//rayPayload.radiance = float3(0, 1, 0);
	}
	else
	{
		// 나뭇잎 이쪽...
		/*
		if (MtlPreset == 4)
		{
			// 매터리얼에 alpha곱셈상수를 넣어서 곱해버리자.
			texDiffuse.a = 0.5;
			//material.AlphaType = ALPHA_TRANSP;
			material.Kd = material.Kd * texDiffuse.a;
		}
		*/
		
		if (ALPHA_TRANSP == material.AlphaType)
		{
			float Kt = (1 - texDiffuse.a);
			material.Kt = float3(Kt, Kt, Kt);
		}
		//material.Kr = 0;
		//rayPayload.radiance = ShadeNoLightOnGBuffer(rayPayload, WorldNormal, WorldNormal, WorldPos, WorldDir, material);
		rayPayload.radiance = ShadeOnGBuffer(rayPayload, WorldNormal, WorldNormal, WorldPos, WorldDir, material, ShadowWeight, shadingType);
	}
	g_OutputDiffuse[launchIndex.xy] = float4(rayPayload.radiance, 1);
	
	// RTAO
	const float RTAO_MinT = 1.0;
	if (g_RTAOEnabled)
	{
		float ao_coeff = 1.0;		
		float tHit = INVALID_AO_DISTNACE;
		if (bUseAOPerPixel & material.bUseRTAO)
		{
			float ambientOcclusion = 0.0;
			// Initialize a random seed, per-pixel, based on a screen position and temporally varying count
			uint randSeed = initRand(launchIndex.x + launchIndex.y * launchDim.x, g_AO_RandomSeed, 16);
			float MinAmbientIllumination = g_PropertyPerShadingTable[shadingType].fMinAmbientIllumination;
			float AORadius = g_PropertyPerShadingTable[shadingType].AORadius;
			float MaxTheoreticalAORayHitTime = g_PropertyPerShadingTable[shadingType].AO_MaxTheoreticalAORayHitTime;

			// Start accumulating from zero if we don't hit the background
			for (int i = 0; i < g_AO_SampleRayNum; i++)
			{
				// Sample cosine-weighted hemisphere around surface normal to pick a random ray direction
				float3 dir = getCosHemisphereSample(randSeed, WorldNormal.xyz);
				
				//float minAmbientIllumination = 0.56;//
				ambientOcclusion += CalculateAO(tHit, WorldPos.xyz, dir, WorldNormal, texDiffuse.rgb, MinAmbientIllumination, MaxTheoreticalAORayHitTime, RTAO_MinT, AORadius);
			}
			ao_coeff = ambientOcclusion / (float)g_AO_SampleRayNum;
		}
		
		g_OutAO_CoEfficient[launchIndex] = ao_coeff;
		g_OutAO_Distance[launchIndex] = tHit;
		float4 ProjPos = mul(float4(WorldPos, 1), g_ViewProj[ArrayIndex]);
		float linear_depth = (ProjPos.w - g_Near) / (g_Far - g_Near);
		g_OutNormalDepth[launchIndex] = EncodeNormalDepth(WorldNormal, linear_depth);
		g_OutLinearDepth[launchIndex] = linear_depth;
		float PrvLinearDepth = 1.0;
		g_OutMotionVector[launchIndex] = CalculateMotionVector(WorldPos, PrvLinearDepth, PixelCenter, ArrayIndex);
		g_OutReprojectedNormalDepth[launchIndex] = EncodeNormalDepth(WorldNormal, PrvLinearDepth);
	}
}

[shader("raygeneration")]
void MyRaygenShader_RadianceRay()
{
	uint ArrayIndex = 0;

	uint2 launchIndex = DispatchRaysIndex().xy;
	uint2 launchDim   = DispatchRaysDimensions().xy;

	//   float2 xy = index + 0.5f; // center in the middle of the pixel.
	   //float2 screenPos = xy / launchDim.xy * 2.0 - 1.0;
   //	float2 pixelCenter = currenPixelLocation / launchDim;

	float2 CurPixel = (float2)launchIndex.xy + float2(0.5f, 0.5f);  // 현재 픽셀의 좌표(픽셀의 중앙)
	float2 Res = (float2)launchDim.xy;

	float4 ray_view = float4(
		(((2.0f * (float)CurPixel.x) / (float)Res.x) - 1.0f) * g_DecompProj[ArrayIndex].rcp_m11,
		-(((2.0f * (float)CurPixel.y) / (float)Res.y) - 1.0f) * g_DecompProj[ArrayIndex].rcp_m22,
		1.0, 0.0);

	float4 ray_world = mul(ray_view, g_ViewInvArray[ArrayIndex]);
	//ray_world.xyz *= (1.0 / 100.0);
	ray_world.xyz = normalize(ray_world.xyz);
	float3 worldDir = ray_world.xyz;
	float3 worldOrigin = float3(g_CaemraPosition.xyz);

	Ray ray =
	{
		worldOrigin,
		worldDir
	};
	uint CurRayRecursionDepth = 0;
	bool cullNonOpaque = false;
	bool cullBackFace = true;
	RadiancePayload rayPayload = TraceRadianceRay(ray, CurRayRecursionDepth, g_MaxRadianceRayRecursionDepth, NEAR_PLANE, FAR_PLANE, cullNonOpaque, cullBackFace, g_RTAOEnabled);

	if (rayPayload.depth < g_OutputDepth[launchIndex.xy].r)
	{
		g_OutputDiffuse[launchIndex.xy] = float4(rayPayload.radiance, 1);
		g_OutputDepth[launchIndex.xy] = float4(rayPayload.depth, 0, 0, 0);
		g_OutputNormal[launchIndex.xy] = ConvertDWORDTofloat(rayPayload.NormalColor);
		g_OutputElementID[launchIndex.xy] = ConvertDWORDTofloat(rayPayload.ElementColor);
	}
#if defined(RTAO_IN_TRACE_RAY)
	g_OutAO_CoEfficient[launchIndex] = rayPayload.ao.AO_CoEfficient;
	g_OutAO_Distance[launchIndex] = rayPayload.ao.AO_Distance;
	g_OutNormalDepth[launchIndex] = rayPayload.ao.NormalDepth;
	g_OutLinearDepth[launchIndex] = rayPayload.ao.LinearDepth;
	g_OutMotionVector[launchIndex] = rayPayload.ao.MotionVector;
	g_OutReprojectedNormalDepth[launchIndex] = rayPayload.ao.ReprojectedNormalDepth;
#endif
}
[shader("closesthit")]
void MyClosestHitShader_RadianceRay(inout RadiancePayload rayPayload, in BuiltInTriangleIntersectionAttributes attr)
{
	uint ArrayIndex = 0;

	float3 hitPosition = HitWorldPosition();

	// Get the base index of the triangle's first 16 bit index.
	uint InstID = InstanceID();
	uint SystemInstIndex = InstanceIndex();				// The autogenerated index of the current instance in the top-level structure.
	uint CustomInstIndex = GetInstanceIndex(InstID);	// CRayTracingManager에서 발급한 인덱스-오브젝트 인덱스
	BLAS_PRIMITIVE_TYPE PrimType = GetPrimitiveType(InstID);	// BLAS_PRIMITIVE_TYPE_TRIANGLE, BLAS_PRIMITIVE_TYPE_VOXEL_TRIANGLE, 
	BLAS_PROPERTY_TYPE PropType = GetPropertyType(InstID);	// BLAS_PROPERTY_TYPE_CHARACTER, BLAS_PROPERTY_TYPE_STRUCT, BLAS_PROPERTY_TYPE_EFFECT

	uint baseIndex = PrimitiveIndex() * g_TriangleIndexStride;
	
	RAY_TRACING_RENDER_OPTION renderOption = g_RenderOptionTable[CustomInstIndex];
	RAY_TRACING_MATERIAL material;

	uint ElementID = 0;

	// Load up 3 16 bit indices for the triangle.
	uint3 indices = Load3x16BitIndices(baseIndex);
	float normalMapWeight = 1.0;
	float2 CurTexCoord = 0;
	float4 texDiffuse = float4(0, 0, 0, 0);
	float3 texNormal = float3(0.5, 0.5, 1);
	float3 VertexNormals[3];
	float3 VertexTangent[3];
	uint cb_MaterialPreset = GetMtlPresetFromPackedProperty(l_rayGeomCB.PackedProperty);
	if (BLAS_PRIMITIVE_TYPE_TRIANGLE == PrimType)
	{
		
		material = g_MtlTable[cb_MaterialPreset];

		VertexNormals[0] = l_Vertices[indices[0]].Normal;
		VertexNormals[1] = l_Vertices[indices[1]].Normal;
		VertexNormals[2] = l_Vertices[indices[2]].Normal;

		VertexTangent[0] = l_Vertices[indices[0]].Tangent;
		VertexTangent[1] = l_Vertices[indices[1]].Tangent;
		VertexTangent[2] = l_Vertices[indices[2]].Tangent;

		float2 TexCoord[3] =
		{
			l_TVertices[indices[0]].uv,
			l_TVertices[indices[1]].uv,
			l_TVertices[indices[2]].uv
		};
		CurTexCoord = HitAttribute(TexCoord, attr);

		if (material.bIsWater)
		{
			float3	texNormalColor0 = (float3)l_texNormal.SampleLevel(samplerMirror, hitPosition.xz * 0.001 + g_TimeValue , 0);
			float3	texNormalColor1 = (float3)l_texNormal.SampleLevel(samplerMirror, hitPosition.xz * 0.001 + g_TimeValue , 0);
			texNormal = (texNormalColor0 + texNormalColor1) * 0.5;
			float4	texDiffuse0 = l_texDiffuse.SampleLevel(samplerMirror, hitPosition.xz * 0.001 + g_TimeValue, 0);
			float4	texDiffuse1 = l_texDiffuse.SampleLevel(samplerMirror, hitPosition.xz * 0.001 - g_TimeValue, 0);
			texDiffuse = lerp(texDiffuse0, texDiffuse1, 0.5);
			normalMapWeight = 0.125;
		}
		else
		{	
			texDiffuse = l_texDiffuse.SampleLevel(samplerWrap, CurTexCoord, 0);
			texNormal = (float3)l_texNormal.SampleLevel(samplerWrap, CurTexCoord, 0);
		}
		uint Property = l_Vertices[indices[0]].Property;
		ElementID = (Property & 0x000000ff);	// VLMEsh의 VertexBuffer로부터 입력, LMMesh등 다른 타입은 0
	}
	else if (BLAS_PRIMITIVE_TYPE_VOXEL_TRIANGLE == PrimType)
	{
		uint cb_BulbOn = 0;
		float cb_VoxelSize = 0;
		uint cb_VoxelObjIndex = 0;
		uint cb_VoxelsPerAxis = 0;
		cb_VoxelsPerAxis = GetVoxelConstFromPackedProperty(cb_BulbOn, cb_VoxelSize, cb_VoxelObjIndex, l_rayGeomCB.PackedProperty);

		uint PackedData[3] =
		{
			l_VoxelVertices[indices[0]].PackedData,
			l_VoxelVertices[indices[1]].PackedData,
			l_VoxelVertices[indices[2]].PackedData
		};
		
		uint3	oPos[3] =
		{
			GetPosInObject(PackedData[0]),
			GetPosInObject(PackedData[1]),
			GetPosInObject(PackedData[2])
		};
		uint3	vPos[3] =
		{
			GetPosInVoxel(PackedData[0]),
			GetPosInVoxel(PackedData[1]),
			GetPosInVoxel(PackedData[2])
		};
		uint Axis[3];
		VertexNormals[0] = GetNormalAndTangent(VertexTangent[0], Axis[0], PackedData[0]);
		VertexNormals[1] = GetNormalAndTangent(VertexTangent[1], Axis[1], PackedData[1]);
		VertexNormals[2] = GetNormalAndTangent(VertexTangent[2], Axis[2], PackedData[2]);
		
		uint3	oPosCenter = (oPos[0] + oPos[1] + oPos[2]) / 3;
		uint PaletteIndex = GetPaletteIndex(oPosCenter, cb_VoxelsPerAxis, cb_VoxelObjIndex);

		float2 PaletteTexCoord[3];
		for (uint i = 0; i < 3; i++)
		{
			PaletteTexCoord[i] = GetVoxelPaletteTexCoord(PaletteIndex, Axis[i], oPos[i], vPos[i], cb_VoxelsPerAxis);
		}
		float2 PaletteTexCoordBarycentric = HitAttribute(PaletteTexCoord, attr);

		//float2 PaletteTexCoord = float2(((float)PaletteIndex / 255) + (0.5 / 255), 0.5);
		texDiffuse = g_texVoxelPaletteTex.SampleLevel(samplerWrap_Point, PaletteTexCoordBarycentric, 0);
		uint mtlPresetIndex = g_texVoxelPaletteMtl.Load(uint3(PaletteIndex, 0, 0)).r;
		material = g_MtlTable[mtlPresetIndex];
		//rayPayload.radiance = Diffuse.rgb;
		//rayPayload.radiance = g_ColorTable[l_rayGeomCB.VoxelObjIndex % COLOR_TABLE_COUNT];
	}
	else
	{
		rayPayload.radiance = float3(1, 0, 0);
		return;
	}
	
	// 오브젝트의 local좌표계에서의 노말
	float3 LocalNormal = HitAttribute(VertexNormals, attr);		
	float3 LocalTangent = HitAttribute(VertexTangent, attr);		

	// 면의 뒷면에 충돌했을 경우 노멀을 뒤집어준다.
	float orientation = HitKind() == HIT_KIND_TRIANGLE_FRONT_FACE ? 1 : -1;
	LocalNormal *= orientation;
	LocalTangent *= orientation;

	// BLAS Transforms in this sample are uniformly scaled so it's OK to directly apply the BLAS transform.
	// 월드좌표계에서의 노말
	
	float3 WorldNormal = normalize(mul(LocalNormal,(float3x3)ObjectToWorld4x3()));	// Transposed Matrix
	float3 WorldTangent = normalize(mul(LocalTangent,(float3x3)ObjectToWorld4x3()));	// Transposed Matrix
	float3 WorldBinormal = cross(WorldTangent, WorldNormal);
	//float3 WorldNormal = normalize(mul((float3x3)ObjectToWorld3x4(), LocalNormal));	// Not Transposed Matrix
   
	float3	tan_normal = texNormal.rgb * 2 - 1;
	float3	surfaceNormal = (tan_normal.xxx * WorldTangent) + (tan_normal.yyy * WorldBinormal) + (tan_normal.zzz * WorldNormal);
	surfaceNormal = lerp(WorldNormal, surfaceNormal, normalMapWeight);	// 버텍스 노말과 노말맵중 어느쪽에 비중을 둘지, 디폴트는 노말맵 100%, 물이면 < 1.0
	//WorldNormal = surfaceNormal;
	// 
	//rayPayload.radiance = (WorldNormal.xyz * 0.5 + 0.5);
	//return;

	//if (g_cb.useNormalMaps && material.hasNormalTexture)
	//{
	//    normal = NormalMap(normal, texCoord, vertices, material, attr);
	//}
	// ex) material
	// 투명일때 opacity = float3(0, 0, 0) , 불투명일때 float3(1, 1, 1)
	// 반사 없을때
	// roughness	0.2
	// kt = float3(0.0, 0.0, 0.0)
	// eta = float3(1.0, 1.0, 1.0)
	// type	Matte 
	// 반사할때 
	// roughness	0.01
	// kt = float3(0.7, 0.7, 0.7)
	// eta = float3(1.5, 1.5, 1.5)
	// type	Default 
	

	
	/*
	material.Kd = float3(0.5, 0.5, 0.5);	// diffuse
	material.hasDiffuseTexture = true;
	material.Ks = float3(0.5, 0.5, 0.5);	// specular
	material.roughness = 0.01;
	material.Kr = float3(0.5, 0.5, 0.5);	// reflection
	//material.Kr = float3(0.0, 0.0, 0.0);	// reflection
	material.hasNormalTexture = false;
	//material.Kt = float3(0.7, 0.7, 0.7);	// transmissive
	material.Kt = float3(0.0, 0.0, 0.0);	// transmissive
	material.hasPerVertexTangents = false;

	material.opacity = float3(0, 0, 0);
	material.type = MaterialType::Default;
	//material.eta = float3(1.5, 1.5, 1.5);
	material.eta = float3(1.0, 1.0, 1.0);
	*/
	

	//uint FaceGroupColorIndex = l_rayGeomCB.FaceGroupIndex % COLOR_TABLE_COUNT;
	//rayPayload.radiance = float3(CurNormal.xyz * float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5), 1);		
	//rayPayload.radiance = float3(g_ColorTable[FaceGroupColorIndex], 1);
	//rayPayload.radiance = float3(g_ColorTable[InstanceColorIndex], 1);
	//rayPayload.radiance = texDiffuse;
	//return;

	/*
	if (material.bIsWater)
	{
		float3	texNormalColor0 = (float3)l_texNormal.SampleLevel(samplerMirror, hitPosition.xz * 0.001 + g_TimeValue , 0);
		float3	texNormalColor1 = (float3)l_texNormal.SampleLevel(samplerMirror, hitPosition.xz * 0.001 + g_TimeValue , 0);
		float3	tan_normal = normalize((texNormalColor0 + texNormalColor1) * 2 - 1);
		surfaceNormal = (tan_normal.xxx * WorldTangent) + (tan_normal.yyy * WorldBinormal) + (tan_normal.zzz * WorldNormal);
		surfaceNormal = lerp(WorldNormal, surfaceNormal, 0.125);

		float4	texDiffuse0 = l_texDiffuse.SampleLevel(samplerMirror, hitPosition.xz * 0.001 + g_TimeValue, 0);
		float4	texDiffuse1 = l_texDiffuse.SampleLevel(samplerMirror, hitPosition.xz * 0.001 - g_TimeValue, 0);
		texDiffuse = lerp(texDiffuse0, texDiffuse1, 0.5);
	}
	*/

	material.Kd = ((texDiffuse.rgb * material.opacity.rgb) * renderOption.Diffuse) + renderOption.DiffuseAdd;
	if (MaterialType::Effect == material.type)
	{		
		if (ALPHA_TRANSP == material.AlphaType)
		{
			material.Kd = texDiffuse.rgb * texDiffuse.a;
			material.Kt = 1 - texDiffuse.a;
		}
		else if (ALPHA_ADD == material.AlphaType)
		{
			//alpha = dot(texDiffuse.rgb, BW_CONST);
		}
		rayPayload.radiance = ShadeNoLight(rayPayload, surfaceNormal, LocalNormal, hitPosition, material);
		//rayPayload.radiance = float3(0, 1, 0);
	}
	else
	{
		if (ALPHA_TRANSP == material.AlphaType)
		{
			float Kt = (1 - texDiffuse.a);
			material.Kt = float3(Kt, Kt, Kt);
		}
		rayPayload.radiance = Shade(rayPayload, surfaceNormal, LocalNormal, hitPosition, material, renderOption.ShadingType);
	}
	
	float4 PrjPos = mul(float4(hitPosition.xyz, 1), g_ViewProj[ArrayIndex]);
	PrjPos /= PrjPos.w;
	rayPayload.depth = saturate(PrjPos.z);
	float3 NormalColor = surfaceNormal.xyz * 0.5 + 0.5;
	rayPayload.NormalColor = ConvertFloat3ToDWORD(NormalColor, g_PropertyTypeTable[PropType]);
	// float4	ElementColor = float4((float)ElementID / 255.0, (float)MtlPreset / 255.0, 0, 0);
	// packed dword컬러는 낮은 어드레스로부터 b - g - r - a 순
	rayPayload.ElementColor = (0 << 24) | (ElementID << 16) | (cb_MaterialPreset << 8) | 0;

#if defined(RTAO_IN_TRACE_RAY)
	// RTAO
	// ao처리할지 인자로 받는다.
	const float RTAO_MinT = 1.0;
	if (rayPayload.ao.RTAOEnabled)
	{
		uint2 launchIndex = DispatchRaysIndex().xy;
		uint2 launchDim   = DispatchRaysDimensions().xy;
		float2 PixelCenter = ((float2)launchIndex.xy + float2(0.5f, 0.5f)) / (float2)launchDim.xy;

		float ao_coeff = 1.0;
		float tHit = INVALID_AO_DISTNACE;
		if (material.bUseRTAO)	//bUseAOPerPixel
		{
			float ambientOcclusion = 0.0;
			// Initialize a random seed, per-pixel, based on a screen position and temporally varying count
			uint randSeed = initRand(launchIndex.x + launchIndex.y * launchDim.x, g_AO_RandomSeed, 16);
			float MinAmbientIllumination = g_PropertyPerShadingTable[renderOption.ShadingType].fMinAmbientIllumination;
			float AORadius = g_PropertyPerShadingTable[renderOption.ShadingType].AORadius;
			float MaxTheoreticalAORayHitTime = g_PropertyPerShadingTable[renderOption.ShadingType].AO_MaxTheoreticalAORayHitTime;

			// Start accumulating from zero if we don't hit the background
			for (int i = 0; i < g_AO_SampleRayNum; i++)
			{
				// Sample cosine-weighted hemisphere around surface normal to pick a random ray direction
				float3 dir = getCosHemisphereSample(randSeed, surfaceNormal.xyz);
				
				//float minAmbientIllumination = 0.56;//
				ambientOcclusion += CalculateAO(tHit, hitPosition.xyz, dir, surfaceNormal, texDiffuse.rgb, MinAmbientIllumination, MaxTheoreticalAORayHitTime, RTAO_MinT, AORadius);
			}
			ao_coeff = ambientOcclusion / (float)g_AO_SampleRayNum;
		}

		rayPayload.ao.AO_CoEfficient = ao_coeff;
		rayPayload.ao.AO_Distance = tHit;
		float4 ProjPos = mul(float4(hitPosition.xyz, 1), g_ViewProj[ArrayIndex]);
		float linear_depth = (ProjPos.w - g_Near) / (g_Far - g_Near);
		rayPayload.ao.NormalDepth = EncodeNormalDepth(surfaceNormal, linear_depth);
		rayPayload.ao.LinearDepth = linear_depth;
		float PrvLinearDepth = 1.0;
		rayPayload.ao.MotionVector = CalculateMotionVector(hitPosition.xyz, PrvLinearDepth, PixelCenter, ArrayIndex);
		rayPayload.ao.ReprojectedNormalDepth = EncodeNormalDepth(surfaceNormal, PrvLinearDepth);
	}
#endif

}
[shader("closesthit")]
void MyClosestHitShader_ShadowRay(inout ShadowPayload rayPayload, in BuiltInTriangleIntersectionAttributes attr)
{
	rayPayload.tHit = RayTCurrent();
}


[shader("miss")]
void MyMissShader_RadianceRay(inout RadiancePayload rayPayload)
{
	//rayPayload.radiance = float3(0, 1, 0);// g_texEnvironmentMap.SampleLevel(LinearWrapSampler, WorldRayDirection(), 0).xyz;
	rayPayload.radiance = g_texSkyEnv.SampleLevel(samplerClamp, WorldRayDirection(), 0).rgb;
	rayPayload.depth = 1.2;
	rayPayload.NormalColor = 0xff000000;
	rayPayload.ElementColor = 0xffffffff;

#if defined(RTAO_IN_TRACE_RAY)
	// rtao
	rayPayload.ao.AO_CoEfficient = 1.0;
	rayPayload.ao.AO_Distance = INVALID_AO_DISTNACE;
	rayPayload.ao.NormalDepth = EncodeNormalDepth(float3(0, 0, 0), 1.0);
	rayPayload.ao.ReprojectedNormalDepth = EncodeNormalDepth(float3(0, 0, 0), 1.0);
	rayPayload.ao.LinearDepth = 1.0;
	rayPayload.ao.MotionVector = 1e3f;
#endif
}

[shader("miss")]
void MyMissShader_ShadowRay(inout ShadowPayload rayPayload)
{
    rayPayload.tHit = HitDistanceOnMiss;
}




[shader("anyhit")]
void MyAnyHitShader_RadianceRay(inout RadiancePayload payload, in BuiltInTriangleIntersectionAttributes attr)
{
	float3 hitPosition = HitWorldPosition();

	// Get the base index of the triangle's first 16 bit index.
	uint InstID = InstanceID();
	uint SystemInstIndex = InstanceIndex();				// The autogenerated index of the current instance in the top-level structure.
	uint CustomInstIndex = GetInstanceIndex(InstID);	// CRayTracingManager에서 발급한 인덱스-오브젝트 인덱스
	BLAS_PRIMITIVE_TYPE PrimType = GetPrimitiveType(InstID);	// BLAS_PRIMITIVE_TYPE_TRIANGLE, BLAS_PRIMITIVE_TYPE_VOXEL_TRIANGLE, 

	uint baseIndex = PrimitiveIndex() * g_TriangleIndexStride;

	// Load up 3 16 bit indices for the triangle.
	uint3 indices = Load3x16BitIndices(baseIndex);
	
	float2 TexCoord[3] =
	{
		l_TVertices[indices[0]].uv,
		l_TVertices[indices[1]].uv,
		l_TVertices[indices[2]].uv
	};
	float2 CurTexCoord = HitAttribute(TexCoord, attr);

	uint cb_MaterialPreset = GetMtlPresetFromPackedProperty(l_rayGeomCB.PackedProperty);
	RAY_TRACING_MATERIAL material = g_MtlTable[cb_MaterialPreset];
	float4 texDiffuse = l_texDiffuse.SampleLevel(samplerWrap_Point, CurTexCoord, 0);

	float alpha = 1.0;

	if (ALPHA_TRANSP == material.AlphaType)
	{
		alpha = texDiffuse.a;
	}
	else if (ALPHA_ADD == material.AlphaType)
	{
		alpha = dot(texDiffuse.rgb, BW_CONST);
	}
	if (alpha < RT_ALPHA_TEST_THRESHOLD)
	{
		IgnoreHit();
	}
	else
	{
		// 여기서 바로 끝내면 안된다.
		//AcceptHitAndEndSearch();
	}
}

[shader("anyhit")]
void MyAnyHitShader_ShadowRay(inout ShadowPayload rayPayload, in BuiltInTriangleIntersectionAttributes attr)
{
	uint cb_MaterialPreset = GetMtlPresetFromPackedProperty(l_rayGeomCB.PackedProperty);
	RAY_TRACING_MATERIAL material = g_MtlTable[cb_MaterialPreset];
	if (MaterialType::Effect == material.type)
	{
		IgnoreHit();
		return;
	}
	float3 hitPosition = HitWorldPosition();

	// Get the base index of the triangle's first 16 bit index.
	uint InstID = InstanceID();
	uint SystemInstIndex = InstanceIndex();				// The autogenerated index of the current instance in the top-level structure.
	uint CustomInstIndex = GetInstanceIndex(InstID);	// CRayTracingManager에서 발급한 인덱스-오브젝트 인덱스
	BLAS_PRIMITIVE_TYPE PrimType = GetPrimitiveType(InstID);	// BLAS_PRIMITIVE_TYPE_TRIANGLE, BLAS_PRIMITIVE_TYPE_VOXEL_TRIANGLE, 

	uint baseIndex = PrimitiveIndex() * g_TriangleIndexStride;

	// Load up 3 16 bit indices for the triangle.
	uint3 indices = Load3x16BitIndices(baseIndex);
	
	float2 TexCoord[3] =
	{
		l_TVertices[indices[0]].uv,
		l_TVertices[indices[1]].uv,
		l_TVertices[indices[2]].uv
	};
	float2 CurTexCoord = HitAttribute(TexCoord, attr);
	float4 texDiffuse = l_texDiffuse.SampleLevel(samplerWrap_Point, CurTexCoord, 0);
	
	float alpha = 1.0;

	if (ALPHA_TRANSP == material.AlphaType)
	{
		alpha = texDiffuse.a;
	}
	else if (ALPHA_ADD == material.AlphaType)
	{
		alpha = dot(texDiffuse.rgb, BW_CONST);
	}
	if (alpha < RT_ALPHA_TEST_THRESHOLD)
	{
		IgnoreHit();
	}
	else
	{
		AcceptHitAndEndSearch();
	}
	//AcceptHitAndEndSearch();
	//IgnoreHit();

}

#endif // RAYTRACING_HLSL
