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
#  Copyright (C) 2007 Stefan Strigler <steve@zeank.in-berlin.de>
##############################################################################

##############################################################################
#
# ChatBot Plugin PlugIn - enables chatbot to (re)load plugins (hot deployment)
#
# Plugins are automatically being reloaded if a change of the file is
# being detected. The Plugin must use the new RegisterPlugin call if
# it needs some initialization/finalization.
#
# Moreover a command 'load' is being supplied that allowes to load
# additional plugins at runtime.
##############################################################################

use strict;

my %Stat;
##############################################################################
#
# Register Plugin
#
##############################################################################
&RegisterPlugin(name     => "plugin",
                init     => \&plugin_plugin_init,
                finalize => \&plugin_plugin_finalize,
                commands => [{command=>"!load",
                              alias=>"!l",
                              handler=>\&plugin_plugin_load,
                              desc=>"Tell ChatBot to load a plugin.",
                              usage=>"<password> <plugin>"}]);

##############################################################################
#
# plugin_plugin_init
#
##############################################################################
sub plugin_plugin_init
  {
    &RegisterTimingEvent(time,"plugin_plugin_tick",\&plugin_plugin_tick);
  }
##############################################################################
#
# plugin_plugin_finalize
#
##############################################################################
sub plugin_plugin_finalize
  {
    &ClearTimingEvent("plugin_plugin_tick");
  }

##############################################################################
#
# plugin_plugin_load
#
##############################################################################
sub plugin_plugin_load
  {
    my $message = shift;
    my $args = shift;

    my $fromJID = $message->GetFrom("jid");

    my ($password, $plugin) = ($args =~ /^\s*(\S+)\s+(\S+)\s*$/);

    return ($message->GetType(),"The command was in error.")
      if !defined($password);
    return ($message->GetType(),"Permission denied.")
      unless &CheckPassword("plugin",$password);

    # load plugin
    return ($message->GetType(), "Failed loading plugin '$plugin'")
      unless require "$config{chatbot}->{plugindir}/${plugin}.pl";

    # call init handler if available
    &PluginInit($plugin);

    return ($message->GetType(),"Plugin '$plugin' loaded");
  }

##############################################################################
#
# plugin_plugin_tick
#
##############################################################################
sub plugin_plugin_tick
  {
    my $c=0;
    while (my($key,$file) = each %INC) {
      next if $file eq 
        $INC{"$config{chatbot}->{plugindir}/plugin.pl"};  #too confusing
      next unless grep /$config{chatbot}->{plugindir}/, $file;
      local $^W = 0;
      my $mtime = (stat $file)[9];
      $Stat{$file} = $^T
        unless defined $Stat{$file};
      $Debug->Log1("stat '$file' got $mtime >? $Stat{$file}");
      if ($mtime > $Stat{$file}) {
        my ($plugin) = ($file =~ /^.*\/(.+)\.pl$/);
        &PluginFinalize($plugin);

        delete $INC{$key};
        eval { 
          local $SIG{__WARN__} = \&warn;
          require $key;
        };
        if ($@) {
          $Debug->Log0("error during reload of '$key': $@");
        }
        &PluginInit($plugin);
        $Debug->Log0("process $$ reloaded '$key'");
        ++$c;
      }
      $Stat{$file} = $mtime;

    }
    $Debug->Log0("plugins reloaded: $c") if $c;
    &RegisterTimingEvent(time+1,"plugin_plugin_tick",\&plugin_plugin_tick);
  }

1;
