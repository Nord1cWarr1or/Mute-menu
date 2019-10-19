/* Thanks to w0w (Telegram: @twisterniq) for base of this plugin */

#include <amxmodx>
#include <amxmisc>
#include <reapi>

new const PLUGIN_VERSION[]	= "1.1.2";

#pragma semicolon 1

new g_iCvarPause;
new g_iCvarOnPage;

new g_iMenuPlayers[MAX_PLAYERS + 1][MAX_PLAYERS], g_iMenuPosition[MAX_PLAYERS + 1];
new bool:g_bMute[MAX_PLAYERS + 1][MAX_PLAYERS + 1];
new g_iLastUsed[MAX_PLAYERS + 1];

new g_bitMutedAll;

#define AUTO_CFG	// Comment out if you don't want the plugin config to be created automatically in "configs/plugins"

#define GetCvarDesc(%0) fmt("%L", LANG_SERVER, %0)

#define get_bit(%1,%2) (%1 & (1 << %2))
#define clr_bit(%1,%2) %1 &= ~(1 << %2)
#define toggle_bit(%1,%2) %1 ^= (1 << %2)

public plugin_init()
{
	register_plugin("Mute Menu", PLUGIN_VERSION, "Nordic Warrior");

	register_dictionary("mute_menu.txt");

	register_clcmd("say /mute", "func_MuteMenu");
	register_clcmd("say_team /mute", "func_MuteMenu");
	register_clcmd("say .ьгеу", "func_MuteMenu");
	register_clcmd("say_team .ьгеу", "func_MuteMenu");

	new iKeys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9;

	register_menu("func_MuteMenu", iKeys, "func_MuteMenu_Handler");

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
	for(new i = 1; i <= MaxClients; i++)
	{
		g_bMute[id][i] = false;
		g_bMute[i][id] = get_bit(g_bitMutedAll, i) ? true : false;
	}
	clr_bit(g_bitMutedAll, id);
}

public refwd_CanPlayerHearPlayer_Pre(iReceiver, iSender)
{
	if(g_bMute[iReceiver][iSender])
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
		if(!is_user_connected(i) || is_user_bot(i) || is_user_hltv(i))
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

	new iLen = formatex(szMenu, charsmax(szMenu), "%l \R%d/%d^n^n", "MUTEMENU_MENU_HEAD", iPage + 1, iPagesNum);

	if(get_bit(g_bitMutedAll, id))
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
					iPlayer, g_bMute[iPlayer][id] ? fmt(" %l", "MUTEMENU_MENU_MUTED_YOU") : "", g_bMute[id][iPlayer] ? fmt(" %l", "MUTEMENU_MENU_MUTED") : "");
			}
		}
	}

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r8. \w%l^n", get_bit(g_bitMutedAll, id) ? "MUTEMENU_MENU_UNMUTEALL" : "MUTEMENU_MENU_MUTEALL");
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
			toggle_bit(g_bitMutedAll, id);

			for(new i = 1; i <= MaxClients; i++)
				g_bMute[id][i] = get_bit(g_bitMutedAll, id) ? true : false;

			ClientPrintToAllExcludeOne(id, print_team_red, "%l %l", "MUTEMENU_CHAT_TAG", get_bit(g_bitMutedAll, id) ? "MUTEMENU_CHAT_ALL_MUTEDALL" : "MUTEMENU_CHAT_ALL_UNMUTEDALL", id);
			client_print_color(id, print_team_red, "%l %l", "MUTEMENU_CHAT_TAG", get_bit(g_bitMutedAll, id) ? "MUTEMENU_CHAT_ID_MUTEDALL" : "MUTEMENU_CHAT_ID_UNMUTEDALL");

			g_iLastUsed[id] = get_systime();	
		}
		case 8: func_MuteMenu(id, ++g_iMenuPosition[id]);
		case 9: func_MuteMenu(id, --g_iMenuPosition[id]);
		default:
		{
			new iTarget = g_iMenuPlayers[id][(g_iMenuPosition[id] * g_iCvarOnPage) + iKey];

			if(!is_user_connected(iTarget) || iTarget == id)
				return func_MuteMenu(id, g_iMenuPosition[id]);

			ClientPrintToAllExcludeTwo(id, iTarget, print_team_default, "%l %l", "MUTEMENU_CHAT_TAG", !g_bMute[id][iTarget] ? "MUTEMENU_CHAT_ALL_MUTED" : "MUTEMENU_CHAT_ALL_UNMUTED", id, iTarget);
			
			client_print_color(id, iTarget, "%l %l", "MUTEMENU_CHAT_TAG", !g_bMute[id][iTarget] ? "MUTEMENU_CHAT_ID_MUTED" : "MUTEMENU_CHAT_ID_UNMUTED", iTarget);
			client_print_color(iTarget, id, "%l %l", "MUTEMENU_CHAT_TAG", !g_bMute[id][iTarget] ? "MUTEMENU_CHAT_TARGET_MUTED" : "MUTEMENU_CHAT_TARGET_UNMUTED", id);

			g_bMute[id][iTarget] = !g_bMute[id][iTarget];
			
			g_iLastUsed[id] = get_systime();

			func_MuteMenu(id, g_iMenuPosition[id]);
		}
	}
	return PLUGIN_HANDLED;
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