/*******************************************************************************
	GAppSystem																	<br />
	System routines, basic server administration								<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GAppSystem.uc,v 1.3 2004/04/12 19:32:34 elmuerte Exp $ -->
*******************************************************************************/

class GAppSystem extends UnGatewayApplication;

/** delayed shutdown actor, if one is programmed this will be != none */
var DelayedShutdown shutdownTimer;

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
		client.output("Usage: shutdown <delay|now> [message]"); //LOCALIZE
		return;
	}
	if (cmd[0] ~= "now") delay = 0;
	else if (!intval(cmd[0], delay))
	{
		client.output("Usage: shutdown <delay|now> [message]"); //LOCALIZE
		return;
	}
	cmd.remove(0, 1);
 	ShutDownMessage = class'wArray'.static.join(cmd, " ");
 	if (ShutDownMessage == "") ShutDownMessage = "Server shutdown requested by"@client.sUsername;
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
		Level.Game.Broadcast(client.PlayerController, "The server will be shut down in"@delay@"seconds"); //LOCALIZE
		client.output("Shutdown delayed"@delay@"seconds");
		shutdownTimer = spawn(class'DelayedShutdown');
		shutdownTimer.setup(delay, ShutDownMessage);
	}
	else {
		client.outputError("A negative delay is not allowed");
	}
}

/** abort a pending shutdown */
function execAbortshutdown(UnGatewayClient client, array<string> cmd)
{
	if (shutdownTimer == none) client.output("No pending shutdown");
	else {
		shutdownTimer.abort();
		shutdownTimer = none;
		client.output("Shutdown aborted");
	}
}

/** executes a "servertravel" console command */
function execServerTravel(UnGatewayClient client, array<string> cmd)
{
	if ((cmd.length == 0) || (cmd[0] == ""))
	{
  		client.output(GetURLMap(true));
	}
	client.output("Server travel:"@cmd[0]);
	Level.ServerTravel(cmd[0], false);
}

defaultproperties
{
	innerCVSversion="$Id: GAppSystem.uc,v 1.3 2004/04/12 19:32:34 elmuerte Exp $"
	Commands[0]=(Name="shutdown",Help="Shutdown the server.ÿUse the command abortshutdown to abort the delayed shutdown.ÿUsage: shutdown <delay|now> [message]")
	Commands[1]=(Name="abortshutdown",Help="abort the delayed shutdown.")
	Commands[2]=(Name="servertravel",Help="Executes a server travel.ÿUse this to change the current map of the server.ÿWhen no url is given the last url will be used.ÿUsage: servertravel [url]")
}
