/*******************************************************************************
	GAppSettings																<br />
	View/change server settings													<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GAppSettings.uc,v 1.2 2004/04/13 21:43:52 elmuerte Exp $ -->
*******************************************************************************/
class GAppSettings extends UnGatewayApplication;

function bool ExecCmd(UnGatewayClient client, array<string> cmd)
{
	local string command;
	command = cmd[0];
	cmd.remove(0, 1);
	switch (command)
	{
		case Commands[0].Name: execSet(client, cmd); return true;
	}
	return false;
}

/** return the PlayInfo istance this client is enditing */
function PlayInfo GetPI(UnGatewayClient client)
{
	local PlayInfo newPI;
	local array<class<Info> > InfoClasses;
	// TODO: find old

	newPI = new class'PlayInfo';
	InfoClasses[0] = Level.Game.Class;
	if (Level.Game.AccessControl != None) InfoClasses[1] = Level.Game.AccessControl.Class;
	// TODO: more shit here
	newPI.Init(InfoClasses);
	return newPI;
}

function execSet(UnGatewayClient client, array<string> cmd)
{
	local PlayInfo PI;
	local int i, j;
	local string cat;

	PI = GetPI(client);
	if ((cmd.length == 0) || (cmd[0] == ""))
	{
		PI.Sort(0);
		client.output("Categories:");
		for (i = 0; i < PI.Settings.Length; i++)
		{
			if (PI.Settings[i].Grouping ~= cat) continue;
			cat = PI.Settings[i].Grouping;
			client.output("    "$PI.Settings[i].Grouping);
		}
	}
	else if (cmd[0] ~= "-list")
	{
		if ((cmd.length < 2) || (cmd[1] == ""))
		{
			client.outputError("...");
			return;
		}
		PI.Sort(4);
		for (i = 1; i < cmd.length; i++)
		{
			for (j = 0; j < PI.Settings.Length; j++)
			{
				if (!class'wString'.static.MaskedCompare(PI.Settings[j].Grouping, cmd[i])) continue;
				client.output(PI.Settings[j].SettingName@"="@PI.Settings[j].Value);
				client.output("    "$PI.Settings[j].DisplayName@"("$PI.Settings[j].Grouping$")");
				if (PI.Settings[j].Description != "") client.output("    "$PI.Settings[j].Description);
			}
		}
	}
	else if (cmd.length >= 2)
	{
		i = PI.FindIndex(cmd[0]);
		if (i > -1)
		{
			cmd.remove(0, 1);
			cmd[0] = Join(cmd, " ", "\"");
			if (PI.StoreSetting(i, cmd[0]))
			{
				client.output("Setting saved, new value:"@PI.Settings[i].Value);
			}
			else client.outputError("Invalid value:"$cmd[0]);
		}
		else {
			client.outputError("Unknown setting");
		}
	}
}

defaultproperties
{
	innerCVSversion="$Id: GAppSettings.uc,v 1.2 2004/04/13 21:43:52 elmuerte Exp $"
	Commands[0]=(Name="set",Help="Change settings",Permission="Ms")
	Commands[1]=(Name="editgame",Help="Change the game type to edit",Permission="Ms")
	Commands[2]=(Name="savesettings",Help="Change the game type to edit",Permission="Ms")
	Commands[3]=(Name="cancelsettings",Help="Change the game type to edit",Permission="Ms")
}
