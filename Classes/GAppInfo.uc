/*******************************************************************************
	GAppInfo																	<br />
	Shows various information about the current game							<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GAppInfo.uc,v 1.4 2004/04/08 19:43:26 elmuerte Exp $ -->
*******************************************************************************/
class GAppInfo extends UnGatewayApplication;

function bool ExecCmd(UnGatewayClient client, array<string> cmd)
{
	local string command;
	command = cmd[0];
	cmd.remove(0, 1);
	switch (command)
	{
		case Commands[0].Name: execPlayers(client, cmd); return true;
	}
	return false;
}

/** show details about the current players and spectators */
function execPlayers(UnGatewayClient client, array<string> cmd)
{
	local Controller C;
	local int i, j, n;
	if ((cmd.length == 0) || (cmd[0] == ""))
	{
		i = 0;
		client.output("ID Name"); // LOCALIZE
		for( C=Level.ControllerList; C!=None; C=C.NextController )
		{
			if (C.PlayerReplicationInfo == none) continue;
			if (C.PlayerReplicationInfo.bBot) continue;
   			client.output(PadRight(i, 2)@C.PlayerReplicationInfo.PlayerName@iif(C.PlayerReplicationInfo.bOnlySpectator, "(spectator)")); //LOCALIZE
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
				client.outputError("No player found for:"@cmd[j]); // LOCALIZE
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
	client.output("    Spectator:"@PC.PlayerReplicationInfo.bOnlySpectator); // LOCALIZE
	client.output("    Admin:    "@PC.PlayerReplicationInfo.bAdmin); // LOCALIZE
	client.output("    Ping:     "@PC.PlayerReplicationInfo.Ping); // LOCALIZE
	client.output("    Class:    "@PC.Name); // LOCALIZE
	client.output("    Address:  "@PC.GetPlayerNetworkAddress()); // LOCALIZE
	client.output("    Hash:     "@PC.GetPlayerIDHash()); // LOCALIZE
}

defaultproperties
{
	innerCVSversion="$Id: GAppInfo.uc,v 1.4 2004/04/08 19:43:26 elmuerte Exp $"
	Commands[0]=(Name="players",Help="Show details about the current players and spectators.ÿWhen an ID is provided more details will be shown about this user.ÿUsage: players [id|name] ...")
}
