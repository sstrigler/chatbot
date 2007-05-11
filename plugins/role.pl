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
#
#  Copyright (C) 2005 Stefan Strigler <steve@zeank.in-berlin.de>
#
##############################################################################

##############################################################################
#
# ChatBot Role Change Plugin - changes roles of participants upon request
#                              Bot must have moderator status to do so
#
##############################################################################

use strict;


##############################################################################
#
# Register Events
#
##############################################################################
&RegisterCommand(command=>"!op",
                 handler=>\&plugin_role_op,
                 desc=>"Give moderator status to nick. If nick is omitted command issuing user is used.",
                 usage=>"<password> [nick]");

&RegisterCommand(command=>"!deop",
                 handler=>\&plugin_role_deop,
                 desc=>"Revoke moderator status from nick. If nick is omitted command issuing user is used.",
                 usage=>"<password> [nick]");

&RegisterCommand(command=>"!kick",
                 handler=>\&plugin_role_kick,
                 desc=>"Kick user with given nickname",
                 usage=>"<password> \"<nick>\" [reason]");

##############################################################################
#
# Register Flags
# 
##############################################################################
&RegisterFlag("role");


##############################################################################
# 
# plugin_role_*
# 
##############################################################################

sub plugin_role_op {
	my $message = shift;
	my ($password,$nick) = split / /,shift,2;

	my $fromJID = $message->GetFrom("jid");
	return unless &CheckFlag($fromJID->GetJID(),"role");

	return ($message->GetType(),"The command was in error.")
		if !defined($password);
	return ($message->GetType(),"Permission denied.")
		unless &CheckPassword("role",$password);

	if (!defined($nick) || $nick =~ /^\s*$/) { # empty nick - set to sender
		$nick = $fromJID->GetResource();
	}
	
	return &plugin_role_change($fromJID->GetJID(),$nick,'moderator');
}

sub plugin_role_deop {
	my $message = shift;
	my ($password,$nick) = split / /,shift,2;

	my $fromJID = $message->GetFrom("jid");
	return unless &CheckFlag($fromJID->GetJID(),"role");

	return ($message->GetType(),"The command was in error.")
		if !defined($password);
	return ($message->GetType(),"Permission denied.")
		unless &CheckPassword("role",$password);

	if (!defined($nick) || $nick =~ /^\s*$/) { # empty nick - set to sender
		$nick = $fromJID->GetResource();
	} elsif ($nick eq &ChatBotNick($fromJID->GetJID())) {
		return ($message->GetType(),"Am I stupid, man?");
	}

	return &plugin_role_change($fromJID->GetJID(),$nick,'participant');
}

sub plugin_role_kick {
	my $message = shift;
	my $args = shift;
	
	my $fromJID = $message->GetFrom("jid");
	return unless &CheckFlag($fromJID->GetJID(),"role");

	my ($password,$nick,$reason) = ($args =~ /^\s*(\S+)\s+\"([^\"]+)\"\s*(.*)$/);

	return ($message->GetType(),"The command was in error.")
		if !defined($password);
	return ($message->GetType(),"Permission denied.")
		unless &CheckPassword("role",$password);

	if (!defined($nick) || $nick =~ /^\s*$/) { # empty nick - set to sender
		return ($message->GetType(),"Missing nick");
	}  elsif ($nick eq &ChatBotNick($fromJID->GetJID())) {
     return ($message->GetType(),"Am I stupid, man?");
  }

	return &plugin_role_change($fromJID->GetJID(),$nick,'none',$reason);
}

sub plugin_role_change {
	my $to = shift;
	my $nick = shift;
	my $role = shift;
	my $reason = shift;

	my $iq = new Net::Jabber::IQ();
	$iq->SetTo($to);
	$iq->SetType('set');

	my $i = $iq->NewQuery('http://jabber.org/protocol/muc#admin')->AddItem();
	$i->SetNick($nick);
	$i->SetRole($role);
	$i->SetReason($reason) if (defined($reason) && $reason ne '');
	Send($iq);

	return;
}

1;
