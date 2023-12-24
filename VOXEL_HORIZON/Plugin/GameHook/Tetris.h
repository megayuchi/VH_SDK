#pragma once

#include "../include/typedef.h"
#include "game_typedef.h"
#include "Util.h"

interface IVHController;
interface IVoxelObjectLiteManager;
class CDisplayPanel;
class CFlightObject;
class CImageData;
class CDDraw;


enum TETRIS_LAYER_INDEX
{
	TETRIS_LAYER_INDEX_OBJECT,
	TETRIS_LAYER_INDEX_BACK,
	TETRIS_LAYER_INDEX_COUNT
};

enum TETRIS_PROCESS_MODE
{
	TETRIS_PROCESS_MODE_MOVING,
	TETRIS_PROCESS_MODE_SHOW_EFFECT_FLASH,
	TETRIS_PROCESS_MODE_SHOW_EFFECT_REMOVE,
	TETRIS_PROCESS_MODE_NOTHING
};


const DWORD FRAME_WIDTH = 16;
const DWORD FRAME_HEIGHT = 24;

struct BLOCK_TEMPLATE
{
	const BYTE* pShapeData;
	int iWidth;
	int iHeight;
};


const DWORD TETRIS_BLOCK_TYPE_COUNT = 5;
const DWORD TETRIS_BLOCK_TRANFORM_TYPE_COUNT = 4;

struct BLOCK_OBJECT
{
	INT_VECTOR2	ivPos{};
	const BYTE*		pShapeData;

	int iWidth;
	int iHeight;
	UINT BlockType;
	UINT TranformType;
	ULONGLONG LastMoveDownTick;
	ULONGLONG LastMoveDownForcedTick;
};
class CTetris
{
	
	IVHController* m_pVHController = nullptr;
	CDisplayPanel*	m_pDisplayPanel = nullptr;
	WCHAR	m_wchPluginPath[_MAX_PATH] = {};
	DWORD m_dwGameFPS = 60;
	DWORD m_dwCurFPS = 0;
	//float m_fTicksPerGameFrame = 16.6f;
	float m_fTicksPerGameFrame = 250.0f;
	ULONGLONG m_PrvGameFrameTick = 0;
	LARGE_INTEGER	m_PrvCounter = {};
	
	TETRIS_PROCESS_MODE	m_CurMode = TETRIS_PROCESS_MODE_MOVING;
	BOOL	m_bUseMultipleLayers = FALSE;
	
	BYTE*	m_pFrameBuffer = nullptr;
	int		m_iFrameWidth = FRAME_WIDTH;
	int		m_iFrameHeight = FRAME_HEIGHT;

	BLOCK_OBJECT*	m_pCurObj = nullptr;
	int m_piCompltedLineIndexList[FRAME_HEIGHT];
	int m_iCompletedCount = 0;
	DWORD m_dwEffectProcessCount = 0;
	ULONGLONG m_BeginEffectTick = 0;
	BOOL m_bKeyDown_Up = FALSE;
	BOOL m_bKeyDown_Down = FALSE;
	BOOL m_bKeyDown_Left = FALSE;
	BOOL m_bKeyDown_Right = FALSE;
	BOOL m_bPause = FALSE;

	void			InitFrame(BYTE* pBuffer, int iWidth, int iHeight);
	BLOCK_OBJECT*	CreateBlockObject(UINT BlockType);
	void	MergeObject(BLOCK_OBJECT** ppInOutObj);
	BOOL	IsCanMove(BLOCK_OBJECT* pObj, int iMoveX, int iMoveY);
	BOOL	IsCanTransform(BLOCK_OBJECT* pObj, UINT TransformType);
	BOOL	IsCanExist(const BYTE* pData, const INT_VECTOR2* pivPos, int iWidth, int iHeight);

	// control game status

	void OnGameFrame(ULONGLONG CurTick);

	BOOL UpdateObjPos(ULONGLONG CurTick, BOOL* pbOutMerged);

	// display
	void DrawScore(int x, int y);
	void DrawScene();
	void DrawObjBoard(DWORD dwLayerIndex);

	// keyboard input
	
	int CheckCompletedLines(int* piOutBuffer, int iMaxBufferCount);
	void ProcessCompletedLines(const int* piCompltedLineIndexList, int iCompletedCount);
	void RemoveCompletedLines(const int* piCompltedLineIndexList, int iCompletedCount);
	void CompactMergedBlocks(const int* piCompltedLineIndexList, int iCompletedCount);
	void CompactMergedBlocks(int iLineIndex);

	void EnableMultipleLayresMode(BOOL bSwitch);
	BOOL IsMultipleLayersMode() const { return m_bUseMultipleLayers; }

	void ChangeShape();
	BOOL CreateDisplayPanel(UINT Width, UINT Height, DWORD dwLayerCount);
	void CleanupDisplayPanel();
	void Cleanup();
public:

	BOOL Initialize(IVHController* pVHController, const WCHAR* wchPluginPath);
	BOOL OnPreConsoleCommand(const WCHAR* wchCmd, DWORD dwCmdLen);
	BOOL OnKeyDown(UINT nChar);
	BOOL OnKeyUp(UINT nChar);
	void OnUpdateWindowSize();
	void OnUpdateWindowPos();
	void Process();
	void OnDeleteVoxelObject(IVoxelObjectLite* pVoxelObj);
	BOOL IsGamePaused() const { return m_bPause; }

	CTetris();
	~CTetris();
};
