/*******************************************************************************
	GAppInfo																	<br />
	Shows various information about the current game							<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GAppInfo.uc,v 1.3 2004/04/07 21:16:39 elmuerte Exp $ -->
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
	local int i;
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
		if (intval(cmd[0], i))
		{
			for( C=Level.ControllerList; C!=None; C=C.NextController )
			{
				if (i <= 0) break;
				i--;
			}
		}
		else { // is a player name
			for( C=Level.ControllerList; C!=None; C=C.NextController )
			{
				if (C.PlayerReplicationInfo == none) continue;
				if (C.PlayerReplicationInfo.PlayerName ~= cmd[0]) break;
			}
		}

		if (C == none)
		{
			client.outputError("No player found for:"@cmd[0]); // LOCALIZE
			return;
		}
		client.output(C.PlayerReplicationInfo.PlayerName);
		client.output("    Spectator:"@C.PlayerReplicationInfo.bOnlySpectator); // LOCALIZE
		client.output("    Admin:    "@C.PlayerReplicationInfo.bAdmin); // LOCALIZE
		client.output("    Ping:     "@C.PlayerReplicationInfo.Ping); // LOCALIZE
		client.output("    Class:    "@C.Name); // LOCALIZE
		client.output("    Address:  "@PlayerController(C).GetPlayerNetworkAddress()); // LOCALIZE
		client.output("    Hash:     "@PlayerController(C).GetPlayerIDHash()); // LOCALIZE
	}
}

defaultproperties
{
	innerCVSversion="$Id: GAppInfo.uc,v 1.3 2004/04/07 21:16:39 elmuerte Exp $"
	Commands[0]=(Name="players",Help="Show details about the current players and spectators.|When an ID is provided more details will be shown about this user.|Usage: players [id|name]")
}
