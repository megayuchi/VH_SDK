#pragma once

#ifdef VH_PLUGIN	// VH_PLUGIN

#if defined(_M_IX86) || defined(_M_AMD64)
#define _USE_SSE
#define _USE_AVX
#define __VECTORCALL __vectorcall
#endif

#if defined(_M_ARM64) || defined(_M_ARM64EC)
#undef _USE_AVX
#define _USE_NEON
#undef __VECTORCALL
#define __VECTORCALL
#endif

//#if defined(_M_ARM64) || defined(_M_ARM64EC)
#if defined(_M_ARM64)	// 순수 arm64빌드일때만 SIMD 에뮬레이션 사용
#define EMULATE_X86_SIMD
#endif

#include <float.h>
#include <math.h>
#include <windows.h>
#include <intrin.h>
#include "emul_x86_simd.inl"

struct MATRIX3
{
	float	_11;
	float	_12;
	float	_13;
	float	_21;
	float	_22;
	float	_23;
	float	_31;
	float	_32;
	float	_33;
};
struct MATRIX4
{
	union
	{
		struct
		{
			float	_11;
			float	_12;
			float	_13;
			float	_14;

			float	_21;
			float	_22;
			float	_23;
			float	_24;

			float	_31;
			float	_32;
			float	_33;
			float	_34;

			float	_41;
			float	_42;
			float	_43;
			float	_44;
		};
		struct
		{
			float f[4][4];
		};
	};
};

struct MATRIX4x3
{
	float	_11;
	float	_12;
	float	_13;
	float	_14;

	float	_21;
	float	_22;
	float	_23;
	float	_24;

	float	_31;
	float	_32;
	float	_33;
	float	_34;
};

#if defined(EMULATE_X86_SIMD)

struct MATRIX4_A
{
	__m128	_11;
	__m128	_21;
	__m128	_31;
	__m128	_41;

	void Set(const MATRIX4* pMatSrc)
	{
		_11.m128_f32[0] = pMatSrc->_11;
		_11.m128_f32[1] = pMatSrc->_12;
		_11.m128_f32[2] = pMatSrc->_13;
		_11.m128_f32[3] = pMatSrc->_14;

		_21.m128_f32[0] = pMatSrc->_21;
		_21.m128_f32[1] = pMatSrc->_22;
		_21.m128_f32[2] = pMatSrc->_23;
		_21.m128_f32[3] = pMatSrc->_24;

		_31.m128_f32[0] = pMatSrc->_31;
		_31.m128_f32[1] = pMatSrc->_32;
		_31.m128_f32[2] = pMatSrc->_33;
		_31.m128_f32[3] = pMatSrc->_34;

		_41.m128_f32[0] = pMatSrc->_41;
		_41.m128_f32[1] = pMatSrc->_42;
		_41.m128_f32[2] = pMatSrc->_43;
		_41.m128_f32[3] = pMatSrc->_44;


	}
};
union PLANE_A
{
	struct
	{
		float x;
		float y;
		float z;
		float D;
	};
	__m128	mem;
};
#else
__declspec(align(16)) struct MATRIX4_A
{
	__m128	_11;
	__m128	_21;
	__m128	_31;
	__m128	_41;

	void Set(const MATRIX4* pMatSrc)
	{
		_11.m128_f32[0] = pMatSrc->_11;
		_11.m128_f32[1] = pMatSrc->_12;
		_11.m128_f32[2] = pMatSrc->_13;
		_11.m128_f32[3] = pMatSrc->_14;

		_21.m128_f32[0] = pMatSrc->_21;
		_21.m128_f32[1] = pMatSrc->_22;
		_21.m128_f32[2] = pMatSrc->_23;
		_21.m128_f32[3] = pMatSrc->_24;

		_31.m128_f32[0] = pMatSrc->_31;
		_31.m128_f32[1] = pMatSrc->_32;
		_31.m128_f32[2] = pMatSrc->_33;
		_31.m128_f32[3] = pMatSrc->_34;

		_41.m128_f32[0] = pMatSrc->_41;
		_41.m128_f32[1] = pMatSrc->_42;
		_41.m128_f32[2] = pMatSrc->_43;
		_41.m128_f32[3] = pMatSrc->_44;


	}
};
__declspec(align(16)) union PLANE_A
{
	__declspec(align(16)) struct
	{
		float x;
		float y;
		float z;
		float D;
	};
	__m128	mem;
};
//#include <xmmintrin.h>
//#pragma intrinsic ( _mm_hadd_ps )
#endif

struct VECTOR2
{
	float		x;
	float		y;

	inline	BOOL		operator==(const VECTOR2& v) const;
	inline	VECTOR2		operator +(const VECTOR2 &v) const;
	inline	VECTOR2		operator -(const VECTOR2 &v) const;
	inline	VECTOR2		operator *(const float	&f) const;
	inline	VECTOR2		operator /(const float	&f) const;
	inline	VECTOR2		operator *(const VECTOR2 &v) const;
	inline	void		Set(float in_x, float in_y);

};


inline VECTOR2 MAKE_VECTOR2(float in_x, float in_y)
{
	VECTOR2 v;
	v.x = in_x;
	v.y = in_y;
	return v;
}


inline void VECTOR2::Set(float in_x, float in_y)
{
	x = in_x;
	y = in_y;
}
inline float Dot(const VECTOR2 &a, const VECTOR2& b)
{
	float		r;
	r = (a.x * b.x) + (a.y * b.y);
	return r;
}

inline	BOOL VECTOR2::operator==(const VECTOR2& v) const
{
	BOOL	bResult;
	if (this->x == v.x && this->y == v.y)
		bResult = TRUE;
	else
		bResult = FALSE;

	return	bResult;
}
inline VECTOR2 VECTOR2::operator +(const VECTOR2 &v2) const
{
	VECTOR2	result;
	result.x = this->x + v2.x;
	result.y = this->y + v2.y;

	return	result;
}

inline VECTOR2 VECTOR2::operator -(const VECTOR2 &v2) const
{
	VECTOR2		result;
	result.x = this->x - v2.x;
	result.y = this->y - v2.y;

	return	result;
}

inline VECTOR2 VECTOR2::operator *(const float	&f) const
{
	VECTOR2		r;
	r.x = this->x * f;
	r.y = this->y * f;

	return	r;
}

inline VECTOR2 VECTOR2::operator /(const float	&f) const
{
	VECTOR2		r;
	r.x = this->x / f;
	r.y = this->y / f;

	return	r;
}
// dot.
inline VECTOR2 VECTOR2::operator *(const VECTOR2 &v) const
{
	VECTOR2		r;
	r.x = this->x * v.x;
	r.y = this->y * v.y;
	return		r;
}

struct MATRIX4;


struct VECTOR3
{
	float	x;
	float	y;
	float	z;

	inline	VECTOR3		operator +(const VECTOR3 &v) const;
	inline	VECTOR3		operator -(const VECTOR3 &v) const;
	inline	VECTOR3		operator *(const float	&f) const;
	inline	VECTOR3		operator /(const float	&f) const;
	inline	VECTOR3		operator *(const VECTOR3 &v) const;
	inline	BOOL		operator==(const VECTOR3& v) const;
	inline	BOOL		operator!=(const VECTOR3& v) const;
	inline	BOOL		NearZero(float fE) const;


	inline	void		Set(float in_x, float in_y, float in_z);

	/*
		VECTOR3		operator +(const VECTOR3 &v3);
		VECTOR3		operator -(const VECTOR3 &v3);
		VECTOR3		operator *(const VECTOR3 &v3);
		VECTOR3		operator /(const VECTOR3 &v3);

		VECTOR3		operator +(const float a);
		VECTOR3		operator -(const float a);
		VECTOR3		operator *(const float a);
		VECTOR3		operator /(const float a);

		void			operator +=(const VECTOR3 &v3);
		void			operator -=(const VECTOR3 &v3);
		void			operator *=(const VECTOR3 &v3);
		void			operator *=(const float a);
		void			operator /=(const float a);
		void			operator /=(const VECTOR3 &v3);
	*/
};
inline VECTOR3 MAKE_VECTOR3(float in_x, float in_y, float in_z)
{
	VECTOR3	v;
	v.x = in_x;
	v.y = in_y;
	v.z = in_z;
	return v;
}
inline float FMIN(float a, float b)
{
	return a < b ? a : b;
}

inline float FMAX(float a, float b)
{
	return a > b ? a : b;
}

inline VECTOR3 FMIN(VECTOR3 a, VECTOR3 b)
{
	return MAKE_VECTOR3(FMIN(a.x, b.x), FMIN(a.y, b.y), FMIN(a.z, b.z));
}

inline VECTOR3 FMAX(VECTOR3 a, VECTOR3 b)
{
	return MAKE_VECTOR3(FMAX(a.x, b.x), FMAX(a.y, b.y), FMAX(a.z, b.z));
}



inline void VECTOR3::Set(float in_x, float in_y, float in_z)
{
	x = in_x;
	y = in_y;
	z = in_z;
}
inline VECTOR3 VECTOR3::operator +(const VECTOR3 &v3) const
{
	VECTOR3	result;
	result.x = this->x + v3.x;
	result.y = this->y + v3.y;
	result.z = this->z + v3.z;
	return	result;
}

inline VECTOR3 VECTOR3::operator -(const VECTOR3 &v3) const
{
	VECTOR3		result;
	result.x = this->x - v3.x;
	result.y = this->y - v3.y;
	result.z = this->z - v3.z;
	return	result;
}

inline VECTOR3 VECTOR3::operator *(const float	&f) const
{
	VECTOR3		r;
	r.x = this->x * f;
	r.y = this->y * f;
	r.z = this->z * f;
	return	r;
}

inline VECTOR3 VECTOR3::operator /(const float	&f) const
{
	VECTOR3		r;
	r.x = this->x / f;
	r.y = this->y / f;
	r.z = this->z / f;
	return	r;
}

inline VECTOR3 VECTOR3::operator *(const VECTOR3 &v) const
{
	VECTOR3		r;
	r.x = this->x * v.x;
	r.y = this->y * v.y;
	r.z = this->z * v.z;
	return		r;
}

inline	BOOL VECTOR3::operator==(const VECTOR3& v) const
{
	BOOL	bResult;
	if (this->x == v.x && this->y == v.y && this->z == v.z)
		bResult = TRUE;
	else
		bResult = FALSE;

	return	bResult;
}
inline	BOOL VECTOR3::operator!=(const VECTOR3& v) const
{
	BOOL	bResult;
	if (this->x != v.x || this->y != v.y || this->z != v.z)
		bResult = TRUE;
	else
		bResult = FALSE;

	return	bResult;
}

inline BOOL VECTOR3::NearZero(float fE) const
{
	if (this->x > -fE && this->x < fE && this->y > -fE && this->y < fE && this->z > -fE && this->z < fE)
		return TRUE;
	else
		return FALSE;
}
inline float Dot(const VECTOR3 &a, const VECTOR3& b)
{
	float		r;
	r = (a.x * b.x) + (a.y * b.y) + (a.z * b.z);
	return r;
}
inline VECTOR3 Cross(const VECTOR3& a, const VECTOR3& b)
{
	VECTOR3	r;

	r.x = a.y * b.z - a.z * b.y;
	r.y = a.z * b.x - a.x * b.z;
	r.z = a.x * b.y - a.y * b.x;

	return r;
}

inline float _log2(float x)
{
	return (logf(x) / logf(2.0f));
}

inline float Distance(const VECTOR3& v0, const VECTOR3& v1)
{
	float mag = (v1.x - v0.x) * (v1.x - v0.x) + (v1.y - v0.y) * (v1.y - v0.y) + (v1.z - v0.z) * (v1.z - v0.z);
	return sqrtf(mag);

}
inline float Distance(const VECTOR2& v0, const VECTOR2& v1)
{
	float mag = (v1.x - v0.x) * (v1.x - v0.x) + (v1.y - v0.y) * (v1.y - v0.y);
	return sqrtf(mag);

}
inline float Det(const VECTOR3& a, const VECTOR3& b, const VECTOR3& c)
{
	float det = Dot(Cross(a, b), c);
	return det;
}
inline BOOL IsPointInAABB(const VECTOR3* pv3Point, const VECTOR3* pv3Min, const VECTOR3* pv3Max)
{
	BOOL	x_cmp = (pv3Point->x >= pv3Min->x && pv3Point->x <= pv3Max->x);
	BOOL	y_cmp = (pv3Point->y >= pv3Min->y && pv3Point->y <= pv3Max->y);
	BOOL	z_cmp = (pv3Point->z >= pv3Min->z && pv3Point->z <= pv3Max->z);
	return (x_cmp & y_cmp & z_cmp);
}

inline BOOL IsRayInAABB(const VECTOR3* pv3Orig, const VECTOR3* pv3Ray, const VECTOR3* pv3Min, const VECTOR3* pv3Max)
{
	VECTOR3	v3To = *pv3Orig + *pv3Ray;
	if (IsPointInAABB(pv3Orig, pv3Min, pv3Max))
		return TRUE;

	if (IsPointInAABB(&v3To, pv3Min, pv3Max))
		return TRUE;

	return FALSE;

}
inline BOOL IsEqual(float a, float b, float near_zero)
{
	BOOL	bResult = fabsf(b - a) <= near_zero;
	return bResult;
}
inline BOOL IsEqual(const VECTOR3& a, const VECTOR3& b, float near_zero)
{
	VECTOR3	d = *(VECTOR3*)&b - *(VECTOR3*)&a;
	float dist = sqrtf(d.x * d.x + d.y * d.y + d.z * d.z);

	BOOL	bResult = dist <= near_zero;

	return bResult;
}

inline BOOL __VECTORCALL IsEqual(const __m128& a, const __m128& b, float near_zero)
{
	const __m128	w_zero_mask = _mm_castsi128_ps(_mm_set_epi32(0, -1, -1, -1));

	__m128 D = _mm_sub_ps(a, b);
	D = _mm_and_ps(D, w_zero_mask);
	D = _mm_mul_ps(D, D);
	__m128 sum = _mm_hadd_ps(D, D);
	sum = _mm_hadd_ps(sum, sum);
	__m128 scl = _mm_sqrt_ss(sum);

	BOOL	bResult = scl.m128_f32[0] <= near_zero;

	return bResult;
}

inline float __VECTORCALL DotProduct_SSE(const __m128& v0, const __m128& v1)
{
	__m128	v0_x_v1 = _mm_mul_ps(v0, v1);
	__m128 r = _mm_hadd_ps(v0_x_v1, v0_x_v1);
	r = _mm_hadd_ps(r, r);
	return r.m128_f32[0];
}

inline __m128 __VECTORCALL Normalize_SSE(const __m128& xyzw)
{
	__m128 mag = _mm_mul_ps(xyzw, xyzw);
	mag = _mm_hadd_ps(mag, mag);
	mag = _mm_hadd_ps(mag, mag);
	mag = _mm_sqrt_ps(mag);

	if (0.0f != mag.m128_f32[0])
	{
		mag = _mm_rcp_ps(mag);
	}

	__m128 N =_mm_mul_ps(xyzw, mag);

	return N;
}

inline float __VECTORCALL PlaneDotVector(const __m128& plane, __m128 v)
{
	v.m128_f32[3] = 0.0f;

	__m128	plane_x_v = _mm_mul_ps(plane, v);
	__m128 r = _mm_hadd_ps(plane_x_v, plane_x_v);
	r = _mm_hadd_ps(r, r);
	return r.m128_f32[0];
}
inline float __VECTORCALL PlaneDotPoint(const __m128& plane, __m128 p)
{
	p.m128_f32[3] = 1.0f;
	__m128	plane_x_p = _mm_mul_ps(plane, p);
	__m128 r = _mm_hadd_ps(plane_x_p, plane_x_p);
	r = _mm_hadd_ps(r, r);
	return r.m128_f32[0];
}


inline __m128 __VECTORCALL CalcYDistOther2Vertex_SSE(const __m128& v0, const __m128& v1, const __m128& v2)
{

	//	dist[0] = fabsf(v0.m128_f32[1] - v1.m128_f32[1]) + fabsf(v0.m128_f32[1] - v2.m128_f32[1]);
	//	dist[1] = fabsf(v1.m128_f32[1] - v0.m128_f32[1]) + fabsf(v1.m128_f32[1] - v2.m128_f32[1]);
	//	dist[2] = fabsf(v2.m128_f32[1] - v0.m128_f32[1]) + fabsf(v2.m128_f32[1] - v1.m128_f32[1]);

	__m128 r;
	const __m128 w_zero_mask = _mm_castsi128_ps(_mm_set_epi32(0, -1, -1, -1));
	const __m128 abs_mask = _mm_castsi128_ps(_mm_set1_epi32(~(1 << 31)));

	__m128 v0v1v2 = _mm_shuffle_ps(v0, v1, 0b01010101);			// v1.y | v1.y | v0.y | v0.y

	v0v1v2 = _mm_shuffle_ps(v0v1v2, v2, 0b01011000);			// v2.y | v2.y | v1.y | v0.y
	__m128 v1v0v0 = _mm_shuffle_ps(v0v1v2, v0v1v2, 0b00000001);	// v0.y | v0.y | v0.y | v1.y
	__m128 v2v2v1 = _mm_shuffle_ps(v0v1v2, v0v1v2, 0b01011010);	// v1.y | v1.y | v2.y | v2.y

	__m128 r0 = _mm_sub_ps(v0v1v2, v1v0v0);
	__m128 r1 = _mm_sub_ps(v0v1v2, v2v2v1);
	r0 = _mm_and_ps(r0, abs_mask);
	r1 = _mm_and_ps(r1, abs_mask);

	r = _mm_add_ps(r0, r1);
	r = _mm_and_ps(r, w_zero_mask);

	return r;
}

inline __m128 __VECTORCALL CalcYDistOther2Vertex_FPU(const __m128& v0, const __m128& v1, const __m128& v2)
{
	__m128 r;

	r.m128_f32[0] = fabsf(v0.m128_f32[1] - v1.m128_f32[1]) + fabsf(v0.m128_f32[1] - v2.m128_f32[1]);
	r.m128_f32[1] = fabsf(v1.m128_f32[1] - v0.m128_f32[1]) + fabsf(v1.m128_f32[1] - v2.m128_f32[1]);
	r.m128_f32[2] = fabsf(v2.m128_f32[1] - v0.m128_f32[1]) + fabsf(v2.m128_f32[1] - v1.m128_f32[1]);
	r.m128_f32[3] = 0.0f;

	return r;
}
inline __m128 __VECTORCALL Convert_XYZRHW_SSE(const __m128& a)
{
	__m128 r;

	__m128 xmm_rhw = _mm_shuffle_ps(a, a, 0b11111111);		//  w  |  w  |  w  |  w
	xmm_rhw = _mm_rcp_ps(xmm_rhw);							// 1/w | 1/w | 1/w | 1/w
	r = _mm_mul_ps(a, xmm_rhw);								// w/w | z/w | y/w | x/w
	xmm_rhw = _mm_movehl_ps(xmm_rhw, r);					// 1/w | 1/w | w/w | z/w

	r = _mm_shuffle_ps(r, xmm_rhw, 0b10000100);				// 1/w | z/w | y/w | x/w

	return r;
}

inline __m128 __VECTORCALL Convert_XYZRHW_FPU(const __m128& a)
{
	__m128 r;
	r.m128_f32[0] = a.m128_f32[0] / a.m128_f32[3];
	r.m128_f32[1] = a.m128_f32[1] / a.m128_f32[3];
	r.m128_f32[2] = a.m128_f32[2] / a.m128_f32[3];
	r.m128_f32[3] = 1.0f / a.m128_f32[3];

	return r;
}




inline __m128 __VECTORCALL CrossProduct_SSE(const __m128& u, const __m128& v)
{
	__m128	w_zero_mask = _mm_castsi128_ps(_mm_set_epi32(0, -1, -1, -1));
	__m128	zero = _mm_set1_ps(0.0);

	//x,y성분
	__m128 su = _mm_shuffle_ps(u, u, 41);				//	u.x		|	u.z		|	u.z		|	u.y
	__m128 sv = _mm_shuffle_ps(v, v, 146);				//	v.z		|	v.y		|	v.x		|	v.z
	__m128 su_x_sv = _mm_mul_ps(su, sv);				//	u.x*v.z |	u.z*v.y | u.z*v.x	|	u.y*v.z	
	__m128 up_xy = _mm_movehl_ps(zero, su_x_sv);		//    0     |	  0		| u.x*v.z   |	u.z*v.y
	up_xy = _mm_sub_ps(su_x_sv, up_xy);			//    ?	    |      ?    | u.z*v.x - u.x*v.z | u.y*v.z - u.z*v.y

	// z성분 
	su = _mm_shuffle_ps(u, u, 0b00010000);		//	?	|   u.y	  |		?	  |	  u.x
	sv = _mm_shuffle_ps(v, v, 0b00000001);		//	?	|   v.x	  |		?	  |	  v.y

	su_x_sv = _mm_mul_ps(su, sv);				//	?	| u.y*v.x |		?	  | u.x*v.y 
	__m128 up_z = _mm_movehl_ps(zero, su_x_sv);		//		|         |			  | u.y*v.x	
	up_z = _mm_sub_ss(su_x_sv, up_z);			//	    |         |           | u.x*v.y - u.y*v.x	

	__m128 up_xyz0 = _mm_and_ps(_mm_shuffle_ps(up_xy, up_z, 0b00000100), w_zero_mask);	// 0 | up.z | up.y | up.x | 

	return up_xyz0;
}

inline __m128 __VECTORCALL CalcPlaneEquation_SSE(const __m128& Point0, const __m128& Point1, const __m128& Point2)
{

	__m128	up_nxnynz0_D = _mm_set1_ps(0);
	__m128	w_zero_mask = _mm_castsi128_ps(_mm_set_epi32(0, -1, -1, -1));
	__m128	zero = _mm_set1_ps(0.0);

	// cross product			r = u*v
	__m128 u = _mm_sub_ps(Point1, Point0);
	__m128 v = _mm_sub_ps(Point2, Point0);

	// cross product			r = u*v
	//x,y성분
	__m128 su = _mm_shuffle_ps(u, u, 41);				//	u.x		|	u.z		|	u.z		|	u.y
	__m128 sv = _mm_shuffle_ps(v, v, 146);				//	v.z		|	v.y		|	v.x		|	v.z
	__m128 su_x_sv = _mm_mul_ps(su, sv);				//	u.x*v.z |	u.z*v.y | u.z*v.x	|	u.y*v.z	
	__m128 up_xy = _mm_movehl_ps(zero, su_x_sv);		//    0     |	  0		| u.x*v.z   |	u.z*v.y
	up_xy = _mm_sub_ps(su_x_sv, up_xy);			//    ?	    |      ?    | u.z*v.x - u.x*v.z | u.y*v.z - u.z*v.y

	// z성분 
	su = _mm_shuffle_ps(u, u, 0b00010000);		//	?	|   u.y	  |		?	  |	  u.x
	sv = _mm_shuffle_ps(v, v, 0b00000001);		//	?	|   v.x	  |		?	  |	  v.y

	su_x_sv = _mm_mul_ps(su, sv);				//	?	| u.y*v.x |		?	  | u.x*v.y 
	__m128 up_z = _mm_movehl_ps(zero, su_x_sv);		//		|         |			  | u.y*v.x	
	up_z = _mm_sub_ss(su_x_sv, up_z);			//	    |         |           | u.x*v.y - u.y*v.x	

	__m128 up_xyz0 = _mm_and_ps(_mm_shuffle_ps(up_xy, up_z, 0b00000100), w_zero_mask);	// 0 | up.z | up.y | up.x | 

	// Normzlie Up
	__m128 upxup = _mm_mul_ps(up_xyz0, up_xyz0);	//	0*0 | z*z* | y*y | x*x

	__m128 sum = _mm_hadd_ps(upxup, upxup);
	sum = _mm_hadd_ps(sum, sum);

	if (_mm_comieq_ss(sum, zero))
	{
		goto lb_return;
	}

	__m128 scl = _mm_sqrt_ps(sum);
	__m128 rcp_scl = _mm_rcp_ps(scl);
	up_nxnynz0_D = _mm_mul_ps(up_xyz0, rcp_scl);

	// D
	// dot(삼각형의 한점, up)
	__m128 dp = _mm_and_ps(_mm_mul_ps(Point0, up_nxnynz0_D), w_zero_mask);

	__m128 D = _mm_hadd_ps(dp, dp);
	D = _mm_hadd_ps(D, D);
	D = _mm_sub_ss(zero, D);					//	0	|	0	|	0	|	D	}
	D = _mm_shuffle_ps(D, D, 0b00010101);		//	D	|	0	|	0	|	0	}
	up_nxnynz0_D = _mm_or_ps(up_nxnynz0_D, D);	//	D	|	nz	|	ny	|	nx	}

lb_return:
	return up_nxnynz0_D;
}

inline float __VECTORCALL VECTOR3Length_SSE(const __m128& v)
{
	__m128 vxv = _mm_mul_ps(v, v);	//	0*0 | z*z* | y*y | x*x

	__m128 sum = _mm_hadd_ps(vxv, vxv);
	sum = _mm_hadd_ps(sum, sum);

	__m128 scl = _mm_sqrt_ss(sum);

	return scl.m128_f32[0];
}

inline float __VECTORCALL CalcTriSizeSSE(const __m128& Point0, const __m128& Point1, const __m128& Point2)
{
	float area_size = 0.0f;

	__m128	up_nxnynz0_D = _mm_set1_ps(0);
	__m128	w_zero_mask = _mm_castsi128_ps(_mm_set_epi32(0, -1, -1, -1));
	__m128	zero = _mm_set1_ps(0.0);

	// cross product			r = u*v
	__m128 u = _mm_sub_ps(Point1, Point0);
	__m128 v = _mm_sub_ps(Point2, Point0);

	// cross product			r = u*v
	//x,y성분
	__m128 su = _mm_shuffle_ps(u, u, 41);				//	u.x		|	u.z		|	u.z		|	u.y
	__m128 sv = _mm_shuffle_ps(v, v, 146);				//	v.z		|	v.y		|	v.x		|	v.z
	__m128 su_x_sv = _mm_mul_ps(su, sv);				//	u.x*v.z |	u.z*v.y | u.z*v.x	|	u.y*v.z	
	__m128 up_xy = _mm_movehl_ps(zero, su_x_sv);		//    0     |	  0		| u.x*v.z   |	u.z*v.y
	up_xy = _mm_sub_ps(su_x_sv, up_xy);			//    ?	    |      ?    | u.z*v.x - u.x*v.z | u.y*v.z - u.z*v.y

	// z성분 
	su = _mm_shuffle_ps(u, u, 0b00010000);		//	?	|   u.y	  |		?	  |	  u.x
	sv = _mm_shuffle_ps(v, v, 0b00000001);		//	?	|   v.x	  |		?	  |	  v.y

	su_x_sv = _mm_mul_ps(su, sv);				//	?	| u.y*v.x |		?	  | u.x*v.y 
	__m128 up_z = _mm_movehl_ps(zero, su_x_sv);		//		|         |			  | u.y*v.x	
	up_z = _mm_sub_ss(su_x_sv, up_z);			//	    |         |           | u.x*v.y - u.y*v.x	

	__m128 up_xyz0 = _mm_and_ps(_mm_shuffle_ps(up_xy, up_z, 0b00000100), w_zero_mask);	// 0 | up.z | up.y | up.x | 

	// Normzlie Up
	__m128 upxup = _mm_mul_ps(up_xyz0, up_xyz0);	//	0*0 | z*z* | y*y | x*x

	__m128 sum = _mm_hadd_ps(upxup, upxup);
	sum = _mm_hadd_ps(sum, sum);

	__m128 scl = _mm_sqrt_ss(sum);
	area_size = scl.m128_f32[0] * 0.5f;
lb_return:
	return area_size;
}


inline __m128i __VECTORCALL GetYEqualCount_SSE(__m128 v0, __m128 v1, __m128 v2, float near_zero)
{
	const __m128 abs_mask = _mm_castsi128_ps(_mm_set1_epi32(~(1 << 31)));
	const __m128i w_zero_mask_i = _mm_set_epi32(-1, -1, -1, 0);
	__m128	n_zero = _mm_set1_ps(near_zero);
	__m128	a = _mm_shuffle_ps(v0, v1, 0b01010101);	// v1.y | v1.y | v0.y |v0.y
	__m128	b = _mm_shuffle_ps(a, v2, 0b01011000);	// v2.y | v2.y | v1.y |v0.y
	a = _mm_shuffle_ps(b, b, 0b10010010);	// v2.y | v1.y | v0.y |v2.y
	__m128  diff_value = _mm_sub_ps(b, a);
	diff_value = _mm_and_ps(diff_value, abs_mask);

	__m128i cmp_value_i = _mm_castps_si128(_mm_cmple_ps(diff_value, n_zero));
	cmp_value_i = _mm_and_si128(w_zero_mask_i, cmp_value_i);

	__m128i r = _mm_hadd_epi32(cmp_value_i, cmp_value_i);
	r = _mm_hadd_epi32(r, r);

	return r;
}

inline __m128 __VECTORCALL TransformVector_SSE(const __m128& src, const __m128& m0, const __m128& m1, const __m128& m2, const __m128& m3)
{
	__m128 xxxx = _mm_shuffle_ps(src, src, 0b00000000);
	__m128 yyyy = _mm_shuffle_ps(src, src, 0b01010101);
	__m128 zzzz = _mm_shuffle_ps(src, src, 0b10101010);
	__m128 wwww = _mm_shuffle_ps(src, src, 0b11111111);

	__m128 r0 = _mm_mul_ps(xxxx, m0);
	__m128 r1 = _mm_mul_ps(yyyy, m1);
	__m128 r2 = _mm_mul_ps(zzzz, m2);
	__m128 r3 = _mm_mul_ps(wwww, m3);

	r0 = _mm_add_ps(r0, r1);
	r2 = _mm_add_ps(r2, r3);
	r0 = _mm_add_ps(r0, r2);

	return r0;
}
inline __m128 __VECTORCALL TransformVector_SSE(const __m128& v, const MATRIX4_A* pMat)
{
	__m128	xxxx = _mm_shuffle_ps(v, v, 0b00000000);
	__m128	yyyy = _mm_shuffle_ps(v, v, 0b01010101);
	__m128	zzzz = _mm_shuffle_ps(v, v, 0b10101010);
	__m128	wwww = _mm_shuffle_ps(v, v, 0b11111111);


	xxxx = _mm_mul_ps(xxxx, pMat->_11);
	yyyy = _mm_mul_ps(yyyy, pMat->_21);
	zzzz = _mm_mul_ps(zzzz, pMat->_31);
	wwww = _mm_mul_ps(wwww, pMat->_41);

	__m128 r0 = _mm_add_ps(xxxx, yyyy);
	__m128 r1 = _mm_add_ps(zzzz, wwww);
	__m128 r = _mm_add_ps(r0, r1);

	return r;
}


inline __m128 __VECTORCALL Saturate_SSE(const __m128& a, const __m128& min_max)
{
	__m128 r;

	__m128 cmp_val_min = _mm_shuffle_ps(min_max, min_max, 0b00000000);
	__m128 cmp_val_max = _mm_shuffle_ps(min_max, min_max, 0b01010101);
	r = _mm_max_ps(a, cmp_val_min);
	r = _mm_min_ps(r, cmp_val_max);

	return r;
}

struct VECTOR4
{
	float x;
	float y;
	float z;
	float w;

	inline		void Set(float in_x, float in_y, float in_z, float in_w);

	inline	VECTOR4		operator +(const VECTOR4 &v) const;
	inline	VECTOR4		operator -(const VECTOR4 &v) const;
	inline	VECTOR4		operator *(const float	&f) const;
	inline	VECTOR4		operator *(const VECTOR4& v) const;
	inline	VECTOR4		operator /(const float	&f) const;
	inline	BOOL		operator==(const VECTOR4& v) const;


};

inline VECTOR4 VECTOR4::operator +(const VECTOR4 &v4) const
{
	VECTOR4	result;
	result.x = this->x + v4.x;
	result.y = this->y + v4.y;
	result.z = this->z + v4.z;
	result.w = this->w + v4.w;
	return	result;
}

inline VECTOR4 VECTOR4::operator -(const VECTOR4 &v4) const
{
	VECTOR4		result;
	result.x = this->x - v4.x;
	result.y = this->y - v4.y;
	result.z = this->z - v4.z;
	result.w = this->w - v4.w;
	return	result;
}

inline VECTOR4 VECTOR4::operator *(const float	&f) const
{
	VECTOR4		r;
	r.x = this->x * f;
	r.y = this->y * f;
	r.z = this->z * f;
	r.w = this->w * f;
	return	r;
}

inline VECTOR4 VECTOR4::operator *(const VECTOR4& v) const
{
	VECTOR4		r;
	r.x = this->x * v.x;
	r.y = this->y * v.y;
	r.z = this->z * v.z;
	r.w = this->w * v.w;
	return	r;
}

inline VECTOR4 VECTOR4::operator /(const float	&f) const
{
	VECTOR4		r;
	r.x = this->x / f;
	r.y = this->y / f;
	r.z = this->z / f;
	r.w = this->w / f;
	return	r;
}

inline	BOOL VECTOR4::operator==(const VECTOR4& v) const
{
	BOOL	bResult;
	if (this->x == v.x && this->y == v.y && this->z == v.z && this->w == v.w)
		bResult = TRUE;
	else
		bResult = FALSE;

	return	bResult;
}


inline void VECTOR4::Set(float in_x, float in_y, float in_z, float in_w)
{
	x = in_x;
	y = in_y;
	z = in_z;
	w = in_w;

}
struct QUATERNION
{
	float x;
	float y;
	float z;
	float w;
	QUATERNION() { x = 0; y = 0; z = 0; w = 1; }

};

struct DOUBLE_VECTOR3
{
	double		x;
	double		y;
	double		z;

	inline	DOUBLE_VECTOR3		operator +(const DOUBLE_VECTOR3 &v) const;
	inline	DOUBLE_VECTOR3		operator -(const DOUBLE_VECTOR3 &v) const;
	inline	DOUBLE_VECTOR3		operator *(const double	&f) const;
	inline	DOUBLE_VECTOR3		operator /(const double	&f) const;
	inline	double		operator *(const DOUBLE_VECTOR3 &v) const;			// dot.
	inline	BOOL		operator==(const DOUBLE_VECTOR3& v) const;
	inline	void		operator=(const VECTOR3& v);

};


inline DOUBLE_VECTOR3 DOUBLE_VECTOR3::operator +(const DOUBLE_VECTOR3 &v3) const
{
	DOUBLE_VECTOR3	result;
	result.x = this->x + v3.x;
	result.y = this->y + v3.y;
	result.z = this->z + v3.z;
	return	result;
}

inline DOUBLE_VECTOR3 DOUBLE_VECTOR3::operator -(const DOUBLE_VECTOR3 &v3) const
{
	DOUBLE_VECTOR3		result;
	result.x = this->x - v3.x;
	result.y = this->y - v3.y;
	result.z = this->z - v3.z;
	return	result;
}

inline DOUBLE_VECTOR3 DOUBLE_VECTOR3::operator *(const double	&f) const
{
	DOUBLE_VECTOR3		r;
	r.x = this->x * f;
	r.y = this->y * f;
	r.z = this->z * f;
	return	r;
}

inline DOUBLE_VECTOR3 DOUBLE_VECTOR3::operator /(const double	&f) const
{
	DOUBLE_VECTOR3		r;
	r.x = this->x / f;
	r.y = this->y / f;
	r.z = this->z / f;
	return	r;
}
// dot.
inline double DOUBLE_VECTOR3::operator *(const DOUBLE_VECTOR3 &v) const
{
	double		r;
	r = this->x * v.x;
	r += this->y * v.y;
	r += this->z * v.z;
	return		r;
}

inline	BOOL DOUBLE_VECTOR3::operator==(const DOUBLE_VECTOR3& v) const
{
	BOOL	bResult;
	if (this->x == v.x && this->y == v.y && this->z == v.z)
		bResult = TRUE;
	else
		bResult = FALSE;

	return	bResult;

}


inline	void DOUBLE_VECTOR3::operator=(const VECTOR3& v)
{

	this->x = (double)v.x;
	this->y = (double)v.y;
	this->z = (double)v.z;
}


inline float __VECTORCALL Orient2D_Vector4(const VECTOR4* a, const VECTOR4* b, const VECTOR4* c)
{
	return (b->x - a->x) * (c->y - a->y) - (b->y - a->y) * (c->x - a->x);
}

inline __m128 __VECTORCALL Orient2D_4Sample(const __m128& a, const __m128& b, const __m128& x0123, const __m128& yyyy)
{
	// float r =  (b->x - a->x) * (c->y - a->y) - (b->y - a->y) * (c->x - a->x);
	//float r0 = (b.m128_f32[0] - a.m128_f32[0]) * (pv4List[0].m128_f32[1] - a.m128_f32[1]) - (b.m128_f32[1] - a.m128_f32[1]) * (pv4List[0].m128_f32[0] - a.m128_f32[0]);
	//float r1 = (b.m128_f32[0] - a.m128_f32[0]) * (pv4List[1].m128_f32[1] - a.m128_f32[1]) - (b.m128_f32[1] - a.m128_f32[1]) * (pv4List[1].m128_f32[0] - a.m128_f32[0]);
	//float r2 = (b.m128_f32[0] - a.m128_f32[0]) * (pv4List[2].m128_f32[1] - a.m128_f32[1]) - (b.m128_f32[1] - a.m128_f32[1]) * (pv4List[2].m128_f32[0] - a.m128_f32[0]);
	//float r3 = (b.m128_f32[0] - a.m128_f32[0]) * (pv4List[3].m128_f32[1] - a.m128_f32[1]) - (b.m128_f32[1] - a.m128_f32[1]) * (pv4List[3].m128_f32[0] - a.m128_f32[0]);
	__m128 r;

	__m128 b_a = _mm_sub_ps(b, a);
	__m128 b0_a0 = _mm_shuffle_ps(b_a, b_a, 0b00000000);
	__m128 b1_a1 = _mm_shuffle_ps(b_a, b_a, 0b01010101);

	//float _b0_a0 = b.m128_f32[0] - a.m128_f32[0];
	//float _b1_a1 = b.m128_f32[1] - a.m128_f32[1];
	//__m128 b0_a0 = _mm_set1_ps(_b0_a0);
	//__m128 b1_a1 = _mm_set1_ps(_b1_a1);

	//__m128 v0 = { pv4List[0].m128_f32[0], pv4List[1].m128_f32[0], pv4List[2].m128_f32[0], pv4List[3].m128_f32[0] };
	//__m128 v1 = { pv4List[0].m128_f32[1], pv4List[1].m128_f32[1], pv4List[2].m128_f32[1], pv4List[3].m128_f32[1] };
	__m128 v0 = x0123;	// pv4List[0].x , pv4List[1].x , pv4List[2].x , pv4List[3].x
	__m128 v1 = yyyy;	// pv4List[0].y , pv4List[1].y , pv4List[2].y , pv4List[3].y
//	__m128 v0 = _mm_setr_ps(pv4List[0].m128_f32[0], pv4List[1].m128_f32[0], pv4List[2].m128_f32[0], pv4List[3].m128_f32[0]);	// pv4List[0].x , pv4List[1].x , pv4List[2].x , pv4List[3].x
//	__m128 v1 = _mm_setr_ps(pv4List[0].m128_f32[1], pv4List[1].m128_f32[1], pv4List[2].m128_f32[1], pv4List[3].m128_f32[1]);	// pv4List[0].y , pv4List[1].y , pv4List[2].y , pv4List[3].y

	//r.m128_f32[0] = (b0_a0) * (v1.m128_f32[0] - a.m128_f32[1]) - (b1_a1) * (v0.m128_f32[0] - a.m128_f32[0]);
	//r.m128_f32[1] = (b0_a0) * (v1.m128_f32[1] - a.m128_f32[1]) - (b1_a1) * (v0.m128_f32[1] - a.m128_f32[0]);
	//r.m128_f32[2] = (b0_a0) * (v1.m128_f32[2] - a.m128_f32[1]) - (b1_a1) * (v0.m128_f32[2] - a.m128_f32[0]);
	//r.m128_f32[3] = (b0_a0) * (v1.m128_f32[3] - a.m128_f32[1]) - (b1_a1) * (v0.m128_f32[3] - a.m128_f32[0]);

	//__m128 a0 = { a.m128_f32[0], a.m128_f32[0], a.m128_f32[0], a.m128_f32[0] };
	//__m128 a1 = { a.m128_f32[1], a.m128_f32[1], a.m128_f32[1], a.m128_f32[1] };

	__m128 a0 = _mm_shuffle_ps(a, a, 0b00000000);
	__m128 a1 = _mm_shuffle_ps(a, a, 0b01010101);

	//r.m128_f32[0] = (b0_a0.m128_f32[0]) * (v1.m128_f32[0] - a1.m128_f32[0]) - (b1_a1.m128_f32[0]) * (v0.m128_f32[0] - a0.m128_f32[0]);
	//r.m128_f32[1] = (b0_a0.m128_f32[1]) * (v1.m128_f32[1] - a1.m128_f32[1]) - (b1_a1.m128_f32[1]) * (v0.m128_f32[1] - a0.m128_f32[1]);
	//r.m128_f32[2] = (b0_a0.m128_f32[2]) * (v1.m128_f32[2] - a1.m128_f32[2]) - (b1_a1.m128_f32[2]) * (v0.m128_f32[2] - a0.m128_f32[2]);
	//r.m128_f32[3] = (b0_a0.m128_f32[3]) * (v1.m128_f32[3] - a1.m128_f32[3]) - (b1_a1.m128_f32[3]) * (v0.m128_f32[3] - a0.m128_f32[3]);

	__m128 A = _mm_mul_ps(b0_a0, _mm_sub_ps(v1, a1));
	__m128 B = _mm_mul_ps(b1_a1, _mm_sub_ps(v0, a0));
	r = _mm_sub_ps(A, B);

	//__m128 B = _mm_mul_ps(b1_a1, _mm_sub_ps(v0, a0));
	//r = _mm_fmsub_ps(b0_a0, _mm_sub_ps(v1, a1), B);

	//for (DWORD i = 0; i < 4; i++)
	//{
	//	if (fabsf(r.m128_f32[i] - r1.m128_f32[i]) > 0.01f)
	//		__debugbreak();
	//}
	return r;

}
//__m128 w0 = Orient2D_4Sample(v1, v2, x0123, yyyy);
inline __m128 __VECTORCALL Orient2D_4Sample_v1_v2(const __m128& v1, const __m128& v2, const __m128& x0123, const __m128& yyyy)
{
	__m128 r;

	__m128 v2_v1 = _mm_sub_ps(v2, v1);
	__m128 v2_0_v1_0 = _mm_shuffle_ps(v2_v1, v2_v1, 0b00000000);
	__m128 v2_1_v1_1 = _mm_shuffle_ps(v2_v1, v2_v1, 0b01010101);

	__m128 v1_0 = _mm_shuffle_ps(v1, v1, 0b00000000);
	__m128 v1_1 = _mm_shuffle_ps(v1, v1, 0b01010101);

	__m128 A = _mm_mul_ps(v2_0_v1_0, _mm_sub_ps(yyyy, v1_1));
	__m128 B = _mm_mul_ps(v2_1_v1_1, _mm_sub_ps(x0123, v1_0));
	r = _mm_sub_ps(A, B);

	return r;
}
//__m128 w1 = Orient2D_4Sample(v2, v0, x0123, yyyy);
inline __m128 __VECTORCALL Orient2D_4Sample_v2_v0(const __m128& v2, const __m128& v0, const __m128& x0123, const __m128& yyyy)
{
	__m128 r;

	__m128 v0_v2 = _mm_sub_ps(v0, v2);
	__m128 v0_0_v2_0 = _mm_shuffle_ps(v0_v2, v0_v2, 0b00000000);
	__m128 v0_1_v2_1 = _mm_shuffle_ps(v0_v2, v0_v2, 0b01010101);

	__m128 v2_0 = _mm_shuffle_ps(v2, v2, 0b00000000);
	__m128 v2_1 = _mm_shuffle_ps(v2, v2, 0b01010101);

	__m128 A = _mm_mul_ps(v0_0_v2_0, _mm_sub_ps(yyyy, v2_1));
	__m128 B = _mm_mul_ps(v0_1_v2_1, _mm_sub_ps(x0123, v2_0));
	r = _mm_sub_ps(A, B);

	return r;
}
//__m128 w2 = Orient2D_4Sample(v0, v1, x0123, yyyy);
inline __m128 __VECTORCALL Orient2D_4Sample_v0_v1(const __m128& v0, const __m128& v1, const __m128& x0123, const __m128& yyyy)
{
	__m128 r;

	__m128 v1_v0 = _mm_sub_ps(v1, v0);
	__m128 v1_0_v0_0 = _mm_shuffle_ps(v1_v0, v1_v0, 0b00000000);
	__m128 v1_1_v0_1 = _mm_shuffle_ps(v1_v0, v1_v0, 0b01010101);

	__m128 v0_0 = _mm_shuffle_ps(v0, v0, 0b00000000);
	__m128 v0_1 = _mm_shuffle_ps(v0, v0, 0b01010101);

	__m128 A = _mm_mul_ps(v1_0_v0_0, _mm_sub_ps(yyyy, v0_1));
	__m128 B = _mm_mul_ps(v1_1_v0_1, _mm_sub_ps(x0123, v0_0));
	r = _mm_sub_ps(A, B);

	return r;
}


/*
inline float __VECTORCALL Orient2D_SSE(__m128& a, __m128& b, __m128& c)
{
	//float r1 = Orient2D_Vector4((VECTOR4*)&a, (VECTOR4*)&b, (VECTOR4*)&c);
	//float r = (b.m128_f32[0] - a.m128_f32[0]) * (c.m128_f32[1] - a.m128_f32[1]) - (b.m128_f32[1] - a.m128_f32[1]) * (c.m128_f32[0] - a.m128_f32[0]);

	__m128 zero = _mm_setzero_ps();
	__m128 bx_by_cy_cx = _mm_shuffle_ps(b, c, 0b00010100);	// c.x | c.y | b.y | b.x
	__m128 ax_ay_ay_ax = _mm_shuffle_ps(a, a, 0b00010100);	// a.x | a.y | a.y | a.x
	__m128 bx_ax__by_ay__cy_ay__cx_ax = _mm_sub_ps(bx_by_cy_cx, ax_ay_ay_ax);	// c.x - a.x | c.y - a.y | b.y - a.y | b.x - a.x
	__m128 cy_ay__cx_ax = _mm_movehl_ps(zero, bx_ax__by_ay__cy_ay__cx_ax);		//		0	 |		0    | c.x - a.x | c.y - a.y
	__m128 r0 = _mm_mul_ps(bx_ax__by_ay__cy_ay__cx_ax, cy_ay__cx_ax);			//		0	 |      0	 | (b.y - a.y)*(c.x - a.x) | (b.x - a.x)*(c.y - a.y)
	float r = r0.m128_f32[0] - r0.m128_f32[1];		 							// (b.x - a.x)*(c.y - a.y) - (b.y - a.y)*(c.x - a.x)

	//if (fabsf(r - r1) > 0.0001f)
	//	__debugbreak();
	return r;
}
*/
inline float __VECTORCALL Orient2D_SSE(__m128& a, __m128& b, __m128& c)
{
	float r = (b.m128_f32[0] - a.m128_f32[0]) * (c.m128_f32[1] - a.m128_f32[1]) - (b.m128_f32[1] - a.m128_f32[1]) * (c.m128_f32[0] - a.m128_f32[0]);
	return r;
}
#if defined(_USE_AVX)
inline __m256 __VECTORCALL Orient2D_8Sample(const __m128& a, const __m128& b, const __m256& x01234567, const __m256& yyyyyyyy)
{
	__m256 r;
	// float r =  (b->x - a->x) * (c->y - a->y) - (b->y - a->y) * (c->x - a->x);

	//r.m256_f32[0] = (b.m128_f32[0] - a.m128_f32[0]) * (pv8List[0].m256_f32[1] - a.m128_f32[1]) - (b.m128_f32[1] - a.m128_f32[1]) * (pv8List[0].m256_f32[0] - a.m128_f32[0]);
	//r.m256_f32[1] = (b.m128_f32[0] - a.m128_f32[0]) * (pv8List[1].m256_f32[1] - a.m128_f32[1]) - (b.m128_f32[1] - a.m128_f32[1]) * (pv8List[1].m256_f32[0] - a.m128_f32[0]);
	//r.m256_f32[2] = (b.m128_f32[0] - a.m128_f32[0]) * (pv8List[2].m256_f32[1] - a.m128_f32[1]) - (b.m128_f32[1] - a.m128_f32[1]) * (pv8List[2].m256_f32[0] - a.m128_f32[0]);
	//r.m256_f32[3] = (b.m128_f32[0] - a.m128_f32[0]) * (pv8List[3].m256_f32[1] - a.m128_f32[1]) - (b.m128_f32[1] - a.m128_f32[1]) * (pv8List[3].m256_f32[0] - a.m128_f32[0]);
	//r.m256_f32[4] = (b.m128_f32[0] - a.m128_f32[0]) * (pv8List[4].m256_f32[1] - a.m128_f32[1]) - (b.m128_f32[1] - a.m128_f32[1]) * (pv8List[4].m256_f32[0] - a.m128_f32[0]);
	//r.m256_f32[5] = (b.m128_f32[0] - a.m128_f32[0]) * (pv8List[5].m256_f32[1] - a.m128_f32[1]) - (b.m128_f32[1] - a.m128_f32[1]) * (pv8List[5].m256_f32[0] - a.m128_f32[0]);
	//r.m256_f32[6] = (b.m128_f32[0] - a.m128_f32[0]) * (pv8List[6].m256_f32[1] - a.m128_f32[1]) - (b.m128_f32[1] - a.m128_f32[1]) * (pv8List[6].m256_f32[0] - a.m128_f32[0]);
	//r.m256_f32[7] = (b.m128_f32[0] - a.m128_f32[0]) * (pv8List[7].m256_f32[1] - a.m128_f32[1]) - (b.m128_f32[1] - a.m128_f32[1]) * (pv8List[7].m256_f32[0] - a.m128_f32[0]);

	__m128 b_a = _mm_sub_ps(b, a);
	__m128 _b0_a0_ = _mm_shuffle_ps(b_a, b_a, 0b00000000);
	__m128 _b1_a1_ = _mm_shuffle_ps(b_a, b_a, 0b01010101);
	__m256 b0_a0 = _mm256_setr_m128(_b0_a0_, _b0_a0_);
	__m256 b1_a1 = _mm256_setr_m128(_b1_a1_, _b1_a1_);

	__m256 v0 = x01234567;
	__m256 v1 = yyyyyyyy;

	__m128 _a0_ = _mm_shuffle_ps(a, a, 0b00000000);
	__m128 _a1_ = _mm_shuffle_ps(a, a, 0b01010101);
	__m256 a0 = _mm256_setr_m128(_a0_, _a0_);
	__m256 a1 = _mm256_setr_m128(_a1_, _a1_);


	//r.m256_f32[0] = b0_a0.m256_f32[0] * (v1.m256_f32[0] - a1.m256_f32[0]) - b1_a1.m256_f32[0] * (v0.m256_f32[0] - a0.m256_f32[0]);
	//r.m256_f32[1] = b0_a0.m256_f32[1] * (v1.m256_f32[1] - a1.m256_f32[1]) - b1_a1.m256_f32[1] * (v0.m256_f32[1] - a0.m256_f32[1]);
	//r.m256_f32[2] = b0_a0.m256_f32[2] * (v1.m256_f32[2] - a1.m256_f32[2]) - b1_a1.m256_f32[2] * (v0.m256_f32[2] - a0.m256_f32[2]);
	//r.m256_f32[3] = b0_a0.m256_f32[3] * (v1.m256_f32[3] - a1.m256_f32[3]) - b1_a1.m256_f32[3] * (v0.m256_f32[3] - a0.m256_f32[3]);
	//r.m256_f32[4] = b0_a0.m256_f32[4] * (v1.m256_f32[4] - a1.m256_f32[4]) - b1_a1.m256_f32[4] * (v0.m256_f32[4] - a0.m256_f32[4]);
	//r.m256_f32[5] = b0_a0.m256_f32[5] * (v1.m256_f32[5] - a1.m256_f32[5]) - b1_a1.m256_f32[5] * (v0.m256_f32[5] - a0.m256_f32[5]);
	//r.m256_f32[6] = b0_a0.m256_f32[6] * (v1.m256_f32[6] - a1.m256_f32[6]) - b1_a1.m256_f32[6] * (v0.m256_f32[6] - a0.m256_f32[6]);
	//r.m256_f32[7] = b0_a0.m256_f32[7] * (v1.m256_f32[7] - a1.m256_f32[7]) - b1_a1.m256_f32[7] * (v0.m256_f32[7] - a0.m256_f32[7]);

	__m256 A = _mm256_mul_ps(b0_a0, _mm256_sub_ps(v1, a1));
	__m256 B = _mm256_mul_ps(b1_a1, _mm256_sub_ps(v0, a0));
	r = _mm256_sub_ps(A, B);

	return r;

}
//__m256 w0 = Orient2D_8Sample(v1, v2, x01234567, yyyyyyyy);
inline __m256 __VECTORCALL Orient2D_8Sample_v1_v2(const __m128& v1, const __m128& v2, const __m256& x01234567, const __m256& yyyyyyyy)
{
	__m256 r;

	__m128 v2_v1 = _mm_sub_ps(v2, v1);
	__m128 _v2_0_v1_0_ = _mm_shuffle_ps(v2_v1, v2_v1, 0b00000000);
	__m128 _v2_1_v1_1_ = _mm_shuffle_ps(v2_v1, v2_v1, 0b01010101);
	__m256 v2_0_v1_0 = _mm256_setr_m128(_v2_0_v1_0_, _v2_0_v1_0_);
	__m256 v2_1_v1_1 = _mm256_setr_m128(_v2_1_v1_1_, _v2_1_v1_1_);

	__m128 _v1_0_ = _mm_shuffle_ps(v1, v1, 0b00000000);
	__m128 _v1_1_ = _mm_shuffle_ps(v1, v1, 0b01010101);
	__m256 v1_0 = _mm256_setr_m128(_v1_0_, _v1_0_);
	__m256 v1_1 = _mm256_setr_m128(_v1_1_, _v1_1_);
	r = _mm256_sub_ps(_mm256_mul_ps(v2_0_v1_0, _mm256_sub_ps(yyyyyyyy, v1_1)), _mm256_mul_ps(v2_1_v1_1, _mm256_sub_ps(x01234567, v1_0)));

	return r;
}
//__m256 w1 = Orient2D_8Sample(v2, v0, x01234567, yyyyyyyy);
inline __m256 __VECTORCALL Orient2D_8Sample_v2_v0(const __m128& v2, const __m128& v0, const __m256& x01234567, const __m256& yyyyyyyy)
{
	__m256 r;

	__m128 v0_v2 = _mm_sub_ps(v0, v2);
	__m128 _v0_0_v2_0_ = _mm_shuffle_ps(v0_v2, v0_v2, 0b00000000);
	__m128 _v0_1_v2_1_ = _mm_shuffle_ps(v0_v2, v0_v2, 0b01010101);
	__m256 v0_0_v2_0 = _mm256_setr_m128(_v0_0_v2_0_, _v0_0_v2_0_);
	__m256 v0_1_v2_1 = _mm256_setr_m128(_v0_1_v2_1_, _v0_1_v2_1_);

	__m128 _v2_0_ = _mm_shuffle_ps(v2, v2, 0b00000000);
	__m128 _v2_1_ = _mm_shuffle_ps(v2, v2, 0b01010101);
	__m256 v2_0 = _mm256_setr_m128(_v2_0_, _v2_0_);
	__m256 v2_1 = _mm256_setr_m128(_v2_1_, _v2_1_);
	r = _mm256_sub_ps(_mm256_mul_ps(v0_0_v2_0, _mm256_sub_ps(yyyyyyyy, v2_1)), _mm256_mul_ps(v0_1_v2_1, _mm256_sub_ps(x01234567, v2_0)));

	return r;
}
//__m256 w2 = Orient2D_8Sample(v0, v1, x01234567, yyyyyyyy);
inline __m256 __VECTORCALL Orient2D_8Sample_v0_v1(const __m128& v0, const __m128& v1, const __m256& x01234567, const __m256& yyyyyyyy)
{
	__m256 r;

	__m128 v1_v0 = _mm_sub_ps(v1, v0);
	__m128 _v1_0_v0_0_ = _mm_shuffle_ps(v1_v0, v1_v0, 0b00000000);
	__m128 _v1_1_v0_1_ = _mm_shuffle_ps(v1_v0, v1_v0, 0b01010101);
	__m256 v1_0_v0_0 = _mm256_setr_m128(_v1_0_v0_0_, _v1_0_v0_0_);
	__m256 v1_1_v0_1 = _mm256_setr_m128(_v1_1_v0_1_, _v1_1_v0_1_);

	__m128 _v0_0_ = _mm_shuffle_ps(v0, v0, 0b00000000);
	__m128 _v0_1_ = _mm_shuffle_ps(v0, v0, 0b01010101);
	__m256 v0_0 = _mm256_setr_m128(_v0_0_, _v0_0_);
	__m256 v0_1 = _mm256_setr_m128(_v0_1_, _v0_1_);
	r = _mm256_sub_ps(_mm256_mul_ps(v1_0_v0_0, _mm256_sub_ps(yyyyyyyy, v0_1)), _mm256_mul_ps(v1_1_v0_1, _mm256_sub_ps(x01234567, v0_0)));

	return r;
}
#endif
#pragma pack(push,1)

struct OCT_BYTES_VECTOR3
{
	WORD		m_wVal[3];
	WORD		m_wExt;

	inline		void		Set(VECTOR3* pv3In);
	inline		void		Get(VECTOR3* pv3Out);
};
#pragma pack(pop)


void OCT_BYTES_VECTOR3::Set(VECTOR3* pv3In)
{
	float*	pfVal = (float*)&pv3In->x;

	int			iExt = 0;

	for (int i = 0; i < 3; i++)
	{
		int		iVal = (int)pfVal[i];
		//		int		iSign = 0x80000000 & iVal;

		m_wVal[i] = (WORD)(iVal & 0x0000ffff);
		iExt |= ((iVal & 0x001f0000) >> 16);
		iExt = iExt << 5;
	}
	iExt = iExt >> 5;
	m_wExt = (WORD)iExt;
}
void OCT_BYTES_VECTOR3::Get(VECTOR3* pv3Out)
{
	float*	pfVal = (float*)&pv3Out->x;


	int		iExt = (int)m_wExt;
	for (int i = 2; i >= 0; i--)
	{
		int		iVal = 0;
		*(WORD*)&iVal = m_wVal[i];
		iVal |= ((iExt & 0x0000001f) << 16);
		iExt = iExt >> 5;

		int		iSign = iVal & 0x00100000;
		iSign = iSign >> 20;
		iSign = (0 - iSign) & 0xffe00000;

		iVal = iVal | iSign;
		pfVal[i] = (float)iVal;
	}

}

#pragma pack(push,1)
struct DWORD_NORMAL_VECTOR3
{
	int				m_iVal;


	inline		void		SetNormal(VECTOR3* pv3In);
	inline		void		GetNormal(VECTOR3* pv3Out);
};
#pragma pack(pop)

inline void DWORD_NORMAL_VECTOR3::SetNormal(VECTOR3* pv3In)
{
	float*	pfVal = (float*)&pv3In->x;

	int		iVal = 0;
	for (int i = 0; i < 3; i++)
	{
		iVal |= (int)(((pfVal[i] + 1.0f) / 2.0f) * 1023.0f);
		m_iVal = iVal;
		iVal = iVal << 10;
	}

}

inline void DWORD_NORMAL_VECTOR3::GetNormal(VECTOR3* pv3Out)
{
	float*	pfVal = (float*)&pv3Out->x;

	int		iVal = m_iVal;
	for (int i = 2; i >= 0; i--)
	{

		pfVal[i] = (((float)(iVal & 0x03ff) / 1023.0f) * 2.0f) - 1.0f;
		iVal = iVal >> 10;
	}
}

struct INT_VECTOR2
{
	int		x;
	int		y;

	inline	BOOL			operator==(const INT_VECTOR2& v) const;
	inline	INT_VECTOR2		operator +(const INT_VECTOR2 &v) const;
	inline	INT_VECTOR2		operator -(const INT_VECTOR2 &v) const;
	inline	INT_VECTOR2		operator *(const int &a) const;
	inline	INT_VECTOR2		operator /(const int &a) const;
	inline	int				operator *(const INT_VECTOR2 &v) const;			// dot.
	inline	void			Set(int in_x, int in_y);

};

inline void INT_VECTOR2::Set(int in_x, int in_y)
{
	x = in_x;
	y = in_y;
}
inline	BOOL INT_VECTOR2::operator==(const INT_VECTOR2& v) const
{
	BOOL	bResult;
	if (this->x == v.x && this->y == v.y)
		bResult = TRUE;
	else
		bResult = FALSE;

	return	bResult;
}



inline INT_VECTOR2 INT_VECTOR2::operator +(const INT_VECTOR2 &v2) const
{
	INT_VECTOR2	result;
	result.x = this->x + v2.x;
	result.y = this->y + v2.y;

	return	result;
}

inline INT_VECTOR2 INT_VECTOR2::operator -(const INT_VECTOR2 &v2) const
{
	INT_VECTOR2		result;
	result.x = this->x - v2.x;
	result.y = this->y - v2.y;

	return	result;
}

inline INT_VECTOR2 INT_VECTOR2::operator *(const int &a) const
{
	INT_VECTOR2		r;
	r.x = this->x * a;
	r.y = this->y * a;

	return	r;
}

inline INT_VECTOR2 INT_VECTOR2::operator /(const int &a) const
{
	INT_VECTOR2		r;
	r.x = this->x / a;
	r.y = this->y / a;

	return	r;
}
// dot.
inline int INT_VECTOR2::operator *(const INT_VECTOR2 &v) const
{
	int		r;
	r = this->x * v.x;
	r += this->y * v.y;

	return		r;
}
/*
int Det(INT_VECTOR2* A,INT_VECTOR2*B)
{
	// A =  | a b |
	//      | c d |
	// det(A) = ad x bc
	int det = (A->x * B->y) - (B->x * A->y);
	return det;
}
*/
struct INT_VECTOR2_FLOAT1 : INT_VECTOR2
{
	float	z;
};

struct INT_VECTOR3
{
	int		x;
	int		y;
	int		z;

	inline	BOOL			operator==(const INT_VECTOR3& v) const;
	inline	INT_VECTOR3		operator +(const INT_VECTOR3 &v) const;
	inline	INT_VECTOR3		operator -(const INT_VECTOR3 &v) const;
	inline	INT_VECTOR3		operator *(const int &a) const;
	inline	INT_VECTOR3		operator /(const int &a) const;
	inline	int				operator *(const INT_VECTOR3 &v) const;			// dot.
	inline	void			Set(int in_x, int in_y, int in_z);

};


inline void INT_VECTOR3::Set(int in_x, int in_y, int in_z)
{
	x = in_x;
	y = in_y;
	z = in_z;
}
inline BOOL INT_VECTOR3::operator==(const INT_VECTOR3& v) const
{
	BOOL	bResult = (this->x == v.x && this->y == v.y && this->z == v.z);
	return	bResult;
}
inline INT_VECTOR3 INT_VECTOR3::operator +(const INT_VECTOR3 &v3) const
{
	INT_VECTOR3	result;
	result.x = this->x + v3.x;
	result.y = this->y + v3.y;
	result.z = this->z + v3.z;

	return	result;
}

inline INT_VECTOR3 INT_VECTOR3::operator -(const INT_VECTOR3 &v3) const
{
	INT_VECTOR3		result;
	result.x = this->x - v3.x;
	result.y = this->y - v3.y;
	result.z = this->z - v3.z;

	return	result;
}

inline INT_VECTOR3 INT_VECTOR3::operator *(const int &a) const
{
	INT_VECTOR3		r;
	r.x = this->x * a;
	r.y = this->y * a;
	r.z = this->z * a;

	return	r;
}

inline INT_VECTOR3 INT_VECTOR3::operator /(const int &a) const
{
	INT_VECTOR3		r;
	r.x = this->x / a;
	r.y = this->y / a;
	r.z = this->z / a;

	return	r;
}
// dot.
inline int INT_VECTOR3::operator *(const INT_VECTOR3 &v) const
{
	int		r;
	r = this->x * v.x;
	r += this->y * v.y;
	r += this->z * v.z;
	return		r;
}

//
struct INT_VECTOR4
{
	int		x;
	int		y;
	int		z;
	int		w;

	inline	BOOL			operator==(const INT_VECTOR4& v) const;
	inline	INT_VECTOR4		operator +(const INT_VECTOR4 &v) const;
	inline	INT_VECTOR4		operator -(const INT_VECTOR4 &v) const;
	inline	INT_VECTOR4		operator *(const int &a) const;
	inline	INT_VECTOR4		operator /(const int &a) const;
	inline	int				operator *(const INT_VECTOR4 &v) const;			// dot.
	inline	void			Set(int in_x, int in_y, int in_z, int in_w);

};


inline void INT_VECTOR4::Set(int in_x, int in_y, int in_z, int in_w)
{
	x = in_x;
	y = in_y;
	z = in_z;
	w = in_w;
}
inline BOOL INT_VECTOR4::operator==(const INT_VECTOR4& v) const
{
	BOOL	bResult = (this->x == v.x && this->y == v.y && this->z == v.z && this->w == v.w);
	return	bResult;
}
inline INT_VECTOR4 INT_VECTOR4::operator +(const INT_VECTOR4 &v3) const
{
	INT_VECTOR4	result;
	result.x = this->x + v3.x;
	result.y = this->y + v3.y;
	result.z = this->z + v3.z;
	result.w = this->z + v3.w;

	return	result;
}

inline INT_VECTOR4 INT_VECTOR4::operator -(const INT_VECTOR4 &v3) const
{
	INT_VECTOR4		result;
	result.x = this->x - v3.x;
	result.y = this->y - v3.y;
	result.z = this->z - v3.z;
	result.w = this->z - v3.w;

	return	result;
}

inline INT_VECTOR4 INT_VECTOR4::operator *(const int &a) const
{
	INT_VECTOR4		r;
	r.x = this->x * a;
	r.y = this->y * a;
	r.z = this->z * a;
	r.w = this->w * a;

	return	r;
}

inline INT_VECTOR4 INT_VECTOR4::operator /(const int &a) const
{
	INT_VECTOR4		r;
	r.x = this->x / a;
	r.y = this->y / a;
	r.z = this->z / a;

	return	r;
}
// dot.
inline int INT_VECTOR4::operator *(const INT_VECTOR4 &v) const
{
	int		r;
	r = this->x * v.x;
	r += this->y * v.y;
	r += this->z * v.z;
	r += this->w * v.w;
	return		r;
}
//
inline void	SET_VECTOR3(VECTOR3* pv3, float fVal)
{
	pv3->x = fVal;
	pv3->y = fVal;
	pv3->z = fVal;
}

inline void VECTOR3_ADD_VECTOR3(VECTOR3* pv3Result, const VECTOR3* pv3Arg1, const VECTOR3* pv3Arg2)
{
	pv3Result->x = pv3Arg1->x + pv3Arg2->x;
	pv3Result->y = pv3Arg1->y + pv3Arg2->y;
	pv3Result->z = pv3Arg1->z + pv3Arg2->z;


}
inline void VECTOR3_SUB_VECTOR3(VECTOR3* pv3Result, const VECTOR3* pv3Arg1, const VECTOR3* pv3Arg2)
{
	pv3Result->x = pv3Arg1->x - pv3Arg2->x;
	pv3Result->y = pv3Arg1->y - pv3Arg2->y;
	pv3Result->z = pv3Arg1->z - pv3Arg2->z;
}
inline void	VECTOR3_MUL_VECTOR3(VECTOR3* pv3Result, const VECTOR3* pv3Arg1, const VECTOR3* pv3Arg2)
{
	pv3Result->x = pv3Arg1->x * pv3Arg2->x;
	pv3Result->y = pv3Arg1->y * pv3Arg2->y;
	pv3Result->z = pv3Arg1->z * pv3Arg2->z;
}
inline void VECTOR3_DIV_VECTOR3(VECTOR3* pv3Result, const VECTOR3* pv3Arg1, const VECTOR3* pv3Arg2)
{
	pv3Result->x = pv3Arg1->x / pv3Arg2->x;
	pv3Result->y = pv3Arg1->y / pv3Arg2->y;
	pv3Result->z = pv3Arg1->z / pv3Arg2->z;
}

inline void VECTOR3_ADDEQU_VECTOR3(VECTOR3* pv3Result, const VECTOR3* pv3Arg1)
{
	pv3Result->x += pv3Arg1->x;
	pv3Result->y += pv3Arg1->y;
	pv3Result->z += pv3Arg1->z;
}
inline void VECTOR3_SUBEQU_VECTOR3(VECTOR3* pv3Result, const VECTOR3* pv3Arg1)
{
	pv3Result->x -= pv3Arg1->x;
	pv3Result->y -= pv3Arg1->y;
	pv3Result->z -= pv3Arg1->z;
}
inline void VECTOR3_MULEQU_VECTOR3(VECTOR3* pv3Result, const VECTOR3* pv3Arg1)
{
	pv3Result->x *= pv3Arg1->x;
	pv3Result->y *= pv3Arg1->y;
	pv3Result->z *= pv3Arg1->z;
}
inline void VECTOR3_DIVEQU_VECTOR3(VECTOR3* pv3Result, const VECTOR3* pv3Arg1)
{
	pv3Result->x /= pv3Arg1->x;
	pv3Result->y /= pv3Arg1->y;
	pv3Result->z /= pv3Arg1->z;
}

inline void	VECTOR3_ADDEQU_FLOAT(VECTOR3* pv3Result, float fVal)
{
	pv3Result->x += fVal;
	pv3Result->y += fVal;
	pv3Result->z += fVal;

}
inline void VECTOR3_SUBEQU_FLOAT(VECTOR3* pv3Result, float fVal)
{
	pv3Result->x -= fVal;
	pv3Result->y -= fVal;
	pv3Result->z -= fVal;
}
inline void VECTOR3_MULEQU_FLOAT(VECTOR3* pv3Result, float fVal)
{
	pv3Result->x *= fVal;
	pv3Result->y *= fVal;
	pv3Result->z *= fVal;
}
inline void	VECTOR3_DIVEQU_FLOAT(VECTOR3* pv3Result, float fVal)
{
	pv3Result->x /= fVal;
	pv3Result->y /= fVal;
	pv3Result->z /= fVal;
}

inline void VECTOR3_ADD_FLOAT(VECTOR3* pv3Result, const VECTOR3* pv3Arg1, float fVal)
{
	pv3Result->x = pv3Arg1->x + fVal;
	pv3Result->y = pv3Arg1->y + fVal;
	pv3Result->z = pv3Arg1->z + fVal;


}
inline void VECTOR3_SUB_FLOAT(VECTOR3* pv3Result, const VECTOR3* pv3Arg1, float fVal)
{
	pv3Result->x = pv3Arg1->x - fVal;
	pv3Result->y = pv3Arg1->y - fVal;
	pv3Result->z = pv3Arg1->z - fVal;
}
inline void VECTOR3_MUL_FLOAT(VECTOR3* pv3Result, const VECTOR3* pv3Arg1, float fVal)
{
	pv3Result->x = pv3Arg1->x * fVal;
	pv3Result->y = pv3Arg1->y * fVal;
	pv3Result->z = pv3Arg1->z * fVal;
}
inline void	VECTOR3_DIV_FLOAT(VECTOR3* pv3Result, const VECTOR3* pv3Arg1, float fVal)
{
	pv3Result->x = pv3Arg1->x / fVal;
	pv3Result->y = pv3Arg1->y / fVal;
	pv3Result->z = pv3Arg1->z / fVal;
}
inline float DotProduct(const VECTOR3* pv3_0, const VECTOR3* pv3_1)
{
	float result;

	result = pv3_0->x * pv3_1->x + pv3_0->y * pv3_1->y + pv3_0->z * pv3_1->z;


	return result;
}


#ifndef DEF_FLOAT3
#define DEF_FLOAT3

struct Float3
{
	float	x;
	float	y;
	float	z;

	inline int	IsZero()
	{
		int result = (x == 0.0f) & (y == 0.0f) & (z == 0.0f);
		return result;
	}

	inline void set(float in_x, float in_y, float in_z)
	{
		x = in_x;
		y = in_y;
		z = in_z;
	}
	inline Float3 operator +(const Float3 &v3) const
	{
		Float3	result;
		result.x = this->x + v3.x;
		result.y = this->y + v3.y;
		result.z = this->z + v3.z;
		return	result;
	}

	inline Float3 operator -(const Float3 &v3) const
	{
		Float3		result;
		result.x = this->x - v3.x;
		result.y = this->y - v3.y;
		result.z = this->z - v3.z;
		return	result;
	}

	inline Float3 operator *(const float f) const
	{
		Float3		r;
		r.x = this->x * f;
		r.y = this->y * f;
		r.z = this->z * f;
		return	r;
	}

	inline Float3 operator /(const float f) const
	{
		Float3		r;
		r.x = this->x / f;
		r.y = this->y / f;
		r.z = this->z / f;
		return	r;
	}
	inline void operator +=(const Float3 &v3)
	{
		this->x += v3.x;
		this->y += v3.y;
		this->z += v3.z;
	}

	inline void	operator -=(const Float3 &v3)
	{
		this->x -= v3.x;
		this->y -= v3.y;
		this->z -= v3.z;
	}

	inline void	operator *=(const float	f)
	{
		this->x *= f;
		this->y *= f;
		this->z *= f;
	}

	inline void	operator /=(const float	f)
	{
		this->x /= f;
		this->y /= f;
		this->z /= f;
	}

};
#endif
typedef unsigned short HALF;

struct HALF3
{
	HALF	x;
	HALF	y;
	HALF	z;
};

#pragma pack(push,1)
struct HALF3_U
{
	HALF	x;
	HALF	y;
	HALF	z;
};
#pragma pack(pop)

inline unsigned int halfToFloatI(HALF y)
{
	int s = (y >> 15) & 0x00000001;                            // sign
	int e = (y >> 10) & 0x0000001f;                            // exponent
	int f = y & 0x000003ff;                            // fraction

	// need to handle 7c00 INF and fc00 -INF?
	if (e == 0)
	{
		// need to handle +-0 case f==0 or f=0x8000?
		if (f == 0)                                            // Plus or minus zero
			return s << 31;
		else
		{                                                 // Denormalized number -- renormalize it
			while (!(f & 0x00000400))
			{
				f <<= 1;
				e -= 1;
			}
			e += 1;
			f &= ~0x00000400;
		}
	}
	else if (e == 31)
	{
		if (f == 0)                                             // Inf
			return (s << 31) | 0x7f800000;
		else                                                    // NaN
			return (s << 31) | 0x7f800000 | (f << 13);
	}

	e = e + (127 - 15);
	f = f << 13;

	return ((s << 31) | (e << 23) | f);
}

inline HALF floatToHalfI(unsigned int i)
{
	int s = (i >> 16) & 0x00008000;                 // sign
	int e = ((i >> 23) & 0x000000ff) - (127 - 15);	// exponent
	int f = i & 0x007fffff;					// fraction

	// need to handle NaNs and Inf?
	if (e <= 0)
	{
		if (e < -10)
		{
			if (s)                                              // handle -0.0
				return 0x8000;
			else
				return 0;
		}
		f = (f | 0x00800000) >> (1 - e);
		return s | (f >> 13);
	}
	else if (e == 0xff - (127 - 15))
	{
		if (f == 0)                                             // Inf
			return s | 0x7c00;
		else
		{                                                  // NAN
			f >>= 13;
			return s | 0x7c00 | f | (f == 0);
		}
	}
	else
	{
		if (e > 30)                                             // Overflow
			return s | 0x7c00;

		return s | (e << 10) | (f >> 13);
	}
}

inline HALF FloatToHALF(float f)
{
	HALF	h = floatToHalfI(*(unsigned int*)&f);
	return h;

}
inline float HALFToFloat(HALF h)
{
	float f;
	*(unsigned int*)&f = halfToFloatI(h);

	return f;
}
inline HALF3 FloatToHALF(Float3& f)
{
	HALF3	h;
	h.x = floatToHalfI(*(unsigned int*)&f.x);
	h.y = floatToHalfI(*(unsigned int*)&f.y);
	h.z = floatToHalfI(*(unsigned int*)&f.z);

	return h;
}
inline Float3 HALFToFloat(HALF3 h)
{
	Float3	f;
	*(unsigned int*)&f.x = halfToFloatI(h.x);
	*(unsigned int*)&f.y = halfToFloatI(h.y);
	*(unsigned int*)&f.z = halfToFloatI(h.z);

	return f;
}
inline float	GetBrightness(float r, float g, float b) { return (r * 0.2125f + g * 0.7154f + b * 0.0721f); }

typedef unsigned short  Float12;

inline Float12 FloatToFloat12(float fValue)
{
	unsigned int iValue = *(int*)&fValue;

	// exponent | fraction
	//  4 bits  | 8 bits
	int s = (iValue >> 16) & 0x00008000;                 // sign

	if (s)
	{
		__debugbreak();
	}

	int e = ((iValue >> 23) & 0x000000ff);

	if (e <= 0)
		return 0;

	e = e - 127 + 7;		// exponent

	if (e <= 0)
	{
		return 0;
	}
	unsigned int f = (iValue & 0x007fffff) >> 15;					// fraction
	if (e > 0x0000000f)
	{
		// 지수부가 4비트 범위를 넘어가면 최대값으로처리
		e = 0x0000000f;
		f = 0x000000ff;
	}

	return ((e & 0x0000000f) << 8) | f;

}
inline float Float12ToFloat(Float12 f12Value)
{
	// exponent | fraction
	//  4 bits  | 8 bits

	int e = ((f12Value >> 8) & 0x0000000f);
	if (e <= 0)
		return 0.0f;

	e = e - 7 + 127;
	int f = (f12Value & 0x000000ff) << 15;				// fraction

	unsigned int i = ((e << 23) | f);
	return *(float*)&i;
}

struct FLOAT3_12BITS
{
	static const unsigned __int64 MASK_36_BITS = 0x0000000fffffffffull;
protected:
	unsigned __int64 Data;
	void Set(float x, float y, float z)
	{
		unsigned __int64 x_f12 = FloatToFloat12(x);
		unsigned __int64 y_f12 = FloatToFloat12(y);
		unsigned __int64 z_f12 = FloatToFloat12(z);
		Data = (Data & (~MASK_36_BITS)) | (((z_f12 << 24) | (y_f12 << 12) | x_f12) & MASK_36_BITS);
	}
	void Get(float* pfOutX, float* pfOutY, float* pfOutZ) const
	{
		Float12 x_f12 = (Float12)((Data & 0x0000000000000fffull));
		Float12 y_f12 = (Float12)((Data & 0x0000000000fff000ull) >> 12);
		Float12 z_f12 = (Float12)((Data & 0x0000000fff000000ull) >> 24);
		*pfOutX = Float12ToFloat(x_f12);
		*pfOutY = Float12ToFloat(y_f12);
		*pfOutZ = Float12ToFloat(z_f12);
	}
};

inline void MakeAABB(VECTOR3* pv3OutMin, VECTOR3* pv3OutMax, const VECTOR3* pv3VertexList, DWORD dwVertexNum)
{
	VECTOR3	v3Min = { 999999.0f, 999999.0f, 999999.0f };
	VECTOR3	v3Max = { -999999.0f, -999999.0f, -999999.0f };

	for (DWORD i = 0; i < dwVertexNum; i++)
	{
		v3Min.x = min(v3Min.x, pv3VertexList[i].x);
		v3Min.y = min(v3Min.y, pv3VertexList[i].y);
		v3Min.z = min(v3Min.z, pv3VertexList[i].z);

		v3Max.x = max(v3Max.x, pv3VertexList[i].x);
		v3Max.y = max(v3Max.y, pv3VertexList[i].y);
		v3Max.z = max(v3Max.z, pv3VertexList[i].z);
	}
	*pv3OutMin = v3Min;
	*pv3OutMax = v3Max;
}
inline void MakeAABBWithStride(VECTOR3* pv3OutMin, VECTOR3* pv3OutMax, const char* pv3VertexList, DWORD dwStride, DWORD dwVertexNum)
{
	VECTOR3	v3Min = { 999999.0f, 999999.0f, 999999.0f };
	VECTOR3	v3Max = { -999999.0f, -999999.0f, -999999.0f };

	for (DWORD i = 0; i < dwVertexNum; i++)
	{
		VECTOR3*	pv3Vertex = (VECTOR3*)pv3VertexList;
		v3Min.x = min(v3Min.x, pv3Vertex->x);
		v3Min.y = min(v3Min.y, pv3Vertex->y);
		v3Min.z = min(v3Min.z, pv3Vertex->z);

		v3Max.x = max(v3Max.x, pv3Vertex->x);
		v3Max.y = max(v3Max.y, pv3Vertex->y);
		v3Max.z = max(v3Max.z, pv3Vertex->z);
		pv3VertexList += dwStride;
	}
	*pv3OutMin = v3Min;
	*pv3OutMax = v3Max;
}

inline void MakeBoxWithAABB(VECTOR3* pv3VertexList, const VECTOR3* pv3Min, const VECTOR3* pv3Max)
{
	VECTOR3*	v = pv3VertexList;
	float	min_x = pv3Min->x;
	float	min_y = pv3Min->y;
	float	min_z = pv3Min->z;

	float	max_x = pv3Max->x;
	float	max_y = pv3Max->y;
	float	max_z = pv3Max->z;

	v[0].x = min_x;
	v[0].y = max_y;
	v[0].z = max_z;

	v[1].x = min_x;
	v[1].y = min_y;
	v[1].z = max_z;

	v[2].x = max_x;
	v[2].y = min_y;
	v[2].z = max_z;

	v[3].x = max_x;
	v[3].y = max_y;
	v[3].z = max_z;

	v[4].x = min_x;
	v[4].y = max_y;
	v[4].z = min_z;

	v[5].x = min_x;
	v[5].y = min_y;
	v[5].z = min_z;

	v[6].x = max_x;
	v[6].y = min_y;
	v[6].z = min_z;

	v[7].x = max_x;
	v[7].y = max_y;
	v[7].z = min_z;
}

inline float SnapFloat(float value, float fUnit)
{
	if (value < 0.0f)
		fUnit *= -1.0f;

	float r = (float)((int)(value / fUnit + 0.5f) * fUnit);
	return r;
}
inline int SnapInt(int iValue, int iUnit)
{
	int	iValuePostive = iValue;
	int iSign = 1;

	if (iValue < 0)
	{
		iValuePostive *= -1;
		iSign = -1;
	}

	// 반올림
	iValuePostive = (int)((float)iValuePostive / (float)iUnit + 0.5f) * iUnit;
	return (iValuePostive * iSign);
}
inline void INL_CrossProduct(VECTOR3* r, const VECTOR3* a, const VECTOR3* b)
{
	r->x = a->y * b->z - a->z * b->y;
	r->y = a->z * b->x - a->x * b->z;
	r->z = a->x * b->y - a->y * b->x;
}

inline float INL_VECTOR3Length(const VECTOR3* v)
{
	float	r = (float)sqrtf(v->x * v->x + v->y * v->y + v->z * v->z);
	return r;
}

inline void INL_Normalize(VECTOR3* n, const VECTOR3* v)
{
	VECTOR3	r = { 0.0f,0.0f,0.0f };
	float len = INL_VECTOR3Length(v);

	if (len != 0.0f)
	{
		r.x = v->x / len;
		r.y = v->y / len;
		r.z = v->z / len;
	}
	*n = r;
}

inline void INL_CalcNormal(VECTOR3* n, const VECTOR3* pTriPoint)
{
	VECTOR3	u = pTriPoint[1] - pTriPoint[0];
	VECTOR3	v = pTriPoint[2] - pTriPoint[0];

	VECTOR3	r;
	INL_CrossProduct(&r, &u, &v);
	INL_Normalize(n, &r);
}
inline float INL_CalcAngleNormalizedVector(const VECTOR3* pv3N_0, const VECTOR3* pv3N_1)
{
	float	cos_angle = DotProduct(pv3N_0, pv3N_1);
	cos_angle = min(cos_angle, 1.0f);
	cos_angle = max(cos_angle, -1.0f);

	float	ang = acosf(cos_angle);
	return ang;
}


inline void INL_CreateVertexListWithBox(VECTOR3* pv3OutArray, const VECTOR3* pv3Oct)
{
	BYTE		bIndex[36] =
	{
		0,1,2,
		0,2,3,

		4,6,5,
		4,7,6,

		0,4,1,
		4,5,1,

		2,7,3,
		7,2,6,

		0,3,7,
		0,7,4,

		1,6,2,
		5,6,1
	};
	for (DWORD i = 0; i < 36; i++)
	{
		*pv3OutArray = pv3Oct[bIndex[i]];
		pv3OutArray++;
	}
}
inline void INL_CreateVertexListWithBoxFilpped(VECTOR3* pv3OutArray, const VECTOR3* pv3Oct)
{
	BYTE		bIndex[36] =
	{
		0,2,1,
		0,3,2,

		4,5,6,
		4,6,7,

		0,1,4,
		4,1,5,

		2,3,7,
		7,6,2,

		0,7,3,
		0,4,7,

		1,2,6,
		5,1,6
	};
	for (DWORD i = 0; i < 36; i++)
	{
		*pv3OutArray = pv3Oct[bIndex[i]];
		pv3OutArray++;
	}
}

inline void INL_CreateVertexListWithBox(__m128* pOutArray36, const VECTOR3* pv3Oct)
{
	BYTE		bIndex[36] =
	{
		0,1,2,
		0,2,3,

		4,6,5,
		4,7,6,

		0,4,1,
		4,5,1,

		2,7,3,
		7,2,6,

		0,3,7,
		0,7,4,

		1,6,2,
		5,6,1
	};
	for (DWORD i = 0; i < 36; i++)
	{
		*(VECTOR3*)&pOutArray36->m128_f32[0] = pv3Oct[bIndex[i]];
		pOutArray36->m128_f32[3] = 1.0f;
		pOutArray36++;
	}
}

inline void INL_CreateBoxWithAABB_M128(__m128* pOutArray8, const VECTOR3* pv3Min, const VECTOR3* pv3Max)
{
	float	min_x = pv3Min->x;
	float	min_y = pv3Min->y;
	float	min_z = pv3Min->z;

	float	max_x = pv3Max->x;
	float	max_y = pv3Max->y;
	float	max_z = pv3Max->z;


	pOutArray8[0].m128_f32[0] = min_x;
	pOutArray8[0].m128_f32[1] = max_y;
	pOutArray8[0].m128_f32[2] = max_z;
	pOutArray8[0].m128_f32[3] = 1;

	pOutArray8[1].m128_f32[0] = min_x;
	pOutArray8[1].m128_f32[1] = min_y;
	pOutArray8[1].m128_f32[2] = max_z;
	pOutArray8[1].m128_f32[3] = 1;

	pOutArray8[2].m128_f32[0] = max_x;
	pOutArray8[2].m128_f32[1] = min_y;
	pOutArray8[2].m128_f32[2] = max_z;
	pOutArray8[2].m128_f32[3] = 1;

	pOutArray8[3].m128_f32[0] = max_x;
	pOutArray8[3].m128_f32[1] = max_y;
	pOutArray8[3].m128_f32[2] = max_z;
	pOutArray8[3].m128_f32[3] = 1;

	pOutArray8[4].m128_f32[0] = min_x;
	pOutArray8[4].m128_f32[1] = max_y;
	pOutArray8[4].m128_f32[2] = min_z;
	pOutArray8[4].m128_f32[3] = 1;

	pOutArray8[5].m128_f32[0] = min_x;
	pOutArray8[5].m128_f32[1] = min_y;
	pOutArray8[5].m128_f32[2] = min_z;
	pOutArray8[5].m128_f32[3] = 1;

	pOutArray8[6].m128_f32[0] = max_x;
	pOutArray8[6].m128_f32[1] = min_y;
	pOutArray8[6].m128_f32[2] = min_z;
	pOutArray8[6].m128_f32[3] = 1;

	pOutArray8[7].m128_f32[0] = max_x;
	pOutArray8[7].m128_f32[1] = max_y;
	pOutArray8[7].m128_f32[2] = min_z;
	pOutArray8[7].m128_f32[3] = 1;
}

#if defined(_USE_NEON)
inline float32x4_t __VECTORCALL Transpose(const float32x4_t& m0, const float32x4_t& m1, const float32x4_t& m2, const float32x4_t& m3, int index)
{
	float32x4_t m_T;
	m_T.n128_f32[0] = m0.n128_f32[index];
	m_T.n128_f32[1] = m1.n128_f32[index];
	m_T.n128_f32[2] = m2.n128_f32[index];
	m_T.n128_f32[3] = m3.n128_f32[index];
	return m_T;
}
#else
inline __m128 __VECTORCALL Transpose(const __m128& m0, const  __m128& m1, const  __m128 &m2, __m128 m3, int index)
{
	__m128 m_T;
	m_T.m128_f32[0] = m0.m128_f32[index];
	m_T.m128_f32[1] = m1.m128_f32[index];
	m_T.m128_f32[2] = m2.m128_f32[index];
	m_T.m128_f32[3] = m3.m128_f32[index];
	return m_T;
}
#endif

#endif	// VH_PLUGIN
