#include "stdafx.h"
#include <Windows.h>
#include "Stack.h"


CStack::CStack()
{
	ClearMember();
}
DWORD_PTR* __stdcall DefaultStackAllocFunc(DWORD_PTR dwItemNum)
{
	DWORD_PTR*		pNewBuffer = new DWORD_PTR[dwItemNum];
	return pNewBuffer;
}

void __stdcall DefaultStackFreeFunc(DWORD_PTR* pBuffer)
{
	delete[] pBuffer;
}

void CStack::ClearMember()
{
	m_pBuffer = nullptr;
	m_pAllocFunc = nullptr;
	m_pFreeFunc = nullptr;
	m_dwMaxItemNum = 0;
	m_dwItemNum = 0;
	m_dwDefaultAllocNum = 0;
	m_dwPeakItemNum = 0;
}
BOOL CStack::Initialize(DWORD_PTR dwDefaultAllocNum)
{
	m_dwDefaultAllocNum = dwDefaultAllocNum;
	m_pAllocFunc = DefaultStackAllocFunc;
	m_pFreeFunc = DefaultStackFreeFunc;

	return ReAlloc(dwDefaultAllocNum);
}

BOOL CStack::ReAlloc(DWORD_PTR dwAddNum)
{
	// CStack�� �ҽ��ڵ����·� �������ؼ� ����� ��� �ش� DLL,EXE���� �޸𸮸� �Ҵ��ϰ�,
	// GenericLib���� CStack::ReAlloc�Լ��� ȣ��ȴ�.
	// GenericLib�� crt���� �Ҵ��� �޸𸮰� �ƴϹǷ� ũ�����Ѵ�.--;
	// ���� dll�Ǵ�exe�� ������ Stack���� Alloc,Free�� �� �ִ� �Լ��� ��� ������ �ֵ��� �ڵ带 �����ߴ�.

	DWORD_PTR		dwNewMaxNum = m_dwMaxItemNum + dwAddNum;
	//DWORD_PTR*		pNewBuffer = new DWORD_PTR[dwNewMaxNum];
	DWORD_PTR*		pNewBuffer = m_pAllocFunc(dwNewMaxNum);

	if (m_pBuffer)
	{
		memcpy(pNewBuffer, m_pBuffer, sizeof(DWORD_PTR)*m_dwItemNum);
		//delete [] m_pBuffer;
		m_pFreeFunc(m_pBuffer);


	}

	m_pBuffer = pNewBuffer;
	m_dwMaxItemNum = dwNewMaxNum;

	return TRUE;

}
void CStack::Push(DWORD_PTR dwItem)
{
	if (m_dwItemNum >= m_dwMaxItemNum)
		ReAlloc(m_dwDefaultAllocNum);

	m_pBuffer[m_dwItemNum] = dwItem;
	m_dwItemNum++;
	if (m_dwItemNum > m_dwPeakItemNum)
		m_dwPeakItemNum = m_dwItemNum;

}

DWORD_PTR CStack::Pop()
{
	DWORD_PTR	dwResult = (DWORD_PTR)(-1);

	if (!m_dwItemNum)
		goto lb_return;

	m_dwItemNum--;
	dwResult = m_pBuffer[m_dwItemNum];

lb_return:
	return dwResult;
}


void CStack::PushFlexibleBytes(char* pMem, DWORD_PTR dwSize)
{
	DWORD_PTR		dwAddNum = dwSize / sizeof(DWORD_PTR) + ((dwSize % sizeof(DWORD_PTR)) != 0);

	if (m_dwItemNum + dwAddNum > m_dwMaxItemNum)
		ReAlloc(m_dwDefaultAllocNum);

	memcpy(m_pBuffer + m_dwItemNum, pMem, dwSize);
	m_dwItemNum += dwAddNum;

	if (m_dwItemNum > m_dwPeakItemNum)
		m_dwPeakItemNum = m_dwItemNum;
}

BOOL CStack::PopFlexibleBytes(char* pMem, DWORD_PTR dwSize)
{
	BOOL		bResult = FALSE;

	DWORD_PTR		dwSubNum = dwSize / sizeof(DWORD_PTR) + ((dwSize % sizeof(DWORD_PTR)) != 0);

	if ((int)m_dwItemNum - (int)dwSubNum < 0)
		goto lb_return;

	m_dwItemNum -= dwSubNum;
	memcpy(pMem, m_pBuffer + m_dwItemNum, dwSize);

	bResult = TRUE;

lb_return:
	return bResult;

}
BOOL CStack::GetFlexibleBytes(char* pMem, DWORD_PTR dwSize) const
{
	// ���������͸� �������� �ʰ� top�� �ڷḦ �����´�.
	BOOL		bResult = FALSE;

	DWORD_PTR		dwSubNum = dwSize / sizeof(DWORD_PTR) + ((dwSize % sizeof(DWORD_PTR)) != 0);

	int iOffset = (int)m_dwItemNum - (int)dwSubNum;
	if (iOffset < 0)
		goto lb_return;

	memcpy(pMem, m_pBuffer + iOffset, dwSize);

	bResult = TRUE;

lb_return:
	return bResult;

}
void CStack::SetStackPos(DWORD_PTR dwItemNum)
{
	m_dwItemNum = dwItemNum;
}
void CStack::Empty()
{
	m_dwItemNum = 0;
}
size_t CStack::GetMemUsage() const
{
	size_t size = m_dwMaxItemNum * sizeof(DWORD_PTR) + sizeof(CStack);
	return size;
}
void CStack::Cleanup()
{
	if (m_pBuffer)
	{
		delete[] m_pBuffer;
	}
	ClearMember();

}
CStack::~CStack()
{
	Cleanup();
}
