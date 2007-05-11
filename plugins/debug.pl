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
# ChatBot Debug PlugIn - provides access to the internals of ChatBot variables
#
##############################################################################

use strict;

##############################################################################
#
# Register events
#
##############################################################################
&RegisterCommand(command=>"!debug",
                 handler=>\&plugin_debug_debug,
                 desc=>"Prints out debug info for ChatBot.",
                 usage=>"<password> <plugin>");


##############################################################################
#
# plugin_debug_debug - show debug info
#
##############################################################################
sub plugin_debug_debug
{
    my $message = shift;
    my $args = shift;

    my ($password,$variable) = ($args =~ /^\s*(\S+)\s+(.*)$/);

    return ("chat","The command was in error.")
        if !defined($password);
    return ("chat","Permission denied.")
        unless &CheckPassword("debug",$password);

    my $response = "\n";
    $response .= "printData:\n";
    eval("\$response .= &Net::Jabber::sprintData('$variable',$variable);");

    $response = substr($response,0,1024);

    return ("chat",$response);
}


1;
