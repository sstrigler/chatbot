#!/usr/bin/perl
#
# feedreader.pl - chatbot plugin for handling rss feeds
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
use constant SUB_FILE     => 'feedreader_sub';       # Subscription DB
use constant CACHE_FILE   => 'feedreader_cache';     # RSS Cache DB
use constant SOURCE_FILE  => 'feedreader_sources';   # Source DB
use constant STATUS_FILE  => 'feedreader_status';    # Source Status DB

# END EXTRA CONFIGURATION
use constant VERSION	=> '1.0';
use Data::Dumper;
use MLDBM 'DB_File';
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
my %sub;
my %cache;
my %sources;
my %status;

# ###
# register plugin
# ###
&RegisterPlugin(name     => 'feedreader',
                flag     => 'feedreader',
                init     => \&plugin_feedreader_init,
                finalize => \&plugin_feedreader_finalize,
                commands => [{command=>"!feed_list",
                              handler=>\&plugin_feed_list,
                              desc=>"list subscribed feeds"},
                             {command=>"!feed_subscribe",
                              handler=>\&plugin_feed_subscribe,
                              desc=>"subscribe feed",
                              usage=>"<password> <name> <url>"},
                             {command=>"!feed_unsubscribe",
                              handler=>\&plugin_feed_unsubscribe,
                              desc=>"unsubscribe feed".
                              usage=>"<password> <name>"}]);

# ###
# INIT
# ###
sub plugin_feedreader_init {
  $Debug->Log0("feedreader starting ...");

  tie (%sub, 'MLDBM', SUB_FILE) or 
    die ("Cannot tie to " . SUB_FILE."!\n");
  tie (%cache, 'MLDBM', CACHE_FILE) or 
    die ("Cannot tie to " . CACHE_FILE."!\n");
  tie (%sources, 'MLDBM', SOURCE_FILE) or 
    die ("Cannot tie to " . SOURCE_FILE."!\n");
  tie (%status, 'MLDBM', STATUS_FILE) or 
    die ("Cannot tie to " . STATUS_FILE."!\n");

  $ua = new LWP::UserAgent(timeout=>RSS_TIMEOUT);

  &RegisterTimingEvent(time,"feed_tick",\&plugin_feed_dotick);
}

# ###
# FINALIZE
# ###
sub plugin_feedreader_finalize {
  $Debug->Log0("feedreader exiting ...");

  ClearTimingEvent("feed_tick");
	
  untie %sub;
  untie %cache;
  untie %sources;
  untie %status;
}

# ###
# LIST
# ###
sub plugin_feed_list {
  $Debug->Log0("feed list");
  my $message = shift;

  my $fromJID = $message->GetFrom("jid");
  return unless &CheckFlag($fromJID->GetJID(),"feedreader");

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

# ###
# SUBSCRIBE
# ###
sub plugin_feed_subscribe {
  my $message = shift;
  my $args = shift;

  my $fromJID = $message->GetFrom("jid");
  return unless &CheckFlag($fromJID->GetJID(),"feedreader");

  my ($password,$name,$url) = ($args =~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s*$/);
	
  return ($message->GetType(),"The command was in error.")
    if !defined($password);
  return ($message->GetType(),"Permission denied.")
    unless &CheckPassword("feedreader",$password);
	
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
  &ClearTimingEvent('feed_tick');
  &RegisterTimingEvent(time,"feed_tick",\&plugin_feed_dotick);

  return ($message->GetType(),"Sucessfully added $name ($url).");
}

# ###
# UNSUBSCRIBE
# ###
sub plugin_feed_unsubscribe {
  my $message = shift;
  my $args = shift;

  my $fromJID = $message->GetFrom("jid");
  return unless &CheckFlag($fromJID->GetJID(),"feedreader");

  my ($password,$name) = ($args =~ /^\s*(\S+)\s+(\S+)\s*$/);

  return ($message->GetType(),"The command was in error.")
    if !defined($password);
  return ($message->GetType(),"Permission denied.")
    unless &CheckPassword("feedreader",$password);

  #delete $sources{lc($name)};
  return ($message->GetType(),"Sucessfully unsubscribed from $name.");
}

# ###
# TICK
# ###
sub plugin_feed_dotick {
  $Debug->Log0("feed tick");
	
  # loop sources
  foreach my $url (sort (keys %sources)) {
    $Debug->Log0("checking $url");

    my $req = $ua->get($url);
    if (!$req->is_success) {
      $Debug->Log1($req->status_line);
      next;
    }

    my $rss = new XML::RSS();
    eval { ## try ###
      $rss->parse($req->content);
    };
    if ($@) { ### catch ###
      $Debug->Log0("Malformed XML on source $url:".$@);
      next;
    }
		
    my @items = @{$rss->{items}};
    $Debug->Log1("got ".@items." items");

    # Discover any new items
    $Debug->Log1("Looking for new items");

    my %temp_items = ();
    # Deterimine & record whether this is a new url.
    my $new_url = 0;
    if (exists $cache{$url}) {
      $Debug->Log1("Not new url");
    } else {
      $Debug->Log1("New url");
      $new_url = 1;
    }

    foreach my $item (@items) {
      my $key = $item->{title};
      $key = $item->{url} unless $key;
      $key = $url unless $key;
      $temp_items{$key} = 1;
      delete $cache{$url} unless (ref($cache{$url}) eq 'HASH');
      if ($new_url or not exists $cache{$url}->{$key}) {
				# New item.
	
        $Debug->Log1("New item from $url - $key");

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
      $Debug->Log0("Killing ${url}'s cache for $key.")
        unless defined($temp_items{$key});
    }

    $cache{$url} = $cached_items;
  }

  &RegisterTimingEvent(time+RSS_DELAY,"feed_tick",\&plugin_feed_dotick);
}

1;
