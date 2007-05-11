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
# ChatBot Join PlugIn - tracks when all users log in and out, and prints out
#                       a join message if that user has one defined
#
##############################################################################

use strict;
use DBI;
use utf8;
use Encode;


##############################################################################
#
# Register Events
#
##############################################################################
&RegisterEvent("startup",\&plugin_joinsql_startup);
&RegisterEvent("shutdown",\&plugin_joinsql_shutdown);
&RegisterEvent("presence_available_join",\&plugin_joinsql_send_message);
&RegisterCommand(command=>"!edit_join",
                 handler=>\&plugin_joinsql_edit_join,
                 desc=>"Add/Edit the join message for a user.",
                 usage=>"<password> \"<user>\" <message>");
&RegisterCommand(command=>"!del_join",
                 handler=>\&plugin_joinsql_del_join,
                 desc=>"Delete the join message for a user.",
                 usage=>"<password> \"<user>\"");
&RegisterCommand(command=>"!import_join",
                 handler=>\&plugin_joinsql_import,
                 desc=>"Import join messages from an older join.xml file.",
                 usage=>"<password> <file>");


##############################################################################
#
# Register Flags
#
##############################################################################
&RegisterFlag("joinsql");


##############################################################################
#
# Define config variables
#
##############################################################################
$config{plugins}->{joinsql}->{mysql}->{database} = "chatbot"
    unless exists($config{plugins}->{joinsql}->{mysql}->{database});
$config{plugins}->{joinsql}->{mysql}->{host} = "localhost"
    unless exists($config{plugins}->{joinsql}->{mysql}->{host});
$config{plugins}->{joinsql}->{mysql}->{user} = ""
    unless exists($config{plugins}->{joinsql}->{mysql}->{user});
$config{plugins}->{joinsql}->{mysql}->{pass} = ""
    unless exists($config{plugins}->{joinsql}->{mysql}->{pass});
$config{plugins}->{joinsql}->{mysql}->{table} = "joinsql"
    unless exists($config{plugins}->{joinsql}->{mysql}->{table});


##############################################################################
#
# plugin_joinsql_startup - connect to the database and make sure the table
#                           exists.
#
##############################################################################
sub plugin_joinsql_startup
{
    my $drh = DBI->install_driver("mysql");
    
    my @dbs = $drh->func($config{plugins}->{joinsql}->{mysql}->{host}, '_ListDBs');
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
                   $config{plugins}->{joinsql}->{mysql}->{database},
                   $config{plugins}->{joinsql}->{mysql}->{host},
                   $config{plugins}->{joinsql}->{mysql}->{user},
                   $config{plugins}->{joinsql}->{mysql}->{pass},
                   "admin");
    }

    $plugin_env{joinsql}->{dbh} = DBI->connect("DBI:mysql:database=$config{plugins}->{joinsql}->{mysql}->{database};host=$config{plugins}->{joinsql}->{mysql}->{host}",$config{plugins}->{joinsql}->{mysql}->{user},$config{plugins}->{joinsql}->{mysql}->{pass});

    $plugin_env{joinsql}->{active} = 1;
    if (!defined($plugin_env{joinsql}->{dbh}))
    {
        print "ERROR:  joinsql: Could not connect to database.  Please fix this for me.\n";
        $plugin_env{joinsql}->{active} = 0;
        return;
    }

    $plugin_env{joinsql}->{dbh}->do("CREATE TABLE IF NOT EXISTS `$config{plugins}->{joinsql}->{mysql}->{table}` (id VARCHAR(50) NOT NULL,value TEXT NOT NULL, PRIMARY KEY (id));");

    $plugin_env{joinsql}->{delete_sth} = $plugin_env{joinsql}->{dbh}->prepare("DELETE FROM `$config{plugins}->{joinsql}->{mysql}->{table}` WHERE(id=?);");

    $plugin_env{joinsql}->{insert_sth} = $plugin_env{joinsql}->{dbh}->prepare("INSERT INTO `$config{plugins}->{joinsql}->{mysql}->{table}` SET id=?,value=?;");

    $plugin_env{joinsql}->{select_sth} = $plugin_env{joinsql}->{dbh}->prepare("SELECT * FROM `$config{plugins}->{joinsql}->{mysql}->{table}` WHERE(id=?);");
}


##############################################################################
#
# plugin_joinsql_shutdown - disconnect from the database
#
##############################################################################
sub plugin_joinsql_shutdown
{
    return unless $plugin_env{joinsql}->{active};

    $plugin_env{joinsql}->{delete_sth}->finish;
    $plugin_env{joinsql}->{insert_sth}->finish;
    $plugin_env{joinsql}->{select_sth}->finish;

    $plugin_env{joinsql}->{dbh}->disconnect;
}


##############################################################################
#
# plugin_joinsql_send_message - send out the join message, if any
#
##############################################################################
sub plugin_joinsql_send_message
{
    return unless $plugin_env{joinsql}->{active};

    my $sid = shift;
    my $presence = shift;

    my $fromJID = $presence->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"joinsql");

    $plugin_env{joinsql}->{select_sth}->execute(Encode::encode_utf8($fromJID->GetResource()));

    return unless ($plugin_env{joinsql}->{select_sth}->rows == 1);

    my $ref = $plugin_env{joinsql}->{select_sth}->fetchrow_hashref;

    return ("groupchat","[".Encode::decode_utf8($ref->{id})."]: ".Encode::decode_utf8($ref->{value}));
}


##############################################################################
#
# plugin_joinsql_edit_join - edit the message for a user
#
##############################################################################
sub plugin_joinsql_edit_join
{
    my $message = shift;
    my $args = shift;

    return ($message->GetType(),"The database was not initialized.")
        unless $plugin_env{joinsql}->{active};

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"joinsql");

    my ($password,$user,$value) = ($args =~ /^\s*(\S+)\s+\"([^\"]+)\"\s*(.*)$/);

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.")
        unless &CheckPassword("joinsql",$password);

    if (defined($user) && defined($value))
    {
        $plugin_env{joinsql}->{delete_sth}->execute(Encode::encode_utf8($user));
        $plugin_env{joinsql}->{insert_sth}->execute(Encode::encode_utf8($user),E
ncode::encode_utf8($value));
    }

    return ($message->GetType(),"[$user]: $value");
}


##############################################################################
#
# plugin_joinsql_del_join - delete the message for a user
#
##############################################################################
sub plugin_joinsql_del_join
{
    my $message = shift;
    my $args = shift;

    return ($message->GetType(),"The database was not initialized.")
        unless $plugin_env{joinsql}->{active};

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"joinsql");

    my ($password,$user) = ($args =~ /^\s*(\S+)\s+\"([^\"]+)\"\s*$/);

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.")
        unless &CheckPassword("joinsql",$password);

    $plugin_env{joinsql}->{delete_sth}->execute(Encode::encode_utf8($user));

    return ($message->GetType(),"Join message for \"$user\" deleted");
}


##############################################################################
#
# plugin_joinsql_import - import from a join.xml file
#
##############################################################################
sub plugin_joinsql_import
{
    my $message = shift;
    my $args = shift;

    return ($message->GetType(),"The database was not initialized.")
        unless $plugin_env{joinsql}->{active};

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"joinsql");

    my ($password,$file) = ($args =~ /^\s*(\S+)\s+(\S+)\s*$/);

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.")
        unless &CheckPassword("joinsql",$password);

    if (-e $file)
    {
        my %old_join = &xmldbRead($file);

        foreach my $key (keys(%old_join))
        {
            $plugin_env{joinsql}->{delete_sth}->execute($key);
            $plugin_env{joinsql}->{insert_sth}->execute($key,$old_join{$key});
        }

        return ($message->GetType(),"Imported queries from $file");
    }
    else
    {
        return ($message->GetType(),"$file is not a file");
    }
}


1;
