/*******************************************************************************
	GAppSettings																<br />
	View/change server settings													<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GAppSettings.uc,v 1.3 2004/04/14 13:39:10 elmuerte Exp $ -->
*******************************************************************************/
class GAppSettings extends UnGatewayApplication;

/** PlayInfo, UnGatewayClient association */
struct PIListEntry
{
	var PlayInfo PI;
	var UnGatewayClient client;
};
/** PlayInfo instance for each client */
var protected array<PIListEntry> PIList;

var localized string msgCategories, msgSetListUsage, msgSettingSaved,
	msgInvalidValue, msgUnknownSetting, msgNotEditing, msgSaved, msgSaveFailed,
	msgChangedAborted, msgUnauthorizedSetting, msgSettingPrivs, msgTrueOrFalse,
	msgMinMax, msgMaxLength, msgInvalidEditClass, msgAlreadyEditing, msgEditUsage,
	msgNoSettings, msgEditing;

function bool ExecCmd(UnGatewayClient client, array<string> cmd)
{
	local string command;
	command = cmd[0];
	cmd.remove(0, 1);
	switch (command)
	{
		case Commands[0].Name: execSet(client, cmd); return true;
		case Commands[1].Name: execEdit(client, cmd); return true;
		case Commands[2].Name: execSavesettings(client, cmd); return true;
		case Commands[3].Name: execCancelsettings(client, cmd); return true;
	}
	return false;
}

/** return the PlayInfo instance this client is enditing */
function PlayInfo GetPI(UnGatewayClient client, optional bool bDontCreate, optional string editclass)
{
	local PlayInfo newPI;
	local array<class<Info> > InfoClasses;
	local int i;
	local mutator m;

	for (i = 0; i < PIList.length; i++)
	{
		if (PIList[i].client == client) return PIList[i].PI;
	}
	if (bDontCreate) return none;

	newPI = new class'PlayInfo';
	if (editclass == "")
	{
		InfoClasses[0] = Level.Game.Class;
	}
	else {
		InfoClasses[0] = class<Info>(DynamicLoadObject(editclass, class'Class', true));
		if (InfoClasses[0] == none)
		{
			client.outputError(repl(msgInvalidEditClass, "%s", editclass));
			return none;
		}
	}
	if (class<GameInfo>(InfoClasses[0]) != none)
	{
		if (Level.Game.AccessControl != None) InfoClasses[1] = Level.Game.AccessControl.Class;
		m = Level.Game.BaseMutator;
		while (m != none)
		{
			InfoClasses[InfoClasses.length] = m.Class;
			m = m.NextMutator;
		}
	}
	newPI.Init(InfoClasses);
	PIList.length = PIList.Length+1;
	PIList[PIList.length-1].client = client;
	PIList[PIList.length-1].PI = newPI;
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
		client.output(msgCategories);
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
			client.outputError(msgSetListUsage);
			return;
		}
		PI.Sort(4);
		for (i = 1; i < cmd.length; i++)
		{
			for (j = 0; j < PI.Settings.Length; j++)
			{
				if (!class'wString'.static.MaskedCompare(PI.Settings[j].Grouping, cmd[i])) continue;
				showSetting(client, PI.Settings[j]);
			}
		}
	}
	else if (cmd.length >= 2)
	{
		i = PI.FindIndex(cmd[0]);
		if (i > -1)
		{
			if (!Auth.HasPermission(client, PI.Settings[i].SecLevel, PI.Settings[i].ExtraPriv))
			{
				client.outputError(msgUnauthorizedSetting);
				return;
			}
			cmd.remove(0, 1);
			cmd[0] = Join(cmd, " ", "\"");
			if (PI.StoreSetting(i, cmd[0]))
			{
				client.output(repl(msgSettingSaved, "%s", PI.Settings[i].Value));
			}
			else client.outputError(repl(msgInvalidValue, "%s", cmd[0]));
		}
		else {
			client.outputError(repl(msgUnknownSetting, "%s", cmd[0]));
		}
	}
	else if (cmd.length == 1)
	{
		i = 0;
		PI.Sort(4);
		for (j = 0; j < PI.Settings.Length; j++)
		{
			if (!class'wString'.static.MaskedCompare(PI.Settings[j].SettingName, cmd[0])) continue;
			i++;
			showSetting(client, PI.Settings[j]);
		}
		if (i == 0) client.outputError(repl(msgUnknownSetting, "%s", cmd[0]));
	}
}

/** show setting details */
protected function showSetting(UnGatewayClient client, out PlayInfo.PlayInfoData PID)
{
	local array<string> data;
	local int i;
	local string tmp;

	client.output(PID.SettingName@"="@PID.Value);
	client.output(PID.DisplayName@"("$PID.Grouping$")", "    ");
	if (PID.Description != "") client.output(PID.Description, "    ");
	split(PID.Data, ";", data);
	switch (PID.RenderType)
	{
		case PIT_Check:		client.output(msgTrueOrFalse, "    ");
							break;
		case PIT_Select:	for (i = 0; i < data.length; i += 2)
							{
								if (tmp != "") tmp = tmp$"; ";
								tmp = tmp$data[i]@"="@data[i+1];
							}
							client.output(tmp, "    ");
							break;
		case PIT_Text:		if ((data.length) > 1 && (data[1] != ""))
							{
								i = InStr(data[1], ":");
								client.output(repl(repl(msgMinMax, "%min", Left(data[1], i)), "%max", Mid(data[1], i+1)), "    ");
							}
							if ((data.length > 0 )&& (data[0] != ""))
							{
								client.output(repl(msgMaxLength, "%max", data[0]), "    ");
							}
							break;
	}
	client.output(repl(repl(msgSettingPrivs, "%level", PID.SecLevel), "%extra", PID.ExtraPriv), "    ");
}

function execSavesettings(UnGatewayClient client, array<string> cmd)
{
	local PlayInfo PI;
	PI = GetPI(client, true);
	if (PI == none)
	{
		client.outputError(msgNotEditing);
	}
	else if (PI.SaveSettings())
	{
		client.outputError(msgSaved);
	}
	else {
		client.outputError(repl(msgSaveFailed, "%s", PI.LastError));
	}
}

function execCancelsettings(UnGatewayClient client, array<string> cmd, optional bool bNoMsg)
{
	local int i;
	for (i = 0; i < PIList.length; i++)
	{
		if (PIList[i].client == client) break;
	}
	if (i == PIList.length)
	{
		if (!bNoMsg) client.outputError(msgNotEditing);
	}
	else {
		PIList.remove(i, 1);
		if (!bNoMsg) client.output(msgChangedAborted);
	}
}

function execEdit(UnGatewayClient client, array<string> cmd)
{
	local PlayInfo PI;
	if (cmd.length == 0 || cmd[0] == "")
	{
		client.outputError(msgEditUsage);
		return;
	}
	PI = GetPI(client, true);
	if (PI != none)
	{
		client.outputError(msgAlreadyEditing);
		return;
	}
 	// TODO: check game type
 	PI = GetPI(client,, cmd[0]);
 	if (PI == none) return;
 	if (PI.Settings.length == 0)
 	{
 		client.outputError(msgNoSettings);
 		execCancelsettings(client, cmd, true);
 	}
 	else client.output(repl(msgEditing, "%s", cmd[0]));
}

defaultproperties
{
	innerCVSversion="$Id: GAppSettings.uc,v 1.3 2004/04/14 13:39:10 elmuerte Exp $"
	Commands[0]=(Name="set",Help="Change or list the settings.ÿWhen called without any arguments it will list all setting groups.ÿYou can use wild cards to match groups or settings.ÿTo list all settings in a group use: set -list <groupname> ...ÿTo list all settings matching a name use: set <match>ÿTo edit a setting use: set <setting> <new value ...>",Permission="Ms")
	Commands[1]=(Name="edit",Help="Change the class to edit.ÿThe class must be a fully qualified name: package.classÿIt's also possible to edit a complete game type. In that case use: -game <name or class of the gametype>ÿUsafe: edit [-game] <class name>",Permission="Ms")
	Commands[2]=(Name="savesettings",Help="Save the settings you've made.ÿSettings are not saved until you execute this command.",Permission="Ms")
	Commands[3]=(Name="cancelsettings",Help="Discard your changes.",Permission="Ms")

	msgCategories="Categories:"
	msgSetListUsage="Usage: set -list <category> ..."
	msgSettingSaved="Setting saved, new value: %s"
	msgInvalidValue="Invalid value: %s"
	msgUnknownSetting="Unknown setting: %s"
	msgNotEditing="You are not editing any settings"
	msgSaved="Changes saved"
	msgSaveFailed="Failed to save changes, error: %s"
	msgChangedAborted="Changes have been discarded"
	msgUnauthorizedSetting="You are not authorized to change this setting"
	msgSettingPrivs="Security level: %level; Additional privileges: %extra"
	msgTrueOrFalse="Use: True or False"
	msgMinMax="Min: %min; Max: %max"
	msgMaxLength="Maximum length: %max"
	msgInvalidEditClass="'%s' is not a valid class to edit. It must be a subclass of 'Info'"
	msgAlreadyEditing="You are already editing, use either 'savesettings' or 'cancelsettings'"
	msgEditUsage="Usage: edit [-gametype] <class name>"
	msgNoSettings="There are no settings to edit"
	msgEditing="Now editing %s"
}
