/*******************************************************************************
	GAppSettings																<br />
	View/change server settings													<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GAppSettings.uc,v 1.6 2004/04/15 07:56:49 elmuerte Exp $ -->
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

/** maplist editing entry */
struct MLListEntry
{
	var int GI;
	var int MI;
	var UnGatewayClient client;
};
/** information about the map list being edited by the client */
var protected array<MLListEntry> MLList;

var localized string msgCategories, msgSetListUsage, msgSettingSaved,
	msgInvalidValue, msgUnknownSetting, msgNotEditing, msgSaved, msgSaveFailed,
	msgChangedAborted, msgUnauthorizedSetting, msgSettingPrivs, msgTrueOrFalse,
	msgMinMax, msgMaxLength, msgInvalidEditClass, msgAlreadyEditing, msgEditUsage,
	msgNoSettings, msgEditing, msgMaplistUsage, msgMleditUsage, msgDirtyMapList,
	msgMLSave, msgMLCanceled, msgInvalidMaplist, msgMLCleared, msgMLList,
	msgMaplistListUsage, msgInvalidMaplistID, msgEditingML, msgMLEditingBy,
	msgInvalidGT, msgMaplistactivateUsage, msgActiveList;

var localized string CommandHelp[6];

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
		case Commands[4].Name: execMaplist(client, cmd); return true;
		case Commands[5].Name: execMledit(client, cmd); return true;
	}
	return false;
}

function string GetHelpFor(string Command)
{
	local int i;
	for (i = 0; i < Commands.length; i++)
	{
		if (Commands[i].Name ~= Command) return CommandHelp[i];
	}
	return "";
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

/** get maplist editing information */
function bool GetML(UnGatewayClient client, out int GI, out int MI, optional bool bDontCreate, optional bool bSet)
{
	local int i, j;
	for (i = 0; i < MLList.length; i++)
	{
		if (MLList[i].client == client)
		{
			if (bSet)
			{
				for (j = 0; j < MLList.length; j++)
				{
					if (MLList[j].GI == GI && MLList[j].MI == MI && (MLList[j].client != client))
					{
						client.outputError(repl(msgMLEditingBy, "%s", MLList[j].client.sUsername));
						return false;
					}
				}
				MLList[i].GI = GI;
				MLList[i].MI = MI;
			}
			else {
				GI = MLList[i].GI;
				MI = MLList[i].MI;
			}
			return true;
		}
	}
	if (bDontCreate)
	{
		GI = -1;
		MI = -1;
		return true;
	}
	MLList.length = MLList.Length+1;
	MLList[MLList.length-1].client = client;
	if (bSet)
	{
		if (MLList[j].GI == GI && MLList[j].MI == MI && (MLList[j].client != client))
		{
			client.outputError(repl(msgMLEditingBy, "%s", MLList[j].client.sUsername));
			return false;
		}
		MLList[MLList.length-1].GI = GI;
		MLList[MLList.length-1].MI = MI;
	}
	else {
		MLList[MLList.length-1].GI = Level.Game.MaplistHandler.GetGameIndex(Level.Game.Class);
		MLList[MLList.length-1].MI = Level.Game.MaplistHandler.GetActiveList(MLList[MLList.length-1].GI);
		GI = MLList[MLList.length-1].GI;
		MI = MLList[MLList.length-1].MI;
	}
	return true;
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

function execMaplist(UnGatewayClient client, array<string> cmd)
{
	local array<string> recs;
	local int i, gi, mi;

	if ((cmd.length == 0) || (cmd[0] == ""))
	{
		client.outputError(msgMaplistUsage);
		return;
	}
	if (cmd[0] ~= "list")
	{
		if ((cmd.length == 1) || (cmd[1] == ""))
		{
			cmd[1] = string(Level.Game.Class);
		}
		gi = Level.Game.MaplistHandler.GetGameIndex(cmd[1]);
		if (gi == -1)
		{
			client.outputError(repl(msgInvalidGT, "%s", cmd[1]));
			return;
		}
		recs = Level.Game.MaplistHandler.GetMapListNames(gi);
		client.output(msgMLList);
		for (i = 0; i < recs.length; i++)
		{
			client.output(PadCenter(gi$"-"$i, 5)@recs[i]);
		}
	}
	else if (cmd[0] ~= "edit")
	{
		if ((cmd.length == 0) || (cmd[0] == ""))
		{
			client.outputError(msgMaplistListUsage);
			return;
		}
		GetML(client, gi, mi, true);
		if (gi > -1 && mi > -1)
		{
			if (MapListManager(Level.Game.MaplistHandler).MaplistDirty(gi, mi))
			{
				client.outputError(msgDirtyMapList);
				return;
			}
		}
		i = InStr(cmd[1], "-");
		if (i < 1)
		{
			client.outputError(msgMaplistListUsage);
			return;
		}
		if (!intval(Left(cmd[1], i), gi) || !intval(Mid(cmd[1], i+1), mi))
		{
			client.outputError(msgInvalidMaplistID);
			return;
		}
		if (Level.Game.MaplistHandler.GetMapListTitle(gi, mi) == "")
		{
			client.outputError(msgInvalidMaplistID);
			return;
		}
		GetML(client, gi, mi,, true);
		client.output(repl(msgEditingML, "%s", Level.Game.MaplistHandler.GetMapListTitle(gi, mi)));
	}
	else if (cmd[0] ~= "activate")
	{
		i = InStr(cmd[1], "-");
		if (i < 1)
		{
			client.outputError(msgMaplistactivateUsage);
			return;
		}
		if (!intval(Left(cmd[1], i), gi) || !intval(Mid(cmd[1], i+1), mi))
		{
			client.outputError(msgInvalidMaplistID);
			return;
		}
		if (Level.Game.MaplistHandler.GetMapListTitle(gi, mi) == "")
		{
			client.outputError(msgInvalidMaplistID);
			return;
		}
  		if (Level.Game.MaplistHandler.SetActiveList(gi, mi))
  		{
  			client.output(repl(msgActiveList, "%s", Level.Game.MaplistHandler.GetMapListTitle(gi, mi)));
  		}
  		else client.output(msgInvalidMaplist);
	}
}

function execMledit(UnGatewayClient client, array<string> cmd)
{
	local int i, gi, mi;
	local array<string> recs;

	if ((cmd.length == 0) || (cmd[0] == ""))
	{
		client.outputError(msgMleditUsage);
		return;
	}
	GetML(client, gi, mi);
	if (cmd[0] ~= "list")
	{
		recs = Level.Game.MaplistHandler.GetMapList(gi, mi);
		for (i = 0; i < recs.length; i++)
		{
			client.output(PadRight(i, 3)@recs[i]);
		}
	}
	else if (cmd[0] ~= "save")
	{
		if (Level.Game.MaplistHandler.SaveMapList(GI, MI)) client.output(msgMLSave);
		else client.output(msgInvalidMaplist);
	}
	else if (cmd[0] ~= "abort")
	{
		client.output(msgMLCanceled);
	}
	else if (cmd[0] ~= "clear")
	{
		if (Level.Game.MaplistHandler.ClearList(GI, MI)) client.output(msgMLCleared);
		else client.output(msgInvalidMaplist);
	}
}

defaultproperties
{
	innerCVSversion="$Id: GAppSettings.uc,v 1.6 2004/04/15 07:56:49 elmuerte Exp $"
	Commands[0]=(Name="set",Permission="Ms")
	Commands[1]=(Name="edit",Permission="Ms")
	Commands[2]=(Name="savesettings",Permission="Ms")
	Commands[3]=(Name="cancelsettings",Permission="Ms")
	Commands[4]=(Name="maplist",Permission="Ms")
	Commands[5]=(Name="mledit",Permission="Ms")

	CommandHelp[0]="Change or list the settings.ÿWhen called without any arguments it will list all setting groups.ÿYou can use wild cards to match groups or settings.ÿTo list all settings in a group use: set -list <groupname> ...ÿTo list all settings matching a name use: set <match>ÿTo edit a setting use: set <setting> <new value ...>"
	CommandHelp[1]="Change the class to edit.ÿThe class must be a fully qualified name: package.classÿIt's also possible to edit a complete game type. In that case use: -game <name or class of the gametype>ÿUsafe: edit [-game] <class name>"
	CommandHelp[2]="Save the settings you've made.ÿSettings are not saved until you execute this command."
	CommandHelp[3]="Discard your changes."
	CommandHelp[4]="Manage map lists."
	CommandHelp[5]="Edit a map list."

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
	msgMaplistUsage="Usage: maplist <add|remove|edit|activate|list> ..."
	msgMleditUsage="Usage: mledit <add|remove|move|list|save|abort> ..."
	msgDirtyMapList="The current maplist has not been saved, use either 'mledit save' or 'mledit abort'"
	msgMLSave="Maplist changes saved"
	msgMLCanceled="Maplist changes canceled"
	msgInvalidMaplist="Invalid maplist credentials"
	msgMLCleared="Maplist cleared"
	msgMLList="  ID  Maplist name"
	msgMaplistListUsage="Usage: maplist edit <ID>"
	msgInvalidMaplistID="Invalid maplist ID"
	msgEditingML="Now editing maplist: %s"
	msgMLEditingBy="This map list is being edited by %s"
	msgInvalidGT="'%s' is not a valid gametype class"
	msgMaplistactivateUsage="Usage: maplist activate <ID>"
	msgActiveList="%s is now the active map list"
}
