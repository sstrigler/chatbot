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
# ChatBot Help PlugIn - Handles printing out the available commands, usage and
#                       descriptions for each one.
#
##############################################################################

use strict;

##############################################################################
#
# Register events
#
##############################################################################
&RegisterEvent("register_help",\&plugin_help_register_help);
&RegisterCommand(command=>"help",
                 handler=>\&plugin_help_help,
                 desc=>"Prints out the help for a command.  To find the list of available commands use the \"!commands\" or the \"!list\" command.",
                 usage=>"<command>");
&RegisterCommand(command=>"!commands",
                 alias=>"!list",
                 handler=>\&plugin_help_commands,
                 desc=>"Lists all of the current available commands.");


##############################################################################
#
# plugin_help_register_help - record the help message for use in the
#                                     help command.
#
##############################################################################
sub plugin_help_register_help
{
    my $command = shift;
    my $alias = shift;
    my $usage = shift;
    my $desc = shift;
    my $examples = shift;

    $plugin_env{help}->{help}->{$command}->{alias} = $alias;
    $plugin_env{help}->{alias}->{$alias} = $command;
    $plugin_env{help}->{help}->{$command}->{usage} = $usage;
    $plugin_env{help}->{help}->{$command}->{desc} = $desc;
    $plugin_env{help}->{help}->{$command}->{examples} = $examples;
}


##############################################################################
#
# plugin_help_help - print out the help message for a command
#
##############################################################################
sub plugin_help_help
{
    my $message = shift;
    my $command = shift;

    $command = "help" unless (defined($command) && ($command ne ""));

    $command = $plugin_env{help}->{alias}->{$command} if exists($plugin_env{help}->{alias}->{$command});

    return ("chat","unknown command \"$command\"")
        unless exists($plugin_env{help}->{help}->{$command});

    my $string;
    $string .= "\n";
    $string .= "usage: $command $plugin_env{help}->{help}->{$command}->{usage}\n";
    $string .= "usage: $plugin_env{help}->{help}->{$command}->{alias} $plugin_env{help}->{help}->{$command}->{usage}\n"
        if ($plugin_env{help}->{help}->{$command}->{alias} ne "");
    $string .= "  $plugin_env{help}->{help}->{$command}->{desc}\n";
    if ($#{$plugin_env{help}->{help}->{$command}->{examples}} > -1)
    {
        $string .= "  examples:\n";
        foreach my $example (@{$plugin_env{help}->{help}->{$command}->{examples}})
        {
            $string .= "    - $example\n";
        }
    }
    chomp($string);
    return ("chat",$string);
}


##############################################################################
#
# plugin_help_commands - prints out the list of available commands
#
##############################################################################
sub plugin_help_commands
{
    my $message = shift;
    my $command = shift;

    my $string;
    foreach my $command (sort {$a cmp $b} keys(%{$plugin_env{help}->{help}}))
    {
        $string .= $command;
        $string .= " ($plugin_env{help}->{help}->{$command}->{alias})"
            if ($plugin_env{help}->{help}->{$command}->{alias} ne "");
        $string .= ", ";
    }
    $string =~ s/\, $//;

    return ("chat",$string);
}


1;
