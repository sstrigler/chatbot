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
# ChatBot Eliza PlugIn - handles putting some spunk into ChatBot by wiring
#                        the Eliza program into place when you address
#                        ChatBot.
#
##############################################################################

use strict;
use Chatbot::Eliza;  

##############################################################################
#
# Register Events
#
##############################################################################
&RegisterEvent("groupchat_message",\&plugin_eliza_eliza);
&RegisterEvent("chat_message",\&plugin_eliza_eliza);


##############################################################################
#
# Register Flags
#
##############################################################################
&RegisterFlag("eliza");


##############################################################################
#
# Instantiate an Eliza
#
##############################################################################
$plugin_env{eliza}->{eliza} = new Chatbot::Eliza {scriptfile=>'eliza_deutsch.txt'};


##############################################################################
#
# plugin_eliza_eliza - prints out the current eliza in UTC
#
##############################################################################
sub plugin_eliza_eliza
{
    my $message = shift;

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"eliza");

    my $body = $message->GetBody();
    my $nick = &ChatBotNick($fromJID->GetJID());
    my $fromNick = $fromJID->GetResource();

    return if ($fromNick eq "");
    return if ($fromNick =~ /$nick/);
    return unless ($body =~ /^\s*$nick\:(.*)$/);

    my $input = $1;
    my $reply = $plugin_env{eliza}->{eliza}->transform("$input");

    return ($message->GetType(),$fromJID->GetResource().": $reply");
}


1;
