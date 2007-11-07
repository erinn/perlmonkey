#!/usr/local/perl/bin/perl

#####################################################
# Program to perform a lookup in LDAP based on either a login name 
# or a common name 
#
#Created: 2007-11-07
#Version: 1.0.1            
#Revised: 
#Revised by:
#Author: Erinn Looney-Triggs
#####################################################

use strict;                         #Do it right
use warnings;                       #Ditto
use Carp;                           #Croak instead of die
use English qw( -no_match_vars );   #Human readable variable names
use Getopt::Long;                   #Grab command line switches
use Net::LDAP;                      #CPAN module to tie to LDAP server
use Pod::Usage;                     #Parse pod file as help file

my $directory = 'directory.colorado.edu';  #Default LDAP directory is colorado
my @common_name;        #Holds the common name specified
my @login;              #Array to hold login names specified on command line
my $timeout = '30';     #Set the timeout for the ldap call (default 30 seconds)
my $VERSION = '1.0.1';  #Version number of program


Getopt::Long::Configure( 'gnu_compat', );

GetOptions( 'directory|d=s' => \$directory,
            'login|l=s{1,}' => \@login,
            'name|n=s{1,}'  => \@common_name,
            'timout|t=i'    => \$timeout,
            'version|V'     => sub { VersionMessage() },
            'help|h'        => sub { pod2usage(1) },
);

#It seems like there should be a better way to do this. If no getopts are 
#specified, pull "whatever" from the command line and search for it as a 
#common name.
unless (@login || @common_name){
     @common_name = @ARGV;
}

if (@common_name){
    ldap_search('cn', \@common_name);
}

elsif (@login) {
    ldap_search('uid', \@login);
}
else {
    pod2usage(1);
}
=for Ldap_search
    Gets passed two peices of information first they type of search, either
    cn or uid, and then the name(s) to be searched for. 
=cut

sub ldap_search {
    my $ldap = Net::LDAP->new( "ldaps://$directory", timeout=>$timeout)
        or croak($EVAL_ERROR);
    
    my $search_type = shift @_;  #Pull the search type from the array
    my $search_input = shift @_; #Pull the users input array reference
    
    for my $name (@$search_input){
        
        #If search type is cn append asterisks around the name \Q and \E 
        if ($search_type eq 'cn'){
            $name =~ s/(.*)/\*$1\*/m
        };
         
        my $mesg = $ldap->bind() or croak($EVAL_ERROR);
        $mesg = $ldap->search(
                            base    =>  "dc=Colorado,dc=EDU",
                            filter  =>  "($search_type=$name)",
                            attrs   =>  ['displayName', 'description', 'title',
                                         'cuEduPersonHomeDepartment', 
                                         'telephoneNumber', 'mail', 
                                         'postalAddress',]
                            );
        parse_print($mesg->entries);
    }

    $ldap->unbind() or croak($EVAL_ERROR);
    return; #Return nothing and do it with success ;).
}
=for Parse_print:
    Pulls the value out of the LDAP object and prints them to stdout. Tried
    to keep this more generic so it could be reused, so it is possible to 
    pass this subroutine more than one entry when it is called, but for da
    only one entry will be passed per call.
=cut

sub parse_print {
    my $dash = q{-};     #Sometimes you need a dash or more ;)
    
    my @entries = @_;
    for my $entry (@entries){ 
        #There has to be a better way to do this than a bunch of if defined
        #statements, but I don't know it so there you are.
        print $dash x 40 . "\n";
        
        if (defined $entry->get_value("displayName")){
            print "Name:\t\t"     .   $entry->get_value("displayName") . "\n";
        }
        if (defined $entry->get_value("description")){
            print "Type:\t\t"     .   $entry->get_value("description") . "\n";
        }
        if (defined $entry->get_value("title")){
            print "Title:\t\t"    .   $entry->get_value("title") . "\n";
        }
        if (defined $entry->get_value("cuEduPersonHomeDepartment")){
            print "Dept:\t\t"     
            .   $entry->get_value("cuEduPersonHomeDepartment") . "\n";
        }
        if (defined $entry->get_value("telephoneNumber")){
            print "Phone:\t\t"    .   $entry->get_value("telephoneNumber") . "\n";
        }
        if (defined $entry->get_value("mail")){
            print "E-Mail:\t\t"   .   $entry->get_value("mail") . "\n";
        }
        if (defined $entry->get_value("postalAddress")){
            print "Address:\t"  .   $entry->get_value("postalAddress") . "\n";
        }
        print $dash x 40 . "\n";
    }; 
    return; #Return nothing meaningful
}

sub main::VersionMessage {
    print <<"EOF";
This is version $VERSION of da.

Copyright (c) 2007 Erinn Looney-Triggs (erinn.looneytriggs\@gmail.com). 
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License. 
See http://www.fsf.org/licensing/licenses/gpl.html

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 

EOF

    exit 1;
}

__END__
=head1 NAME

da - Searches the specified LDAP directory by common name or by user name.

=head1 VERSION

This documentation refers to da version 1.0.1

=head1 USAGE

da [options] PATTERN

=head1 REQUIRED ARGUMENTS

Must supply at least one common name to search for.

=head1 OPTIONS

da [options] PATTERN

--directory (-d)   Specifies the location of the LDAP server, defaults to Colorado

--help      (-h)   Will list the command line switches that can be used

--login     (-l)   Must be followed by one or more login name(s)

--name      (-n)   Must be followed by on or more common name(s)

--timeout   (-t)   Specifies the max timeout to wait for a return (default 30 seconds)

--version   (-V)   Will output the version information for the program

=head1 DESCRIPTION
 
This is a small perl script that connects to an LDAP server and searches
for either a login name (--login, -l) or for a common name (--name , -n) and 
returns the results in an easy to read form.

=head1 CONFIGURATION AND ENVIRONMENT

Networking and openssl must be available for the link to the LDAP directory 
to work.
 
=head1 DEPENDENCIES
 
    da depends on the following modules:
    Getop::Long     Standard Perl 5.8 module
    Net::LDAP       CPAN module
    Pod::Usage      Standard Perl 5.8 module
    
=head1 INCOMPATIBILITIES

None known yet.

=head1 BUGS AND LIMITATIONS

Bugs, never heard of 'em ;).
If you encounter any bugs let me know. (erinn.looneytriggs@gmail.com)

=head1 AUTHOR

Erinn Looney-Triggs (erinn.looneytriggs@gmail.com)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007 Erinn Looney-Triggs (erinn.looneytriggs@gmail.com). 
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License. 
See L<http://www.fsf.org/licensing/licenses/gpl.html>.
 
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 

