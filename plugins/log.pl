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
# ChatBot Log PlugIn - Handles logging of the groupchat rooms.
#
##############################################################################

use strict;
use utf8;

use FileHandle;
#use Encode 'encode_utf8';


##############################################################################
#
# Register Events
#
##############################################################################
&RegisterEvent("groupchat_message",\&plugin_log_log);


##############################################################################
#
# Register Flags
#
##############################################################################
&RegisterFlag("log");
&RegisterFlag("log-private");


##############################################################################
#
# Define config variables
#
##############################################################################
$config{plugins}->{log}->{publiclogs} = "./logs"
    unless exists($config{plugins}->{log}->{publiclogs});
$config{plugins}->{log}->{privatelogs} = "./logs-secret"
    unless exists($config{plugins}->{log}->{privatelogs});


##############################################################################
#
# plugin_log_log - take the message and log it to the proper log file
#
##############################################################################
sub plugin_log_log
{
    my $message = shift;

    my $fromJID = $message->GetFrom("jid");

    return unless &CheckFlag($fromJID->GetJID(),"log");

    my $fh = &plugin_log_GetFileHandle($fromJID);

    my $timeStamp = &Net::Jabber::GetTimeStamp("local",time,"shortest");
    print $fh "<font color=\"#666666\">[$timeStamp]</font> ";
    print $fh "<font color=\"";
    my $body = $message->GetBody();
    print $fh "#0000ff"
        unless (($body =~ /^\/me/i) || ($fromJID->GetResource() eq ""));
    print $fh "#990099"
        if ($body =~ /^\/me/i);
    print $fh "#009900"
        if ($fromJID->GetResource() eq "");
    print $fh "\">";

    print $fh "&lt;"
        unless (($body =~ /^\/me/i) || ($fromJID->GetResource() eq ""));
    print $fh "* "
        if ($body =~ /^\/me/i);
    print $fh "%% "
        if ($fromJID->GetResource() eq "");
    print $fh $fromJID->GetResource();
    print $fh "&gt;</font>  "
        unless (($body =~ /^\/me/i) || ($fromJID->GetResource() eq ""));
    my $body2 = $body;
    $body2 =~ s/^\/me//i;

    $body2 =~ s/\&/\&amp\;/g;
    $body2 =~ s/\</\&lt\;/g;
    $body2 =~ s/\>/\&gt\;/g;
    $body2 =~ s/\n/\<br\>/g;
    $body2 =~ s/(http|ftp)(\:\/\/\S+)/\<a href\=\"$1$2\"\>$1$2\<\/a\>/g;

    print $fh $body2;
    print $fh "</font>"
        if (($body =~ /^\/me/i) || ($fromJID->GetResource() eq ""));
    print $fh "<br>\n";

    return;
}


##############################################################################
#
# plugin_log_GetFileHandle - based on the jid and date, return the correct
#                            filehandle.
#
##############################################################################
sub plugin_log_GetFileHandle
{
    my ($jid) = @_;

    my $channel = $jid->GetJID();

    my($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    $mday = "0".$mday if ($mday < 10);
    $mon++;
    $mon = "0".$mon if ($mon < 10);
    $year += 1900;

    my $filename = $config{plugins}->{log}->{publiclogs};
    $filename = $config{plugins}->{log}->{privatelogs}
        if &CheckFlag($channel,"log-private");
    system("mkdir $filename") if !(-e $filename);
    $filename .= "/".$jid->GetServer();
    system("mkdir $filename") if !(-e $filename);
    $filename .= "/".$jid->GetUserID();
    system("mkdir $filename") if !(-e $filename);
    $filename .= "/$year-$mon-$mday.html";

    #--------------------------------------------------------------------------
    # We have not logged for this channel yet.  We don't have anything in the
    # environment, or the filename is different from the one were looking at
    # before.
    #--------------------------------------------------------------------------
    if (!exists($plugin_env{log}->{channels}->{$channel}) ||
        ($plugin_env{log}->{channels}->{$channel}->{filename} ne $filename))
    {
        
        #----------------------------------------------------------------------
        # If there is a current filehandle, then close it out.
        #----------------------------------------------------------------------
        if (exists($plugin_env{log}->{channels}->{$channel}->{handle}))
        {
            my $fh = $plugin_env{log}->{channels}->{$channel}->{handle};
            print $fh &plugin_log_getFooter(channel=>$channel,
                                            date=>"$year/$mon/$mday");
            $plugin_env{log}->{channels}->{$channel}->{handle}->close();
            delete($plugin_env{log}->{channels}->{$channel}->{handle});
            delete($plugin_env{log}->{channels}->{$channel}->{filename});
        }

        #----------------------------------------------------------------------
        # Open the new filehandle.  If the file already exists, then append,
        # otherwise, open it and write the header.
        #----------------------------------------------------------------------
        $plugin_env{log}->{channels}->{$channel}->{filename} = $filename;
        if (!-e $filename)
        {
            $plugin_env{log}->{channels}->{$channel}->{handle} =
                new FileHandle(">$filename");
#            binmode($plugin_env{log}->{channels}->{$channel}->{handle}, ":utf8");
            my $fh = $plugin_env{log}->{channels}->{$channel}->{handle};
            print $fh	&plugin_log_getHeader(channel=>$channel,
                                              date=>"$year/$mon/$mday");
        }
        else
        {
            $plugin_env{log}->{channels}->{$channel}->{handle} =
                new FileHandle(">>$filename");
          #  binmode($plugin_env{log}->{channels}->{$channel}->{handle}, ":utf8");
        }
        $plugin_env{log}->{channels}->{$channel}->{handle}->autoflush(1);
    }
    
    #--------------------------------------------------------------------------
    # At this point we have a handle... or at least we'd better.  So return it.
    #--------------------------------------------------------------------------
    return $plugin_env{log}->{channels}->{$channel}->{handle};
}


##############################################################################
#
# plugin_log_getHeader - return the header to use for this log.
#
##############################################################################
sub plugin_log_getHeader
{
    my (%args) = @_;

    my $header = "";

    if (exists($config{plugins}->{log}->{headerfile}) &&
        (-e $config{plugins}->{log}->{headerfile}))
    {
        open(HEADER,$config{plugins}->{log}->{headerfile});
        while(<HEADER>)
        {
            s/<!--TITLE-->/$args{title}/g;
            s/<!--CHANNEL-->/$args{channel}/g;
            s/<!--DATE-->/$args{date}/g;
            $header .= $_;
        }
        close(HEADER);
    }
    else
    {
        $header .= "<html>\n";
        $header .= "<head>\n";
        $header .= "<title>$args{channel} - $args{date}</title>\n";
        $header .= "</head>\n";
        $header .= "<body bgcolor=\"#ffffff\">\n";
        $header .= "<h1>$args{channel} - $args{date}</h1>\n";
        $header .= "<hr>\n";
    }

    return $header;
}


##############################################################################
#
# plugin_log_getFooter - return the footer to use for this log.
#
##############################################################################
sub plugin_log_getFooter
{
    my (%args) = @_;

    my $footer = "";

    if (exists($config{plugins}->{log}->{footerfile}) &&
        (-e $config{plugins}->{log}->{footerfile}))
    {
        open(FOOTER,$config{plugins}->{log}->{footerfile});
        while(<FOOTER>)
        {
            s/<!--TITLE-->/$args{title}/g;
            s/<!--CHANNEL-->/$args{channel}/g;
            s/<!--DATE-->/$args{date}/g;
            $footer .= $_;
        }
        close(FOOTER);
    }
    else
    {
        $footer .= "</body>\n";
        $footer .= "</html>\n";
    }

    return $footer;
}


1;
