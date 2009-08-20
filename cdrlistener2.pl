#!/usr/bin/perl

# This listener was adapted from code found at 
# http://poe.perl.org/?POE_Cookbook/TCP_Servers
#
# It has been modified to accept CDR connections from an Avaya Definity PBX 
# and format that data for insertion into a MySQL database for later analysis
# Adaption was done by David F. Cox
# Ramtex, Inc. 
# Ramseur, NC.
# Use this software at your own risk. If it works for you great. If not fix it and let me know what you did.
# I created this because I could not find an existing method to get CDR data into MySQL in a realtime manner.
# 
# I'm posting the code to hopefully save someone else the trouble.
# You can contact me at davidcox[at]ramtex[dot]com if you have questions but 
# I can't guarantee any answers.



use strict;
use warnings;
use DBI;

use Socket;
use POE qw(Wheel::SocketFactory
  Wheel::ReadWrite
  Driver::SysRW
  Filter::Stream
);

#####
# MAIN
#####

local $| = 1;
our $debug      = 0;        # be very very noisy
our $serverport = 50000;    # 'poe' in base10 :P
our $file = "/tmp/cdrlistener.log";  # our debug logfile

our $hostname="localhost";
our $database="cdr";
our $dbport=3336;
our $user="yourdbuser";
our $password="yourdbpassword";
our $DSN = "DBI:mysql:database=$database;host=$hostname;port=$dbport";
our $DB_HANDLE = DBI->connect($DSN, $user, $password) or die "Not able to Connect. Check the UserName and Password";
our $drh = DBI->install_driver("mysql");




fork and exit unless $debug;

POE::Session->create(
    inline_states => {
        _start => \&parent_start,
        _stop  => \&parent_stop,

        socket_birth => \&socket_birth,
        socket_death => \&socket_death,
      }
);

# $poe_kernel is exported from POE
$poe_kernel->run();

exit;

####################################

sub parent_start {
    my $heap = $_[HEAP];

    print "= L = Listener birth\n" if $debug;

    $heap->{listener} = POE::Wheel::SocketFactory->new(
        BindAddress  => 'server.domain.com', 
        BindPort     => $serverport,
        Reuse        => 'yes',
        SuccessEvent => 'socket_birth',
        FailureEvent => 'socket_death',
    );
}

sub parent_stop {
    my $heap = $_[HEAP];
    delete $heap->{listener};
    delete $heap->{session};
    print "= L = Listener death\n" if $debug;
}

##########
# SOCKET #
##########

sub socket_birth {
    my ( $socket, $address, $port ) = @_[ ARG0, ARG1, ARG2 ];
    $address = inet_ntoa($address);

    print "= S = Socket birth\n" if $debug;

    POE::Session->create(
        inline_states => {
            _start => \&socket_success,
            _stop  => \&socket_death,

            socket_input => \&socket_input,
            socket_death => \&socket_death,
        },
        args => [ $socket, $address, $port ],
    );

}

sub socket_death {
    my $heap = $_[HEAP];
    if ( $heap->{socket_wheel} ) {
        print "= S = Socket death\n" if $debug;
        delete $heap->{socket_wheel};
    }
}

sub socket_success {
    my ( $heap, $kernel, $connected_socket, $address, $port ) =
      @_[ HEAP, KERNEL, ARG0, ARG1, ARG2 ];

    print "= I = CONNECTION from $address : $port \n" if $debug;

    $heap->{socket_wheel} = POE::Wheel::ReadWrite->new(
        Handle => $connected_socket,
        Driver => POE::Driver::SysRW->new(),
        Filter => POE::Filter::Stream->new(),

        InputEvent => 'socket_input',
        ErrorEvent => 'socket_death',
    );

}

sub socket_input {
    my ( $heap, $display ) = @_[ HEAP, ARG0 ];
    $display =~ s/[\r\n]//gs;
    open( LOG, ">> $file" );

        if (length($display)>=62)
        {
            #Break $display down to the component pieces
            my $month=(substr($display,0,2));
            my $day=(substr($display,2,2));
            my $year=(substr($display,4,2));
            my $hour=(substr($display,7,2));
            my $minute=(substr($display,9,2));
            my $origination=(substr($display,23,10));
            my $destination=(substr($display,39,24));
            my $duration=(substr($display,12,5));

            $origination=alltrim($origination);
            $destination=alltrim($destination);

            my $query="INSERT into cdrlog (month,day,year,hour,minute,extension,dialednumber,duration) 
            VALUES ($month,$day,$year,$hour,$minute,$origination,$destination,$duration)";

            my $sth = $DB_HANDLE->prepare($query);
            $sth->execute;
            $sth->finish;
            
            print LOG "[".length($display)."]".$query."\n" if $debug;
        }
        else
        {
            # What did we get if the length is shorter than expected
            print LOG "[".length($display)."]".$display."\n" if $debug;
        }
   close(LOG);
}


sub alltrim {
    my $string = shift;
    for ($string) {
        s/^\s+//;
        s/\s+$//;
    }
    return $string;
}

