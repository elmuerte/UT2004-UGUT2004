/*******************************************************************************
    DelayedShutdown                                                             <br />
    Used for a delayed shutdown of the server                                   <br />
                                                                                <br />
    Authors:    Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;  <br />
                                                                                <br />
    Copyright 2003, 2004 Michiel "El Muerte" Hendriks                           <br />
    Released under the Open Unreal Mod License                                  <br />
    http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense
    <!-- $Id: DelayedShutdown.uc,v 1.2 2004/10/20 14:08:40 elmuerte Exp $ -->
*******************************************************************************/
class DelayedShutdown extends Info;

/** the shutdown message */
var string Message;
/** true if still enabled, prevents split second shutdown */
var protected bool bEnabled;

/** start the delayed shutdown */
function setup(int delay, optional string myMessage)
{
    Message = myMessage;
    bEnabled = true;
    settimer(Delay, false);
}

/** abort the delayed shutdown */
function abort()
{
    bEnabled = false;
    Destroy();
}

function Timer()
{
    if (bEnabled)
    {
        Level.Game.Broadcast(Level, Message);
        Level.ConsoleCommand("quit");
    }
}
