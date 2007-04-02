#!/usr/local/perl/bin/perl -w

=for Information:
Program to check to make sure spamd is running and report back to nrpe for 
nagios. The variable that most folks will want to change is "$spamc" which
is the location of the spamc program.
Created: 11/29/2006
Version: 1.3              
Revised: 3/31/2007
Revised by: Erinn Looney-Triggs
Author: Erinn Looney-Triggs
=cut

use strict;                  #Do it right
use Switch;                  #Standard perl 5.8 module to use switch statement
use POSIX qw( WIFEXITED );   #Fix system call's strange return values

my $spamc = "/usr/local/perl/bin/spamc";                #Location of spamc
my $cmd   = "echo foo | $spamc -x 2>&1 > /dev/null";    #The command
my $timeout = "10";    #Nagios plugins call for a max timeout of 10 seconds

#Make sure spamc exists and if not give back a nagios warning
if ( !-e $spamc ) {
    print "The $spamc program does not exist.\n";
    exit 2;
}

#Timer operation. Times out after 10 seconds.
eval {

    local $SIG{ALRM} = sub { die "alarm\n" };
    alarm $timeout;

    #Run the command
    WIFEXITED( system("$cmd") ) or die "Couldn't run $cmd\n";

    alarm 0;
};

#Test return value and exit if eval caught the alarm
if ($@) {
    if ( $@ eq "alarm\n" ) {
        print "Operation timed out after $timeout seconds.\n";
        exit 2;
    }
    else {
        print "An unknown error has occured.\n";
        exit 3;
    }
}
else {

    #Divide by 256 or bitshift right by 8 to get the original error code
    my $return_code = $? >> 8;

    #Parse the errors and give Nagios parsible error codes and messages
    switch ($return_code) {
        case 0  { print "OK\n";                                     exit 0; }
        case 64 { print "Command line usage error\n";               exit 1; }
        case 65 { print "Data format error\n";                      exit 1; }
        case 66 { print "Cannot open input\n";                      exit 1; }
        case 67 { print "Addressee unknown\n";                      exit 1; }
        case 68 { print "Host name unknown\n";                      exit 1; }
        case 69 { print "Spamd service unavailable\n";              exit 2; }
        case 70 { print "Internal software error\n";                exit 2; }
        case 71 { print "System error (e.g., can't fork)\n";        exit 2; }
        case 72 { print "Critical OS file missing\n";               exit 2; }
        case 73 { print "Can't create (user) output file\n";        exit 1; }
        case 74 { print "Input/output error\n";                     exit 1; }
        case 75 { print "Temp failure; user is invited to retry\n"; exit 1; }
        case 76 { print "Remote error in protocol\n";               exit 2; }
        case 77 { print "Permission denied\n";                      exit 1; }
        case 78 { print "Configuration error\n";                    exit 1; }
        else    { print "An unknown error has occured in $spamc\n"; exit 3; }
    }
}
