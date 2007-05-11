#!/usr/bin/perl
#
# Url Catcher Chatbot Plugin 
# grabs urls from channel and returns them on behalf

use strict;
use vars qw ( %urls );

&RegisterFlag("url");

&RegisterCommand(command=>"!url",
                 handler=>\&plugin_url_url,
                 desc=>"list last [count] seen urls in chat room",
                 usage=>"[count]",
                 examples=>["!url","!url 10"]);
&RegisterEvent("groupchat_message",\&plugin_url_message);

$config{plugins}->{url}->{maxmessages} = 50
    unless exists($config{plugins}->{url}->{maxmessages});
$config{plugins}->{url}->{defaultcount} = 5
    unless exists($config{plugins}->{url}->{defaultcount});

sub plugin_url_url {
	my $msg = shift;
	my $args = shift;
	
	my $fromJID = $msg->GetFrom("jid");

	return unless &CheckFlag($fromJID->GetJID(),"url");

	my ($count) = ($args =~ /^\s*(\d+)\s*$/);
	$count = $config{plugins}->{url}->{defaultcount} unless (defined($count) && $count ne "");
	$count = 1 if ($count < 1); # don't make it negative
	$count = ($#{$urls{$fromJID->GetJID()}} + 1)
		if ($count > ($#{$urls{$fromJID->GetJID()}} + 1)); # limit to max avail (which is always less than maxmessages
	$count -= 1; # $count means index position in @{urls{...}} from now on

	return ("chat", "No links catched yet ...") unless ($count>0);

	my $reply = "Here are the last ".($count+1)." urls I've seen on ".$fromJID->GetJID().":\n";
	foreach my $idx (($#{$urls{$fromJID->GetJID()}}-$count)..$#{$urls{$fromJID->GetJID()}}) {
		$reply .= "- ".${$urls{$fromJID->GetJID()}}[$idx]."\n";
	}

	return ("chat", $reply);
}

sub plugin_url_message {
	my $msg = shift;
	my $fromJID = $msg->GetFrom("jid");

	return unless &CheckFlag($fromJID->GetJID(),"url");

	# skip my own messages
	return if ($fromJID->GetResource() eq &ChatBotNick($fromJID->GetJID()) || $fromJID->GetResource() eq '');
	
	my ($url) = ($msg->GetBody() =~ /(https?:\/\/\S+)/i);
	if ($url) {
		push (@{$urls{$fromJID->GetJID()}},$url); # add to queue
		# check queue for identical url
		
		# else cut off last element on queue overflow
		shift (@{$urls{$fromJID->GetJID()}}) if ($#{$urls{$fromJID->GetJID()}} >= $config{plugins}->{url}->{maxmessages});
	}
}
