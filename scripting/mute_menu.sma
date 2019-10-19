#include <amxmodx>
#include <reapi>
#include <sky>

#pragma semicolon 1

new const PLUGIN_VERSION[]	= "1.0.1";

new g_pCvarPause;

new g_iMenuPlayers[MAX_PLAYERS + 1][32], g_iMenuPosition[MAX_PLAYERS + 1];
new bool:g_bMute[MAX_PLAYERS + 1][MAX_PLAYERS + 1];
new g_iLastUsed[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin("Mute Menu", PLUGIN_VERSION, "w0w/Nordic Warrior");

	register_dictionary("mute_menu.txt");

	register_clcmd("say /mute", "func_MuteMenu");
	register_clcmd("say_team /mute", "func_MuteMenu");	register_clcmd("say .ьгеу", "func_MuteMenu");
	register_clcmd("say_team .ьгеу", "func_MuteMenu");

	register_menucmd(register_menuid("func_MuteMenu"), (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9), "func_MuteMenu_Handler");

	bind_pcvar_num(register_cvar("mutemenu_pause", "3"), g_pCvarPause);			// Pause for mute/unmute one player. (antiflood)

	RegisterHookChain(RG_CSGameRules_CanPlayerHearPlayer, "refwd_CanPlayerHearPlayer_Pre");
}

public client_putinserver(id)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		g_bMute[id][i] = false;
		g_bMute[i][id] = false;
	}
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

	new i = min(iPage * 8, iPlayerCount);
	new iStart = i - (i % 8);
	new iEnd = min(iStart + 8, iPlayerCount);
	g_iMenuPosition[id] = iPage = iStart / 8;

	new szMenu[MAX_MENU_LENGTH], iMenuItem, iKeys = (1<<9), iPagesNum = (iPlayerCount / 8 + ((iPlayerCount % 8) ? 1 : 0));

	SetGlobalTransTarget(id);

	new iLen = formatex(szMenu, charsmax(szMenu), "%l \R%d/%d^n^n", "MUTEMENU_MENU_HEAD", iPage + 1, iPagesNum);

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
			iKeys |= (1<<iMenuItem);
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%n%s%s^n", ++iMenuItem,
				iPlayer, g_bMute[iPlayer][id] ? fmt(" %l", "MUTEMENU_MENU_MUTED_YOU") : "", g_bMute[id][iPlayer] ? fmt(" %l", "MUTEMENU_MENU_MUTED") : "");
		}
	}

	if(iEnd != iPlayerCount)
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9. \w%s^n\y0. \w%s", fmt("%l", "MUTEMENU_MENU_MORE"), iPage ? fmt("%l", "MUTEMENU_MENU_BACK") : fmt("%l", "MUTEMENU_MENU_EXIT"));
		iKeys |= (1<<8);
	}
	else formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w%s", iPage ? fmt("%l", "MUTEMENU_MENU_BACK") : fmt("%l", "MUTEMENU_MENU_EXIT"));

	show_menu(id, iKeys, szMenu, -1, "func_MuteMenu");
	return PLUGIN_HANDLED;
}

public func_MuteMenu_Handler(id, iKey)
{
	switch(iKey)
	{
		case 8: func_MuteMenu(id, ++g_iMenuPosition[id]);
		case 9: func_MuteMenu(id, --g_iMenuPosition[id]);
		default:
		{
			static iTarget; 

			if(iTarget == g_iMenuPlayers[id][(g_iMenuPosition[id] * 8) + iKey])
			{
				if(get_systime() - g_iLastUsed[id] < g_pCvarPause)
				{
					client_print(id, print_center, "*** %l ***", "MUTEMENU_CHAT_PAUSE");
					return func_MuteMenu(id, g_iMenuPosition[id]);
				}
			}

			iTarget = g_iMenuPlayers[id][(g_iMenuPosition[id] * 8) + iKey];

			if(!is_user_connected(iTarget) || iTarget == id)
				return func_MuteMenu(id, g_iMenuPosition[id]);

			ClientPrintToAllExcludeTwo(id, iTarget, print_team_default, "^3[^4%l^3] %l", "MUTEMENU_CHAT_TAG", !g_bMute[id][iTarget] ? "MUTEMENU_CHAT_ALL_MUTED" : "MUTEMENU_CHAT_ALL_UNMUTED", id, iTarget);
			
			client_print_color(id, iTarget, "^1[^4%l^1] %l", "MUTEMENU_CHAT_TAG", !g_bMute[id][iTarget] ? "MUTEMENU_CHAT_ID_MUTED" : "MUTEMENU_CHAT_ID_UNMUTED", iTarget);
			client_print_color(iTarget, id, "^1[^4%l^1] %l", "MUTEMENU_CHAT_TAG", !g_bMute[id][iTarget] ? "MUTEMENU_CHAT_TARGET_MUTED" : "MUTEMENU_CHAT_TARGET_UNMUTED", id);

			g_bMute[id][iTarget] = !g_bMute[id][iTarget];
			func_MuteMenu(id, g_iMenuPosition[id]);

			g_iLastUsed[id] = get_systime();
		}
	}
	return PLUGIN_HANDLED;
}