#!/usr/bin/perl
#
# feedreader.pl - chatbot plugin for handling (rss) feeds
# adopted from janchor.pl by Jeremy Nickurak, 2002
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

# BEGIN EXTRA CONFIGURATION

# Interval for RSS checks in seconds. Note that many sites will be
# very upset if you use less then a 30 minute delay, notably,
# slashdot.
use constant RSS_DELAY => 10;

# Timeout for HTTP connections to RSS sources
use constant RSS_TIMEOUT => 15;

# RSS Cache DB
use constant CACHE_FILE   => 'feedreader_cache';

# Source DB
use constant SOURCE_FILE  => 'feedreader_sources';

# END EXTRA CONFIGURATION


use constant VERSION	=> '1.0';
use Data::Dumper;
use MLDBM qw(DB_File Storable);
use Text::Iconv;
use LWP::UserAgent;
use XML::RSS;

use strict;

# ###
# globals
# ###
my $ua;

# ###
# DB-tied hashes
# ###
my %cache;
my %sources;

# ###
# register plugin
# ###
&RegisterPlugin(name     => 'feedreader',
                flag     => 'feedreader',
                init     => \&plugin_feedreader_init,
                finalize => \&plugin_feedreader_finalize,
                commands =>
                [{command=>"!feed_list",
                  alias=>"!fl",
                  handler=>\&plugin_feed_list,
                  desc=>"list subscribed feeds"},
                 {command=>"!feed_subscribe",
                  alias=>"!fs",
                  handler=>\&plugin_feed_subscribe,
                  desc=>"subscribe feed",
                  usage=>"<password> <name> <url>"},
                 {command=>"!feed_unsubscribe",
                  alias=>"!fu",
                  handler=>\&plugin_feed_unsubscribe,
                  desc=>"unsubscribe feed".
                  usage=>"<password> <url>"}]);

# ###
# INIT
# ###
sub plugin_feedreader_init {
  tie (%cache, 'MLDBM', CACHE_FILE) or 
    die ("Cannot tie to " . CACHE_FILE."!\n");
  tie (%sources, 'MLDBM', SOURCE_FILE) or 
    die ("Cannot tie to " . SOURCE_FILE."!\n");

  $ua = new LWP::UserAgent(timeout=>RSS_TIMEOUT);

  &RegisterTimingEvent(time,"feed_tick",\&plugin_feed_dotick);
}

# ###
# FINALIZE
# ###
sub plugin_feedreader_finalize {
  ClearTimingEvent("feed_tick");
	
  untie %cache;
  untie %sources;
}

# ###
# LIST
# ###
sub plugin_feed_list {
  my $message = shift;

  my $fromJID = $message->GetFrom("jid");
  return unless &CheckFlag($fromJID->GetJID(),"feedreader");

  my $header = $fromJID->GetJID()." is subscribed to:";
  my $txt = $header;

  foreach my $feed (keys %sources) {
    $txt .= "\n" . $sources{$feed}->{$fromJID->GetJID()} . ": " . $feed
      if (exists($sources{$feed}->{$fromJID->GetJID()}));
  }

  $txt = $fromJID->GetJID()." is not subscribed to any feed"
    if ($txt eq $header);

  return ($message->GetType(),$txt);
}

# ###
# SUBSCRIBE
# ###
sub plugin_feed_subscribe {
  my $message = shift;
  my $args = shift;

  my $fromJID = $message->GetFrom("jid");
  return unless &CheckFlag($fromJID->GetJID(),"feedreader");

  my ($password,$name,$feed) = ($args =~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s*$/);
	
  return ($message->GetType(),"The command was in error.")
    if !defined($password);
  return ($message->GetType(),"Permission denied.")
    unless &CheckPassword("feedreader",$password);

  if (exists($sources{$feed})) {
    my $tmp = $sources{$feed};
    $tmp->{$fromJID->GetJID()} = $name;
    $sources{$feed} = $tmp
  } else {
    $sources{$feed} = {$fromJID->GetJID() => $name};
  }

  # run scheduler to fetch this one
  &ClearTimingEvent('feed_tick');
  &RegisterTimingEvent(time,"feed_tick",\&plugin_feed_dotick);

  return ($message->GetType(),"Sucessfully subscribed to $feed as $name.");
}

# ###
# UNSUBSCRIBE
# ###
sub plugin_feed_unsubscribe {
  my $message = shift;
  my $args = shift;

  my $fromJID = $message->GetFrom("jid");
  return unless &CheckFlag($fromJID->GetJID(),"feedreader");

  my ($password, $feed) = ($args =~ /^\s*(\S+)\s+(\S+)\s*$/);

  return ($message->GetType(),"The command was in error.")
    if !defined($password);
  return ($message->GetType(),"Permission denied.")
    unless &CheckPassword("feedreader",$password);

  return ($message->GetType(),"No such feed: $feed.")
    unless exists $sources{$feed};

  return ($message->GetType(),
          $fromJID->GetJID()." is not subscribed to $feed.")
    unless exists $sources{$feed}->{$fromJID->GetJID()};

  my $tmp = $sources{$feed};
  delete $tmp->{$fromJID->GetJID()};
  $sources{$feed} = $tmp;

  delete $sources{$feed} unless (keys %{$sources{$feed}});

  return ($message->GetType(),"Sucessfully unsubscribed from $feed.");
}

# ###
# TICK
# ###
sub plugin_feed_dotick {	
  # loop sources
  foreach my $feed (keys %sources) {
    $Debug->Log0("checking $feed");

    my $req = $ua->get($feed);
    if (!$req->is_success) {
      $Debug->Log1($req->status_line);
      next;
    }

    my $rss = new XML::RSS();
    eval { ## try ###
      $rss->parse($req->content);
    };
    if ($@) { ### catch ###
      $Debug->Log0("Malformed XML on source $feed:".$@);
      next;
    }
		
    my @items = @{$rss->{items}};
    $Debug->Log1("got ".@items." items");

    # Discover any new items
    $Debug->Log1("Looking for new items");

    my %temp_items = ();
    # Deterimine & record whether this is a new url.
    my $new_url = exists $cache{$feed} ? 0 : 1;

    foreach my $item (@items) {
      my $key = $item->{title};
      $key = $item->{url} unless $key;
      $key = $feed unless $key;
      $temp_items{$key} = 1;
      delete $cache{$feed} unless (ref($cache{$feed}) eq 'HASH');
      if ($new_url or not exists $cache{$feed}->{$key}) {
        # New item.
	
        $Debug->Log1("New item from $feed - $key");

        # Broadcast the message, IFF this isn't our first encounter
        # with this url.
        if (not $new_url) {
          my @channels = &Channels();
          foreach my $chan (@channels) {
            next unless &CheckFlag($chan,"feedreader");
            next unless exists($sources{$feed}->{$chan});
            my $msg = new Net::Jabber::Message();
            $msg->SetMessage(type=>'groupchat',
                             body =>("[".$sources{$feed}->{$chan}."] ".
                                     $item->{title}."\n".$item->{link}));
            $msg->SetTo($chan);
            &Send($msg);
          }
        }

        # Remember that we've seen it.
        my $element = $cache{$feed};
        $element->{$key} = 1;
        $cache{$feed} = $element;
      }
    }

    # Forget cached items that have since been removed from their source.
    my $cached_items = $cache{$feed};
    foreach my $key (keys(%$cached_items)) {
      delete $cached_items->{$key} 
        unless defined($temp_items{$key});
      $Debug->Log0("Killing ${feed}'s cache for $key.")
        unless defined($temp_items{$key});
    }

    $cache{$feed} = $cached_items;
  }

  &RegisterTimingEvent(time+RSS_DELAY,"feed_tick",\&plugin_feed_dotick);
}

1;
