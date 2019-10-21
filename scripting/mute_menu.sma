/* Thanks to w0w (Telegram: @twisterniq) for base of this plugin */

#include <amxmodx>
#include <amxmisc>
#include <reapi>

new const PLUGIN_VERSION[]	= "1.2.0";

#pragma semicolon 1

#define GetCvarDesc(%0) fmt("%L", LANG_SERVER, %0)

#define GetBit(%1,%2)		(%1 & (1 << %2))
#define SetBit(%1,%2)		%1 |= (1 << (%2 & 31))
#define ClrBit(%1,%2)		%1 &= ~(1 << %2)
#define ToggleBit(%1,%2)	%1 ^= (1 << %2)

#define CheckFlag(%1,%2)	(g_iMutedPlayer[%1] & (1 << %2))	// Thanks to BlackSignature
#define SetFlag(%1,%2)		(g_iMutedPlayer[%1] |= (1 << %2))
#define ClearFlag(%1,%2)	(g_iMutedPlayer[%1] &= ~(1 << %2))
#define ToggleFlag(%1,%2)	(g_iMutedPlayer[%1] ^= (1 << %2))

new g_iCvarPause;
new g_iCvarOnPage;

new g_iMuteMenuId;

new g_iMenuPlayers[MAX_PLAYERS + 1][MAX_PLAYERS];
new g_iMenuPosition[MAX_PLAYERS + 1];
new g_iMutedPlayer[MAX_PLAYERS + 1];
new g_iLastUsed[MAX_PLAYERS + 1];

new g_bitMutedAll;
new g_bitIsUserConnected;

#define AUTO_CFG	// Comment out if you don't want the plugin config to be created automatically in "configs/plugins"

public plugin_init()
{
	register_plugin("Mute Menu", PLUGIN_VERSION, "Nordic Warrior");

	register_dictionary("mute_menu.txt");

	register_clcmd("say /mute", "func_MuteMenu");
	register_clcmd("say_team /mute", "func_MuteMenu");
	register_clcmd("say .ьгеу", "func_MuteMenu");
	register_clcmd("say_team .ьгеу", "func_MuteMenu");

	register_menucmd(
		.menuid = g_iMuteMenuId = register_menuid("func_MuteMenu"),
		.keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9,
		.function = "func_MuteMenu_Handler");

	bind_pcvar_num(create_cvar("mutemenu_pause", "3",
		.description = GetCvarDesc("MUTEMENU_CVAR_PAUSE")),
		g_iCvarPause);

	bind_pcvar_num(create_cvar("mutemenu_onpage", "7",
		.description = GetCvarDesc("MUTEMENU_CVAR_ONPAGE"),
		.has_min = true, .min_val = 1.0,
		.has_max = true, .max_val = 7.0), 
		g_iCvarOnPage);

	#if defined AUTO_CFG
	AutoExecConfig(true);
	#endif

	RegisterHookChain(RG_CSGameRules_CanPlayerHearPlayer, "refwd_CanPlayerHearPlayer_Pre");
}

public OnConfigsExecuted()
{
	register_cvar("MuteMenu_version", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED);
}

public client_putinserver(id)
{
	SetBit(g_bitIsUserConnected, id);

	for(new i = 1; i <= MaxClients; i++)
	{
		ClearFlag(id, i);
		
		if(GetBit(g_bitMutedAll, i))
		{
			SetFlag(i, id);	
		}
		else ClearFlag(i, id);
	}

	ClrBit(g_bitMutedAll, id);
	RefreshMenu();
}

public client_disconnected(id)
{
	if(!GetBit(g_bitIsUserConnected, id))
		return;

	RequestFrame("RefreshMenu");

	ClrBit(g_bitIsUserConnected, id);
}

public refwd_CanPlayerHearPlayer_Pre(iReceiver, iSender)
{
	if(CheckFlag(iReceiver, iSender))
	{
		SetHookChainReturn(ATYPE_BOOL, false);
		return HC_SUPERCEDE;
	}
	return HC_CONTINUE;
}

public func_MuteMenu(id, iPage)
{
	if(iPage < 0)
		return PLUGIN_HANDLED;

	new iPlayerCount;

	for(new i = 1; i <= MaxClients; i++)
	{
		if(!GetBit(g_bitIsUserConnected, i) || is_user_bot(i) || is_user_hltv(i))
			continue;

		g_iMenuPlayers[id][iPlayerCount++] = i;
	}

	new i = min(iPage * g_iCvarOnPage, iPlayerCount);
	new iStart = i - (i % g_iCvarOnPage);
	new iEnd = min(iStart + g_iCvarOnPage, iPlayerCount);
	g_iMenuPosition[id] = iPage = iStart / g_iCvarOnPage;

	new szMenu[MAX_MENU_LENGTH], iMenuItem;
	new iPagesNum = (iPlayerCount / g_iCvarOnPage + ((iPlayerCount % g_iCvarOnPage) ? 1 : 0));
	new iKeys = MENU_KEY_0;

	SetGlobalTransTarget(id);

	new iLen = formatex(szMenu, charsmax(szMenu), "%l%s^n^n", "MUTEMENU_MENU_HEAD", GetBit(g_bitMutedAll, id) ? "" : fmt(" \R%d/%d", iPage + 1, iPagesNum));

	if(GetBit(g_bitMutedAll, id))
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%l^n", "MUTEMENU_MENU_MUTEDALL");
	}
	else
	{
		for(new a = iStart, iPlayer; a < iEnd; ++a)
		{
			iPlayer = g_iMenuPlayers[id][a];

			if(iPlayer == id)
			{
				++iMenuItem;
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d#. %n^n", iPlayer);
			}
			else
			{
				iKeys |= (1 << iMenuItem);
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%n%s%s^n", ++iMenuItem,
					iPlayer, CheckFlag(iPlayer, id) ? fmt(" %l", "MUTEMENU_MENU_MUTED_YOU") : "", CheckFlag(id, iPlayer) ? fmt(" %l", "MUTEMENU_MENU_MUTED") : "");
			}
		}
	}

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r8. \w%l^n", GetBit(g_bitMutedAll, id) ? "MUTEMENU_MENU_UNMUTEALL" : "MUTEMENU_MENU_MUTEALL");
	iKeys |= MENU_KEY_8;

	if(iEnd != iPlayerCount)
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9. \w%s^n\r0. \w%s", fmt("%l", "MUTEMENU_MENU_MORE"), iPage ? fmt("%l", "MUTEMENU_MENU_BACK") : fmt("%l", "MUTEMENU_MENU_EXIT"));
		iKeys |= MENU_KEY_9;
	}
	else formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w%s", iPage ? fmt("%l", "MUTEMENU_MENU_BACK") : fmt("%l", "MUTEMENU_MENU_EXIT"));

	show_menu(id, iKeys, szMenu, -1, "func_MuteMenu");
	return PLUGIN_HANDLED;
}

public func_MuteMenu_Handler(id, iKey)
{
	if(get_systime() - g_iLastUsed[id] < g_iCvarPause)
	{
		client_print(id, print_center, "*** %l ***", "MUTEMENU_CHAT_PAUSE");
		return func_MuteMenu(id, g_iMenuPosition[id]);
	}

	switch(iKey)
	{
		case 7:
		{
			ToggleBit(g_bitMutedAll, id);

			for(new i = 1; i <= MaxClients; i++)
			{
				if(GetBit(g_bitMutedAll, id))
				{
					SetFlag(id, i);
				}
				else ClearFlag(id, i);
			}

			ClientPrintToAllExcludeOne(id, print_team_red, "%l %l", "MUTEMENU_CHAT_TAG", GetBit(g_bitMutedAll, id) ? "MUTEMENU_CHAT_ALL_MUTEDALL" : "MUTEMENU_CHAT_ALL_UNMUTEDALL", id);
			client_print_color(id, print_team_red, "%l %l", "MUTEMENU_CHAT_TAG", GetBit(g_bitMutedAll, id) ? "MUTEMENU_CHAT_ID_MUTEDALL" : "MUTEMENU_CHAT_ID_UNMUTEDALL");

			g_iLastUsed[id] = get_systime();
			RefreshMenu();
		}
		case 8: func_MuteMenu(id, ++g_iMenuPosition[id]);
		case 9: func_MuteMenu(id, --g_iMenuPosition[id]);
		default:
		{
			new iTarget = g_iMenuPlayers[id][(g_iMenuPosition[id] * g_iCvarOnPage) + iKey];

			if(!GetBit(g_bitIsUserConnected, iTarget) || iTarget == id)
				return func_MuteMenu(id, g_iMenuPosition[id]);

			ClientPrintToAllExcludeTwo(id, iTarget, print_team_default, "%l %l", "MUTEMENU_CHAT_TAG", !CheckFlag(id, iTarget) ? "MUTEMENU_CHAT_ALL_MUTED" : "MUTEMENU_CHAT_ALL_UNMUTED", id, iTarget);
			
			client_print_color(id, iTarget, "%l %l", "MUTEMENU_CHAT_TAG", !CheckFlag(id, iTarget) ? "MUTEMENU_CHAT_ID_MUTED" : "MUTEMENU_CHAT_ID_UNMUTED", iTarget);
			client_print_color(iTarget, id, "%l %l", "MUTEMENU_CHAT_TAG", !CheckFlag(id, iTarget) ? "MUTEMENU_CHAT_TARGET_MUTED" : "MUTEMENU_CHAT_TARGET_UNMUTED", id);

			ToggleFlag(id, iTarget);
			
			g_iLastUsed[id] = get_systime();

			func_MuteMenu(id, g_iMenuPosition[id]);
			RefreshMenu();
		}
	}
	return PLUGIN_HANDLED;
}

public RefreshMenu()	// Thanks to bionext for idea
{
	new iPlayers[MAX_PLAYERS], iPlayersNum;
	get_players_ex(iPlayers, iPlayersNum, GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV);

	for(new i, iPlayer; i < iPlayersNum; i++)
	{
		iPlayer = iPlayers[i];

		if(check_menu_by_menuid(iPlayer, g_iMuteMenuId))
		{
			func_MuteMenu(iPlayer, g_iMenuPosition[iPlayer]);
		}	
	}
}

stock ClientPrintToAllExcludeOne(const iExcludePlayer, const iSender, const szMessage[], any:...)
{
	new szText[192];
	vformat(szText, charsmax(szText), szMessage, 4);

	new iPlayers[MAX_PLAYERS], iNumPlayers;
	get_players(iPlayers, iNumPlayers, "ch");

	for(new i; i < iNumPlayers; i++)
	{
		new iPlayer = iPlayers[i];

		if(iPlayer != iExcludePlayer)
		{
			client_print_color(iPlayer, iSender, szText);
		}
	}
}

stock ClientPrintToAllExcludeTwo(const iExcludePlayer1, const iExcludePlayer2, const iSender, const szMessage[], any:...)
{
	new szText[192];
	vformat(szText, charsmax(szText), szMessage, 5);

	new iPlayers[MAX_PLAYERS], iNumPlayers;
	get_players(iPlayers, iNumPlayers, "ch");

	for(new i; i < iNumPlayers; i++)
	{
		new iPlayer = iPlayers[i];

		if(iPlayer != iExcludePlayer1 && iPlayer != iExcludePlayer2)
		{
			client_print_color(iPlayer, iSender, szText);
		}
	}
}

stock bool:check_menu_by_menuid(const pPlayer, iMenuIdToCheck)	// Thanks to BlackSignature
{
	new iMenuID, iKeys;
	get_user_menu(pPlayer, iMenuID, iKeys);

	return (iMenuID == iMenuIdToCheck);
}