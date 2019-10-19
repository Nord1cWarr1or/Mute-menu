/* Thx to w0w (Telegram: @twisterniq) for base of this plugin*/

#include <amxmodx>
#include <reapi>
#include <sky>

#pragma semicolon 1

new const PLUGIN_VERSION[]	= "1.1.0";

new g_pCvarPause;

new g_iMenuPlayers[MAX_PLAYERS + 1][MAX_PLAYERS], g_iMenuPosition[MAX_PLAYERS + 1];
new bool:g_bMute[MAX_PLAYERS + 1][MAX_PLAYERS + 1];
new g_iLastUsed[MAX_PLAYERS + 1];
new bool:g_bMutedAll[MAX_PLAYERS + 1];

#define ONPAGE 7

public plugin_init()
{
	register_plugin("Mute Menu", PLUGIN_VERSION, "Nordic Warrior");

	register_dictionary("mute_menu.txt");

	register_clcmd("say /mute", "func_MuteMenu");
	register_clcmd("say_team /mute", "func_MuteMenu");
	register_clcmd("say .ьгеу", "func_MuteMenu");
	register_clcmd("say_team .ьгеу", "func_MuteMenu");

	new iKeys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9;

	register_menucmd(register_menuid("func_MuteMenu"), iKeys, "func_MuteMenu_Handler");

	bind_pcvar_num(register_cvar("mutemenu_pause", "3"), g_pCvarPause);			// Pause for mute/unmute one player. (antiflood)
	//bind_pcvar_num(create_cvar("mutemenu_onpage"))

	RegisterHookChain(RG_CSGameRules_CanPlayerHearPlayer, "refwd_CanPlayerHearPlayer_Pre");
}

public client_putinserver(id)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		g_bMute[id][i] = false;
		g_bMute[i][id] = g_bMutedAll[i] ? true : false;
		log_amx("%i", g_bMute[i][id]);
	}
	g_bMutedAll[id] = false;
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

	new i = min(iPage * ONPAGE, iPlayerCount);
	new iStart = i - (i % ONPAGE);
	new iEnd = min(iStart + ONPAGE, iPlayerCount);
	g_iMenuPosition[id] = iPage = iStart / ONPAGE;

	new szMenu[MAX_MENU_LENGTH], iMenuItem;
	new iPagesNum = (iPlayerCount / ONPAGE + ((iPlayerCount % ONPAGE) ? 1 : 0));
	new iKeys = MENU_KEY_0;

	SetGlobalTransTarget(id);

	new iLen = formatex(szMenu, charsmax(szMenu), "%l \R%d/%d^n^n", "MUTEMENU_MENU_HEAD", iPage + 1, iPagesNum);

	if(g_bMutedAll[id])
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

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r8. \w%l^n", g_bMutedAll[id] ? "MUTEMENU_MENU_UNMUTEALL" : "MUTEMENU_MENU_MUTEALL");
	iKeys |= MENU_KEY_8;

	if(iEnd != iPlayerCount)
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9. \w%s^n\y0. \w%s", fmt("%l", "MUTEMENU_MENU_MORE"), iPage ? fmt("%l", "MUTEMENU_MENU_BACK") : fmt("%l", "MUTEMENU_MENU_EXIT"));
		iKeys |= MENU_KEY_9;
	}
	else formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w%s", iPage ? fmt("%l", "MUTEMENU_MENU_BACK") : fmt("%l", "MUTEMENU_MENU_EXIT"));

	show_menu(id, iKeys, szMenu, -1, "func_MuteMenu");
	return PLUGIN_HANDLED;
}

public func_MuteMenu_Handler(id, iKey)
{
	if(get_systime() - g_iLastUsed[id] < g_pCvarPause)
	{
		client_print(id, print_center, "*** %l ***", "MUTEMENU_CHAT_PAUSE");
		return func_MuteMenu(id, g_iMenuPosition[id]);
	}

	switch(iKey)
	{
		case 7:
		{
			g_bMutedAll[id] = !g_bMutedAll[id];

			for(new i = 1; i <= MaxClients; i++)
				g_bMute[id][i] = g_bMutedAll[id] ? true : false;

			ClientPrintToAllExcludeOne(id, print_team_red, "^1[^4%l^1] %l", "MUTEMENU_CHAT_TAG", g_bMutedAll[id] ? "MUTEMENU_CHAT_ALL_MUTEDALL" : "MUTEMENU_CHAT_ALL_UNMUTEDALL", id);
			client_print_color(id, print_team_red, "^1[^4%l^1] %l", "MUTEMENU_CHAT_TAG", g_bMutedAll[id] ? "MUTEMENU_CHAT_ID_MUTEDALL" : "MUTEMENU_CHAT_ID_UNMUTEDALL");

			g_iLastUsed[id] = get_systime();	
		}
		case 8: func_MuteMenu(id, ++g_iMenuPosition[id]);
		case 9: func_MuteMenu(id, --g_iMenuPosition[id]);
		default:
		{
			new iTarget = g_iMenuPlayers[id][(g_iMenuPosition[id] * ONPAGE) + iKey];

			if(!is_user_connected(iTarget) || iTarget == id)
				return func_MuteMenu(id, g_iMenuPosition[id]);

			ClientPrintToAllExcludeTwo(id, iTarget, print_team_default, "^3[^4%l^3] %l", "MUTEMENU_CHAT_TAG", !g_bMute[id][iTarget] ? "MUTEMENU_CHAT_ALL_MUTED" : "MUTEMENU_CHAT_ALL_UNMUTED", id, iTarget);
			
			client_print_color(id, iTarget, "^1[^4%l^1] %l", "MUTEMENU_CHAT_TAG", !g_bMute[id][iTarget] ? "MUTEMENU_CHAT_ID_MUTED" : "MUTEMENU_CHAT_ID_UNMUTED", iTarget);
			client_print_color(iTarget, id, "^1[^4%l^1] %l", "MUTEMENU_CHAT_TAG", !g_bMute[id][iTarget] ? "MUTEMENU_CHAT_TARGET_MUTED" : "MUTEMENU_CHAT_TARGET_UNMUTED", id);

			g_bMute[id][iTarget] = !g_bMute[id][iTarget];
			
			g_iLastUsed[id] = get_systime();

			func_MuteMenu(id, g_iMenuPosition[id]);
		}
	}
	return PLUGIN_HANDLED;
}