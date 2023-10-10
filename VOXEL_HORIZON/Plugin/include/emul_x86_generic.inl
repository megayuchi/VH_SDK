#pragma once

#ifdef VH_PLUGIN	// VH_PLUGIN

#if defined(_M_ARM64) || defined(_M_ARM64EC)

inline DWORD64 ___rdtsc()
{
	DWORD64 CurClock = _ReadStatusReg(ARM64_PMCCNTR_EL0);
	return CurClock;
}
#endif

#endif	// VH_PLUGIN