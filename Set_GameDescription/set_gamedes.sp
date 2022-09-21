#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sourcescramble>

#define GAMEDATA	"set_gamedes"
#define CVAR_FLAGS	FCVAR_NOTIFY

MemoryPatch g_mGameDesPatch;	//记录内存修补数据
bool g_bPatchEnable;			//记录内存补丁状态
int g_iOS;						//记录不同系统下的修改位置起始点
char g_cGameDes[128];			//最大128长度, 中文占3字节(UTF8), 全中文最多42(服务器文件函数里写死0x80(128)长度)

public Plugin myinfo =
{
	name = "Set Game Description",
	author = "yuzumi",
	version	= "1.0.1",
	description	= "Change Description at any time!",
	url = "https://github.com/joyrhyme"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion iEngineVersion = GetEngineVersion();
	if(iEngineVersion != Engine_Left4Dead2 && !IsDedicatedServer())
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2 and Dedicated Server!");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	Format(g_cGameDes, sizeof(g_cGameDes), "Left 8 Dead 4");
	InitGameData();
	RegAdminCmd("sm_setgamedes", cmdSetGameDes, ADMFLAG_ROOT, "更改游戏描述 - Change Game Description");
}

void InitGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_mGameDesPatch = MemoryPatch.CreateFromConf(hGameData, "GetGameDescription::GameDescription");
	if (!g_mGameDesPatch.Validate())
		SetFailState("Failed to verify patch: \"GetGameDescription::GameDescription\"");
	else if (g_mGameDesPatch.Enable()) {
		g_iOS = hGameData.GetOffset("OS") ? 4 : 1; //Linux从第5位开始,Win从第2位开始(从0开始算)
		StoreToAddress(g_mGameDesPatch.Address + view_as<Address>(g_iOS), view_as<int>(GetAddressOfString(g_cGameDes)), NumberType_Int32);
		PrintToServer("[%s] Enabled patch: \"GetGameDescription::GameDescription\"", GAMEDATA);
		g_bPatchEnable = true; //上面校验不通过的话应该不会Enable,所以记录这个就行?
	}

	delete hGameData;
}

Action cmdSetGameDes(int client, int args)
{
	switch(args)
	{
		case 0:
		{
			ReplyToCommand(client, "%s", "Usage: sm_setgamedes <DescriptionText>");
			return Plugin_Handled;
		}
		case 1:
		{
			if (g_bPatchEnable)
			{
				GetCmdArg(1, g_cGameDes, sizeof(g_cGameDes));
				ReplyToCommand(client, "%s%s", "Description Set to ", g_cGameDes);
			}
			else
				ReplyToCommand(client, "%s", "GameDesPatch is Disable or InValidate!");
			return Plugin_Handled;
		}
		default:
		{
			ReplyToCommand(client, "%s", "Usage: sm_setgamedes <DescriptionText>");
			return Plugin_Handled;
		}
	}
}