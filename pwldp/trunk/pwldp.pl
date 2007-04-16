#!/usr/local/perl/bin/perl -w

=for Information:
Script that pulls all usernames with a userid >= 1000 and checks them against
the University of Colorado LDAP directory. Returns a list of any usernames 
that do not exist in LDAP but do exist in the local passwd file. If there
is any variable you may need to change it will probably be the $ldap_server.
Created: 03/27/2007
Version: 0.0.4              #Change the version number in POD when you bump
Revised: 04/01/2007
Revised by: Erinn Looney-Triggs
Author: Erinn Looney-Triggs
=cut

use strict;                #Do it right
use Net::LDAP;             #CPAN module to bind to an LDAP server
use Tie::File;             #Built in module to tie to files as arrays
use Fcntl qw(O_RDONLY);    #Built in module to allow tieing a file readonly
use Getopt::Std;           #Grab short command line switches

$Getopt::Std::STANDARD_HELP_VERSION = 1;    #Die on help

my %options;                                #Command line switches
$main::VERSION  = "0.0.4";                  #Version number
my $passwd_file = "/etc/passwd";                    #Location of password file
my $ldap_server = 'ldaps://directory.colorado.edu'; #LDAP Server

#Allow for --help and --version to be used from command line
getopts( '', \%options );

#Die if the password file does not exist
die "Cannot find $passwd_file" if ( !-e $passwd_file );

#Get all usernames with a UID greater than or equal to 1000
my @uname_list = &get_uname($passwd_file);

#Search for all users in @uname_list and return those users who have no record
#in LDAP
my @final_list = &ldap_search(@uname_list);

#Print the list out
print "$_ \n" for (@final_list);

# Returns a list of usernames from a passwd formatted file
sub get_uname {
    my $passwd_file = shift @_;
    my @unamelist;

    tie my @PASSWD, 'Tie::File', "$passwd_file", mode => O_RDONLY
        or die "Unable to tie to $passwd_file: $!\n";

    for (@PASSWD) {
        my ( $uname, $uid ) = ( split /:/ )[ 0, 2 ];
        push @unamelist, $uname if ( "$uid" >= "1000" );
    }

    untie @PASSWD or die "Unable to untie $passwd_file: $!\n";
    return ( sort (@unamelist) );
}

#Return either exists (1) or does not exist (0) in LDAP for a given list
sub ldap_search {
    my @username_list = @_;
    my @nonexistant_users;

    #Open the connection to the LDAP server
    my $ldap = Net::LDAP->new("$ldap_server")
        or die "Unable to open connection to LDAP server: $@";

    for my $username (@username_list) {
        my $mesg = $ldap->bind();
        $mesg = $ldap->search(
            base   => "dc=Colorado,dc=EDU",
            filter => "(uid=$username)",
        );
        push @nonexistant_users, $username if ( $mesg->count == "0" );
    }

    $ldap->unbind();
    return (@nonexistant_users);
}

#Version message information displayed in both --version and --help
sub main::VERSION_MESSAGE {
    print <<"EOF";
This is version $main::VERSION of pwldp.

Copyright (c) 2007 Erinn Looney-Triggs (erinn.looneytriggs\@gmail.com). 
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License. 
See http://www.fsf.org/licensing/licenses/gpl.html

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 

EOF

}

__END__


=head1 NAME

pwldp - Pulls the users from the passwd file and checks LDAP for their existence

=head1 VERSION

This documentation refers to pwldp version 0.0.4

=head1 USAGE

./pwldp

=head1 REQUIRED ARGUMENTS

None

=head1 OPTIONS
 
    --help      for help
    --version   for version information

=head1 DESCRIPTION
 
This program parses the /etc/passwd file and takes all of the user names with
a userid equal to or greater than 1000 and bind to the LDAP server and checks
to see if each user exists in the directory. The list that is returned is a 
list of all users that DO NOT exist in LDAP. 

=head1 DIAGNOSTICS

=head2 Cannot find /etc/passwd:

Indicates that the password file does not exist in that location. You need to 
have an /etc/passwd file in order for this program to work.

=head2 Unable to tie to /etc/passwd:

The program is unable to open the /etc/passwd file for reading. Check the 
permissions on /etc/passwd. 

=head2 Unable to untie /etc/passwd:

The program is unable to close /etc/passwd, this should not occur but if it 
does it is a fatal error.

=head2 Unable to open connection to LDAP server:

The Net::LDAP module is unable to make a connection to the LDAP server. Check
that it is up and running. 
 
=head1 CONFIGURATION AND ENVIRONMENT

The /etc/passwd file must exist for the program to run, as well a working LDAP
server is handy.
 
=head1 DEPENDENCIES
 
    pwldp depends on the following modules:
    Net::LDAP;              CPAN module
    Tie::File;              Built in Perl core module(5.8)
    Fcntl qw( O_RDONLY );   Built in Perl core module(5.8)
    use Getopt::Std;        Built in Perl core module(5.8)
    
=head1 INCOMPATIBILITIES

None known yet.

=head1 BUGS AND LIMITATIONS

Bugs, never heard of 'em ;).
If you encounter any bugs let me know. (erinn.looneytriggs@gmail.com)

=head1 AUTHOR

Erinn Looney-Triggs (looneytr@colorado.edu)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007 Erinn Looney-Triggs (erinn.looneytriggs@gmail.com). 
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License. 
See L<http://www.fsf.org/licensing/licenses/gpl.html>.
 
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
