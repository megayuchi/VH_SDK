#pragma once

#include <intrin.h>

inline unsigned long BTCalcSize(unsigned long max_index)
{
	unsigned long quad_size = (max_index / 32) + ((max_index % 32) != 0);
	return quad_size * 4;

}

// thread unsafe
inline void BTSetBit(unsigned long* pBits, unsigned long index)
{
	unsigned long dword_index = index >> 5;
	unsigned long bit_index = index - (dword_index << 5);

	unsigned long	bit_mask = 1 << bit_index;

	pBits[dword_index] |= bit_mask;
}
inline void BTSet(unsigned long* pBits, unsigned long index, unsigned long value)
{
	unsigned long dword_index = index >> 5;
	unsigned long bit_index = index - (dword_index << 5);

	unsigned long	bit_mask = 1 << bit_index;

	pBits[dword_index] = (pBits[dword_index] & (~bit_mask)) | (value << bit_index);
}

// thread unsafe
inline unsigned long BTGet(const unsigned long* pBits, unsigned long index)
{
	unsigned long dword_index = index >> 5;
	unsigned long bit_index = index - (dword_index << 5);

	unsigned long	bit_mask = 1 << bit_index;
	unsigned long	value = pBits[dword_index] & bit_mask;


	value = value >> bit_index;

	return value;

}
// thread unsafe
inline void BTClearBit(unsigned long* pBits, unsigned long index)
{
	unsigned long dword_index = index >> 5;
	unsigned long bit_index = index - (dword_index << 5);

	unsigned long	bit_mask = 1 << bit_index;

	pBits[dword_index] &= (~bit_mask);
}

// thread safe
inline void BTSetBitAtomic(unsigned long* pBits, unsigned long index)
{
	unsigned long dword_index = index >> 5;
	unsigned long bit_index = index - (dword_index << 5);

	unsigned long	bit_mask = 1 << bit_index;

	//pBits[dword_index] |= bit_mask;
	_InterlockedOr((long*)&pBits[dword_index], bit_mask);

}
// thread safe
// 기존의 비트값을 get함과 동시에 bit을 set한다.
inline unsigned long BTGetAndSetBitAtomic(unsigned long* pBits, unsigned long index)
{
	unsigned long dword_index = index >> 5;
	unsigned long bit_index = index - (dword_index << 5);

	unsigned long	bit_mask = 1 << bit_index;
	//unsigned long	value = pBits[dword_index] & bit_mask;
	unsigned long	old_value = _InterlockedOr((long*)&pBits[dword_index], bit_mask);
	unsigned long	value = old_value & bit_mask;
	value = value >> bit_index;

	return value;

}
/*
inline unsigned long BTGetAtomic(unsigned long* pBits,unsigned long index)
{
	unsigned long dword_index = index >> 5;
	unsigned long bit_index = index - (dword_index<<5);

	unsigned long	bit_mask = 1<<bit_index;
	//unsigned long	value = pBits[dword_index] & bit_mask;
	unsigned long	value = _InterlockedOr(pBits+dword_index,0);
	value = value & bit_mask;

	value = value >> bit_index;

	return value;

}


// thread safe
inline void BTClearBitAtomic(unsigned long* pBits,unsigned long index)
{
	unsigned long dword_index = index >> 5;
	unsigned long bit_index = index - (dword_index<<5);

	unsigned long	bit_mask = 1<<bit_index;

	//pBits[dword_index] &= (~bit_mask);
	_InterlockedAnd(&pBits[dword_index],(~bit_mask));
}
*/


inline void BTOr(unsigned long* pOutBits, unsigned long* pBitsSrc0, unsigned long* pBitsSrc1, unsigned long max_bit_count)
{
	unsigned long	quad_count = (max_bit_count >> 5);
	for (unsigned long i = 0; i < quad_count; i++)
	{
		*pOutBits = *pBitsSrc0 | *pBitsSrc1;
		pBitsSrc0++;
		pBitsSrc1++;
		pOutBits++;
	}
	unsigned long bit_count = max_bit_count - (quad_count << 5);
	if (bit_count)
	{
		unsigned long mask = 0;
		for (unsigned long i = 0; i < bit_count; i++)
		{
			mask |= (1 << i);
		}
		*pOutBits = (*pOutBits & (~mask)) | ((*pBitsSrc0 | *pBitsSrc1) & mask);
	}
}
inline int BTCmp(const unsigned long* pBitsSrc0, const unsigned long* pBitsSrc1, unsigned long max_bit_count)
{
	int result = -1;

	{
		unsigned long	quad_count = (max_bit_count >> 5);
		for (unsigned long i = 0; i < quad_count; i++)
		{
			if (*pBitsSrc0 != *pBitsSrc1)
				goto lb_return;

			pBitsSrc0++;
			pBitsSrc1++;
		}
		unsigned long bit_count = max_bit_count - (quad_count << 5);
		if (bit_count)
		{
			for (unsigned long i = 0; i < bit_count; i++)
			{
				unsigned long bit_mask = (1 << i);
				if ((*pBitsSrc0 & bit_mask) != (*pBitsSrc1 & bit_mask))
					goto lb_return;
			}
		}
		result = 0;
	}
lb_return:
	return result;
}
inline void BTCpy(unsigned long* pBitsDest, const unsigned long* pBitsSrc, unsigned long max_bit_count)
{
	unsigned long	quad_count = (max_bit_count >> 5);

	if (quad_count)
	{
		memcpy(pBitsDest, pBitsSrc, sizeof(unsigned long)*quad_count);
		pBitsDest += quad_count;
		pBitsSrc += quad_count;
	}
	unsigned long bit_count = max_bit_count - (quad_count << 5);
	if (bit_count)
	{
		unsigned long mask = 0;
		for (unsigned long i = 0; i < bit_count; i++)
		{
			mask |= (1 << i);
		}
		*pBitsDest = (*pBitsDest & (~mask)) | (*pBitsSrc & mask);
	}
}
// thread unsafe
inline void BTClearAll(unsigned long* pBits, unsigned long max_bit_count)
{
	unsigned long	quad_count = (max_bit_count >> 5);
	for (unsigned long i = 0; i < quad_count; i++)
	{
		pBits[i] = 0;
	}
	unsigned long bit_count = max_bit_count - (quad_count << 5);
	if (bit_count)
	{
		unsigned long mask = 0;
		for (unsigned long i = 0; i < bit_count; i++)
		{
			mask |= (1 << i);
		}
		pBits[quad_count] &= (~mask);
	}
}
inline void BTFillAll(unsigned long* pBits, unsigned long max_bit_count)
{
	unsigned long	quad_count = (max_bit_count >> 5);
	for (unsigned long i = 0; i < quad_count; i++)
	{
		pBits[i] = (unsigned long)(-1);
	}
	unsigned long bit_count = max_bit_count - (quad_count << 5);
	if (bit_count)
	{
		unsigned long mask = 0;
		for (unsigned long i = 0; i < bit_count; i++)
		{
			mask |= (1 << i);
		}
		pBits[quad_count] |= (mask);
		
	}
}

inline BOOL BTIsAllZero(const unsigned long* pBits, unsigned long max_bit_count)
{
	BOOL	bResult = FALSE;
	{
		unsigned long	quad_count = (max_bit_count >> 5);

		for (unsigned long i = 0; i < quad_count; i++)
		{
			if (pBits[i] != 0)
				goto lb_return;
		}

		unsigned long bit_count = max_bit_count - (quad_count << 5);
		if (bit_count)
		{
			unsigned long quadBits = pBits[quad_count];
			for (unsigned long i = 0; i < bit_count; i++)
			{
				if (quadBits & (1 << i))
					goto lb_return;
			}
		}

		bResult = TRUE;
	}
lb_return:
	return bResult;
}

inline unsigned long BTGetBitCount(const unsigned long* pBits, unsigned long max_bit_count)
{
	unsigned long	BitCount = 0;

	unsigned long	quad_count = (max_bit_count >> 5);
	quad_count += (0 != (max_bit_count - (quad_count << 5)));

	for (unsigned long i = 0; i < quad_count; i++)
	{
		unsigned long	bit_count_once = max_bit_count;
		if (bit_count_once > 32)
			bit_count_once = 32;

		unsigned long quadBits = pBits[i];
		unsigned long bit_mask = 1;
		for (unsigned long bit_index = 0; bit_index < bit_count_once; bit_index++)
		{
			BitCount += ((quadBits & bit_mask) != 0);

			bit_mask = bit_mask << 1;
		}
		max_bit_count -= bit_count_once;
	}
lb_return:
	return BitCount;
}

inline void BTSetNBitsValue(unsigned long* pBitTable, unsigned long MaxBits, unsigned long index, unsigned long value, unsigned long NBits)
{
	unsigned long n_bits_mask = ((unsigned long)(-1)) >> (32 - NBits);

#ifdef _DEBUG
	if (index + NBits > MaxBits)
		__debugbreak();
#endif
	unsigned long dword_index_first = index >> 5;
	unsigned long dword_index_last = (index + NBits) >> 5;
	unsigned long bit_index = index - (dword_index_first << 5);

	if (dword_index_first == dword_index_last)
	{
		// 경계에 걸치지 않는 경우
		unsigned long	bit_mask = n_bits_mask << bit_index;
		pBitTable[dword_index_first] = (pBitTable[dword_index_first] & (~bit_mask)) | (value << bit_index);
	}
	else
	{
		// 경계에 걸치는 경우
		// 64 bits 단위로 써넣는다.
		if (dword_index_last != dword_index_first + 1)
		{
			__debugbreak();
		}
		unsigned __int64	bit_mask64 = (unsigned __int64)n_bits_mask << bit_index;
		unsigned __int64*	pBits64 = (unsigned __int64*)(pBitTable + dword_index_first);
		unsigned __int64	value64 = (unsigned __int64)value;

		*pBits64 = (*pBits64 & (~bit_mask64)) | (value64 << bit_index);
	}
}
inline unsigned long BTGetNBitsValue(const unsigned long* pBitTable, unsigned long MaxBits, unsigned long index, unsigned long NBits)
{
	unsigned long n_bits_mask = ((unsigned long)(-1)) >> (32 - NBits);
#ifdef _DEBUG
	if (index + NBits > MaxBits)
		__debugbreak();
#endif
	unsigned long	value;

	unsigned long dword_index_first = index >> 5;
	unsigned long dword_index_last = (index + NBits) >> 5;
	unsigned long bit_index = index - (dword_index_first << 5);

	if (dword_index_first == dword_index_last)
	{
		// 경계에 걸치지 않는 경우
		unsigned long bit_mask = n_bits_mask << bit_index;
		value = (pBitTable[dword_index_first] & bit_mask) >> bit_index;
	}
	else
	{
		// 경계에 걸치는 경우
		if (dword_index_last != dword_index_first + 1)
		{
			__debugbreak();
		}
		// 64 bits 단위로 읽는다.
		unsigned __int64	bit_mask64 = (unsigned __int64)n_bits_mask << bit_index;
		unsigned __int64*	pBits64 = (unsigned __int64*)(pBitTable + dword_index_first);
		unsigned __int64	value64 = *pBits64 & (unsigned __int64)bit_mask64;
		value = (unsigned long)(value64 >> bit_index);
	}
	return value;
}
