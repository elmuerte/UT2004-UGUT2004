/*******************************************************************************
	GAppSystem																	<br />
	System routines, basic server administration								<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GAppSystem.uc,v 1.6 2004/04/14 15:34:28 elmuerte Exp $ -->
*******************************************************************************/

class GAppSystem extends UnGatewayApplication;

/** delayed shutdown actor, if one is programmed this will be != none */
var DelayedShutdown shutdownTimer;

var localized string msgShutdownUsage, msgNow, msgShutdownRequest, msgShutdownDelay,
	msgNegativeDelay, msgNoPending, msgShutdownAborted, msgServerTravel,
	msgPlayerListHeader, msgSpectator, msgNoPlayerFound, msgPSpectator,
	msgPAdmin, msgPPing, msgPClass, msgPAddress, msgPHash, msgGTTeamGame,
	msgGTMapPrefix, msgGTGroup, msgMPlayers;

var localized array<string> msgGTGroups;

function bool ExecCmd(UnGatewayClient client, array<string> cmd)
{
	local string command;
	command = cmd[0];
	cmd.remove(0, 1);
	switch (command)
	{
		case Commands[0].Name: execShutdown(client, cmd); return true;
		case Commands[1].Name: execAbortshutdown(client, cmd); return true;
		case Commands[2].Name: execServerTravel(client, cmd); return true;
		case Commands[3].Name: execPlayers(client, cmd); return true;
		case Commands[4].Name: execMutators(client, cmd); return true;
		case Commands[5].Name: execGametypes(client, cmd); return true;
		case Commands[6].Name: execMaps(client, cmd); return true;
	}
	return false;
}

/** program a server shutdown */
function execShutdown(UnGatewayClient client, array<string> cmd)
{
	local int delay;
	local string ShutDownMessage;
	if (cmd.length == 0)
	{
		client.output(msgShutdownUsage);
		return;
	}
	if (cmd[0] ~= msgNow) delay = 0;
	else if (!intval(cmd[0], delay))
	{
		client.output(msgShutdownUsage);
		return;
	}
	cmd.remove(0, 1);
 	ShutDownMessage = class'wArray'.static.join(cmd, " ");
 	if (ShutDownMessage == "") ShutDownMessage = repl(msgShutdownRequest, "%s", client.sUsername);
	if (delay == 0)
	{
		Level.Game.Broadcast(client.PlayerController, ShutDownMessage);
		client.output(ShutDownMessage);
		client.OnLogout();
		Level.ConsoleCommand("quit");
	}
	else if (delay > 0)
	{
		Level.Game.Broadcast(client.PlayerController, ShutDownMessage);
		Level.Game.Broadcast(client.PlayerController, repl(msgShutdownDelay, "%s", delay));
		client.output(repl(msgShutdownDelay, "%s", delay));
		shutdownTimer = spawn(class'DelayedShutdown');
		shutdownTimer.setup(delay, ShutDownMessage);
	}
	else {
		client.outputError(msgNegativeDelay);
	}
}

/** abort a pending shutdown */
function execAbortshutdown(UnGatewayClient client, array<string> cmd)
{
	if (shutdownTimer == none) client.output(msgNoPending);
	else {
		shutdownTimer.abort();
		shutdownTimer = none;
		client.output(msgShutdownAborted);
	}
}

/** executes a "servertravel" console command */
function execServerTravel(UnGatewayClient client, array<string> cmd)
{
	if ((cmd.length == 0) || (cmd[0] == ""))
	{
  		cmd[0] = GetURLMap(true);
	}
	client.output(repl(msgServerTravel, "%s", cmd[0]));
	Level.ServerTravel(cmd[0], false);
}

/** show details about the current players and spectators */
function execPlayers(UnGatewayClient client, array<string> cmd)
{
	local Controller C;
	local int i, j, n;
	if ((cmd.length == 0) || (cmd[0] == ""))
	{
		i = 0;
		client.output(msgPlayerListHeader);
		for( C=Level.ControllerList; C!=None; C=C.NextController )
		{
			if (C.PlayerReplicationInfo == none) continue;
			if (C.PlayerReplicationInfo.bBot) continue;
   			client.output(PadRight(i, 2)@C.PlayerReplicationInfo.PlayerName@iif(C.PlayerReplicationInfo.bOnlySpectator, msgSpectator));
			i++;
		}
	}
	else {
		for (j = 0; j < cmd.length; j++)
		{
			n = 0;
			if (intval(cmd[j], i))
			{
				for( C=Level.ControllerList; C!=None; C=C.NextController )
				{
					if (i <= 0)
					{
						n++;
						break;
					}
					i--;
				}
				if (C != none) SendPlayerInfo(client, PlayerController(C));
			}
			else { // is a player name
				for( C=Level.ControllerList; C!=None; C=C.NextController )
				{
					if (C.PlayerReplicationInfo == none) continue;
					if (class'wString'.static.MaskedCompare(C.PlayerReplicationInfo.PlayerName, cmd[j]))
					{
						n++;
						SendPlayerInfo(client, PlayerController(C));
					}
				}
			}
			if (n == 0)
			{
				client.outputError(repl(msgNoPlayerFound, "%s", cmd[j]));
				return;
			}
		}
	}
}

/** send detailed information about a player */
function SendPlayerInfo(UnGatewayClient client, PlayerController PC)
{
	if (PC == none) return;
	client.output(PC.PlayerReplicationInfo.PlayerName);
	client.output(PadLeft(msgPSpectator, 15)@PC.PlayerReplicationInfo.bOnlySpectator, "    ");
	client.output(PadLeft(msgPAdmin, 15)@PC.PlayerReplicationInfo.bAdmin, "    ");
	client.output(PadLeft(msgPPing, 15)@PC.PlayerReplicationInfo.Ping, "    ");
	client.output(PadLeft(msgPClass, 15)@PC.Name, "    ");
	client.output(PadLeft(msgPAddress, 15)@PC.GetPlayerNetworkAddress(), "    ");
	client.output(PadLeft(msgPHash, 15)@PC.GetPlayerIDHash(), "    ");
}

function execMutators(UnGatewayClient client, array<string> cmd)
{
	local array<CacheManager.MutatorRecord> muts;
	local int i,j;

	class'CacheManager'.static.GetMutatorList(muts);
	if (cmd.length == 0 || cmd[0] == "") cmd[0] = "*";
	for (i = 0; i < cmd.length; i++)
	{
		for (j = 0; j < muts.length; j++)
		{
			if (class'wString'.static.MaskedCompare(muts[j].ClassName, cmd[i]))
			{
				client.output(muts[j].ClassName);
				client.output(muts[j].FriendlyName$iif(muts[j].GroupName != ""," ("$muts[j].GroupName$")",""), "    ");
				if (muts[j].Description != "") client.output(muts[j].Description, "    ");
			}
		}
	}
}

function execGametypes(UnGatewayClient client, array<string> cmd)
{
	local array<CacheManager.GameRecord> gts;
	local int i,j;

	class'CacheManager'.static.GetGameTypeList(gts);
	if (cmd.length == 0 || cmd[0] == "") cmd[0] = "*";
	for (i = 0; i < cmd.length; i++)
	{
		for (j = 0; j < gts.length; j++)
		{
			if (class'wString'.static.MaskedCompare(gts[j].ClassName, cmd[0]))
			{
				client.output(gts[j].ClassName);
				client.output(gts[j].GameName, "    ");
				if (gts[j].Description != "") client.output(gts[j].Description, "    ");
				client.output(msgGTMapPrefix@gts[j].MapPrefix, "    ");
				client.output(msgGTTeamGame@gts[j].bTeamGame, "    ");
				client.output(msgGTGroup@msgGTGroups[gts[j].GameTypeGroup], "    ");
			}
		}
	}
}

function execMaps(UnGatewayClient client, array<string> cmd)
{
	local array<CacheManager.MapRecord> mrs;
	local int i,j;

	class'CacheManager'.static.GetMapList(mrs);
	if (cmd.length == 0 || cmd[0] == "") cmd[0] = "*";
	for (i = 0; i < cmd.length; i++)
	{
		for (j = 0; j < mrs.length; j++)
		{
			if (class'wString'.static.MaskedCompare(mrs[j].MapName, cmd[0]))
			{
				client.output(mrs[j].MapName);
				if (mrs[j].FriendlyName != "") client.output(mrs[j].FriendlyName, "    ");
				if (mrs[j].Description != "") client.output(mrs[j].Description, "    ");
				client.output(repl(repl(msgMPlayers, "%min", mrs[j].PlayerCountMin), "%max", mrs[j].PlayerCountMax), "    "); //TODO
				if (mrs[j].ExtraInfo != "") client.output(mrs[j].ExtraInfo, "    ");
			}
		}
	}
}

defaultproperties
{
	innerCVSversion="$Id: GAppSystem.uc,v 1.6 2004/04/14 15:34:28 elmuerte Exp $"
	Commands[0]=(Name="shutdown",Help="Shutdown the server.ÿUse the command abortshutdown to abort the delayed shutdown.ÿUsage: shutdown <delay|now> [message]",Level=255)
	Commands[1]=(Name="abortshutdown",Help="abort the delayed shutdown.",Level=255)
	Commands[2]=(Name="servertravel",Help="Executes a server travel.ÿUse this to change the current map of the server.ÿWhen no url is given the last url will be used.ÿUsage: servertravel [url]",Permission="Mr|Mt|Mm")
	Commands[3]=(Name="players",Help="Show details about the current players and spectators.ÿWhen an ID is provided more details will be shown about this user.ÿUsage: players [id|name] ...",Permission="Xp")
	Commands[4]=(Name="mutators",Help="Show all available mutators.ÿBy default all mutators are listedÿUsage: mutators <match>")
	Commands[5]=(Name="gametypes",Help="Show all available game types.ÿBy default all game types are listedÿUsage: gametypes <match>")
	Commands[6]=(Name="maps",Help="Show all available maps.ÿBy default all maps are listedÿUsage: maps <match>")

	msgShutdownUsage="Usage: shutdown <delay|now> [message]"
	msgNow="now"
	msgShutdownRequest="Server shutdown requested by %s"
	msgShutdownDelay="The server will be shut down in %s seconds"
	msgNegativeDelay="A negative delay is not allowed"
	msgNoPending="No pending shutdown"
	msgShutdownAborted="Shutdown aborted"
	msgServerTravel="Server travel: %s"
	msgPlayerListHeader="ID Name"
	msgSpectator="(spectator)"
	msgNoPlayerFound="No player found for: %s"
	msgPSpectator="Spectator:"
	msgPAdmin="Admin:"
	msgPPing="Ping:"
	msgPClass="Class:"
	msgPAddress="Address:"
	msgPHash"Hash:"
	msgGTTeamGame="Team game:"
	msgGTMapPrefix="Map prefix:"
	msgGTGroup="Group:"
	msgGTGroups[0]="UT2003"
	msgGTGroups[1]="Bonus Pack #1"
	msgGTGroups[2]="UT2004"
	msgGTGroups[3]="Custom"
	msgMPlayers="Player count: %min-%max"
}
