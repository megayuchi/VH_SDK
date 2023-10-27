#pragma once

#include "../include/typedef.h"
#include "game_typedef.h"

interface IVHController;
interface IVoxelObjectLiteManager;
class CDisplayPanel;
class CFlightObject;
class CImageData;
class CDDraw;


enum LAYER_INDEX
{
	LAYER_INDEX_OBJECT,
	LAYER_INDEX_BACK_0,
	LAYER_INDEX_BACK_1,
	LAYER_INDEX_COUNT,
	LAYER_INDEX_DEFAULT = LAYER_INDEX_OBJECT
};

class CTestGame
{
	static const DWORD DISPLAY_PANEL_WIDTH = 320;
	static const DWORD DISPLAY_PANEL_HEIGHT = 240;

	IVHController* m_pVHController = nullptr;
	CDisplayPanel*	m_pDisplayPanel = nullptr;
	WCHAR	m_wchPluginPath[_MAX_PATH] = {};
	DWORD m_dwGameFPS = 60;
	DWORD m_dwCurFPS = 0;
	float m_fTicksPerGameFrame = 16.6f;
	ULONGLONG m_PrvGameFrameTick = 0;
	LARGE_INTEGER	m_PrvCounter = {};

	
	CImageData*	m_pPlayerImgData = nullptr;
	CImageData*	m_pAmmoImgData = nullptr;
	CImageData*	m_pEnemyImgData = nullptr;
	CImageData*	m_pMidScrollImageData = nullptr;
	CImageData*	m_pBackImage = nullptr;

	//CTGAImage*	m_pCircleImage = nullptr;
	//CImageData*	m_pCircleImgData = nullptr;
	BOOL	m_bUseMultipleLayers = FALSE;

	int	m_iCursorPosX = 0;
	int m_iCursorPosY = 0;

//	int m_iPlayerPosX = 0;
//	int m_iPlayerPosY = 0;
	int m_iBackImagePosX = 0;
	int m_iBackImagePosY = 0;

	int m_iMidScrollImagePosX = 0;
	int m_iMidScrollImagePosY = 0;

	BOOL m_bKeyDown_Up = FALSE;
	BOOL m_bKeyDown_Down = FALSE;
	BOOL m_bKeyDown_Left = FALSE;
	BOOL m_bKeyDown_Right = FALSE;
	BOOL m_bPause = FALSE;

	CFlightObject*	m_pPlayer = nullptr;
	CFlightObject*	m_ppAmmoList[MAX_AMMO_NUM] = {};
	DWORD m_dwCurAmmoNum = 0;

	CFlightObject*	m_ppEnemyList[MAX_ENEMY_NUM] = {};
	DWORD m_dwCurEnemiesNum = 0;

	// control game status
	void InterpolatePostion(float fAlpha);
	void FixPostionPostion();
	void OnGameFrame(ULONGLONG CurTick);
	void ProcessEnemies();
	void OnHitEnemy(CFlightObject* pEnemy, ULONGLONG CurTick);
	DWORD AddScore(DWORD dwAddval);
	void FillEnemies();
	void MoveEnemies();
	BOOL IsCollisionFlightObjectVsFlightObject(const CFlightObject* pObj0, const CFlightObject* pObj1);
	BOOL ProcessCollisionAmmoVsEnemies(CFlightObject* pAmmo, ULONGLONG CurTick);
	void ProcessCollision(ULONGLONG CurTick);
	void DeleteDestroyedEnemies(ULONGLONG CurTick);
	void ShootFromPlayer();
	void DeleteAllAmmos();
	void DeleteAllEnemies();
	void UpdateBackground();
	void UpdatePlayerPos(int iScreenWidth, int iScreenHeight);

	// display
	void DrawScore(int x, int y);
	void DrawScene();
	void DrawFlightObject(CFlightObject* pFighter, int x, int y, DWORD dwLayerIndex);

	// keyboard input
	

	void EnableMultipleLayresMode(BOOL bSwitch);
	BOOL IsMultipleLayersMode() const { return m_bUseMultipleLayers; }

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

	CTestGame();
	~CTestGame();
};

extern CTestGame* g_pGame;
