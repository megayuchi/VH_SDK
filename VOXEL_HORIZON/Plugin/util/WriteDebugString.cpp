#include "stdafx.h"
#include <stdio.h>
#include "WriteDebugString.h"

void WriteDebugStringW(DEBUG_OUTPUT_TYPE type, const WCHAR* wchFormat, ...)
{
	va_list argptr;
	WCHAR cBuf[2048];

	va_start(argptr, wchFormat);
	vswprintf_s(cBuf, 2048, wchFormat, argptr);
	va_end(argptr);

	switch (type)
	{
		case DEBUG_OUTPUT_TYPE_NULL:
			break;
		case DEBUG_OUTPUT_TYPE_CONSOLE:
			wprintf_s(cBuf);
			break;
		case DEBUG_OUTPUT_TYPE_DEBUG_CONSOLE:
			OutputDebugStringW(cBuf);
			break;
	}
}

void WriteDebugStringA(DEBUG_OUTPUT_TYPE type, const char* szFormat, ...)
{
	va_list argptr;
	char cBuf[2048];

	va_start(argptr, szFormat);
	vsprintf_s(cBuf, 2048, szFormat, argptr);
	va_end(argptr);

	switch (type)
	{
		case DEBUG_OUTPUT_TYPE_NULL:
			break;
		case DEBUG_OUTPUT_TYPE_CONSOLE:
			printf_s(cBuf);
			break;
		case DEBUG_OUTPUT_TYPE_DEBUG_CONSOLE:
			OutputDebugStringA(cBuf);
			break;
	}
}
