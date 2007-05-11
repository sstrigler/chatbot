##############################################################################
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
#  Jabber
#  Copyright (C) 1998-2002 The Jabber Team http://jabber.org/
#
##############################################################################

##############################################################################
#
# ChatBot Flags PlugIn - handles listing and toggling the channel flags to
#                        control how ChatBot behaves in a channel.
#
##############################################################################

use strict;

##############################################################################
#
# Register Events
#
##############################################################################
&RegisterCommand(command=>"!flags",
                 handler=>\&plugin_flags_flags,
                 desc=>"Return a list of all available flags for the channel, and their current state.",
                 usage=>"<password>");
&RegisterCommand(command=>"!toggle_flag",
                 alias=>"!tog",
                 handler=>\&plugin_flags_toggle_flag,
                 desc=>"Toggle a flag(s) on/off for the channel.",
                 usage=>"<password> <flag> [ <flag> ... ]");
&RegisterCommand(command=>"!toggle_flag_all",
                 alias=>"!togall",
                 handler=>\&plugin_flags_toggle_flag_all,
                 desc=>"Toggle a flag(s) on/off for all of the channels.",
                 usage=>"<password> <flag> [ <flag ... ]");


##############################################################################
#
# plugin_flags_flags - return the list of current flags and their states
#
##############################################################################
sub plugin_flags_flags
{
    my $message = shift;
    my $password = shift;

    my $fromJID = $message->GetFrom("jid");

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.")
        unless &CheckPassword("flags",$password);

    my $string = "Here are the current flags for this channel:\n";
    foreach my $flag (&Flags())
    {
        $string .= "$flag -> ";
        if (&CheckFlag($fromJID->GetJID(),$flag))
        {
            $string .= "on";
        }
        else
        {
            $string .= "off";
        }
        $string .= "\n";
    }
    return ($message->GetType(),$string);
}


##############################################################################
#
# plugin_flags_toggle_flag - toggle the state of the given flag
#
##############################################################################
sub plugin_flags_toggle_flag
{
    my $message = shift;
    my $args = shift;

    my $fromJID = $message->GetFrom("jid");

    my ($password,$flags) = ($args =~ /^\s*(\S+)\s+(.*)$/);

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.")
        unless &CheckPassword("flags",$password);

    my $string = "Toggled flags:\n";
    foreach my $flag (split(/\s+/,$flags))
    {
        &ToggleFlag($fromJID->GetJID(),$flag);
        $string .= "$flag -> ";
        if (&CheckFlag($fromJID->GetJID(),$flag))
        {
            $string .= "on";
        }
        else
        {
            $string .= "off";
        }
        $string .= "\n";
    }
    chomp($string);

    return ($message->GetType(),$string);
}


##############################################################################
#
# plugin_flags_toggle_flag_all - toggle the state of the given flag for all
#                                channels
#
##############################################################################
sub plugin_flags_toggle_flag_all
{
    my $message = shift;
    my $args = shift;

    my $fromJID = $message->GetFrom("jid");

    my ($password,$flags) = ($args =~ /^\s*(\S+)\s+(.*)$/);

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.") 
        unless &CheckPassword("flags",$password);

    my $string = "Toggled flags:\n";
    foreach my $channel (&Channels())
    {
        $string .= "  channel: $channel\n";
        foreach my $flag (split(/\s+/,$flags))
        {
            &ToggleFlag($channel,$flag);
            $string .= "    $flag -> ";
            if (&CheckFlag($channel,$flag))
            {
                $string .= "on";
            }
            else
            {
                $string .= "off";
            }
            $string .= "\n";
        }
    }
    chomp($string);

    return ($message->GetType(),$string);
}


1;
