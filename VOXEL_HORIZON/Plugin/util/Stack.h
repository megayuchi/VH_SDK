#pragma once


typedef DWORD_PTR* (__stdcall *STACK_ALLOC_FUNC)(DWORD_PTR dwItemNum);
typedef void(__stdcall *STACK_FREE_FUNC)(DWORD_PTR* pBuffer);


class CStack
{
	DWORD_PTR*			m_pBuffer;
	STACK_ALLOC_FUNC	m_pAllocFunc;
	STACK_FREE_FUNC		m_pFreeFunc;
	DWORD_PTR			m_dwMaxItemNum;
	DWORD_PTR			m_dwItemNum;
	DWORD_PTR			m_dwDefaultAllocNum;
	DWORD_PTR			m_dwPeakItemNum;


	void			ClearMember();
	BOOL			ReAlloc(DWORD_PTR dwAddNum);

public:
	DWORD_PTR		GetItemNum() const { return m_dwItemNum; }
	BOOL			Initialize(DWORD_PTR dwDefaultAllocNum);
	void			Cleanup();
	void			Push(DWORD_PTR dwItem);
	DWORD_PTR		Pop();
	void			PushFlexibleBytes(char* pMem, DWORD_PTR dwSize);
	BOOL			PopFlexibleBytes(char* pMem, DWORD_PTR dwSize);
	BOOL			GetFlexibleBytes(char* pMem, DWORD_PTR dwSize) const;
	DWORD_PTR		GetPeakItemNum() const { return m_dwPeakItemNum; }
	void			SetStackPos(DWORD_PTR dwItemNum);
	void			Empty();
	size_t			GetMemUsage() const;

	CStack();
	~CStack();
};


DWORD_PTR* __stdcall DefaultStackAllocFunc(DWORD_PTR dwItemNum);
void __stdcall DefaultStackFreeFunc(DWORD_PTR* pBuffer);