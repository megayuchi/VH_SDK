#ifndef PRE_DEFINE_CPP_SHADER_H
#define PRE_DEFINE_CPP_SHADER_H

#define USE_GBUFFER_RASTERIZED
//#define USE_CUDA_DENOISER


#if defined(USE_GBUFFER_RASTERIZED)
	#define PAYLOAD_SIZE 28
#else
	#define PAYLOAD_SIZE 60
	#define RTAO_IN_TRACE_RAY
#endif

#endif