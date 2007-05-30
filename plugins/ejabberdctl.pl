#!/usr/bin/perl
#
# ejabberdctl.pl - control ejabberd using chatbot
#
# Copyright (c) 2007 Stefan Strigler <sstrigler@mediaventures.de>
#
# !!! WARNING !!!
#
# please be aware that using this plugin might introduce serious
# security concerns to your jabber server infrastructre. make sure you
# really know what you're doing when activating this plugin.
#
# !!! WARNING !!!
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# ###
# BEGIN EXTRA CONFIGURATION
# ###
my $ERL="/usr/bin/erl";
my $ERL_COOKIE="";
my $EJABBERD_PA = "/home/zeank/src/ejabberd-svn/src";
my $ERL_DEFAULT_NODE = 'ejabberd@localhost';
# ###
# END EXTRA CONFIGURATION
# ###

# ###
# register plugin
# ###
&RegisterPlugin(name     => 'ejabberdctl',
                flag     => 'ejabberdctl',
                commands =>
                [{command  => "!ejabberdctl",
                  alias    => "!ectl",
                  handler  => \&plugin_ejabberdctl,
                  desc     => "issue an ejabberdctl command",
                  usage    => "!ejabberdctl <password> <node> [vhost] <command>"
                 },
                 {command  => "!ejabberd_connected",
                  alias    => "!econ",
                  handler  => \&plugin_ejabberdctl_connected,
                  desc     => "show number of users connected",
                  usage    => "!ejabberd_connected [node]"}]);

sub plugin_ejabberdctl {
  my $message = shift;
  my $args = shift;

  my $fromJID = $message->GetFrom("jid");
  return unless &CheckFlag($fromJID->GetJID(),"feedreader");

  my ($password,$node,$command) = ($args =~ /^\s*(\S+)\s+(\S+)\s+(.+)$/);

  # check input
  return ($message->GetType(),"The command was in error.")
    if !defined($password);
  return ($message->GetType(),"Permission denied.")
    unless &CheckPassword("ejabberdctl",$password);

  my $call = "$ERL -noinput -sname ejabberdctl -pa $EJABBERD_PA -s ejabberd_ctl ";

  $call .= "-setcookie $ERL_COOKIE " unless ($ERL_COOKIE eq '');

  $call .= "-extra $node $command";

  my $ret = `$call`;

  $Debug->Log0($ret);

  return ($message->GetType(),$ret);
}

sub plugin_ejabberdctl_connected {
  my $message = shift;
  my $args = shift;

  my $fromJID = $message->GetFrom("jid");
  return unless &CheckFlag($fromJID->GetJID(),"ejabberdctl");

  my ($node) = ($args =~ /^\s*(\S+)\s*$/);

  my $call = "$ERL -noinput -sname ejabberdctl -pa $EJABBERD_PA -s ejabberd_ctl ";
  $call .= "-setcookie $ERL_COOKIE " unless ($ERL_COOKIE eq '');
  $call .= "-extra ";
  if ($node ne '') {
    $call .= "$node "
   } else {
      $call .= "$ERL_DEFAULT_NODE ";
    }
  $call .= "connected-users-number";

  return ($message->GetType(),"Connected Users: ".`$call`);
}
