#pragma once

#ifdef VH_PLUGIN	// VH_PLUGIN

#if defined(EMULATE_X86_SIMD)
inline float32x4_t __VECTORCALL _ARM64_mm_shuffle_ps(float32x4_t a, float32x4_t b, int i)
{
	float32x4_t r;

	unsigned dest_index_0 = i & 0b00000011;
	unsigned dest_index_1 = (i & 0b00001100) >> 2;
	unsigned src_index_0 = (i & 0b000110000) >> 4;
	unsigned src_index_1 = (i & 0b11000000) >> 6;

	r.n128_f32[0] = a.n128_f32[dest_index_0];
	r.n128_f32[1] = a.n128_f32[dest_index_1];
	r.n128_f32[2] = b.n128_f32[src_index_0];
	r.n128_f32[3] = b.n128_f32[src_index_1];

	return r;
}

inline float32x4_t __VECTORCALL _ARM64_mm_shuffle_00_10_10_01(float32x4_t a, float32x4_t b, unsigned int imm)
{
	float32x4_t ret;
	
	ret = vmovq_n_f32(vgetq_lane_f32(a, 1));
	ret = vsetq_lane_f32(vgetq_lane_f32(a, 2), ret, 1);
	ret = vsetq_lane_f32(vgetq_lane_f32(b, 2), ret, 2);
	ret = vsetq_lane_f32(vgetq_lane_f32(b, 0), ret, 3);
	
	return ret;
}

inline float32x4_t __VECTORCALL _ARM64_mm_shuffle_10_01_00_10(float32x4_t a, float32x4_t b, unsigned int imm)
{
	float32x4_t ret;
	
	ret = vmovq_n_f32(vgetq_lane_f32(a, 2));
	ret = vsetq_lane_f32(vgetq_lane_f32(a, 0), ret, 1);
	ret = vsetq_lane_f32(vgetq_lane_f32(b, 1), ret, 2);
	ret = vsetq_lane_f32(vgetq_lane_f32(b, 2), ret, 3);
	
	return ret;
}
inline float32x4_t __VECTORCALL _ARM64_mm_shuffle_00_01_00_00(float32x4_t a, float32x4_t b, unsigned int imm)
{
	float32x4_t ret;
	
	ret = vmovq_n_f32(vgetq_lane_f32(a, 0));
	ret = vsetq_lane_f32(vgetq_lane_f32(a, 0), ret, 1);
	ret = vsetq_lane_f32(vgetq_lane_f32(b, 1), ret, 2);
	ret = vsetq_lane_f32(vgetq_lane_f32(b, 0), ret, 3);
	
	return ret;
}
inline float32x4_t __VECTORCALL _ARM64_mm_shuffle_00_00_01_01(float32x4_t a, float32x4_t b, unsigned int imm)
{
	float32x4_t ret;
	
	ret = vmovq_n_f32(vgetq_lane_f32(a, 1));
	ret = vsetq_lane_f32(vgetq_lane_f32(a, 1), ret, 1);
	ret = vsetq_lane_f32(vgetq_lane_f32(b, 0), ret, 2);
	ret = vsetq_lane_f32(vgetq_lane_f32(b, 0), ret, 3);
	
	return ret;
}






#if defined(_M_ARM64)
#define __rdtsc	___rdtsc
#define _mm_add_ss __mm_add_ss
#define _mm_sub_ss __mm_sub_ss
#define _mm_mul_ss __mm_mul_ss
#define _mm_div_ss __mm_div_ss
#define _mm_add_ps	__mm_add_ps
#define _mm_sub_ps	__mm_sub_ps
#define _mm_mul_ps	__mm_mul_ps
#define _mm_div_ps	__mm_div_ps
#define _mm_max_ps	__mm_max_ps
#define _mm_min_ps	__mm_min_ps
#define _mm_add_epi32 __mm_add_epi32
#define _mm_cvtepi32_ps __mm_cvtepi32_ps
#define _mm_hadd_ps __mm_hadd_ps
#define _mm_hadd_epi32 __mm_hadd_epi32
#define _mm_sub_epi32 __mm_sub_epi32
#define _mm_setzero_si128 __mm_setzero_si128
#define _mm_setzero_ps	__mm_setzero_ps
#define _mm_set_epi32 __mm_set_epi32
#define _mm_setr_epi32 __mm_setr_epi32
#define _mm_set1_epi32 __mm_set1_epi32
#define _mm_set1_ps __mm_set1_ps
#define _mm_setr_ps __mm_setr_ps
#define _mm_load_ss __mm_load_ss
#define _mm_load_ps __mm_load_ps
#define _mm_loadu_ps __mm_loadu_ps
#define _mm_loadl_pi __mm_loadl_pi
#define _mm_store_ss __mm_store_ss
#define _mm_store_ps __mm_store_ps
#define _mm_storel_pi __mm_storel_pi
#define _mm_storeu_ps __mm_storeu_ps
#define _mm_castps_si128 __mm_castps_si128
#define _mm_castsi128_ps __mm_castsi128_ps
#define _mm_and_ps __mm_and_ps
#define _mm_and_si128 __mm_and_si128
#define _mm_or_si128 __mm_or_si128
#define _mm_or_ps __mm_or_ps
#define _mm_xor_ps __mm_xor_ps
#define _mm_sqrt_ss __mm_sqrt_ss
#define _mm_sqrt_ps __mm_sqrt_ps
#define _mm_rcp_ps __mm_rcp_ps
#define _mm_rcp_ss __mm_rcp_ss
#define _mm_shuffle_ps __mm_shuffle_ps
#define _mm_cvttps_epi32 __mm_cvttps_epi32
#define _mm_movehl_ps __mm_movehl_ps
#define _mm_movelh_ps __mm_movelh_ps
#define _mm_comieq_ss __mm_comieq_ss
#define _mm_cmple_ps __mm_cmple_ps
#define _mm_cmplt_ps __mm_cmplt_ps
#define _mm_cmpgt_ps __mm_cmpgt_ps
#define _mm_cmpge_ps __mm_cmpge_ps
#define _mm_extract_epi32 __mm_extract_epi32
#define _mm_testz_si128 __mm_testz_si128
#define _mm_test_all_zeros __mm_test_all_zeros
#define _mm_insert_ps __mm_insert_ps
#define _mm_slli_epi32 __mm_slli_epi32

typedef union  __declspec(align(8)) __m64
{
    unsigned __int64    m64_u64;
    float               m64_f32[2];
    __int8              m64_i8[8];
    __int16             m64_i16[4];
    __int32             m64_i32[2];
    __int64             m64_i64;
    unsigned __int8     m64_u8[8];
    unsigned __int16    m64_u16[4];
    unsigned __int32    m64_u32[2];
} __m64;

typedef union __m128 {
     float               m128_f32[4];
     unsigned __int64    m128_u64[2];
     __int8              m128_i8[16];
     __int16             m128_i16[8];
     __int32             m128_i32[4];
     __int64             m128_i64[2];
     unsigned __int8     m128_u8[16];
     unsigned __int16    m128_u16[8];
     unsigned __int32    m128_u32[4];
 } __m128;
typedef union __m128i {
    __int8              m128i_i8[16];
    __int16             m128i_i16[8];
    __int32             m128i_i32[4];
    __int64             m128i_i64[2];
    unsigned __int8     m128i_u8[16];
    unsigned __int16    m128i_u16[8];
    unsigned __int32    m128i_u32[4];
    unsigned __int64    m128i_u64[2];
} __m128i;
#else
#include <mmintrin.h>
#include <intrin.h>
#endif

inline __m128 __VECTORCALL __mm_add_ss(__m128 a, __m128 b)
{
	//r0: = a0 + b0
	//r1 : = a1; r2: = a2; r3: = a3
	__m128 r;
	r.m128_f32[0] = a.m128_f32[0] + b.m128_f32[0];
	r.m128_f32[1] = a.m128_f32[1];
	r.m128_f32[2] = a.m128_f32[2];
	r.m128_f32[3] = a.m128_f32[3];
	
	return r;
}
inline __m128 __VECTORCALL __mm_sub_ss(__m128 a, __m128 b)
{
	//r0: = a0 - b0
	//r1 : = a1; r2: = a2; r3: = a3
	__m128 r;
	r.m128_f32[0] = a.m128_f32[0] - b.m128_f32[0];
	r.m128_f32[1] = a.m128_f32[1];
	r.m128_f32[2] = a.m128_f32[2];
	r.m128_f32[3] = a.m128_f32[3];
	
	return r;
}
inline __m128 __VECTORCALL __mm_mul_ss(__m128 a, __m128 b)
{
	//r0: = a0 * b0
	//r1 : = a1; r2: = a2; r3: = a3
	__m128 r;
	r.m128_f32[0] = a.m128_f32[0] * b.m128_f32[0];
	r.m128_f32[1] = a.m128_f32[1];
	r.m128_f32[2] = a.m128_f32[2];
	r.m128_f32[3] = a.m128_f32[3];
	
	return r;
}
inline __m128 __VECTORCALL __mm_div_ss(__m128 a, __m128 b)
{
	//r0: = a0 / b0
	//r1 : = a1; r2: = a2; r3: = a3
	__m128 r;
	r.m128_f32[0] = a.m128_f32[0] / b.m128_f32[0];
	r.m128_f32[1] = a.m128_f32[1];
	r.m128_f32[2] = a.m128_f32[2];
	r.m128_f32[3] = a.m128_f32[3];
	
	return r;
}
inline __m128 __VECTORCALL __mm_add_ps(__m128 a, __m128 b)
{
	__m128 r;
	r.m128_f32[0] = a.m128_f32[0] + b.m128_f32[0];
	r.m128_f32[1] = a.m128_f32[1] + b.m128_f32[1];
	r.m128_f32[2] = a.m128_f32[2] + b.m128_f32[2];
	r.m128_f32[3] = a.m128_f32[3] + b.m128_f32[3];

	return r;
}
inline __m128 __VECTORCALL __mm_sub_ps(__m128 a, __m128 b)
{
	__m128 r;
	r.m128_f32[0] = a.m128_f32[0] - b.m128_f32[0];
	r.m128_f32[1] = a.m128_f32[1] - b.m128_f32[1];
	r.m128_f32[2] = a.m128_f32[2] - b.m128_f32[2];
	r.m128_f32[3] = a.m128_f32[3] - b.m128_f32[3];

	return r;
}

inline __m128 __VECTORCALL __mm_mul_ps(__m128 a, __m128 b)
{
	__m128 r;
	r.m128_f32[0] = a.m128_f32[0] * b.m128_f32[0];
	r.m128_f32[1] = a.m128_f32[1] * b.m128_f32[1];
	r.m128_f32[2] = a.m128_f32[2] * b.m128_f32[2];
	r.m128_f32[3] = a.m128_f32[3] * b.m128_f32[3];
	
	return r;
}
inline __m128 __VECTORCALL __mm_div_ps(__m128 a, __m128 b)
{
	__m128 r;
	r.m128_f32[0] = a.m128_f32[0] / b.m128_f32[0];
	r.m128_f32[1] = a.m128_f32[1] / b.m128_f32[1];
	r.m128_f32[2] = a.m128_f32[2] / b.m128_f32[2];
	r.m128_f32[3] = a.m128_f32[3] / b.m128_f32[3];

	return r;
}
inline __m128 __VECTORCALL __mm_max_ps(__m128 a, __m128 b)
{
	__m128 r;
	r.m128_f32[0] = max(a.m128_f32[0], b.m128_f32[0]);
	r.m128_f32[1] = max(a.m128_f32[1], b.m128_f32[1]);
	r.m128_f32[2] = max(a.m128_f32[2], b.m128_f32[2]);
	r.m128_f32[3] = max(a.m128_f32[3], b.m128_f32[3]);

	return r;
}
inline __m128 __VECTORCALL __mm_min_ps(__m128 a, __m128 b)
{
	__m128 r;
	r.m128_f32[0] = min(a.m128_f32[0], b.m128_f32[0]);
	r.m128_f32[1] = min(a.m128_f32[1], b.m128_f32[1]);
	r.m128_f32[2] = min(a.m128_f32[2], b.m128_f32[2]);
	r.m128_f32[3] = min(a.m128_f32[3], b.m128_f32[3]);

	return r;

}
inline __m128i __VECTORCALL __mm_add_epi32(__m128i a, __m128i b)
{
    __m128i r;
    //r0 := a0 + b0
    //r1 := a1 + b1
    //r2 := a2 + b2
    //r3 := a3 + b3

    r.m128i_i32[0] = a.m128i_i32[0] + b.m128i_i32[0];
    r.m128i_i32[1] = a.m128i_i32[1] + b.m128i_i32[1];
    r.m128i_i32[2] = a.m128i_i32[2] + b.m128i_i32[2];
    r.m128i_i32[3] = a.m128i_i32[3] + b.m128i_i32[3];
    
    return r;
}
inline __m128 __VECTORCALL __mm_cvtepi32_ps(__m128i a)
{
    __m128 r;
    //r0 := (float) a0
    //r1 := (float) a1
    //r2 := (float) a2
    //r3 := (float) a3

    r.m128_f32[0] = (float)a.m128i_i32[0];
    r.m128_f32[1] = (float)a.m128i_i32[1];
    r.m128_f32[2] = (float)a.m128i_i32[2];
    r.m128_f32[3] = (float)a.m128i_i32[3];

    return r;
}
inline __m128i __VECTORCALL __mm_setzero_si128()
{
	//r := 0x0
	__m128i r;
	r.m128i_u32[0] = 0;
	r.m128i_u32[1] = 0;
	r.m128i_u32[2] = 0;
	r.m128i_u32[3] = 0;
	return r;

}
inline __m128 __VECTORCALL __mm_setzero_ps()
{
	//r0 := r1 := r2 := r3 := 0.0 
	__m128 r;
	r.m128_f32[0] = 0.0f;
	r.m128_f32[1] = 0.0f;
	r.m128_f32[2] = 0.0f;
	r.m128_f32[3] = 0.0f;
	return r;
}
inline __m128 __VECTORCALL __mm_set1_ps(float w)
{
	__m128 r;
	r.m128_f32[0] = w;
	r.m128_f32[1] = w;
	r.m128_f32[2] = w;
	r.m128_f32[3] = w;
	return r;
}
inline __m128 __VECTORCALL __mm_set_ps(float A, float B, float C, float D)
{
	//r0 := D 
	//r1 := C 
	//r2 := B 
	//r3 := A 
	__m128 r;
	r.m128_f32[0] = D;
	r.m128_f32[1] = C;
	r.m128_f32[2] = B;
	r.m128_f32[3] = A;

	return r;
}

inline __m128 __VECTORCALL __mm_setr_ps(float D, float C, float B, float A)
{
	//r0 := D 
	//r1 := C 
	//r2 := B 
	//r3 := A 
	__m128 r;
	r.m128_f32[0] = D;
	r.m128_f32[1] = C;
	r.m128_f32[2] = B;
	r.m128_f32[3] = A;

	return r;
}
inline __m128i __VECTORCALL __mm_set_epi32(int i3, int i2, int i1, int i0)
{
	__m128i r;
	r.m128i_i32[0] = i0;
	r.m128i_i32[1] = i1;
	r.m128i_i32[2] = i2;
	r.m128i_i32[3] = i3;

	return r;
}
inline __m128i __VECTORCALL __mm_setr_epi32 (int i0, int i1, int i2, int i3)
{
	__m128i r;
	r.m128i_i32[0] = i0;
	r.m128i_i32[1] = i1;
	r.m128i_i32[2] = i2;
	r.m128i_i32[3] = i3;

	return r;
}
inline __m128i __VECTORCALL __mm_set1_epi32(int i)
{
	//r0 := i
	//r1 := i
	//r2 := i
	//r3 := i
	__m128i r;
	r.m128i_i32[0] = i;
	r.m128i_i32[1] = i;
	r.m128i_i32[2] = i;
	r.m128i_i32[3] = i;

	return r;
}
inline __m128 __VECTORCALL __mm_loadu_ps(const float * p)
{
	//MOVUPS 
	//r0 := p[0] 
	//r1 := p[1] 
	//r2 := p[2] 
	//r3 := p[3] 

	__m128 r;
	r.m128_f32[0] = p[0];
	r.m128_f32[1] = p[1];
	r.m128_f32[2] = p[2];
	r.m128_f32[3] = p[3];
	
	return r;
}
inline __m128 __VECTORCALL __mm_load_ss(const float * p)
{
	//r0 := *p 
	//r1 := 0.0 ; r2 := 0.0 ; r3 := 0.0 
	__m128 r;
	r.m128_f32[0] = *p;
	r.m128_f32[1] = 0.0f;
	r.m128_f32[2] = 0.0f;
	r.m128_f32[3] = 0.0f;
	
	return r;
}
inline __m128 __VECTORCALL __mm_load_ps(float * p)
{
	//r0 := p[0] 
	//r1 := p[1] 
	//r2 := p[2] 
	//r3 := p[3] 
	__m128 r;
	r.m128_f32[0] = p[0];
	r.m128_f32[1] = p[1];
	r.m128_f32[2] = p[2];
	r.m128_f32[3] = p[3];
	
	return r;

}
inline __m128 __VECTORCALL __mm_loadl_pi(__m128 a, __m64 * p)
{
	//r0 : = *p0
	//r1 : = *p1
	//r2 : = a2
	//r3 : = a3
	__m128 r;
	r.m128_f32[0] = p->m64_f32[0];
	r.m128_f32[1] = p->m64_f32[1];
	r.m128_f32[2] = a.m128_f32[2];
	r.m128_f32[3] = a.m128_f32[3];

	return r;
}
inline void __VECTORCALL __mm_store_ss(float * p, __m128 a)
{
	//*p := a0
	*p = a.m128_f32[0];
}
inline void __VECTORCALL __mm_store_ps(float *p, __m128 a)
{
	//p[0] := a0
	//p[1] := a1
	//p[2] := a2
	//p[3] := a3
	p[0] = a.m128_f32[0];
	p[1] = a.m128_f32[1];
	p[2] = a.m128_f32[2];
	p[3] = a.m128_f32[3];
}
inline void __VECTORCALL __mm_storeu_ps(float *p, __m128 a )
{
	//p[0] := a0
	//p[1] := a1
	//p[2] := a2
	//p[3] := a3
	p[0] = a.m128_f32[0];
	p[1] = a.m128_f32[1];
	p[2] = a.m128_f32[2];
	p[3] = a.m128_f32[3];
}
inline void __VECTORCALL __mm_storel_pi(__m64 * p, __m128 a)
{
	//*p0 := b0
	//*p1 := b1
	*(unsigned int*)&p->m64_i32[0] = *(unsigned int*)&a.m128_f32[0];
	*(unsigned int*)&p->m64_i32[1] = *(unsigned int*)&a.m128_f32[1];
}
inline __m128 __VECTORCALL __mm_castsi128_ps(__m128i a)
{
	__m128 r;
	r.m128_u32[0] = a.m128i_u32[0];
	r.m128_u32[1] = a.m128i_u32[1];
	r.m128_u32[2] = a.m128i_u32[2];
	r.m128_u32[3] = a.m128i_u32[3];
	return r;

}
inline __m128i __VECTORCALL __mm_castps_si128(__m128 a)
{
	__m128i	r;
	r.m128i_u32[0] = a.m128_u32[0];
	r.m128i_u32[1] = a.m128_u32[1];
	r.m128i_u32[2] = a.m128_u32[2];
	r.m128i_u32[3] = a.m128_u32[3];
	
	return r;
}
inline __m128 __VECTORCALL __mm_shuffle_ps(__m128 a, __m128 b, int i)
{
	__m128 r;
	
	unsigned dest_index_0 = i & 0b00000011;
	unsigned dest_index_1 = (i & 0b00001100) >> 2;
	unsigned src_index_0 = (i & 0b000110000) >> 4;
	unsigned src_index_1 = (i & 0b11000000) >> 6;

	r.m128_f32[0] = a.m128_f32[dest_index_0];
	r.m128_f32[1] = a.m128_f32[dest_index_1];
	r.m128_f32[2] = b.m128_f32[src_index_0];
	r.m128_f32[3] = b.m128_f32[src_index_1];

	return r;
}


inline __m128 __VECTORCALL __mm_and_ps(__m128 a, __m128 b)
{
	__m128 r;
	r.m128_u32[0] = a.m128_u32[0] & b.m128_u32[0];
	r.m128_u32[1] = a.m128_u32[1] & b.m128_u32[1];
	r.m128_u32[2] = a.m128_u32[2] & b.m128_u32[2];
	r.m128_u32[3] = a.m128_u32[3] & b.m128_u32[3];

	return r;

}
inline __m128i __VECTORCALL __mm_and_si128(__m128i a, __m128i b)
{
	__m128i r;
	r.m128i_u32[0] = a.m128i_u32[0] & b.m128i_u32[0];
	r.m128i_u32[1] = a.m128i_u32[1] & b.m128i_u32[1];
	r.m128i_u32[2] = a.m128i_u32[2] & b.m128i_u32[2];
	r.m128i_u32[3] = a.m128i_u32[3] & b.m128i_u32[3];

	return r;
}
inline __m128i __VECTORCALL __mm_or_si128(__m128i a, __m128i b)
{
	__m128i r;
	r.m128i_u32[0] = a.m128i_u32[0] | b.m128i_u32[0];
	r.m128i_u32[1] = a.m128i_u32[1] | b.m128i_u32[1];
	r.m128i_u32[2] = a.m128i_u32[2] | b.m128i_u32[2];
	r.m128i_u32[3] = a.m128i_u32[3] | b.m128i_u32[3];
    
    return r;
}
inline __m128 __VECTORCALL __mm_xor_ps(__m128 a, __m128 b)
{
	//r0 := a0 ^ b0
	//r1 := a1 ^ b1
	//r2 := a2 ^ b2
	//r3 := a3 ^ b3 
	__m128 r;
	r.m128_u32[0] = a.m128_u32[0] ^ b.m128_u32[0];
	r.m128_u32[1] = a.m128_u32[1] ^ b.m128_u32[1];
	r.m128_u32[2] = a.m128_u32[2] ^ b.m128_u32[2];
	r.m128_u32[3] = a.m128_u32[3] ^ b.m128_u32[3];

	return r;
}
inline __m128 __VECTORCALL __mm_or_ps(__m128 a, __m128 b)
{
	__m128 r;
	r.m128_u32[0] = a.m128_u32[0] | b.m128_u32[0];
	r.m128_u32[1] = a.m128_u32[1] | b.m128_u32[1];
	r.m128_u32[2] = a.m128_u32[2] | b.m128_u32[2];
	r.m128_u32[3] = a.m128_u32[3] | b.m128_u32[3];

	return r;

}

inline __m128 __VECTORCALL __mm_sqrt_ss(__m128 a)
{
	
	//r0 := sqrt(a0)
	//r1 := a1 ; r2 := a2 ; r3 := a3
	__m128 r;
	r.m128_f32[0] = sqrtf(a.m128_f32[0]);
	r.m128_f32[1] = a.m128_f32[1];
	r.m128_f32[2] = a.m128_f32[2];
	r.m128_f32[3] = a.m128_f32[3];

	return r;
}
inline __m128 __VECTORCALL __mm_sqrt_ps(__m128 a)
{
	//SQRTPS

	//r0 := sqrt(a0)
	//r1 := sqrt(a1)
	//r2 := sqrt(a2)
	//r3 := sqrt(a3)
	__m128 r;
	r.m128_f32[0] = sqrtf(a.m128_f32[0]);
	r.m128_f32[1] = sqrtf(a.m128_f32[1]);
	r.m128_f32[2] = sqrtf(a.m128_f32[2]);
	r.m128_f32[3] = sqrtf(a.m128_f32[3]);

	return r;
}
inline __m128 __VECTORCALL __mm_hadd_ps(__m128 a, __m128 b)
{
	__m128 r;

	//(B3 + B2, B1 + B0, A3 + A2, A1 + A0).
	r.m128_f32[0] = a.m128_f32[0] + a.m128_f32[1];
	r.m128_f32[1] = a.m128_f32[2] + a.m128_f32[3];
	r.m128_f32[2] = b.m128_f32[0] + b.m128_f32[1];
	r.m128_f32[3] = b.m128_f32[2] + b.m128_f32[3];

	return r;
}
inline __m128i __VECTORCALL __mm_hadd_epi32(__m128i a, __m128i b)
{
	//r0 : = a0 + a1
	//r1 : = a2 + a3
	//r2 : = b0 + b1
	//r3 : = b2 + b3
	__m128i r;
	r.m128i_u32[0] = a.m128i_u32[0] + a.m128i_u32[1];
	r.m128i_u32[1] = a.m128i_u32[2] + a.m128i_u32[3];
	r.m128i_u32[2] = b.m128i_u32[0] + b.m128i_u32[1];
	r.m128i_u32[3] = b.m128i_u32[2] + b.m128i_u32[3];

	return r;
}
inline __m128i __VECTORCALL __mm_sub_epi32(__m128i a, __m128i b)
{
	//r0 := a0 - b0
	//r1 := a1 - b1
	//r2 := a2 - b2
	//r3 := a3 - b3
	__m128i r;
	r.m128i_i32[0] = a.m128i_i32[0] - b.m128i_i32[0];
	r.m128i_i32[1] = a.m128i_i32[1] - b.m128i_i32[1];
	r.m128i_i32[2] = a.m128i_i32[2] - b.m128i_i32[2];
	r.m128i_i32[3] = a.m128i_i32[3] - b.m128i_i32[3];
	
	return r;
}
inline __m128 __VECTORCALL __mm_movelh_ps(__m128 a, __m128 b)
{
	//r3 := b1
	//r2 := b0
	//r1 := a1
	//r0 := a0
	__m128 r;
	r.m128_f32[0] = a.m128_f32[0];
	r.m128_f32[1] = a.m128_f32[1];
	r.m128_f32[2] = b.m128_f32[0];
	r.m128_f32[3] = b.m128_f32[1];

	return r;

}
inline __m128 __VECTORCALL __mm_movehl_ps(__m128 a, __m128 b)
{
	//r3 := a3
	//r2 := a2
	//r1 := b3
	//r0 := b2
	__m128 r;
	r.m128_f32[0] = b.m128_f32[2];
	r.m128_f32[1] = b.m128_f32[3];
	r.m128_f32[2] = a.m128_f32[2];
	r.m128_f32[3] = a.m128_f32[3];

	return r;
}
inline __m128i __VECTORCALL __mm_cvttps_epi32(__m128 a)
{
	//r0 : = (int)a0
	//r1 : = (int)a1
	//r2 : = (int)a2
	//r3 : = (int)a3
	__m128i r;
	r.m128i_i32[0] = (int)a.m128_f32[0];
	r.m128i_i32[1] = (int)a.m128_f32[1];
	r.m128i_i32[2] = (int)a.m128_f32[2];
	r.m128i_i32[3] = (int)a.m128_f32[3];
	
	return r;
}
inline __m128 __VECTORCALL __mm_cmple_ps(__m128 a, __m128 b)
{
	//r0 := (a0 <= b0) ? 0xffffffff : 0x0
	//r1 := (a1 <= b1) ? 0xffffffff : 0x0
	//r2 := (a2 <= b2) ? 0xffffffff : 0x0
	//r3 := (a3 <= b3) ? 0xffffffff : 0x0
	__m128 r;
	r.m128_u32[0] = (unsigned int)((int)(a.m128_f32[0] > b.m128_f32[0]) - 1);
	r.m128_u32[1] = (unsigned int)((int)(a.m128_f32[1] > b.m128_f32[1]) - 1);
	r.m128_u32[2] = (unsigned int)((int)(a.m128_f32[2] > b.m128_f32[2]) - 1);
	r.m128_u32[3] = (unsigned int)((int)(a.m128_f32[3] > b.m128_f32[3]) - 1);

	return r;
}

inline __m128 __VECTORCALL __mm_cmpge_ps(__m128 a, __m128 b)
{
    //r0 : = (a0 >= b0) ? 0xffffffff : 0x0
    //r1 : = (a1 >= b1) ? 0xffffffff : 0x0
    //r2 : = (a2 >= b2) ? 0xffffffff : 0x0
    //r3 : = (a3 >= b3) ? 0xffffffff : 0x0
	__m128 r;
	r.m128_u32[0] = (unsigned int)((int)(a.m128_f32[0] < b.m128_f32[0]) - 1);
	r.m128_u32[1] = (unsigned int)((int)(a.m128_f32[1] < b.m128_f32[1]) - 1);
	r.m128_u32[2] = (unsigned int)((int)(a.m128_f32[2] < b.m128_f32[2]) - 1);
	r.m128_u32[3] = (unsigned int)((int)(a.m128_f32[3] < b.m128_f32[3]) - 1);

    return r;

}
inline __m128 __VECTORCALL __mm_cmplt_ps(__m128 a, __m128 b)
{
	//	Compares for less than.
	//r0 : = (a0 < b0) ? 0xffffffff : 0x0
	//r1 : = (a1 < b1) ? 0xffffffff : 0x0
	//r2 : = (a2 < b2) ? 0xffffffff : 0x0
	//r3 : = (a3 < b3) ? 0xffffffff : 0x0
	__m128 r;
	r.m128_u32[0] = (unsigned int)((int)(a.m128_f32[0] >= b.m128_f32[0]) - 1);
	r.m128_u32[1] = (unsigned int)((int)(a.m128_f32[1] >= b.m128_f32[1]) - 1);
	r.m128_u32[2] = (unsigned int)((int)(a.m128_f32[2] >= b.m128_f32[2]) - 1);
	r.m128_u32[3] = (unsigned int)((int)(a.m128_f32[3] >= b.m128_f32[3]) - 1);
	
	return r;
}
inline __m128 __VECTORCALL __mm_cmpgt_ps(__m128 a, __m128 b)
{
	//r0 := (a0 > b0) ? 0xffffffff : 0x0
	//r1 := (a1 > b1) ? 0xffffffff : 0x0
	//r2 := (a2 > b2) ? 0xffffffff : 0x0
	//r3 := (a3 > b3) ? 0xffffffff : 0x0
	__m128 r;
	r.m128_u32[0] = (unsigned int)((int)(a.m128_f32[0] <= b.m128_f32[0]) - 1);
	r.m128_u32[1] = (unsigned int)((int)(a.m128_f32[1] <= b.m128_f32[1]) - 1);
	r.m128_u32[2] = (unsigned int)((int)(a.m128_f32[2] <= b.m128_f32[2]) - 1);
	r.m128_u32[3] = (unsigned int)((int)(a.m128_f32[3] <= b.m128_f32[3]) - 1);

	return r;
}

inline int __mm_comieq_ss(__m128 a, __m128 b)
{
	//r := (a0 == b0) ? 0x1 : 0x0
	int r = a.m128_f32[0] == b.m128_f32[0];
	return r;
}

inline __m128 __VECTORCALL __mm_rcp_ps(__m128 a)
{
	//r0 : = recip(a0)
	//r1 : = recip(a1)
	//r2 : = recip(a2)
	//r3 : = recip(a3)
	__m128 r;
	r.m128_f32[0] = 1.0f / a.m128_f32[0];
	r.m128_f32[1] = 1.0f / a.m128_f32[1];
	r.m128_f32[2] = 1.0f / a.m128_f32[2];
	r.m128_f32[3] = 1.0f / a.m128_f32[3];

	return r;
}

inline __m128 __VECTORCALL __mm_rcp_ss(__m128 a)
{
	//r0 := recip(a0)
	//r1 := a1 ; r2 := a2 ; r3 := a3
	__m128 r;
	r.m128_f32[0] = 1.0f / a.m128_f32[0];
	r.m128_f32[1] = a.m128_f32[1];
	r.m128_f32[2] = a.m128_f32[2];
	r.m128_f32[3] = a.m128_f32[3];
	
	return r;
}
inline int __mm_extract_epi32(__m128i a, int imm8)
{
  //  r := (ndx == 0) ? a0 :
  //((ndx == 1) ? a1 :
  //((ndx == 2) ? a2 : a3))
    if (imm8 >= 4)
    {
        imm8 %= 4;
    }
    int r = a.m128i_i32[imm8];
    return r;
}
inline int __mm_testz_si128(__m128i a, __m128i b)
{
	//ZF := (a & b) == 0
	//r := ZF
	int r = ((a.m128i_u32[0] & b.m128i_u32[0]) | (a.m128i_u32[1] & b.m128i_u32[1]) | (a.m128i_u32[2] & b.m128i_u32[2]) | (a.m128i_u32[3] & b.m128i_u32[3])) == 0;
	return r;
}

inline __m128 __VECTORCALL __mm_insert_ps(__m128 a, __m128 b, const int sel)
{
    __m128 r;
    //sx := sel6-7
    //sval := (sx == 0) ? b0 : ((sx == 1) ? b1 : ((sx == 2) ? b2 : b3))

    //dx := sel4-5
    //r0 := (dx == 0) ? sval : a0
    //r1 := (dx == 1) ? sval : a1
    //r2 := (dx == 2) ? sval : a2
    //r3 := (dx == 3) ? sval : a3

    //zmask := sel0-3
    //r0 := (zmask0 == 1) ? +0.0 : r0
    //r1 := (zmask1 == 1) ? +0.0 : r1
    //r2 := (zmask2 == 1) ? +0.0 : r2
    //r3 := (zmask3 == 1) ? +0.0 : r3

    int sx = (sel & 0b11000000) >> 6;
    float sval = (sx == 0) ? b.m128_f32[0] : ((sx == 1) ? b.m128_f32[1] : ((sx == 2) ? b.m128_f32[2] : b.m128_f32[3]));

    int dx = (sel & 0b00110000) >> 4;
    r.m128_f32[0] = (dx == 0) ? sval : a.m128_f32[0];
    r.m128_f32[1] = (dx == 1) ? sval : a.m128_f32[1];
    r.m128_f32[2] = (dx == 2) ? sval : a.m128_f32[2];
    r.m128_f32[3] = (dx == 3) ? sval : a.m128_f32[3];
    
    //zmask := sel0-3
    int zmask = (sel & 0b00001111);
    r.m128_f32[0] = (zmask & 0b0001) ? 0.0f : r.m128_f32[0];
    r.m128_f32[1] = (zmask & 0b0010) ? 0.0f : r.m128_f32[1];
    r.m128_f32[2] = (zmask & 0b0100) ? 0.0f : r.m128_f32[2];
    r.m128_f32[3] = (zmask & 0b1000) ? 0.0f : r.m128_f32[3];

    return r;
}

inline __m128i __VECTORCALL __mm_slli_epi32(__m128i a, int count)
{
    __m128i r;
    //r0 : = a0 << count
    //r1 : = a1 << count
    //r2 : = a2 << count
    //r3 : = a3 << count

    r.m128i_i32[0] = a.m128i_i32[0] << count;
    r.m128i_i32[1] = a.m128i_i32[1] << count;
    r.m128i_i32[2] = a.m128i_i32[2] << count;
    r.m128i_i32[3] = a.m128i_i32[3] << count;
    
    return r;
}

#define __mm_test_all_zeros(mask, val)     __mm_testz_si128((mask), (val))

#endif

#endif	// VH_PLUGIN