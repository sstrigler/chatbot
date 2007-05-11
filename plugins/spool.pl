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
# ChatBot Spool Plugin - send raw packets from spool
#
##############################################################################

use strict;

use constant SPOOLDELAY   => 10;	# poll interval in seconds 
                                        # for checking spool
use constant VERBOSE      => 2;         # Verbosity level for logging output


##############################################################################
#
# Register Events
#
##############################################################################

##############################################################################
#
# Register Flags
# 
##############################################################################
&RegisterFlag("spool");

##############################################################################
#
# Register Events
# 
##############################################################################
&RegisterEvent("startup",\&plugin_spool_startup);
&RegisterEvent("shutdown",\&plugin_spool_shutdown);


##############################################################################
##
## Define config variables
##
###############################################################################
$config{plugins}->{spool}->{spooldir} = "./spool"
  unless exists($config{plugins}->{spool}->{spooldir});


##############################################################################
# 
# Callbacks
#
##############################################################################
sub plugin_spool_startup {
  log3("spool plugin starting up...");

  opendir SPOOLDIR, $config{plugins}->{spool}->{spooldir} or die "Can't open spooldir: $!";
  $config{plugins}->{spool}->{fh} = *SPOOLDIR;

  &RegisterTimingEvent(time,"spool_tick",\&plugin_spool_dotick);
}

sub plugin_spool_dotick {
  log3("tick");

  my @allfiles = grep -T, map "$config{plugins}->{spool}->{spooldir}/$_", readdir $config{plugins}->{spool}->{fh};

  foreach my $file (@allfiles) {
    log2("got $file");

    open FH, $file or die "Can't open $file: $!";

    my $raw = join "", <FH>;
    
    log2("sending: $raw");

    Send($raw);

    unlink $file;
  }

  rewinddir $config{plugins}->{spool}->{fh};

  &RegisterTimingEvent(time+SPOOLDELAY,"spool_tick",\&plugin_spool_dotick);
}

sub plugin_spool_shutdown {
  log3("spool plugin exiting ...");

  ClearTimingEvent("spool_tick");
  closedir $config{plugins}->{spool}->{fh};	
}
sub log1 {
  # WARN
  my $msg = shift;
  return unless VERBOSE >= 1;
  print STDERR "WARN: $msg\n";
}
  
sub log2 {
  # INFO
  my $msg = shift;
  return unless VERBOSE >= 2;
  print "INFO: $msg\n";
}
 
sub log3 {
  # DBUG
  my $msg = shift;
  return unless VERBOSE >= 3;
  print "DBUG: $msg\n";
}


1;
