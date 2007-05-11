#/usr/bin/perl

use strict;

&RegisterFlag("keyword");
&RegisterEvent("groupchat_message",\&message_received);

sub message_received {
	my $msg = shift;

	my $from = $msg->GetFrom("jid");

	return unless &CheckFlag($from->GetJID(),"keyword");

  return if ($from->GetResource() eq &ChatBotNick($from->GetJID())); # it's me

#	return ($msg->GetType(),"http://metaatem.net/words/PoMo") if ($msg->GetBody() =~ /pomo/i || $msg->GetBody() =~ /postmodern/i);
	return ($msg->GetType(),":helicopter:") if ($msg->GetBody() =~ /(\W|^)vs(\W|$)/i || $msg->GetBody() =~ /polizei/i);
	return ($msg->GetType(),":no:") if ($msg->GetBody() =~/(^|\W)mg($|\W)/i || $msg->GetBody() =~ /(^|\W)gsp($|\W)/i || $msg->GetBody() =~ /gegenstandpunkt/i);
	return ($msg->GetType(),"Dschihad, Dschihad! Muhammed, Allah!") if ($msg->GetBody() =~ /bahamas/i || $msg->GetBody() =~ /wertmüller/i);
	return ($msg->GetType(),"Ruhm und Ehre der Roten Armee!") if ($msg->GetBody() =~ /stalin/i);
	return ($msg->GetType(),"Popper? Muss nur mal richtig durchgefickt werden!") if ($msg->GetBody() =~ /popper/i);
}

1
;
