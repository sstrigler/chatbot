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
# ChatBot Time PlugIn - prints out the current time in UTC.
#
##############################################################################

use strict;

eval("use Date::Manip;");
$plugin_env{time}->{datemanip} = 1;
if ($@)
{
    $plugin_env{time}->{datemanip} = 0;
}

##############################################################################
#
# Register Events
#
##############################################################################
&RegisterCommand(command=>"!time",
                 handler=>\&plugin_time_time,
                 desc=>"Prints out the current time in UTC.",
                 usage=>($plugin_env{time}->{datemanip} ? "[<TZ>]" : ""));


##############################################################################
#
# plugin_time_time - prints out the current time in UTC
#
##############################################################################
sub plugin_time_time
{
    my $message = shift;
    my $args = shift;

    my $fromJID = $message->GetFrom("jid");

    my $utc = &Net::Jabber::GetTimeStamp("utc")." UTC";
    
    if ($plugin_env{time}->{datemanip})
    {
        my ($tz) = ($args =~ /^(\S+)/);
        $tz = "UTC" if ($tz eq "");

        my $date = &ParseDate("now");
        $date = &Date_ConvTZ($date,"",$tz);
        $utc = &UnixDate($date,"%a %b %d, %Y %H:%M:%S ".uc($tz));
    }
        
    return ($message->GetType(),"[time]: ".$utc);
}


1;

