/*******************************************************************************
	GAppSettings																<br />
	View/change server settings													<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GAppSettings.uc,v 1.15 2004/05/01 15:56:05 elmuerte Exp $ -->
*******************************************************************************/
class GAppSettings extends UnGatewayApplication;

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

/** a session struct to keep information during some commands that request information from the client */
struct SessionEntry
{
	/** session entries */
	var array<string> entries;
	var UnGatewayClient client;
};
var protected array<SessionEntry> Sessions;

//!localization
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
	msgMultiAdmin, msgSessionError, msgPasswordPrompt1, msgPasswordPrompt2,
	msgPasswordMatchError, msgPasswordUpdated, msgAdminAddUsage, msgAdminRemoveUsage,
	msgInvalidPassword, msgAdminCreated, msgAdminCreateExists, msgAdminCreateInvalid,
	msgAdminPrivileges, msgAdminMergedPrivileges, msgAdminMaxSecLevel, msgAdminNoSuch,
	msgAdminRemoved, msgAdminEditUsage, msgAdminMaster, msgAdminUsage, msgAdminEditPrivUpdate,
	msgAdminEditAddPriv, msgAdminEditInvalidGroup, msgAdminEditGroupAdded, msgAdminEditAddGroupUsage,
	msgAdminEditDelGroupUsage, msgAdminEditDelGroup, msgAdminEditAddmGroupUsage,
	msgAdminEditDelmGroupUsage, msgAdminLGroups, msgAdminLMGroups, msgGroupUsers,
	msgGroupManagers, msgGroupAddUsage, msgGroupInvalidName, msgGroupExists, msgGroupAdded,
	msgGroupInvalidSecLevel	, msgGroupRemoveUsage, msgGroupDoesNotExists, msgGroupRemoved,
	msgGroupEditUsage	, msgGroupSecLevelUpdate, msgGroupMaster;

var localized string CommandHelp[10];

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
		case Commands[8].Name: execPrivilege(client, cmd); return true;
		case Commands[9].Name: execGroup(client, cmd); return true;
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

/** returns the index in the session list */
function int GetSession(UnGatewayClient client, optional bool bNoCreate)
{
	local int j;
	for (j = 0; j < Sessions.length; j++)
	{
		if (Sessions[j].client == client)
		{
			return j;
		}
	}
	if (bNoCreate) return -1;
	Sessions.length = j+1;
	Sessions[j].client = client;
	return j;
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
	local int i, idx;
	local xAdminUser xau;
	local xAdminGroup xag;
	local xAdminUserList xul;
	local string tmp;

	if (Level.Game.AccessControl.Users == none)
	{
		client.outputError(msgMultiAdmin);
		return;
	}
	if (AccessControlIni(Level.Game.AccessControl) == none)
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
		xau = Level.Game.AccessControl.GetLoggedAdmin(client.PlayerController);
		xul = xau.GetManagedUsers(Level.Game.AccessControl.Groups);
		for (idx = 0; idx < xul.Count(); idx++)
		{
			xau = xul.Get(idx);
			client.output(xau.UserName);
			client.output(msgAdminPrivileges@privilegesToString(xau.Privileges), "    ");
			client.output(msgAdminMergedPrivileges@privilegesToString(xau.MergedPrivs), "    ");
			client.output(msgAdminMaxSecLevel@xau.MaxSecLevel(), "    ");
			client.output(msgAdminMaster@xau.bMasterAdmin, "    ");
			tmp = "";
			for (i = 0; i < xau.Groups.Count(); i++)
			{
				if (tmp != "") tmp $= ", ";
				tmp $= xau.Groups.Get(i).GroupName;
			}
			client.output(msgAdminLGroups@tmp, "    ");
			tmp = "";
			for (i = 0; i < xau.ManagedGroups.Count(); i++)
			{
				if (tmp != "") tmp $= ", ";
				tmp $= xau.ManagedGroups.Get(i).GroupName;
			}
			client.output(msgAdminLMGroups@tmp, "    ");
		}
	}
	else if (cmd[0] ~= "password")
	{
		idx = GetSession(client);
		Sessions[idx].entries[0] = cmd[0];
		client.requestInput(self, msgPasswordPrompt1, true);
	}
	else if (cmd[0] ~= "add")
	{
		if (!Auth.HasPermission(client,, "Aa"))
		{
			client.outputError(msgUnauthorized);
			return;
		}
		if ((cmd.length < 2) || (cmd[1] == ""))
		{
			client.outputError(msgAdminAddUsage);
			return;
		}
		if (Level.Game.AccessControl.Users.FindByName(cmd[1]) != none)
		{
			client.outputError(repl(msgAdminCreateExists, "%s", cmd[1]));
			return;
		}
		if (!class'xAdminUser'.static.ValidName(cmd[1]))
		{
			client.outputError(repl(msgAdminCreateInvalid, "%s", cmd[1]));
			return;
		}
		idx = GetSession(client);
		Sessions[idx].entries[0] = cmd[0]; // add
		Sessions[idx].entries[1] = cmd[1]; // username
		if (cmd.length > 2) Sessions[idx].entries[2] = cmd[2]; // privs
		else Sessions[idx].entries[2] = "";
		client.requestInput(self, msgPasswordPrompt1, true);
	}
	else if (cmd[0] ~= "remove")
	{
		if (!Auth.HasPermission(client,, "Aa"))
		{
			client.outputError(msgUnauthorized);
			return;
		}
		if ((cmd.length < 2) || (cmd[1] == ""))
		{
			client.outputError(msgAdminRemoveUsage);
			return;
		}
		xau = Level.Game.AccessControl.Users.FindByName(cmd[1]);
		if (xau == none)
		{
			client.outputError(repl(msgAdminNoSuch, "%s", cmd[1]));
			return;
		}
		xau.UnlinkGroups();
		Level.Game.AccessControl.Users.Remove(xau);
		Level.Game.AccessControl.SaveAdmins();
		client.output(msgAdminRemoved);
	}
	else if (cmd[0] ~= "edit")
	{
		if ((cmd.length < 3) || (cmd[2] == ""))
		{
			client.outputError(msgAdminEditUsage);
			return;
		}
		xau = Level.Game.AccessControl.Users.FindByName(cmd[1]);
		if (!Level.Game.AccessControl.GetLoggedAdmin(client.PlayerController).CanManageUser(xau))
		{
			client.outputError(msgUnauthorized);
			return;
		}
		if (xau == none)
		{
			client.outputError(repl(msgAdminNoSuch, "%s", cmd[1]));
			return;
		}
		if (cmd[2] ~= "password")
		{
			if (!Auth.HasPermission(client,, "Ae"))
			{
				client.outputError(msgUnauthorized);
				return;
			}
			idx = GetSession(client);
			Sessions[idx].entries[0] = cmd[0]$cmd[2]; // edit
			Sessions[idx].entries[1] = cmd[1]; // username
			client.requestInput(self, msgPasswordPrompt1, true);
		}
		else if (cmd[2] ~= "setpriv")
		{
			if (!Auth.HasPermission(client,, "Ae"))
			{
				client.outputError(msgUnauthorized);
				return;
			}
			if (cmd.length < 4) xau.Privileges = "";
			else xau.Privileges = cmd[3];
			xau.RedoMergedPrivs();
			Level.Game.AccessControl.SaveAdmins();
			client.output(msgAdminEditPrivUpdate);
		}
		else if (cmd[2] ~= "addpriv")
		{
			if (!Auth.HasPermission(client,, "Ae"))
			{
				client.outputError(msgUnauthorized);
				return;
			}
			if (cmd.length < 4 || cmd[3] == "")
			{
				client.outputError(msgAdminEditAddPriv);
				return;
			}
			if (InStr("|"$xau.Privileges$"|", "|"$cmd[3]$"|") == -1) xau.Privileges = xau.Privileges$"|"$cmd[3];
			xau.RedoMergedPrivs();
			Level.Game.AccessControl.SaveAdmins();
			client.output(msgAdminEditPrivUpdate);
		}
		else if (cmd[2] ~= "delpriv")
		{
			if (!Auth.HasPermission(client,, "Ae"))
			{
				client.outputError(msgUnauthorized);
				return;
			}
			if (cmd.length < 4 || cmd[3] == "")
			{
				client.outputError(msgAdminEditAddPriv);
				return;
			}
			if (InStr(xau.Privileges, "|"$cmd[3]$"|") > -1)
			{
				xau.Privileges = repl(xau.Privileges, "|"$cmd[3]$"|", "|");
			}
			if (InStr(xau.Privileges, cmd[3]$"|") == 0)
			{
				xau.Privileges = repl(xau.Privileges, cmd[3]$"|", "");
			}
			if (InStr(xau.Privileges, "|"$cmd[3]) == Len(xau.Privileges)-Len("|"$cmd[3]))
			{
				xau.Privileges = repl(xau.Privileges, "|"$cmd[3], "");
			}
			xau.RedoMergedPrivs();
			Level.Game.AccessControl.SaveAdmins();
			client.output(msgAdminEditPrivUpdate);
		}
		else if (cmd[2] ~= "addgroup")
		{
			if (!Auth.HasPermission(client,, "Ag"))
			{
				client.outputError(msgUnauthorized);
				return;
			}
			if (cmd.length < 4 || cmd[3] == "")
			{
				client.outputError(msgAdminEditAddGroupUsage);
				return;
			}
			for (i = 3; i < cmd.length; i ++)
			{
				xag = Level.Game.AccessControl.Groups.FindByName(cmd[i]);
				if (xag == none)
				{
					client.outputError(repl(msgAdminEditInvalidGroup, "%s", cmd[i]));
				}
				else {
					xau.AddGroup(xag);
					client.output(repl(repl(msgAdminEditGroupAdded, "%user", xau.UserName), "%group", xag.GroupName));
				}
			}
			Level.Game.AccessControl.SaveAdmins();
		}
		else if (cmd[2] ~= "delgroup")
		{
			if (!Auth.HasPermission(client,, "Ag"))
			{
				client.outputError(msgUnauthorized);
				return;
			}
			if (cmd.length < 4 || cmd[3] == "")
			{
				client.outputError(msgAdminEditDelGroupUsage);
				return;
			}
			for (i = 3; i < cmd.length; i ++)
			{
				xag = Level.Game.AccessControl.Groups.FindByName(cmd[i]);
				if (xag == none)
				{
					client.outputError(repl(msgAdminEditInvalidGroup, "%s", cmd[i]));
				}
				else {
					xau.RemoveGroup(xag);
					client.output(repl(repl(msgAdminEditDelGroup, "%user", xau.UserName), "%group", xag.GroupName));
				}
			}
			Level.Game.AccessControl.SaveAdmins();
		}
		else if (cmd[2] ~= "addmgroup")
		{
			if (!Auth.HasPermission(client,, "Ag"))
			{
				client.outputError(msgUnauthorized);
				return;
			}
			if (cmd.length < 4 || cmd[3] == "")
			{
				client.outputError(msgAdminEditAddMGroupUsage);
				return;
			}
			for (i = 3; i < cmd.length; i ++)
			{
				xag = Level.Game.AccessControl.Groups.FindByName(cmd[i]);
				if (xag == none)
				{
					client.outputError(repl(msgAdminEditInvalidGroup, "%s", cmd[i]));
				}
				else {
					xau.AddManagedGroup(xag);
					client.output(repl(repl(msgAdminEditGroupAdded, "%user", xau.UserName), "%group", xag.GroupName));
				}
			}
			Level.Game.AccessControl.SaveAdmins();
		}
		else if (cmd[2] ~= "delmgroup")
		{
			if (!Auth.HasPermission(client,, "Ag"))
			{
				client.outputError(msgUnauthorized);
				return;
			}
			if (cmd.length < 4 || cmd[3] == "")
			{
				client.outputError(msgAdminEditDelMGroupUsage);
				return;
			}
			for (i = 3; i < cmd.length; i ++)
			{
				xag = Level.Game.AccessControl.Groups.FindByName(cmd[i]);
				if (xag == none)
				{
					client.outputError(repl(msgAdminEditInvalidGroup, "%s", cmd[i]));
				}
				else {
					xau.RemoveManagedGroup(xag);
					client.output(repl(repl(msgAdminEditDelGroup, "%user", xau.UserName), "%group", xag.GroupName));
				}
			}
			Level.Game.AccessControl.SaveAdmins();
		}
		else if (cmd[2] ~= "master")
		{
			xau.bMasterAdmin = cmd[3] ~= string(true);
			Level.Game.AccessControl.SaveAdmins();
			client.output(repl(msgGroupMaster, "%b", xau.bMasterAdmin));
		}
		else {
			client.outputError(msgAdminEditUsage);
			return;
		}
	}
	else client.outputError(msgAdminUsage);
}

function RequestInputResult(UnGatewayClient client, coerce string result)
{
	local int idx;
	local xAdminUser xau;

	idx = GetSession(client);
	if ((idx == -1) || (Sessions[idx].entries.length == 0))
	{
		client.outputError(msgSessionError);
		client.endRequestInput(self);
		return;
	}
	if (Sessions[idx].entries[0] ~= "password")
	{
		if (Sessions[idx].entries.length < 2)
		{
			if (!class'xAdminUser'.static.ValidPass(result))
			{
				client.outputError(msgInvalidPassword);
				Sessions[idx].entries.Length = 0;
				client.endRequestInput(self);
				return;
			}
			Sessions[idx].entries[1] = result;
			client.requestInput(self, msgPasswordPrompt2, true);
		}
		else {
			if (Sessions[idx].entries[1] != result)
			{
				client.outputError(msgPasswordMatchError);
			}
			else {
				Level.Game.AccessControl.GetLoggedAdmin(client.PlayerController).Password = Sessions[idx].entries[1];
				Level.Game.AccessControl.SaveAdmins();
				client.output(msgPasswordUpdated);
			}
			Sessions[idx].entries.Length = 0;
			client.endRequestInput(self);
		}
	}
	if (Sessions[idx].entries[0] ~= "add")
	{
		if (Sessions[idx].entries.length < 4)
		{
			if (!class'xAdminUser'.static.ValidPass(result))
			{
				client.outputError(msgInvalidPassword);
				Sessions[idx].entries.Length = 0;
				client.endRequestInput(self);
				return;
			}
			Sessions[idx].entries[3] = result;
			client.requestInput(self, msgPasswordPrompt2, true);
		}
		else {
			if (Sessions[idx].entries[3] != result)
			{
				client.outputError(msgPasswordMatchError);
			}
			else {
				xau = Level.Game.AccessControl.Users.Create(Sessions[idx].entries[1], Sessions[idx].entries[3], Sessions[idx].entries[2]);
				Level.Game.AccessControl.Users.Add(xau);
				Level.Game.AccessControl.SaveAdmins();
				client.output(repl(msgAdminCreated, "%s", Sessions[idx].entries[1]));
			}
			Sessions[idx].entries.Length = 0;
			client.endRequestInput(self);
		}
	}
	else if (Sessions[idx].entries[0] ~= "editpassword")
	{
		if (Sessions[idx].entries.length < 3)
		{
			if (!class'xAdminUser'.static.ValidPass(result))
			{
				client.outputError(msgInvalidPassword);
				Sessions[idx].entries.Length = 0;
				client.endRequestInput(self);
				return;
			}
			Sessions[idx].entries[2] = result;
			client.requestInput(self, msgPasswordPrompt2, true);
		}
		else {
			if (Sessions[idx].entries[2] != result)
			{
				client.outputError(msgPasswordMatchError);
			}
			else {
				xau = Level.Game.AccessControl.Users.FindByName(Sessions[idx].entries[1]);
				xau.Password = Sessions[idx].entries[2];
				Level.Game.AccessControl.SaveAdmins();
				client.output(msgPasswordUpdated);
			}
			Sessions[idx].entries.Length = 0;
			client.endRequestInput(self);
		}
	}
}

/** converts a permission list to a list with privilege names */
function string privilegesToString(string priv, optional string delim)
{
	local array<string> privs;
	local int i;
	if (delim == "") delim = ", ";
	split(priv, "|", privs);
	priv = "";
	for (i = 0; i < privs.length; i++)
	{
		if (priv != "") priv $= delim;
		priv $= privilegeToString(privs[i]);
	}
	return priv;
}

/** converts the privilege token to it's string representation */
function string privilegeToString(string priv)
{
	local int i,j;
	local array<string> privs;

	if (priv == "") return "";
	for (i = 0; i < Level.Game.AccessControl.PrivManagers.Length; i++)
	{
		if ((InStr(Level.Game.AccessControl.PrivManagers[i].MainPrivs, priv) > -1) ||
			(InStr(Level.Game.AccessControl.PrivManagers[i].SubPrivs, priv) > -1))
		{
			split(Level.Game.AccessControl.PrivManagers[i].MainPrivs$"|"$Level.Game.AccessControl.PrivManagers[i].SubPrivs, "|", privs);
		}
		for (j = 0; j < privs.length; j++)
		{
			if (privs[j] == priv) return Level.Game.AccessControl.PrivManagers[i].Tags[j]@"("$privs[j]$")";
		}
	}
	return priv;
}

function execPrivilege(UnGatewayClient client, array<string> cmd)
{
	local int i,j;
	local array<string> privs;
	if (cmd.length < 1 || cmd[0] == "") cmd[0] = "*";
	for (i = 0; i < Level.Game.AccessControl.PrivManagers.Length; i++)
	{
		split(Level.Game.AccessControl.PrivManagers[i].MainPrivs$"|"$Level.Game.AccessControl.PrivManagers[i].SubPrivs, "|", privs);
		for (j = 0; j < privs.length; j++)
		{
			if (class'wString'.static.MaskedCompare(Level.Game.AccessControl.PrivManagers[i].Tags[j], cmd[0]) ||
				class'wString'.static.MaskedCompare(privs[j], cmd[0]))
				client.output(PadLeft(privs[j], 3)@Level.Game.AccessControl.PrivManagers[i].Tags[j]);
		}
	}
}

function execGroup(UnGatewayClient client, array<string> cmd)
{
	local int i, idx;
	local xAdminUser xau;
	local xAdminGroup xag;
	local xAdminGroupList xgl;
	local string tmp;

	if (Level.Game.AccessControl.Users == none)
	{
		client.outputError(msgMultiAdmin);
		return;
	}
	if (AccessControlIni(Level.Game.AccessControl) == none)
	{
		client.outputError(msgMultiAdmin);
		return;
	}
	if ((cmd.length == 0) || (cmd[0] == "") || (cmd[0] ~= "list"))
	{
		if (!Auth.HasPermission(client,, "Gl"))
		{
			client.outputError(msgUnauthorized);
			return;
		}
		xau = Level.Game.AccessControl.GetLoggedAdmin(client.PlayerController);
		if (xau.bMasterAdmin) xgl = Level.Game.AccessControl.Groups;
		else xgl = xau.ManagedGroups;
		for (idx = 0; idx < xgl.Count(); idx++)
		{
			xag = xgl.Get(idx);
			client.output(xag.GroupName);
			client.output(msgAdminPrivileges@privilegesToString(xag.Privileges), "    ");
			client.output(msgAdminMaxSecLevel@xag.GameSecLevel, "    ");
			client.output(msgAdminMaster@xag.bMasterAdmin, "    ");
			tmp = "";
			for (i = 0; i < xag.Users.Count(); i++)
			{
				if (tmp != "") tmp $= ", ";
				tmp $= xag.Users.Get(i).UserName;
			}
			client.output(msgGroupUsers@tmp, "    ");
			tmp = "";
			for (i = 0; i < xag.Managers.Count(); i++)
			{
				if (tmp != "") tmp $= ", ";
				tmp $= xag.Managers.Get(i).UserName;
			}
			client.output(msgGroupManagers@tmp, "    ");
		}
	}
	else if (cmd[0] ~= "add")
	{
		if (!Auth.HasPermission(client,, "Ga"))
		{
			client.outputError(msgUnauthorized);
			return;
		}
		if ((cmd.length < 2) || (cmd[1] == ""))
		{
			client.outputError(msgGroupAddUsage);
			return;
		}
		if (!class'xAdminGroup'.static.ValidName(cmd[1]))
		{
			client.outputError(repl(msgGroupInvalidName, "%s", cmd[1]));
			return;
		}
		if (Level.Game.AccessControl.Groups.FindByName(cmd[1]) != none)
		{
			client.outputError(repl(msgGroupExists, "%s", cmd[1]));
			return;
		}
		if (cmd.length < 3) cmd[2] = "";
		if (cmd.length < 4) cmd[3] = "0";
		if (!intval(cmd[3], i))
		{
			client.outputError(repl(msgGroupInvalidSecLevel, "%s", cmd[3]));
			return;
		}
		xag = level.Game.AccessControl.Groups.CreateGroup(cmd[1], cmd[2], i);
		Level.Game.AccessControl.Groups.Add(xag);
		Level.Game.AccessControl.SaveAdmins();
		client.output(repl(msgGroupAdded, "%s", cmd[1]));
	}
	else if (cmd[0] ~= "remove")
	{
		if (!Auth.HasPermission(client,, "Ga"))
		{
			client.outputError(msgUnauthorized);
			return;
		}
		if ((cmd.length < 2) || (cmd[1] == ""))
		{
			client.outputError(msgGroupRemoveUsage);
			return;
		}
		xag = Level.Game.AccessControl.Groups.FindByName(cmd[1]);
		if (xag == none)
		{
			client.outputError(repl(msgGroupDoesNotExists, "%s", cmd[1]));
			return;
		}
		xag.UnlinkUsers();
		Level.Game.AccessControl.Groups.Remove(xag);
		Level.Game.AccessControl.SaveAdmins();
		client.output(repl(msgGroupRemoved, "%s", cmd[1]));
	}
	else if (cmd[0] ~= "edit")
	{
		if (!Auth.HasPermission(client,, "Ge"))
		{
			client.outputError(msgUnauthorized);
			return;
		}
		if ((cmd.length < 3) || (cmd[1] == "") || (cmd[2] == ""))
		{
			client.outputError(msgGroupEditUsage);
			return;
		}
		if (cmd.length < 3) cmd[3] = "";
		xag = Level.Game.AccessControl.Groups.FindByName(cmd[1]);
		if (xag == none)
		{
			client.outputError(repl(msgGroupDoesNotExists, "%s", cmd[1]));
			return;
		}
		if (cmd[2] ~= "setperm")
		{
			xag.SetPrivs(cmd[3]);
			Level.Game.AccessControl.SaveAdmins();
			client.output(msgAdminEditPrivUpdate);
		}
		else if (cmd[2] ~= "addperm")
		{
			if (InStr("|"$xag.Privileges$"|", "|"$cmd[3]$"|") == -1)
			{
				cmd[3] = xag.Privileges$"|"$cmd[3];
				xag.SetPrivs(cmd[3]);
			}
			Level.Game.AccessControl.SaveAdmins();
			client.output(msgAdminEditPrivUpdate);
		}
		else if (cmd[2] ~= "delperm")
		{
			tmp = xag.Privileges;
			if (InStr(tmp, "|"$cmd[3]$"|") > -1)
			{
				tmp = repl(tmp, "|"$cmd[3]$"|", "|");
			}
			if (InStr(tmp, cmd[3]$"|") == 0)
			{
				tmp = repl(tmp, cmd[3]$"|", "");
			}
			if (InStr(tmp, "|"$cmd[3]) == Len(tmp)-Len("|"$cmd[3]))
			{
				tmp = repl(tmp, "|"$cmd[3], "");
			}
			xag.SetPrivs(tmp);
			Level.Game.AccessControl.SaveAdmins();
			client.output(msgAdminEditPrivUpdate);
		}
		else if (cmd[2] ~= "seclevel")
		{
			if (!intval(cmd[3], i))
			{
				client.outputError(repl(msgGroupInvalidSecLevel, "%s", cmd[3]));
				return;
			}
			xag.GameSecLevel = i;
			Level.Game.AccessControl.SaveAdmins();
			client.output(msgGroupSecLevelUpdate);
		}
		else if (cmd[2] ~= "master")
		{
			xag.bMasterAdmin = cmd[3] ~= string(true);
			Level.Game.AccessControl.SaveAdmins();
			client.output(repl(msgGroupMaster, "%b", xag.bMasterAdmin));
		}
		else {
			client.outputError(msgGroupEditUsage);
			return;
		}
	}
}

defaultproperties
{
	innerCVSversion="$Id: GAppSettings.uc,v 1.15 2004/05/01 15:56:05 elmuerte Exp $"
	Commands[0]=(Name="set",Permission="Ms")
	Commands[1]=(Name="edit",Permission="Ms")
	Commands[2]=(Name="savesettings",Permission="Ms")
	Commands[3]=(Name="cancelsettings",Permission="Ms")
	Commands[4]=(Name="maplist",Permission="Ms")
	Commands[5]=(Name="mledit",Permission="Ms")
	Commands[6]=(Name="policy",Permission="Xi")
	Commands[7]=(Name="admin",Permission="A")
	Commands[8]=(Name="privilege")
	Commands[9]=(Name="group",Permission="G")

	CommandHelp[0]="Change or list the settings.ÿWhen called without any arguments it will list all setting groups.ÿYou can use wild cards to match groups or settings.ÿTo list all settings in a group use: set -list <groupname> ...ÿTo list all settings matching a name use: set <match>ÿTo edit a setting use: set <setting> <new value ...>"
	CommandHelp[1]="Change the class to edit.ÿThe class must be a fully qualified name: package.classÿIt's also possible to edit a complete game type. In that case use: -game <name or class of the gametype>ÿUsage: edit [-game] <class name>"
	CommandHelp[2]="Save the settings you've made.ÿSettings are not saved until you execute this command."
	CommandHelp[3]="Discard any changes made to the current settings."
	CommandHelp[4]="Manage map lists.ÿThis command will allow you to create, delete, rename, list or activate map lists.ÿIt will also allow you to change the maplist that can be edited with 'mledit'.ÿTo list maplists of other game types than the current game type use: maplist list package.gametypeÿUsage: maplist <create|delete|rename|edit|activate|list> ..."
	CommandHelp[5]="Edit a map list.ÿWith the command you can edit the current maplist.ÿUse the 'maplist' command to change the maplist being edited.ÿmledit <add|remove|move|list|save|abort|available> ..."
	CommandHelp[6]="Manage access policies.ÿWithout any arguments the current access policy will be listed.ÿUsage: policy <add|remove> ..."
	CommandHelp[7]="Manage admins.ÿThis command is only available when using the so called xAdmin system.ÿUsage: admin <list|add|remove|edit|password|master> ...ÿUsage: admin add <username>ÿUsage: admin remove <username>ÿUsage: admin edit <username> <password|addgroup|delgroup|addmgroup|delmgroup|addpriv|delpriv|setpriv> ..."
	CommandHelp[8]="List all privileges.ÿUsage: privilege <match>"
	CommandHelp[9]="Manage user groups.ÿThis command is only available when using the so called xAdmin system.ÿUsage: group <list|add|remove|edit|master> ..."

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
	msgSessionError="Internal session error"
	msgPasswordPrompt1="Password: "
	msgPasswordPrompt2="Again:    "
	msgPasswordMatchError="Passwords do no match"
	msgPasswordUpdated="Password changed"
	msgAdminAddUsage="Usage: admin add <username>"
	msgAdminRemoveUsage="Usage: admin remove <username>"
	msgInvalidPassword="Invalid password"
	msgAdminCreated="Admin %s created"
	msgAdminCreateExists="User %s already exists"
	msgAdminCreateInvalid="Invalid username: %s"
	msgAdminPrivileges="Privileges:"
	msgAdminMergedPrivileges="Merged privileges:"
	msgAdminMaxSecLevel="Security level:"
	msgAdminNoSuch="No such admin: %s"
	msgAdminRemoved="Admin user removed"
	msgAdminEditUsage="Usage: admin edit <username> <password|addgroup|delgroup|addpriv|delpriv|setpriv|master> ..."
	msgAdminMaster="Master admin:"
	msgAdminUsage="admin <list|add|remove|edit|password> ..."
	msgAdminEditPrivUpdate="Privileges updated"
	msgAdminEditAddPriv="Usage: admin edit <username> addpriv <privilege>"
	msgAdminEditInvalidGroup="'%s' is not a valid group name"
	msgAdminEditGroupAdded="Added %user to group %group"
	msgAdminEditAddGroupUsage="Usage: admin edit <username> addgroup <group> ..."
	msgAdminEditDelGroupUsage="Usage: admin edit <username> delgroup <group> ..."
	msgAdminEditDelGroup="Removed user %user from group %group"
	msgAdminEditAddmGroupUsage="Usage: admin edit <username> addmgroup <group> ..."
	msgAdminEditDelmGroupUsage="Usage: admin edit <username> delmgroup <group> ..."
	msgAdminLGroups="Groups:"
	msgAdminLMGroups="Managed groups:"
	msgGroupUsers="Users:"
	msgGroupManagers="Managers:"
	msgGroupAddUsage="Usage: group add <name> [privileges] [security level]"
	msgGroupInvalidName="'%s' is not a valid group name"
	msgGroupExists="A group with the name '%s' already exists"
	msgGroupAdded="Added group %s"
	msgGroupInvalidSecLevel="'%i' is not a valid security level"
	msgGroupRemoveUsage="Usage: group remove <name>"
	msgGroupDoesNotExists="There is no group with the name %s"
	msgGroupRemoved="Removed the group %s"
	msgGroupEditUsage="Usage: group edit <name> <setperm|addperm|delperm|seclevel|master> ..."
	msgGroupSecLevelUpdate="Security level updated"
	msgGroupMaster="Master admin switch set to %b"
}
