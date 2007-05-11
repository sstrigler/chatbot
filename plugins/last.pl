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
# ChatBot Last PlugIn - tracks the last X things a user says in a channel, and
#                       allows you to get those things reported to you.
#
##############################################################################

use strict;
use vars qw ( %last );

##############################################################################
#
# Register Events
#
##############################################################################
&RegisterEvent("groupchat_message",\&plugin_last_message);
&RegisterEvent("garbage_collect",\&plugin_last_garbage_collect);
&RegisterCommand(command=>"!last",
                 handler=>\&plugin_last_last,
                 desc=>"Prints the last few lines that a user said in the channel.",
                 usage=>"\"<user>\" [<count>]",
                 examples=>["last \"reatmon\"","last \"reatmon\" 10"]);


##############################################################################
#
# Register Flags
#
##############################################################################
&RegisterFlag("last");


##############################################################################
#
# Define config variables
#
##############################################################################
$config{plugins}->{last}->{storage} = "./last_storage.xml"
    unless exists($config{plugins}->{last}->{storage});
$config{plugins}->{last}->{daystolive} = 14
    unless exists($config{plugins}->{last}->{daystolive});
$config{plugins}->{last}->{maxmessages} = 10
    unless exists($config{plugins}->{last}->{maxmessages});
$config{plugins}->{last}->{defaultcount} = 5
    unless exists($config{plugins}->{last}->{defaultcount});


##############################################################################
#
# plugin_last_last - generate the report on the last X messages
#
##############################################################################
sub plugin_last_last
{
    my $message = shift;
    my $args = shift;

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"last");

    my ($user,$count) = ($args =~ /^\"(.+?)\"\s*(\d*)$/);
    ($user,$count) = ($args =~ /^(.+?)\s+(\d*)$/) unless defined($user);
    ($user,$count) = ($args =~ /^(.+?)$/) unless defined($user);
    
    return ($message->GetType(),"Command not available for the user ".$user)
        if ($user eq &ChatBotNick($fromJID->GetJID()));

    return ("chat","No data found for \"$user\"")
        if !exists($last{$fromJID->GetJID()}->{$user});

    $count = $config{plugins}->{last}->{defaultcount}
    unless (defined($count) && ($count ne ""));
    $count = 1 if ($count < 1);
    $count = ($#{$last{$fromJID->GetJID()}->{$user}} + 1)
        if ($count > ($#{$last{$fromJID->GetJID()}->{$user}} + 1));
    $count -= 1;

    my $string = "Here are the last ".($count+1)." lines from $user:\n";

    foreach my $index (($#{$last{$fromJID->GetJID()}->{$user}}-$count)..$#{$last{$fromJID->GetJID()}->{$user}})
    {
        my $timeStamp = &Net::Jabber::GetTimeStamp("utc",$last{$fromJID->GetJID()}->{$user}->[$index]->{time},"shortest");

        $string .= "[$timeStamp UTC]".$last{$fromJID->GetJID()}->{$user}->[$index]->{body}."\n";
    }

    return ("chat",$string);
}


##############################################################################
#
# plugin_last_message - track the last x things a user said
#
##############################################################################
sub plugin_last_message
{
    my $message = shift;

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"last");

    return if ($fromJID->GetResource() eq &ChatBotNick($fromJID->GetJID()));

    if ($fromJID->GetResource() ne "")
    {
        my $channel = $fromJID->GetJID();
        my $nick = $fromJID->GetResource();
        if ($#{$last{$channel}->{$nick}} == ($config{plugins}->{last}->{maxmessages}))
        {
            shift(@{$last{$channel}->{$nick}});
        }
        push(@{$last{$channel}->{$nick}},{time=>time,body=>$message->GetBody()});
    }

    return;
}


##############################################################################
#
# plugin_last_garbage_collect - clean up the old messages
#
##############################################################################
sub plugin_last_garbage_collect
{

    foreach my $channel (keys(%last))
    {
        foreach my $nick (keys(%{$last{$channel}}))
        {
            foreach my $index (reverse(0..$#{$last{$channel}->{$nick}}))
            {
                splice(@{$last{$channel}->{$nick}},$index,1)
                    if ((time - $last{$channel}->{$nick}->[$index]->{time}) >=
                        ($config{plugins}->{last}->{daystolive} * 86400));
            }
        }
    }

    return;
}


1;
