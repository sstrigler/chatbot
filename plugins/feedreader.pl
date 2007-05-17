#!/usr/bin/perl
#
# rss.pl - chatbot plugin for handling rss feeds
#
# Copyright (c) 2005-2007 Stefan Strigler <steve@zeank.in-berlin.de>
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
#
# adopted from janchor.pl by Jeremy Nickurak, 2002

# BEGIN EXTRA CONFIGURATION
use constant RSS_DELAY => 10;     # Interval for RSS checks. Note that
                                 # many sites will be very upset if
                                 # you use less then a 30 minute
                                 # delay, notably, slashdot.
use constant RSS_TIMEOUT => 15;  # Timeout for HTTP connections to RSS
                                 # sources
use constant SUB_FILE     => 'rss_subscriptions'; # Subscription DB
use constant CACHE_FILE   => 'rss_cache';     # RSS Cache DB
use constant SOURCE_FILE  => 'rss_sources';   # Source DB
use constant STATUS_FILE  => 'rss_status';    # Source Status DB
use constant VERBOSE => 2;                    # Verbosity level for
                                              # logging output

# END EXTRA CONFIGURATION
use constant VERSION	=> '0.3';
use Data::Dumper;
use MLDBM 'DB_File';
use Text::Iconv;
use LWP::UserAgent;
use XML::RSS;

use strict;

# DB-tied hashes
my %sub;
my %cache;
my %sources;
my %status;

# my user agent
my $ua = new LWP::UserAgent(timeout=>RSS_TIMEOUT);

# ###
# register events
# ###

&RegisterEvent("startup",\&plugin_rss_startup);
&RegisterEvent("shutdown",\&plugin_rss_shutdown);

&RegisterCommand(command=>"!rss_list",
                 handler=>\&plugin_rss_list,
                 desc=>"list subscribed feeds");

&RegisterCommand(command=>"!rss_subscribe",
                 handler=>\&plugin_rss_subscribe,
                 desc=>"subscribe RSS feed",
                 usage=>"<password> <name> <url>");

&RegisterCommand(command=>"!rss_unsubscribe",
                 handler=>\&plugin_rss_unsubscribe,
                 desc=>"unsubscribe RSS feed".
                 usage=>"<password> <name>");

# ###
# register flag
# ###
&RegisterFlag('rss');

# ###
# callbacks
# ###
sub plugin_rss_startup {
  log3("rss-reader starting ...");
  tie (%sub, 'MLDBM', SUB_FILE) or 
    die ("Cannot tie to " . SUB_FILE."!\n");
  tie (%cache, 'MLDBM', CACHE_FILE) or 
    die ("Cannot tie to " . CACHE_FILE."!\n");
  tie (%sources, 'MLDBM', SOURCE_FILE) or 
    die ("Cannot tie to " . SOURCE_FILE."!\n");
  tie (%status, 'MLDBM', STATUS_FILE) or 
    die ("Cannot tie to " . STATUS_FILE."!\n");


  &RegisterTimingEvent(time,"rss_tick",\&plugin_rss_dotick);
}

sub plugin_rss_shutdown {
  log3("rss-reader exiting ...");

  ClearTimingEvent("rss_tick");
	
  untie %sub;
  untie %cache;
  untie %sources;
  untie %status;
}

sub plugin_rss_list {
  my $message = shift;

  my $fromJID = $message->GetFrom("jid");
  return unless &CheckFlag($fromJID->GetJID(),"rss");

  my $txt = '';
  if (exists($sub{$fromJID->GetJID()})) {
    foreach (keys %{$sub{$fromJID->GetJID()}}) {
      $txt .= $sub{$fromJID->GetJID()}->{$_}.': '.$_."\n";
    }
  } else {
    $txt = "You're not subscribed to any feed";
  }

  return ($message->GetType(),$txt);
}

sub plugin_rss_subscribe {
  my $message = shift;
  my $args = shift;

  my $fromJID = $message->GetFrom("jid");
  return unless &CheckFlag($fromJID->GetJID(),"rss");

  my ($password,$name,$url) = ($args =~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s*$/);
	
  return ($message->GetType(),"The command was in error.")
    if !defined($password);
  return ($message->GetType(),"Permission denied.")
    unless &CheckPassword("rss",$password);
	
  if (exists($sub{$fromJID->GetJID()})) {
    my %feeds = ($url => $name);
    $sub{$fromJID->GetJID()}->{$url} = $name;
    log2(Data::Dumper->Dump([$sub{$fromJID->GetJID()}]));
  } else {
    my %feeds = ($url => $name);
    $sub{$fromJID->GetJID()} = \%feeds;
  }

  $sources{$url} = (
     'errors' => 0,
     'last' => 0)
  unless (grep $url, keys %sources);

  # run schedular to fetch this one
  &ClearTimingEvent('rss_tick');
  &RegisterTimingEvent(time,"rss_tick",\&plugin_rss_dotick);

  return ($message->GetType(),"Sucessfully added $name ($url).");
}

sub plugin_rss_unsubscribe {
  my $message = shift;
  my $args = shift;

  my $fromJID = $message->GetFrom("jid");
  return unless &CheckFlag($fromJID->GetJID(),"rss");

  my ($password,$name) = ($args =~ /^\s*(\S+)\s+(\S+)\s*$/);

  return ($message->GetType(),"The command was in error.")
    if !defined($password);
  return ($message->GetType(),"Permission denied.")
    unless &CheckPassword("rss",$password);

  #delete $sources{lc($name)}; 
  return ($message->GetType(),"Sucessfully unsubscribed from $name.");
}

sub plugin_rss_dotick {
  log3("tick");
	
  # loop sources
  foreach my $url (sort (keys %sources)) {
    log2("checking $url");

    my $req = $ua->get($url);
    if (!$req->is_success) {
      log3($req->status_line);
      next;
    }

    my $rss = new XML::RSS();
    eval { ## try ###
      $rss->parse($req->content);
    };
    if ($@) { ### catch ###
      log1("Malformed XML on source $url:".$@);
      next;
    }
		
    my @items = @{$rss->{items}};
    log3("got ".@items." items");

    # Discover any new items
    log3("Looking for new items");

    my %temp_items = ();
    log3("after reset");
    # Deterimine & record whether this is a new url.
    my $new_url = 0;
    log3("after new init");
    if (exists $cache{$url}) {
      log3("Not new url");
    } else {
      log3("New url");
      $new_url = 1;
    }
    log3("Iterating.");

    foreach my $item (@items) {
      my $key = $item->{title};
      $key = $item->{url} unless $key;
      $key = $url unless $key;
      $temp_items{$key} = 1;
      delete $cache{$url} unless (ref($cache{$url}) eq 'HASH');
      if ($new_url or not exists $cache{$url}->{$key}) {
				# New item.
	
        log2("New item from $url - $key");

        # Broadcast the message, IFF this isn't our first encounter
        # with this url.
        if (not $new_url) {
          my @channels = &Channels();
          foreach my $chan (@channels) {
            next unless &CheckFlag($chan,"rss");
            my $msg = new Net::Jabber::Message();
            $msg->SetMessage(type=>'groupchat',
                           body =>("[".$sub{$chan}->{$url}."] ".
                                   $item->{title}."\n".$item->{link}));
            $msg->SetTo($chan);
            &Send($msg);
          }
        }

        # Remember that we've seen it.
        my $element = $cache{$url};
        $element->{$key} = 1;
        $cache{$url} = $element;
      }
    }

    # Forget cached items that have since been removed from their source.
    my $cached_items = $cache{$url};
    foreach my $key (keys(%$cached_items)) {
      delete $cached_items->{$key} 
        unless defined($temp_items{$key});
      log1("Killing ${url}'s cache for $key.")
        unless defined($temp_items{$key});
    }

    $cache{$url} = $cached_items;
										
  }
	
  &ScheduleNextTick();
}

sub ScheduleNextTick {
  &RegisterTimingEvent(time+RSS_DELAY,"rss_tick",\&plugin_rss_dotick);
}

# ###
# da bug
# ###
sub log1 {
  # WARN
  my $msg = shift;
  return unless VERBOSE >= 1;
  print STDERR "WARN: $msg\n";
}

sub log2 {
  # INFO
  my $msg = shift;
  return unless VERBOSE >= 2;
  print "INFO: $msg\n";
}

sub log3 {
  # DBUG
  my $msg = shift;
  return unless VERBOSE >= 3;
  print "DBUG: $msg\n";
}
