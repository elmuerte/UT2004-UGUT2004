/*******************************************************************************
    GAppSystem                                                                  <br />
    System routines, basic server administration                                <br />
                                                                                <br />
    Authors:    Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;  <br />
                                                                                <br />
    Copyright 2003, 2004 Michiel "El Muerte" Hendriks                           <br />
    Released under the Open Unreal Mod License                                  <br />
    http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense
    <!-- $Id: GAppSystem.uc,v 1.12 2004/10/20 14:08:40 elmuerte Exp $ -->
*******************************************************************************/

class GAppSystem extends UnGatewayApplication;

/** delayed shutdown actor, if one is programmed this will be != none */
var DelayedShutdown shutdownTimer;

var localized string msgShutdownUsage, msgNow, msgShutdownRequest, msgShutdownDelay,
    msgNegativeDelay, msgNoPending, msgShutdownAborted, msgServerTravel,
    msgPlayerListHeader, msgSpectator, msgNoPlayerFound, msgPSpectator,
    msgPAdmin, msgPPing, msgPClass, msgPAddress, msgPHash, msgGTTeamGame,
    msgGTMapPrefix, msgGTGroup, msgMPlayers, msgBanUsage, msgKickUsage,
    msgPlayerKicked, msgPlayerNotKicked, msgPlayerBanned, msgPlayerNotBanned;

var localized string CommandHelp[10];

var localized array<string> msgGTGroups;

function Destroy()
{
    if (shutdownTimer != none)
    {
        shutdownTimer.Destroy();
        shutdownTimer = none;
    }
}

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
        case Commands[7].Name: execSay(client, cmd); return true;
        case Commands[8].Name: execKick(client, cmd); return true;
        case Commands[9].Name: execBan(client, cmd); return true;
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
                    if (C.PlayerReplicationInfo == none) continue;
                    if (C.PlayerReplicationInfo.bBot) continue;
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
                    if (C.PlayerReplicationInfo.bBot) continue;
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
    client.output(PadLeft(msgPClass, 15)@PC.Class, "    ");
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

function execSay(UnGatewayClient client, array<string> cmd)
{
    Level.Game.Broadcast(client.PlayerController, join(cmd, " "), 'Say');
}

function execKick(UnGatewayClient client, array<string> cmd)
{
    local int i;
    local Controller C;

    if ((cmd.length < 1) || (cmd[0] == ""))
    {
        client.outputError(msgKickUsage);
        return;
    }
    if (intval(cmd[0], i))
    {
        for( C=Level.ControllerList; C!=None; C=C.NextController )
        {
            if (C.PlayerReplicationInfo == none) continue;
            if (C.PlayerReplicationInfo.bBot) continue;
            if (i <= 0)
            {
                cmd[0] = C.PlayerReplicationInfo.PlayerName;
                if (Level.Game.AccessControl.KickPlayer(PlayerController(C))) client.output(repl(msgPlayerKicked, "%s", cmd[0]));
                else client.outputError(repl(msgPlayerNotKicked, "%s", cmd[0]));
                return;
            }
            i--;
        }
    }
    else {
        for( C=Level.ControllerList; C!=None; C=C.NextController )
        {
            if (C.PlayerReplicationInfo == none) continue;
            if (C.PlayerReplicationInfo.bBot) continue;
            if (!(C.PlayerReplicationInfo.PlayerName ~= cmd[0])) continue;
            cmd[0] = C.PlayerReplicationInfo.PlayerName;
            if (Level.Game.AccessControl.KickPlayer(PlayerController(C))) client.output(repl(msgPlayerKicked, "%s", cmd[0]));
            else client.outputError(repl(msgPlayerNotKicked, "%s", cmd[0]));
            return;
        }
    }
}

function execBan(UnGatewayClient client, array<string> cmd)
{
    local int i;
    local Controller C;

    if ((cmd.length < 1) || (cmd[0] == ""))
    {
        client.outputError(msgBanUsage);
        return;
    }
    if (intval(cmd[0], i))
    {
        for( C=Level.ControllerList; C!=None; C=C.NextController )
        {
            if (C.PlayerReplicationInfo == none) continue;
            if (C.PlayerReplicationInfo.bBot) continue;
            if (i <= 0)
            {
                cmd[0] = C.PlayerReplicationInfo.PlayerName;
                if (Level.Game.AccessControl.KickBanPlayer(PlayerController(C))) client.output(repl(msgPlayerKicked, "%s", cmd[0]));
                else client.outputError(repl(msgPlayerNotKicked, "%s", cmd[0]));
                return;
            }
            i--;
        }
    }
    else {
        for( C=Level.ControllerList; C!=None; C=C.NextController )
        {
            if (C.PlayerReplicationInfo == none) continue;
            if (C.PlayerReplicationInfo.bBot) continue;
            if (!(C.PlayerReplicationInfo.PlayerName ~= cmd[0])) continue;
            cmd[0] = C.PlayerReplicationInfo.PlayerName;
            if (Level.Game.AccessControl.KickBanPlayer(PlayerController(C))) client.output(repl(msgPlayerBanned, "%s", cmd[0]));
            else client.outputError(repl(msgPlayerNotBanned, "%s", cmd[0]));
            return;
        }
    }
}

defaultproperties
{
    innerCVSversion="$Id: GAppSystem.uc,v 1.12 2004/10/20 14:08:40 elmuerte Exp $"
    Commands[0]=(Name="shutdown",Level=255)
    Commands[1]=(Name="abortshutdown",Level=255)
    Commands[2]=(Name="servertravel",Permission="Mr|Mt|Mm")
    Commands[3]=(Name="players",Permission="Xp")
    Commands[4]=(Name="mutators")
    Commands[5]=(Name="gametypes")
    Commands[6]=(Name="maps")
    Commands[7]=(Name="say")
    Commands[8]=(Name="kick",Permission="Kp")
    Commands[9]=(Name="ban",Permission="Kb")

    CommandHelp[0]="Shutdown the server with a delay.?Use the command abortshutdown to abort the delayed shutdown.?To shutdown the server immediately use 'now' as the delay. this shutdown can not be aborted.?Usage: shutdown <delay|now> [message]"
    CommandHelp[1]="Abort the delayed shutdown."
    CommandHelp[2]="Executes a server travel.?Use this to change the current map of the server.?When no url is given the last url will be used.?Usage: servertravel [url]"
    CommandHelp[3]="Show details about the current players and spectators.?When an ID is provided more details will be shown about this user.?Usage: players [id|name] ..."
    CommandHelp[4]="Show all available mutators.?By default all mutators are listed, but you can also provide a name to match.?Usage: mutators <match>"
    CommandHelp[5]="Show all available game types.?By default all game types are listed, but you can also provide a name to match.?Usage: gametypes <match>"
    CommandHelp[6]="Show all available maps.?By default all maps are listed, but you can also provide a name to match.?Usage: maps <match>"
    CommandHelp[7]="Say something on the server.?Usage: say message ..."
    CommandHelp[8]="Kick a player from the current game.?Usage: kick <name|id>"
    CommandHelp[9]="Ban a player from the current game.?Usage: ban <name|id>"

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
    msgBanUsage="Usage: ban <name|ID>"
    msgKickUsage="Usage: kick <name|ID>"
    msgPlayerKicked="%s has been kicked from the server"
    msgPlayerNotKicked="%s has not been kicked"
    msgPlayerBanned="%s has been banned from the server"
    msgPlayerNotBanned="%s has not been banned"
}
