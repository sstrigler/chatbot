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
# ChatBot Dice Roller PlugIn - Handles rolling dice and generating D&D
#                              characters
#
##############################################################################

use strict;

##############################################################################
#
# Register Events
#
##############################################################################
&RegisterCommand(command=>"!roll",
                 handler=>\&plugin_dice_roll,
                 desc=>"Rolls a die combination for you.",
                 usage=>"<num_die>D<size_die>[+<modifier>][%]",
                 examples=>["4D6","1D20+2","D%","D+4%"]);
&RegisterCommand(command=>"!rollall",
                 handler=>\&plugin_dice_rollall,
                 desc=>"Rolls a die combination for everyone in the channel.",
                 usage=>"<num_die>D<size_die>[+<modifier>][%]",
                 examples=>["4D6","1D20+2","D%","D+4%"]);
&RegisterCommand(command=>"!chargen",
                 handler=>\&plugin_dice_chargen,
                 desc=>"Generates the stats for a character using the 4D6 drop two lowest method.");


##############################################################################
#
# Register Flags
#
##############################################################################
&RegisterFlag("dice");


##############################################################################
#
# Define config variables
#
##############################################################################
$config{plugins}->{dice}->{maxsize} = 1000000
    unless exists($config{plugins}->{dice}->{maxsize});
$config{plugins}->{dice}->{maxdie} = 20
    unless exists($config{plugins}->{dice}->{maxdie});
$config{plugins}->{dice}->{defaultsize} = 6
    unless exists($config{plugins}->{dice}->{defaultsize});
$config{plugins}->{dice}->{defaultdie} = 1
    unless exists($config{plugins}->{dice}->{defaultdie});


##############################################################################
#
# plugin_dice_rollthebones - do the actual die rolling for everyone
#                                    listed and return the results.
#
##############################################################################
sub plugin_dice_rollthebones
{
    my $type = shift;
    my $die = shift;
    my (@list) = @_;

    my ($numDie,$sizeDie,$rollMod,$percent) = ($die =~ /(\d*)d(\d*)([-+\*\/]?\d*)(\%?)/i);

    if ($percent eq "%")
    {
        $numDie = 2;
        $sizeDie = 10;
    }

    $numDie = $config{plugins}->{dice}->{defaultdie} if ($numDie eq "");
    $numDie = $config{plugins}->{dice}->{maxdie}
    if ($numDie > $config{plugins}->{dice}->{maxdie});
    $sizeDie = $config{plugins}->{dice}->{defaultsize} if ($sizeDie eq "");
    $sizeDie = $config{plugins}->{dice}->{maxsize}
    if ($sizeDie > $config{plugins}->{dice}->{maxsize});
    my $origRollMod = $rollMod;
    $rollMod =~ s/([-+\*\/])/$1 /;

    my @response;

    my $response = "";
    foreach my $player (@list)
    {

        my $total = 0;
        my @roll;
        foreach my $count (0..($numDie-1))
        {
            $roll[$count] = int(rand($sizeDie)) + 1;
            $roll[$count] = 0 if (($percent eq "%") && ($roll[$count] eq "10"));
            $total += $roll[$count];
        }
        
        if ($percent eq "%")
        {
            $total = $roll[0].$roll[1];
            $total = 100 if ($total eq "00");
        }

        eval("\$total = \$total $rollMod");

        if ($percent eq "%")
        {
            $total .= "%";
        }

        $response .= "rolling for ".$player." ${numDie}D${sizeDie}${origRollMod}${percent}: ";
        my $breakdown = "[ ".join(" + ",@roll)." ] " if ($numDie > 1);

        $response .= (length($breakdown) <= 100) ? $breakdown : "[ ... ] ";
        $response .= $roll[0]." " if (($numDie == 1) && ($rollMod ne ""));
        $response .= "$rollMod " if ($rollMod ne "");
        $response .= "= " if (($rollMod ne "") || ($numDie > 1));
        $response .= $total;
        $response .= "\n";
    }
    chomp($response);
    push(@response,$type,$response);

    return @response;
}


##############################################################################
#
# plugin_dice_roll - roll the die for you alone
#
##############################################################################
sub plugin_dice_roll
{
    my $message = shift;
    my $die = shift;

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"dice");

    return &plugin_dice_rollthebones($message->GetType(),$die,$fromJID->GetResource());
}


##############################################################################
#
# plugin_dice_rollall - roll the die for everyone in the channel
#
##############################################################################
sub plugin_dice_rollall
{
    my $message = shift;
    my $die = shift;

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"dice");

    my @list;
    foreach my $player (sort {$a cmp $b} &CurrentUsers($fromJID->GetJID()))
    {
        next if ($player eq &ChatBotNick($fromJID->GetJID()));
        next if ($player eq "DM");
        next if ($player =~ /Dungeon.*Master/i);
        push(@list,$player);
    }

    return &plugin_dice_rollthebones($message->GetType(),$die,@list);
}


##############################################################################
#
# plugin_dice_chargen - roll a 5D6, drop the lowest roll, and add them
#                               together, six times.  These numbers are valid
#                               for starting a new character.
#
##############################################################################
sub plugin_dice_chargen
{
    my $message = shift;
    my $args = shift;

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"dice");

    my $response = "Generating new character: ";
    foreach my $stat (0..5)
    {

        my $total = 0;
        my @roll;
        foreach my $count (0..4)
        {
            $roll[$count] = int(rand(6)) + 1;
            $total += $roll[$count];
        }
        @roll = sort {$a <=> $b} @roll;
        $total -= $roll[0] + $roll[1];

        $response .= " $total,";
    }
    $response =~ s/\,$//;

    return ($message->GetType(),$response);
}


1;
