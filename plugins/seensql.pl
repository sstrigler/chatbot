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
use DBI;
use utf8;
use Encode;
use vars qw ( %seen );

##############################################################################
#
# Register Events
#
##############################################################################
&RegisterEvent("startup",\&plugin_seensql_startup);
&RegisterEvent("shutdown",\&plugin_seensql_shutdown);
&RegisterEvent("presence_available",\&plugin_seensql_available);
&RegisterEvent("presence_unavailable",\&plugin_seensql_unavailable);
&RegisterEvent("groupchat_message",\&plugin_seensql_active);
&RegisterCommand(command=>"!seen",
                 handler=>\&plugin_seensql_seen,
                 desc=>"Prints the last time this user was seen in the channel.",
                 usage=>"<user>");
&RegisterCommand(command=>"!import_seen",
                 handler=>\&plugin_seensql_import,
                 desc=>"Import seen data from an older seen file.",
                 usage=>"<password> <file>");


##############################################################################
#
# Register Flags
#
##############################################################################
&RegisterFlag("seensql");


##############################################################################
#
# Define config variables
#
##############################################################################
$config{plugins}->{seensql}->{mysql}->{database} = "chatbot"
    unless exists($config{plugins}->{seensql}->{mysql}->{database});
$config{plugins}->{seensql}->{mysql}->{host} = "localhost"
    unless exists($config{plugins}->{seensql}->{mysql}->{host});
$config{plugins}->{seensql}->{mysql}->{user} = ""
    unless exists($config{plugins}->{seensql}->{mysql}->{user});
$config{plugins}->{seensql}->{mysql}->{pass} = ""
    unless exists($config{plugins}->{seensql}->{mysql}->{pass});
$config{plugins}->{seensql}->{mysql}->{table} = "seensql"
    unless exists($config{plugins}->{seensql}->{mysql}->{table});


##############################################################################
#
# plugin_seensql_startup - connect to the database and make sure the table
#                           exists.
#
##############################################################################
sub plugin_seensql_startup
{
    my $drh = DBI->install_driver("mysql");

    my @dbs = $drh->func($config{plugins}->{seensql}->{mysql}->{host}, '_ListDBs');
    my $exists = 0;
    foreach my $dbname (@dbs)
    {
        if ($dbname eq "chatbot")
        {
            $exists = 1;
            last;
        }
    }

    if ($exists == 0)
    {
        $drh->func("createdb",
                   $config{plugins}->{seensql}->{mysql}->{database},
                   $config{plugins}->{seensql}->{mysql}->{host},
                   $config{plugins}->{seensql}->{mysql}->{user},
                   $config{plugins}->{seensql}->{mysql}->{pass},
                   "admin");
    }

    $plugin_env{seensql}->{dbh} = DBI->connect("DBI:mysql:database=$config{plugins}->{seensql}->{mysql}->{database};host=$config{plugins}->{seensql}->{mysql}->{host}",$config{plugins}->{seensql}->{mysql}->{user},$config{plugins}->{seensql}->{mysql}->{pass});

    $plugin_env{seensql}->{active} = 1;
    if (!defined($plugin_env{seensql}->{dbh}))
    {
        print "ERROR:  seensql: Could not connect to database.  Please fix this for me.\n";
        $plugin_env{seensql}->{active} = 0;
        return;
    }

    $plugin_env{seensql}->{dbh}->do("CREATE TABLE IF NOT EXISTS `$config{plugins}->{seensql}->{mysql}->{table}` (channel VARCHAR(255) NOT NULL,nick VARCHAR(255) NOT NULL,status VARCHAR(10) NOT NULL,time VARCHAR(15) NOT NULL, KEY channel (channel),KEY nick (nick));");


    $plugin_env{seensql}->{delete_sth} = $plugin_env{seensql}->{dbh}->prepare("DELETE FROM `$config{plugins}->{seensql}->{mysql}->{table}` WHERE(channel=? && nick=?);");

    $plugin_env{seensql}->{insert_sth} = $plugin_env{seensql}->{dbh}->prepare("INSERT INTO `$config{plugins}->{seensql}->{mysql}->{table}` SET channel=?,nick=?,status=?,time=?;");

    $plugin_env{seensql}->{update_sth} = $plugin_env{seensql}->{dbh}->prepare("UPDATE IGNORE `$config{plugins}->{seensql}->{mysql}->{table}` SET time=? WHERE(channel=? && nick=?);");

    $plugin_env{seensql}->{select_sth} = $plugin_env{seensql}->{dbh}->prepare("SELECT * FROM `$config{plugins}->{seensql}->{mysql}->{table}` WHERE(channel=? && nick=?);");

    $plugin_env{seensql}->{select_looking_sth} = $plugin_env{seensql}->{dbh}->prepare("SELECT * FROM `$config{plugins}->{seensql}->{mysql}->{table}` WHERE(nick LIKE ?);");
}


##############################################################################
#
# plugin_seensql_shutdown - disconnect from the database
#
##############################################################################
sub plugin_seensql_shutdown
{
    return unless $plugin_env{seensql}->{active};

    $plugin_env{seensql}->{delete_sth}->finish;
    $plugin_env{seensql}->{insert_sth}->finish;
    $plugin_env{seensql}->{update_sth}->finish;
    $plugin_env{seensql}->{select_sth}->finish;
    $plugin_env{seensql}->{select_looking_sth}->finish;

    $plugin_env{seensql}->{dbh}->disconnect;
}


##############################################################################
#
# plugin_seensql_seen - check the seen hash and report back to the user.
#
##############################################################################
sub plugin_seensql_seen
{
    return unless $plugin_env{seensql}->{active};

    my $message = shift;
    my $user = Encode::encode_utf8(shift);

    return if ($user eq "");

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"seensql");

    my @response;

    #-------------------------------------------------------------------------
    # If we did not do "seen ChatBot" then...
    #-------------------------------------------------------------------------
    if ($user ne &ChatBotNick($fromJID->GetJID()))
    {

        $plugin_env{seensql}->{select_sth}->execute(Encode::encode_utf8($fromJID->GetJID()), $user);

        #---------------------------------------------------------------------
        # The user is not in the channel
        #---------------------------------------------------------------------
        if ($plugin_env{seensql}->{select_sth}->rows == 0)
        {

            #-----------------------------------------------------------------
            # Look for them in the other chatbot channels
            #-----------------------------------------------------------------
            $plugin_env{seensql}->{select_looking_sth}->execute("%$user%");

            my @found;
            while(my $ref = $plugin_env{seensql}->{select_looking_sth}->fetchrow_hashref)
            {
                if ($ref->{status} eq "on")
                {
                    if ((time - $ref->{time}) <= 60)
                    {
                        push(@found,Encode::decode_utf8($ref->{channel})."/".Encode::decode_utf8($ref->{nick})."  active");
                    }
                    else
                    {
                        push(@found,Encode::decode_utf8($ref->{channel})."/".Encode::decode_utf8($ref->{nick}));
                    }
                }
            }

            #-----------------------------------------------------------------
            # Tell the channel that chatbot doesn't know that user.
            #-----------------------------------------------------------------
            push(@response,$message->GetType(),"I have never had the pleasure of meeting \"$user\"");

            #-----------------------------------------------------------------
            # If the nick was found in other channels then private chat it them.
            #-----------------------------------------------------------------
            push(@response,"chat","The user has not been in this channel, but I have found the following nicks in these channels:\n - ".join("\n - ",@found))
                if ($#found > -1);


        }
        #---------------------------------------------------------------------
        # ... the user is in the channel ...
        #---------------------------------------------------------------------
        else
        {
            my $ref = $plugin_env{seensql}->{select_sth}->fetchrow_hashref;

            #-----------------------------------------------------------------
            # and they are logged in right now
            #-----------------------------------------------------------------
            if ($ref->{status} eq "on")
            {
                push(@response,$message->GetType(),"$user is in the channel right now...");
            }
            #-----------------------------------------------------------------
            # and they are *not* logged in
            #-----------------------------------------------------------------
            else
            {
                my $seconds = time - $ref->{time};

                my $response = "Last seen ";
                $response .= &Net::Jabber::GetHumanTime($seconds);
                $response .= "ago";

                $plugin_env{seensql}->{select_looking_sth}->execute("%$user%");

                my @found;
                while(my $ref = $plugin_env{seensql}->{select_looking_sth}->fetchrow_hashref)
                {
                    if ($ref->{status} eq "on")
                    {
                        if ((time - $ref->{time}) <= 60)
                        {
                            push(@found,Encode::decode_utf8($ref->{channel})."/".Encode::decode_utf8($ref->{nick})."  active");
                        }
                        else
                        {
                            push(@found,Encode::decode_utf8($ref->{channel})."/".Encode::decode_utf8($ref->{nick}));
                        }
                    }
                }

                #-------------------------------------------------------------
                # Tell the channel that you know them and what their status is
                #-------------------------------------------------------------
                push(@response,$message->GetType(),$response);

                #-------------------------------------------------------------
                # If the nick was found in other channels then private chat it them.
                #-------------------------------------------------------------
                push(@response,"chat","Checking my other channels has revealed that the nick is in use on the following channels:\n - ".join("\n - ",@found))
                    if ($#found > -1);
            }
        }
    }
    else
    {
        push(@response,$message->GetType(),"You are looking for me?");
    }

    return @response;
}


##############################################################################
#
# plugin_seensql_active - track when the user was last active
#
##############################################################################
sub plugin_seensql_active
{
    return unless $plugin_env{seensql}->{active};

    my $presence = shift;

    my $fromJID = $presence->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"seensql");

    return if ($fromJID->GetResource() eq "");

    $plugin_env{seensql}->{update_sth}->execute(time,
                                                Encode::encode_utf8($fromJID->GetJID()),
                                                Encode::encode_utf8($fromJID->GetResource()));

    return;
}


##############################################################################
#
# plugin_seensql_available - track when the user enters the channel.
#
##############################################################################
sub plugin_seensql_available
{
    return unless $plugin_env{seensql}->{active};

    my $presence = shift;

    my $fromJID = $presence->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"seensql");

    return if ($fromJID->GetResource() eq "");

    my $jid = Encode::encode_utf8($fromJID->GetJID());
    my $res = Encode::encode_utf8($fromJID->GetResource());

    $plugin_env{seensql}->{delete_sth}->execute($jid,$res);
    $plugin_env{seensql}->{insert_sth}->execute($jid,$res, "on", time);

    return;
}


##############################################################################
#
# plugin_seensql_unavailable - track when the user leaves the channel.
#
##############################################################################
sub plugin_seensql_unavailable
{
    return unless $plugin_env{seensql}->{active};

    my $presence = shift;

    my $fromJID = $presence->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"seensql");

    return if ($fromJID->GetResource() eq "");

    my $jid = Encode::encode_utf8($fromJID->GetJID());
    my $res = Encode::encode_utf8($fromJID->GetResource());
    
    $plugin_env{seensql}->{delete_sth}->execute($jid,$res);
    $plugin_env{seensql}->{insert_sth}->execute($jid,$res, "off", time);
    return;
}


##############################################################################
#
# plugin_seensql_import - import from a seen.xml file
#
##############################################################################
sub plugin_seensql_import
{
    my $message = shift;
    my $args = shift;

    return ($message->GetType(),"The database was not initialized.")
        unless $plugin_env{seensql}->{active};

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"seensql");

    my ($password,$file) = ($args =~ /^\s*(\S+)\s+(\S+)\s*$/);

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.")
        unless &CheckPassword("seensql",$password);

    if (-e $file)
    {
        do $file;

        foreach my $channel (keys(%seen))
        {
            foreach my $nick (keys(%{$seen{$channel}}))
            {
                $plugin_env{seensql}->{delete_sth}->
                execute($channel,
                        $nick);
                $plugin_env{seensql}->{insert_sth}->
                execute($channel,$nick,
                        $seen{$channel}->{$nick}->{status},
                        $seen{$channel}->{$nick}->{time});
            }
        }

        undef(%seen);

        return ($message->GetType(),"Imported seen from $file");
    }
    else
    {
        return ($message->GetType(),"$file is not a file");
    }
}


1;
