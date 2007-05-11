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
# ChatBot Query PlugIn - responds to requests for a definition of a phrase or
#                        term.  ?? chatbot
#
##############################################################################

use strict;
use DBI;
use Encode;
use utf8;


##############################################################################
#
# Register Events
#
##############################################################################
&RegisterEvent("startup",\&plugin_querysql_startup);
&RegisterEvent("shutdown",\&plugin_querysql_shutdown);
&RegisterCommand(command=>"!query",
                 alias=>"??",
                 handler=>\&plugin_querysql_query,
                 desc=>"Return the value for the requested key. NOTE: The space in between the command and the key is VERY important.",
                 usage=>"<key>");
&RegisterCommand(command=>"!edit_query",
                 handler=>\&plugin_querysql_edit_query,
                 desc=>"Add/Edit the query value for the given key.",
                 usage=>"<password> \"<key>\" <value>");
&RegisterCommand(command=>"!del_query",
                 handler=>\&plugin_querysql_del_query,
                 desc=>"Delete the query value for the given key.",
                 usage=>"<password> \"<key>\"");
&RegisterCommand(command=>"!import_query",
                 handler=>\&plugin_querysql_import,
                 desc=>"Import queries from an older query.xml file.",
                 usage=>"<password> <file>");


##############################################################################
#
# Register Flags
#
##############################################################################
&RegisterFlag("querysql");


##############################################################################
#
# Define config variables
#
##############################################################################
$config{plugins}->{querysql}->{mysql}->{database} = "chatbot"
    unless exists($config{plugins}->{querysql}->{mysql}->{database});
$config{plugins}->{querysql}->{mysql}->{host} = "localhost"
    unless exists($config{plugins}->{querysql}->{mysql}->{host});
$config{plugins}->{querysql}->{mysql}->{user} = ""
    unless exists($config{plugins}->{querysql}->{mysql}->{user});
$config{plugins}->{querysql}->{mysql}->{pass} = ""
    unless exists($config{plugins}->{querysql}->{mysql}->{pass});
$config{plugins}->{querysql}->{mysql}->{table} = "querysql"
    unless exists($config{plugins}->{querysql}->{mysql}->{table});


##############################################################################
#
# plugin_querysql_startup - connect to the database and make sure the table
#                           exists.
#
##############################################################################
sub plugin_querysql_startup
{
    my $drh = DBI->install_driver("mysql");
    
    my @dbs = $drh->func($config{plugins}->{querysql}->{mysql}->{host}, '_ListDBs');
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
                   $config{plugins}->{querysql}->{mysql}->{database},
                   $config{plugins}->{querysql}->{mysql}->{host},
                   $config{plugins}->{querysql}->{mysql}->{user},
                   $config{plugins}->{querysql}->{mysql}->{pass},
                   "admin");
    }
    
    $plugin_env{querysql}->{dbh} = DBI->connect("DBI:mysql:database=$config{plugins}->{querysql}->{mysql}->{database};host=$config{plugins}->{querysql}->{mysql}->{host}",$config{plugins}->{querysql}->{mysql}->{user},$config{plugins}->{querysql}->{mysql}->{pass});

    $plugin_env{querysql}->{active} = 1;
    if (!defined($plugin_env{querysql}->{dbh}))
    {
        print "ERROR:  querysql: Could not connect to database.  Please fix this for me.\n";
        $plugin_env{querysql}->{active} = 0;
        return;
    }

    $plugin_env{querysql}->{dbh}->do("CREATE TABLE IF NOT EXISTS `$config{plugins}->{querysql}->{mysql}->{table}` (id VARCHAR(50) NOT NULL,value TEXT NOT NULL, PRIMARY KEY (id));");

    $plugin_env{querysql}->{delete_sth} = $plugin_env{querysql}->{dbh}->prepare("DELETE FROM `$config{plugins}->{querysql}->{mysql}->{table}` WHERE(id=?);");

    $plugin_env{querysql}->{insert_sth} = $plugin_env{querysql}->{dbh}->prepare("INSERT INTO `$config{plugins}->{querysql}->{mysql}->{table}` SET id=?,value=?;");

    $plugin_env{querysql}->{select_sth} = $plugin_env{querysql}->{dbh}->prepare("SELECT * FROM `$config{plugins}->{querysql}->{mysql}->{table}` WHERE(id=?);");
}


##############################################################################
#
# plugin_querysql_shutdown - disconnect from the database
#
##############################################################################
sub plugin_querysql_shutdown
{
    return unless $plugin_env{querysql}->{active};

    $plugin_env{querysql}->{delete_sth}->finish;
    $plugin_env{querysql}->{insert_sth}->finish;
    $plugin_env{querysql}->{select_sth}->finish;

    $plugin_env{querysql}->{dbh}->disconnect;
}


##############################################################################
#
# plugin_querysql_query - return the query value, if any
#
##############################################################################
sub plugin_querysql_query
{
    return unless $plugin_env{querysql}->{active};

    my $message = shift;
    my $key = shift;

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"querysql");

    return unless (defined($key) && ($key ne ""));

    $plugin_env{querysql}->{select_sth}->execute(Encode::encode_utf8(lc($key)));

    return ($message->GetType(),"Unknown query \"$key\"")
        unless ($plugin_env{querysql}->{select_sth}->rows == 1);

    my $ref = $plugin_env{querysql}->{select_sth}->fetchrow_hashref;

    return ($message->GetType(),"[".Encode::decode_utf8($ref->{id})."]: ".Encode::decode_utf8($ref->{value}));
}


##############################################################################
#
# plugin_querysql_edit_query - edit the message for a user
#
##############################################################################
sub plugin_querysql_edit_query
{
    my $message = shift;
    my $args = shift;

    return ($message->GetType(),"The database was not initialized.")
        unless $plugin_env{querysql}->{active};

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"querysql");

    my ($password,$key,$value) = ($args =~ /^\s*(\S+)\s+\"([^\"]+)\"\s*(.*)$/);

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.")
        unless &CheckPassword("querysql",$password);

    if (defined($key) && defined($value))
    {
        $plugin_env{querysql}->{delete_sth}->execute(Encode::encode_utf8(lc($key)));
        $plugin_env{querysql}->{insert_sth}->execute(Encode::encode_utf8(lc($key)),Encode::encode_utf8($value));
    }

    return ($message->GetType(),"[".lc($key)."]: $value");
}


##############################################################################
#
# plugin_querysql_del_query - delete the message for a user
#
##############################################################################
sub plugin_querysql_del_query
{
    my $message = shift;
    my $args = shift;

    return ($message->GetType(),"The database was not initialized.")
        unless $plugin_env{querysql}->{active};

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"querysql");

    my ($password,$key) = ($args =~ /^\s*(\S+)\s+\"([^\"]+)\"\s*$/);

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.")
        unless &CheckPassword("querysql",$password);

    $plugin_env{querysql}->{delete_sth}->execute(Encode::encode_utf8(lc($key)));

    return ($message->GetType(),"Query message for \"".lc($key)."\" deleted");
}


##############################################################################
#
# plugin_querysql_import - import from a query.xml file
#
##############################################################################
sub plugin_querysql_import
{
    my $message = shift;
    my $args = shift;

    return ($message->GetType(),"The database was not initialized.")
        unless $plugin_env{querysql}->{active};

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"querysql");

    my ($password,$file) = ($args =~ /^\s*(\S+)\s+(\S+)\s*$/);

    return ($message->GetType(),"The command was in error.")
        if !defined($password);
    return ($message->GetType(),"Permission denied.")
        unless &CheckPassword("querysql",$password);

    if (-e $file)
    {
        my %old_query = &xmldbRead($file);

        foreach my $key (keys(%old_query))
        {
            $plugin_env{querysql}->{delete_sth}->execute(lc($key));
            $plugin_env{querysql}->{insert_sth}->execute(lc($key),$old_query{$key});
        }

        return ($message->GetType(),"Imported queries from $file");
    }
    else
    {
        return ($message->GetType(),"$file is not a file");
    }
}


1;
