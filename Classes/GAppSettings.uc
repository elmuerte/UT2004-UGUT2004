/*******************************************************************************
	GAppSettings																<br />
	View/change server settings													<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GAppSettings.uc,v 1.12 2004/04/23 08:53:51 elmuerte Exp $ -->
*******************************************************************************/
class GAppSettings extends UnGatewayApplication;
/*
	TODO:
	- admin add/remove/edit commands
*/

/** PlayInfo, UnGatewayClient association */
struct PIListEntry
{
	var PlayInfo PI;
	var UnGatewayClient client;
	var bool bChanged;
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
	msgInvalidGT, msgMaplistactivateUsage, msgActiveList, msgMLAdded, msgMLAddUsage,
	msgMLRemoveUsage, msgMLRemoved, msgMLRemoveFailed, msgMLAddFailed, msgMLAddMatchUsage,
	msgMLRemoveMatchUsage, msgInvalidIndex, msgMapMoved, msgMLMoveUsage, msgMapNotInList,
	msgMaplistCreateUsage, msgCreateError, msgMaplistDeleteUsage, msgMaplistRemoved,
	msgMaplistRenameUsage, msgMaplistRenamed, msgPolicyRemoveUsage, msgPolicyAddUsage,
	msgPolicyRemove, msgInvalidPolicy, msgPolicyAdd, msgNoSuchPolicy, msgNoSuchGameType,
	msgMultiAdmin;

var localized string CommandHelp[7];

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
		case Commands[6].Name: execPolicy(client, cmd); return true;
		case Commands[7].Name: execAdmin(client, cmd); return true;
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

function bool CanClose(UnGatewayClient client)
{
	local int GI, MI;
	local bool res;

	res = true;
	if (GetPI(client, true,, GI) != none)
	{
		if (PIList[GI].bChanged)
		{
			client.output("");
			client.outputError(msgAlreadyEditing);
			res = false;
		}
	}
	GetML(client, GI, MI, true);
	if (GI > -1 && MI > -1)
	{
		if (MapListManager(Level.Game.MaplistHandler).MaplistDirty(gi, mi))
		{
			client.output("");
			client.outputError(msgDirtyMapList);
			res = false;
		}
	}
	return super.CanClose(client) && res;
}

/** return the PlayInfo instance this client is enditing */
function PlayInfo GetPI(UnGatewayClient client, optional bool bDontCreate, optional string editclass, optional out int idx)
{
	local PlayInfo newPI;
	local array<class<Info> > InfoClasses;
	local int i;
	local mutator m;

	for (i = 0; i < PIList.length; i++)
	{
		if (PIList[i].client == client)
		{
			idx = i;
			return PIList[i].PI;
		}
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
	if (InfoClasses.length == 0) return none;
	newPI.Init(InfoClasses);
	PIList.length = PIList.Length+1;
	PIList[PIList.length-1].client = client;
	PIList[PIList.length-1].PI = newPI;
	idx = PIList.length-1;
	return newPI;
}

/** get maplist editing information */
function bool GetML(UnGatewayClient client, out int GI, out int MI, optional bool bDontCreate, optional bool bSet)
{
	local int i;
	if (EditedML(client, GI, MI)) return false;
	for (i = 0; i < MLList.length; i++)
	{
		if (MLList[i].client == client)
		{
			if (bSet)
			{
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

/** returns true when the combination of GI\MI is being edited by someone else */
function bool EditedML(UnGatewayClient client, int GI, int MI)
{
	local int j;
	for (j = 0; j < MLList.length; j++)
	{
		if (MLList[j].GI == GI && MLList[j].MI == MI && (MLList[j].client != client))
		{
			client.outputError(repl(msgMLEditingBy, "%s", MLList[j].client.sUsername));
			return true;
		}
	}
	return false;
}

function execSet(UnGatewayClient client, array<string> cmd)
{
	local PlayInfo PI;
	local int i, j, idx;
	local string cat;

	PI = GetPI(client,,,idx);
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
				PIList[idx].bChanged = true;
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
	local array<CacheManager.GameRecord> gra;
	local int i;

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
 	if (cmd[0] ~= "-game")
 	{
 		cmd.remove(0, 1);
 		cmd[0] = join(cmd, " ");
		class'CacheManager'.static.GetGameTypeList(gra);
		for (i = 0; i < gra.length; i++)
		{
			if ((gra[i].GameName ~= cmd[0]) || (gra[i].ClassName ~= cmd[0]) || (gra[i].GameAcronym ~= cmd[0]))
			{
				cmd[0] = gra[i].ClassName;
				break;
			}
		}
		if (i == gra.length)
		{
			client.outputError(repl(msgNoSuchGameType, "%s", cmd[0]));
			return;
		}
 	}
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
	local string tmp;

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
		if ((cmd.length == 1) || (cmd[1] == ""))
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
	else if (cmd[0] ~= "create")
	{
		if (cmd.length < 3 || cmd[1] == "")
		{
			client.outputError(msgMaplistCreateUsage);
			return;
		}
		tmp = cmd[1];
		GI = Level.Game.MaplistHandler.GetGameIndex(tmp);
		if (GI == -1)
		{
			client.outputError(repl(msgInvalidGT, "%s", tmp));
			return;
		}
		cmd.remove(0, 2);
		cmd[0] = join(cmd, " ");
		recs.length = 0; // force default maps
		MI = Level.Game.MaplistHandler.AddList(tmp, cmd[0], recs);
		if (MI > -1)
		{
			client.output(repl(msgActiveList, "%s", Level.Game.MaplistHandler.GetMapListTitle(gi, mi)));
		}
		else client.outputError(msgCreateError);
	}
	else if (cmd[0] ~= "delete")
	{
		if ((cmd.length == 1) || (cmd[1] == ""))
		{
			client.outputError(msgMaplistDeleteUsage);
			return;
		}
		i = InStr(cmd[1], "-");
		if (i < 1)
		{
			client.outputError(msgMaplistDeleteUsage);
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
		if (EditedML(client, GI, MI)) return;
		Level.Game.MaplistHandler.RemoveList(gi, mi);
		client.output(msgMaplistRemoved);
	}
	else if (cmd[0] ~= "rename")
	{
		if ((cmd.length < 3) || (cmd[2] == ""))
		{
			client.outputError(msgMaplistRenameUsage);
			return;
		}
		i = InStr(cmd[1], "-");
		if (i < 1)
		{
			client.outputError(msgMaplistRenameUsage);
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
		cmd.remove(0, 2);
		cmd[0] = join(cmd, " ");
		Level.Game.MaplistHandler.RenameList(gi, mi, cmd[0]);
		client.output(repl(msgMaplistRenamed, "%s", cmd[0]));
	}
}

function execMledit(UnGatewayClient client, array<string> cmd)
{
	local int i, gi, mi;
	local array<string> recs;
	local array<MaplistRecord.MapItem> mlar;
	local string tmp;

	if ((cmd.length == 0) || (cmd[0] == ""))
	{
		client.outputError(msgMleditUsage);
		return;
	}
	GetML(client, gi, mi);
	if (cmd[0] ~= "list")
	{
		recs = Level.Game.MaplistHandler.GetMapList(gi, mi);
		client.output(Level.Game.MaplistHandler.GetMapListTitle(gi, mi));
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
		Level.Game.MaplistHandler.ResetList(GI, MI);
		client.output(msgMLCanceled);
	}
	else if (cmd[0] ~= "clear")
	{
		if (Level.Game.MaplistHandler.ClearList(GI, MI)) client.output(msgMLCleared);
		else client.output(msgInvalidMaplist);
	}
	else if (cmd[0] ~= "available")
	{
		if (MapListManager(Level.Game.MaplistHandler).GetAvailableMaps(gi, mlar))
		{
			for (i = 0; i < mlar.length; i++)
			{
				client.output(mlar[i].MapName);
			}
		}
	}
	else if (cmd[0] ~= "add")
	{
		if (cmd.length == 1)
		{
			client.outputError(msgMLAddUsage);
			return;
		}
		if (cmd[1] ~= "-match")
		{
			if (cmd.length == 2 || cmd[2] == "")
			{
				client.outputError(msgMLAddMatchUsage);
				return;
			}
			tmp = cmd[2];
			cmd.remove(1, cmd.length-1);
			if (MapListManager(Level.Game.MaplistHandler).GetAvailableMaps(gi, mlar))
			{
				for (i = 0; i < mlar.length; i++)
				{
					if (!class'wString'.static.MaskedCompare(mlar[i].MapName, tmp)) continue;
					cmd[i+1] = mlar[i].MapName;
				}
			}
		}
		tmp = Level.Game.MaplistHandler.GetMapListTitle(gi, mi);
		for (i = 1; i < cmd.length; i++)
		{
			if (Level.Game.MaplistHandler.AddMap(GI, MI, cmd[i])) client.output(repl(repl(msgMLAdded, "%map", cmd[i]), "%list", tmp));
			else client.output(repl(msgMLAddFailed, "%s", cmd[i]));
		}
	}
	else if (cmd[0] ~= "remove")
	{
		if (cmd.length == 1)
		{
			client.outputError(msgMLRemoveUsage);
			return;
		}
		if (cmd[1] ~= "-match")
		{
			if (cmd.length == 2 || cmd[2] == "")
			{
				client.outputError(msgMLRemoveMatchUsage);
				return;
			}
			tmp = cmd[2];
			cmd.remove(1, cmd.length-1);
			if (MapListManager(Level.Game.MaplistHandler).GetAvailableMaps(gi, mlar))
			{
				for (i = 0; i < mlar.length; i++)
				{
					if (!class'wString'.static.MaskedCompare(mlar[i].MapName, tmp)) continue;
					cmd[i+1] = mlar[i].MapName;
				}
			}
		}
		tmp = Level.Game.MaplistHandler.GetMapListTitle(gi, mi);
		for (i = 1; i < cmd.length; i++)
		{
			if (Level.Game.MaplistHandler.RemoveMap(GI, MI, cmd[i])) client.output(repl(repl(msgMLRemoved, "%map", cmd[i]), "%list", tmp));
			else client.output(repl(msgMLRemoveFailed, "%s", cmd[i]));
		}
	}
	else if (cmd[0] ~= "move")
	{
		if (cmd.length < 3)
		{
			client.outputError(msgMLMoveUsage);
			return;
		}
		if (Level.Game.MaplistHandler.GetMapIndex(GI, MI, cmd[1]) == -1)
		{
			client.outputError(repl(msgMapNotInList, "%map", cmd[1]));
			return;
		}
		if (Left(cmd[2], 1) == "-")
		{
			i = int(cmd[2]);
		}
		else if (Left(cmd[2], 1) == "+")
		{
			i = int(Mid(cmd[2], 1));
		}
		else {
			if (!intval(cmd[2], i))
			{
				client.outputError(repl(msgInvalidIndex, "%i", cmd[2]));
				return;
			}
			// calculate offset
			i = i - Level.Game.MaplistHandler.GetMapIndex(GI, MI, cmd[1]);
		}
		Level.Game.MaplistHandler.ShiftMap(GI, MI, cmd[1], i);
		client.output(repl(repl(msgMapMoved, "%map", cmd[1]), "%pos", Level.Game.MaplistHandler.GetMapIndex(GI, MI, cmd[1])));
	}
}

function execPolicy(UnGatewayClient client, array<string> cmd)
{
	local int i, n;
	if ((cmd.length == 0) || (cmd[0] == "") || (cmd[0] ~= "list"))
	{
		n = 0;
		for (i = 0; i < Level.Game.AccessControl.IPPolicies.length; i++)
		{
			client.output(PadRight(n++, 3)@Level.Game.AccessControl.IPPolicies[i]);
		}
		for (i = 0; i < Level.Game.AccessControl.BannedIDs.length; i++)
		{
			client.output(PadRight(n++, 3)@Level.Game.AccessControl.BannedIDs[i]);
		}
	}
	else if (cmd[0] ~= "add")
	{
		if ((cmd.length < 2) || (cmd[1] == ""))
		{
			client.outputError(msgPolicyAddUsage);
			return;
		}
		if (isIPPolicy(cmd[1]))
		{
			Level.Game.AccessControl.IPPolicies[Level.Game.AccessControl.IPPolicies.length] = cmd[1];
			client.output(repl(msgPolicyAdd, "%s", cmd[1]));
		}
		else if (isIDPolicy(cmd[1]))
		{
			Level.Game.AccessControl.BannedIDs[Level.Game.AccessControl.BannedIDs.length] = cmd[1];
			cmd.remove(0, 2);
			Level.Game.AccessControl.BannedIDs[Level.Game.AccessControl.BannedIDs.length-1] @= join(cmd, " ");
			client.output(repl(msgPolicyAdd, "%s", Level.Game.AccessControl.BannedIDs[Level.Game.AccessControl.BannedIDs.length-1]));
		}
		else {
			client.outputError(repl(msgInvalidPolicy, "%s", cmd[1]));
			return;
		}
	}
	else if (cmd[0] ~= "remove")
	{
		if ((cmd.length < 2) || (cmd[1] == ""))
		{
			client.outputError(msgPolicyRemoveUsage);
			return;
		}
		if (intval(cmd[1], n)) // is ID
		{
			if (n < Level.Game.AccessControl.IPPolicies.length)
			{
				client.output(repl(msgPolicyRemove, "%s", Level.Game.AccessControl.IPPolicies[n]));
				Level.Game.AccessControl.IPPolicies.remove(n, 1);
			}
			else if (n < Level.Game.AccessControl.BannedIDs.length)
			{
				n -= Level.Game.AccessControl.IPPolicies.length;
				client.output(repl(msgPolicyRemove, "%s", Level.Game.AccessControl.BannedIDs[n]));
				Level.Game.AccessControl.BannedIDs.remove(n, 1);
			}
			else {
				client.outputError(repl(msgInvalidIndex, "%i", n));
			}
		}
		else {
			for (i = 0; i < Level.Game.AccessControl.IPPolicies.length; i++)
			{
				if (Level.Game.AccessControl.IPPolicies[i] ~= cmd[1])
				{
					client.output(repl(msgPolicyRemove, "%s", Level.Game.AccessControl.IPPolicies[i]));
					Level.Game.AccessControl.IPPolicies.remove(i, 1);
					return;
				}
			}
			for (i = 0; i < Level.Game.AccessControl.BannedIDs.length; i++)
			{
				if (Level.Game.AccessControl.BannedIDs[i] ~= cmd[1])
				{
					client.output(repl(msgPolicyRemove, "%s", Level.Game.AccessControl.BannedIDs[i]));
					Level.Game.AccessControl.BannedIDs.remove(i, 1);
					return;
				}
			}
			client.outputError(repl(msgNoSuchPolicy, "%s", cmd[1]));
		}
	}
}

/** returns true when the input is a valid IP policy entry */
static function bool isIPPolicy(string pol)
{
	local string ip;
	if (!divide(pol, ";", pol, ip)) return false;
	return ((pol ~= "ACCEPT") || (pol ~= "DENY")) && (ip != "");
}

/** returns true if the input is a valid CDKey hash */
static function bool isIDPolicy(string pol)
{
	return Len(pol) == 32;
}

function execAdmin(UnGatewayClient client, array<string> cmd)
{
	local int i;
	if (Level.Game.AccessControl.Users == none)
	{
		client.outputError(msgMultiAdmin);
		return;
	}
	if ((cmd.length == 0) || (cmd[0] == "") || (cmd[0] ~= "list"))
	{
		if (!Auth.HasPermission(client,, "Al"))
		{
			client.outputError(msgUnauthorized);
			return;
		}
		for (i = 0; i < Level.Game.AccessControl.Users.Users.length; i++)
		{
			client.output(Level.Game.AccessControl.Users.Users[i].UserName);
			client.output("Privileges:"@Level.Game.AccessControl.Users.Users[i].Privileges, "    ");
			client.output("Merged privileges:"@Level.Game.AccessControl.Users.Users[i].MergedPrivs, "    ");
			client.output("Security level:"@Level.Game.AccessControl.Users.Users[i].MaxSecLevel(), "    ");
		}
	}
}

defaultproperties
{
	innerCVSversion="$Id: GAppSettings.uc,v 1.12 2004/04/23 08:53:51 elmuerte Exp $"
	Commands[0]=(Name="set",Permission="Ms")
	Commands[1]=(Name="edit",Permission="Ms")
	Commands[2]=(Name="savesettings",Permission="Ms")
	Commands[3]=(Name="cancelsettings",Permission="Ms")
	Commands[4]=(Name="maplist",Permission="Ms")
	Commands[5]=(Name="mledit",Permission="Ms")
	Commands[6]=(Name="policy",Permission="Xi")
	Commands[7]=(Name="admin",Permission="A")

	CommandHelp[0]="Change or list the settings.ÿWhen called without any arguments it will list all setting groups.ÿYou can use wild cards to match groups or settings.ÿTo list all settings in a group use: set -list <groupname> ...ÿTo list all settings matching a name use: set <match>ÿTo edit a setting use: set <setting> <new value ...>"
	CommandHelp[1]="Change the class to edit.ÿThe class must be a fully qualified name: package.classÿIt's also possible to edit a complete game type. In that case use: -game <name or class of the gametype>ÿUsage: edit [-game] <class name>"
	CommandHelp[2]="Save the settings you've made.ÿSettings are not saved until you execute this command."
	CommandHelp[3]="Discard any changes made to the current settings."
	CommandHelp[4]="Manage map lists.ÿThis command will allow you to create, delete, rename, list or activate map lists.ÿIt will also allow you to change the maplist that can be edited with 'mledit'.ÿTo list maplists of other game types than the current game type use: maplist list package.gametypeÿUsage: maplist <create|delete|rename|edit|activate|list> ..."
	CommandHelp[5]="Edit a map list.ÿWith the command you can edit the current maplist.ÿUse the 'maplist' command to change the maplist being edited.ÿmledit <add|remove|move|list|save|abort|available> ..."
	CommandHelp[6]="Manage access policies.ÿWithout any arguments the current access policy will be listed.ÿUsage: policy <add|remove> ..."
	CommandHelp[7]="Manage admins.ÿThis command is only available when using the so called xAdmin system.ÿUsage: admin <list|add|remove|edit> ...ÿUsage: admin add <username> <password> <password>ÿUsage: admin remove <username>ÿUsage: admin edit <password|addgroup|delgroup|addpriv|delpriv|setpriv> ..."

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
	msgMaplistUsage="Usage: maplist <create|delete|rename|edit|activate|list> ..."
	msgMleditUsage="Usage: mledit <add|remove|move|list|save|abort|available> ..."
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
	msgMLAddUsage="Usage: mledit add <map> ..."
	msgMLAdded="Added %map to %list"
	msgMLRemoveUsage="Usage: mledit remove <map> ..."
	msgMLRemoved="Removed %map from %list"
	msgMLRemoveFailed="Failed to remove the map %s"
	msgMLAddFailed="Failed to add the map %s"
	msgMLAddMatchUsage="Usage: mledit add -match <mask>"
	msgMLRemoveMatchUsage="Usage: mledit remove -match <mask>"
	msgMLMoveUsage="Usage: mledit move <map> <new position|+offset|-offset>"
	msgMapMoved="Map '%map' moved to position %pos"
	msgInvalidIndex="'%i' is not a valid index"
	msgMapNotInList="'%map' is not in this map list"
	msgMaplistCreateUsage="Usage: maplist create <gametype> <title ...>"
	msgCreateError="Error creating a new maplist"
	msgMaplistDeleteUsage="Usage: maplist delete <ID>"
	msgMaplistRemoved="Maplist removed"
	msgMaplistRenameUsage="Usage: maplist rename <ID> <new name ...>"
	msgMaplistRenamed="Maplist renamed to %s"
	msgPolicyRemoveUsage="Usage: policy remove <id|policy rule>"
	msgPolicyAddUsage="Usage: policy add <policy rule>"
	msgPolicyRemove="Removed policy: %s"
	msgInvalidPolicy="'%s' is neither a valid IP policy nor a valid CDKey hash (GUID)"
	msgPolicyAdd="Added policy: %s"
	msgNoSuchPolicy="No such policy: %s"
	msgNoSuchGameType="No such gametype: %s"
	msgMultiAdmin="No multi admin system has been enabled (xAdmin.AccessControlIni)"
}
