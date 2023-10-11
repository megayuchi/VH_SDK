# VH_SDK
This is a repository for VOXEL HORIZON's MOD development.

## VOXEL HORIZON in steam store
- [store](https://store.steampowered.com/app/1221390/VOXEL_HORIZON/)
- [community](https://steamcommunity.com/app/1221390/)

## Requirements
Visual Studio 2022 , Windows 10/11

## How to build the plugin
1. Open 'VH_SDK/VOXEL_HORIZON/Plugin/GameHook/GameHook.sln' in Visual Studio.
2. Modify the code as you want.
3. build the projtect.
4. When you build a plugin project, a .dll file is created in the 'VH_SDK/VOXEL_HORIZON/Plugin/bin' folder.

## How to run the game
1. goto to '/VH_SDK/VOXEL_HORIZON/App/'
2. Enter a command or create a shortcut in the following folder path.
   
   use '/dx11' switch for DirectX 11 Renderer
   **Client_x64_release.exe /p /dx11 /ns**

   use '/dxr' switch for DirectX Raytracing
   **Client_x64_release.exe /p /dxr /ns**

   use '/su' switch To quickly use offline mode
   **Client_x64_release.exe /p /dxr /ns /su**

   use '/steam' switch to login with steam account
   **Client_x64_release.exe /p /dxr /ns /steam**

### How to load the Plugin in game
1. In the game, press the '`' key to open the console.
2. Enter the **load_plugin file's name** in the console. ex) **load_plugin GameHook_x64_debug.dll**
3. To unload the plugin, enter **unload_plugin**

### How to load plugin when the game launched
Use the '/pl' switch to specify the file name of the plugin.
For example, when the plugin file name is **GameHook_x64_debug.dll**  

1. goto to '/VH_SDK/VOXEL_HORIZON/App/'
2. Enter a command or create a shortcut in the following folder path.
   **Client_x64_release.exe /p /dxr /ns /pl GameHook_x64_debug.dll**

## How to debug the plugin
1. Open the Plugin Project in Visual Studio.
2. Project -> Properties -> Debugging -> Command
   'your dev folder'\VH_SDK\VOXEL_HORIZON\App\Client_x64_release.exe
4. Project -> Properties -> Debugging -> Working Directory
   'your dev folder'\VH_SDK\VOXEL_HORIZON\App\
5. Project -> Properties -> Debugging -> Command Arguments
   /p /dxr /ns /su /pl GameHook_x64_release.dll
7. Set a breakpoint at the desired location in the code and press 'F5' key to start debugging.
