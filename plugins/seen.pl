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
# ChatBot Seen User PlugIn - tracks when all users log in and out, and reports
#                            back the time when they were last seen in this
#                            channel.
#
##############################################################################

use strict;
use vars qw ( %seen );

##############################################################################
#
# Register Events
#
##############################################################################
&RegisterEvent("presence_available",\&plugin_seen_available);
&RegisterEvent("presence_unavailable",\&plugin_seen_unavailable);
&RegisterEvent("groupchat_message",\&plugin_seen_active);
&RegisterCommand(command=>"!seen",
		 handler=>\&plugin_seen_seen,
		 desc=>"Prints the last time this user was seen in the channel.",
		 usage=>"<user>");


##############################################################################
#
# Register Flags
#
##############################################################################
&RegisterFlag("seen");


##############################################################################
#
# Define config variables
#
##############################################################################
$config{plugins}->{seen}->{storage} = "./seen_storage.xml"
  unless exists($config{plugins}->{seen}->{storage});


##############################################################################
#
# Get the seen data back in here...
#
##############################################################################
do $config{plugins}->{seen}->{storage}
  if (-e $config{plugins}->{seen}->{storage});

##############################################################################
#
# plugin_seen_seen - check the seen hash and report back to the user.
#
##############################################################################
sub plugin_seen_seen {
  my $message = shift;
  my $user = shift;

  return if ($user eq "");

  my $fromJID = $message->GetFrom("jid");

  return unless &CheckFlag($fromJID->GetJID(),"seen");

  my @response;

  #---------------------------------------------------------------------------
  # If we did not do "seen ChatBot" then...
  #---------------------------------------------------------------------------
  if ($user ne &ChatBotNick($fromJID->GetJID())) {

    #-------------------------------------------------------------------------
    # The user is not in the channel
    #-------------------------------------------------------------------------
    if (!exists($seen{$fromJID->GetJID()}->{$user})) {
	
      my $matchuser = $user;
      $matchuser =~ s/([\\\/\?\+\.\*])/\\$1/g;

      #-----------------------------------------------------------------------
      # Look for them in the other chatbot channels
      #-----------------------------------------------------------------------
      my @found;
      foreach my $channel (keys(%seen)) {
	next if ($channel eq $fromJID->GetJID());

	foreach my $nick (keys(%{$seen{$channel}})) {
	  my $lcnick = lc($nick);
	  if ($lcnick =~ /$matchuser/i) {
	    if ($seen{$channel}->{$nick}->{status} eq "on") {
	      if ((time - $seen{$channel}->{$nick}->{time}) <= 60) {
		push(@found, $channel."/".$nick."  active");
	      } else {
		push(@found, $channel."/".$nick);
	      }
	    }
	  }
	}
      }

      #-----------------------------------------------------------------------
      # Tell the channel that chatbot doesn't know that user.
      #-----------------------------------------------------------------------
      push(@response,$message->GetType(),"I have never had the pleasure of meeting \"$user\"");

      #-----------------------------------------------------------------------
      # If the nick was found in other channels then private chat it them.
      #-----------------------------------------------------------------------
      push(@response,"chat","The user has not been in this channel, but I have found the following nicks in these channels:\n - ".join("\n - ",@found))
	if ($#found > -1);


    #-------------------------------------------------------------------------
    # ... the user is in the channel ...
    #-------------------------------------------------------------------------
    } else {
      #-----------------------------------------------------------------------
      # and they are logged in right now
      #-----------------------------------------------------------------------
      if ($seen{$fromJID->GetJID()}->{$user}->{status} eq "on") {
	push(@response,$message->GetType(),"$user is in the channel right now...");

      #-----------------------------------------------------------------------
      # and they are *not* logged in
      #-----------------------------------------------------------------------
      } else {
	my $seconds = time - $seen{$fromJID->GetJID()}->{$user}->{time};
	my $minutes = 0;
	my $hours = 0;
	my $days = 0;
	
	while ($seconds >= 60) {
	  $minutes++;
	  if ($minutes == 60) {
	    $hours++;
	    if ($hours == 24) {
	      $days++;
	      $hours -= 24;
	    }	
	    $minutes -= 60;
	  }	
	  $seconds -= 60;
	}
	
	my $response = "Last seen ";
	$response .= "$days days " if ($days > 0);
	$response .= "$hours hours " if ($hours > 0);
	$response .= "$minutes minutes " if ($minutes > 0);
	$response .= "$seconds seconds " if ($seconds > 0);
	$response .= "ago";
	
	my @found;
	my $channel;
	foreach $channel (keys(%seen)) {
	  next if ($channel eq $fromJID->GetJID());

	  if (exists($seen{$channel}->{$user})) {
	    if ($seen{$channel}->{$user}->{status} eq "on") {
	      if ((time - $seen{$channel}->{$user}->{time}) <= 60) {
		push(@found, $channel."  active");
	      } else {
		push(@found, $channel);
	      }
	    }
	  }
	}
	
	#---------------------------------------------------------------------
	# Tell the channel that you know them and what their status is
	#---------------------------------------------------------------------
	push(@response,$message->GetType(),$response);
	
	#---------------------------------------------------------------------
	# If the nick was found in other channels then private chat it them.
	#---------------------------------------------------------------------
	push(@response,"chat","Checking my other channels has revealed that the nick is in use on the following channels:\n - ".join("\n - ",@found))
	  if ($#found > -1);
      }
    }
  } else {
    push(@response,$message->GetType(),"You are looking for me?");
  }

  return @response;
}


##############################################################################
#
# plugin_seen_active - track when the user was last active
#
##############################################################################
sub plugin_seen_active {
  my $presence = shift;

  my $fromJID = $presence->GetFrom("jid");

  return unless &CheckFlag($fromJID->GetJID(),"seen");

  return if ($fromJID->GetResource() eq "");

  $seen{$fromJID->GetJID()}->{$fromJID->GetResource()}->{time} = time;

  return;
}


##############################################################################
#
# plugin_seen_available - track when the user enters the channel.
#
##############################################################################
sub plugin_seen_available {
  my $presence = shift;

  my $fromJID = $presence->GetFrom("jid");

  return unless &CheckFlag($fromJID->GetJID(),"seen");

  return if ($fromJID->GetResource() eq "");

  $seen{$fromJID->GetJID()}->{$fromJID->GetResource()}->{status} = "on";
  $seen{$fromJID->GetJID()}->{$fromJID->GetResource()}->{time} = time;

  &plugin_seen_write_seen();

  return;
}


##############################################################################
#
# plugin_seen_unavailable - track when the user leaves the channel.
#
##############################################################################
sub plugin_seen_unavailable {
  my $presence = shift;

  my $fromJID = $presence->GetFrom("jid");

  return unless &CheckFlag($fromJID->GetJID(),"seen");

  return if ($fromJID->GetResource() eq "");

  $seen{$fromJID->GetJID()}->{$fromJID->GetResource()}->{status} = "off";
  $seen{$fromJID->GetJID()}->{$fromJID->GetResource()}->{time} = time;

  &plugin_seen_write_seen();

  return;
}


##############################################################################
#
# plugin_seen_write_seen - saves the seen data, for in between sessions.
#
##############################################################################
sub plugin_seen_write_seen {
  open(SEEN,">$config{plugins}->{seen}->{storage}");
  print SEEN &Net::Jabber::sprintData("\$seen",\%seen);
  close(SEEN);
}


1;
