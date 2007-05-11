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
# ChatBot Channel PlugIn - facilitates telling chatbot to join/leave channels
#
##############################################################################

use strict;

##############################################################################
#
# Register Events
#
##############################################################################
&RegisterCommand(command=>"!join_channel",
                 alias=>"!jc",
                 handler=>\&plugin_channel_join_channel,
                 desc=>"Tell ChatBot to join a new channel.",
                 usage=>"<password> <channel> <server> <resource>");
&RegisterCommand(command=>"!leave_channel",
                 alias=>"!lc",
                 handler=>\&plugin_channel_leave_channel,
                 desc=>"Tell ChatBot to leave a channel.",
                 usage=>"<password> <channel> <server>");


##############################################################################
#
# plugin_channel_join_channel - tell chatbot to join a channel
#
##############################################################################
sub plugin_channel_join_channel
{
    my $message = shift;
    my $args = shift;

    my $fromJID = $message->GetFrom("jid");

    my ($password,$name,$server,$resource) = ($args =~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s+(.*?)$/);

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.")
        unless &CheckPassword("channel",$password);

    return ($message->GetType(),"ChatBot is already in the channel $name\@$server as ".&ChatBotNick($name."\@".$server))
        if defined(&ChatBotNick($name."\@".$server));

    &JoinChannel($name,$server,$resource);

    return ($message->GetType(),"ChatBot is scheduled to join any time now.");
}


##############################################################################
#
# plugin_channel_leave_channel - tell chatbot to leave a channel
#
##############################################################################
sub plugin_channel_leave_channel
{
    my $message = shift;
    my $args = shift;

    my $fromJID = $message->GetFrom("jid");

    my ($password,$name,$server) = ($args =~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s*$/);

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.")
        unless &CheckPassword("channel",$password);

    return ($message->GetType(),"ChatBot is not in the channel $name\@$server")
        unless defined(&ChatBotNick($name."\@".$server));

    &LeaveChannel($name,$server);

    return ($message->GetType(),"ChatBot has been told to leave the channel.");
}


1;
