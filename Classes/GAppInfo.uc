/*******************************************************************************
	GAppInfo																	<br />
	Shows various information about the current game							<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GAppInfo.uc,v 1.2 2004/04/07 16:37:34 elmuerte Exp $ -->
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
}

defaultproperties
{
	innerCVSversion="$Id: GAppInfo.uc,v 1.2 2004/04/07 16:37:34 elmuerte Exp $"
	Commands[0]=(Name="players",Help="Show details about the current players and spectators")
}
