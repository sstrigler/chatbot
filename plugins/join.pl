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
# ChatBot Join PlugIn - tracks when all users log in and out, and prints out
#                       a join message if that user has one defined
#
##############################################################################

use strict;
use vars qw ( %join );

##############################################################################
#
# Register Events
#
##############################################################################
&RegisterEvent("presence_available_join",\&plugin_join_send_message);
&RegisterCommand(command=>"!edit_join",
                 handler=>\&plugin_join_edit_join,
                 desc=>"Add/Edit the join message for a user.",
                 usage=>"<password> \"<user>\" <message>");
&RegisterCommand(command=>"!del_join",
                 handler=>\&plugin_join_del_join,
                 desc=>"Delete the join message for a user.",
                 usage=>"<password> \"<user>\"");


##############################################################################
#
# Register Flags
#
##############################################################################
&RegisterFlag("join");


##############################################################################
#
# Define config variables
#
##############################################################################
$config{plugins}->{join}->{messages} = "./join_messages.xml"
    unless exists($config{plugins}->{join}->{messages});


##############################################################################
#
# Grab the join messages from disk
#
##############################################################################
%join = &xmldbRead($config{plugins}->{join}->{messages});


##############################################################################
#
# plugin_join_send_message - send out the join message, if any
#
##############################################################################
sub plugin_join_send_message
{
    my $presence = shift;

    my $fromJID = $presence->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"join");

    return unless exists($join{$fromJID->GetResource()});
    return ("groupchat","[".$fromJID->GetResource()."]: ".$join{$fromJID->GetResource()});
}


##############################################################################
#
# plugin_join_edit_join - edit the message for a user
#
##############################################################################
sub plugin_join_edit_join
{
    my $message = shift;
    my $args = shift;

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"join");

    my ($password,$user,$value) = ($args =~ /^\s*(\S+)\s+\"([^\"]+)\"\s*(.*)$/);

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.")
        unless &CheckPassword("join",$password);

    $join{$user} = $value unless (!defined($user) || !defined($value));
    &xmldbWrite($config{plugins}->{join}->{messages},%join);
    return ($message->GetType(),"[$user]: $join{$user}");
}


##############################################################################
#
# plugin_join_del_join - delete the message for a user
#
##############################################################################
sub plugin_join_del_join
{
    my $message = shift;
    my $args = shift;

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"join");

    my ($password,$user) = ($args =~ /^\s*(\S+)\s+\"([^\"]+)\"\s*$/);

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.")
        unless &CheckPassword("join",$password);

    delete($join{$user});
    &xmldbWrite($config{plugins}->{join}->{messages},%join);
    return ($message->GetType(),"Join message for \"$user\" deleted");
}


1;
