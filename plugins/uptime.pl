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
# ChatBot Uptime PlugIn - Handles calculating and displaying the current
#                         uptime for ChatBot.
#
##############################################################################

use strict;

##############################################################################
#
# Register events
#
##############################################################################
&RegisterEvent("startup",\&plugin_uptime_startup);
&RegisterCommand(command=>"!uptime",
                 handler=>\&plugin_uptime_uptime,
                 desc=>"Prints out the length of time that ChatBot has been running for.",
                 usage=>"");


##############################################################################
#
# plugin_uptime_startup - grab the startup time.
#
##############################################################################
sub plugin_uptime_startup
{
    $plugin_env{uptime}->{start} = time;
}


##############################################################################
#
# plugin_uptime_uptime - calculate the uptime and print it.
#
##############################################################################
sub plugin_uptime_uptime
{
    my $message = shift;

    my $seconds = time - $plugin_env{uptime}->{start};

    my $response = "Uptime: ";
    $response .= &Net::XMPP::GetHumanTime($seconds);

    return ($message->GetType(),$response);
}


1;
