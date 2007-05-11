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
# ChatBot Query PlugIn - responds to requests for a definition of a phrase or
#                        term.  ?? chatbot
#
##############################################################################

use strict;
use URI::Escape qw(uri_escape_utf8);

use vars qw ( %query );

##############################################################################
#
# Register Events
#
##############################################################################
&RegisterCommand(command=>"!query",
                 alias=>"??",
                 handler=>\&plugin_query_query,
                 desc=>"Return the value for the requested key. NOTE: The space in between the command and the key is VERY important.",
                 usage=>"<key>");
&RegisterCommand(command=>"!edit_query",
                 handler=>\&plugin_query_edit_query,
                 desc=>"Add/Edit the query value for the given key.",
                 usage=>"<password> \"<key>\" <value>");
&RegisterCommand(command=>"!del_query",
                 handler=>\&plugin_query_del_query,
                 desc=>"Delete the query value for the given key.",
                 usage=>"<password> \"<key>\"");


##############################################################################
#
# Register Flags
#
##############################################################################
&RegisterFlag("query");


##############################################################################
#
# Define config variables
#
##############################################################################
$config{plugins}->{query}->{values} = "./queries.xml"
    unless exists($config{plugins}->{query}->{values});


##############################################################################
#
# Grab the query messages from disk
#
##############################################################################
%query = &xmldbRead($config{plugins}->{query}->{values});


##############################################################################
#
# plugin_query_query - return the query value, if any
#
##############################################################################
sub plugin_query_query
{
    my $message = shift;
    my $key = shift;

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"query");

    return unless (defined($key) && ($key ne ""));
    return ($message->GetType(),"http://de.wikipedia.org/wiki/".uri_escape_utf8($key))
        unless exists($query{lc($key)});
    return ($message->GetType(),"[".lc($key)."]: ".$query{lc($key)});
}


##############################################################################
#
# plugin_query_edit_query - edit the message for a user
#
##############################################################################
sub plugin_query_edit_query
{
    my $message = shift;
    my $args = shift;

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"query");

    my ($password,$key,$value) = ($args =~ /^\s*(\S+)\s+\"([^\"]+)\"\s*(.*)$/);

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.")
        unless &CheckPassword("query",$password);

    $query{lc($key)} = $value unless (!defined($key) || !defined($value));
    &xmldbWrite($config{plugins}->{query}->{values},%query);
    return ($message->GetType(),"[$key]: $query{$key}");
}


##############################################################################
#
# plugin_query_del_query - delete the message for a user
#
##############################################################################
sub plugin_query_del_query
{
    my $message = shift;
    my $args = shift;

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"query");

    my ($password,$key) = ($args =~ /^\s*(\S+)\s+\"([^\"]+)\"\s*$/);

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.")
        unless &CheckPassword("query",$password);

    delete($query{lc($key)});
    &xmldbWrite($config{plugins}->{query}->{messages},%query);
    return ($message->GetType(),"Query message for \"$key\" deleted");
}


1;
