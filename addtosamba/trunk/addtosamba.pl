#!/usr/local/perl/bin/perl -w
=for Information:
Program to add users from the /etc/passwd file to the smbpasswd file. 
Also cleans out any users present in the smbpasswd file that are not 
present in the passwd file. In order to access samba shares a user must
have both a system account and an smb account. Thus, any enttries that are
present in the smbpasswd file and not in the passwd file are cruft and need
to be removed.
Created: 10/29/2006
Version: 0.0.3              #Change this in the pod as well, when you bump up
Revised: 04/01/2007
Revised by: Erinn Looney-Triggs
Author: Erinn Looney-Triggs, with a lot of help
=cut

use strict;                     #Build it right or don't do it at all ;)
use Tie::File;                  #Access smbpasswd file as an array
use File::Basename;             #Strips the directory path
use List::Compare;              #Compares two lists in many different ways
use File::Temp qw(tempfile);    #Create temporary files safely

my $program_name   = basename($0);
my $passwd_file    = "/etc/passwd";
my $smbpasswd_dir  = "/usr/local/samba/private/";
my $smbpasswd_file = "/usr/local/samba/private/smbpasswd";

umask 077;                      #Antisocial umask to keep people out

#Test to make sure the files exist, if not die
if ( !-e $passwd_file or !-e $smbpasswd_file ){
    die "The /etc/passwd file or the smbpasswd file does not exist.\n" 
}

#Check to make sure this is being run with root privileges.
die "This program must be run with root privileges.\n" if ( $< ne "0" );

#Get a sorted list of system usernames
my @passwd_uname = &get_uname($passwd_file);

#Get a sorted list of samba usernames
my @samba_uname = &get_uname($smbpasswd_file);

#List of comparisons
my $lc = List::Compare->new( \@passwd_uname, \@samba_uname );

#Get the unames that are unique to the smbpasswd file
my @unique_samba_uname = $lc->get_Ronly;

#Get the unames that are unique to the passwd file
my @unique_passwd_uname = $lc->get_Lonly;

#Removes entries in smbpasswd that are not in the passwd file
&rm_from_samba(@unique_samba_uname);

#Adds the new entries from the passwd file to the smbpasswd file
&add_to_samba(@unique_passwd_uname);


#Adds unique users from passwd file into smbpasswd file
sub add_to_samba {

    #Ties the smb_passwd file into the program as an array
    tie my @passwd, 'Tie::File', $smbpasswd_file
        or die "Can't tie to $smbpasswd_file: $!\n";

    my $x    = "X";
    my $time = sprintf( "%X", time );    #Grab time, convert to hex

    ( tied @passwd )->defer;    #Defer writes until we are done messing about

    for (@_) {
        push @passwd,
            "$_:"
            . getpwnam($_) . ":"
            . $x x 32 . ":"
            . $x x 32
            . ":[U          ]:LCT-$time:\n";
    }

    @passwd = sort(@passwd);
    ( tied @passwd )->flush;    #Flush those writes to disk
    untie @passwd;              #Be polite and untie it
}

#Returns a list of usernames from a passwd formatted file
sub get_uname {
    my $passwd_file = shift @_;
    my @unamelist;

    open my $PASSWD, "<", "$passwd_file"
        or die "Unable to open $passwd_file: $!\n";

    
    while (<$PASSWD>) { push @unamelist, ( split /:/ )[0]; }

    close $PASSWD or die "Unable to close $passwd_file: $!\n";
    return ( sort(@unamelist) );
}

#Remove entries in smbpasswd that are not in the passwd file
sub rm_from_samba {

    my $string;

    open my $OLD_SMBPASSWD, "<", "$smbpasswd_file"
        or die "Unable to open $smbpasswd_file: $!\n";
    my ( $NEW_SMBPASSWD, $tmp_filename ) = tempfile( DIR => $smbpasswd_dir );
    die "Unable to create temporary file.\n" if ( !defined $NEW_SMBPASSWD );

    while (<$OLD_SMBPASSWD>) {
        for $string (@_) {

            #\Q and \E stop $string from changing the regex with special
            #characters. So find the lines that match, with the users that
            #were found to not exist in the passwd file and delete those users
            s/^\Q$string\E:.*\n//;
        }

        print {$NEW_SMBPASSWD} $_
            or die "Unable to write to temporary file: $!\n";
    }

    #Close up the files that we have used
    close $OLD_SMBPASSWD or die "Unable to close $smbpasswd_file: $!\n";
    close $NEW_SMBPASSWD or die "Unable to close temporary file: $!\n";

    #Rename the tmp file to smbpasswd
    rename( $tmp_filename, $smbpasswd_file );
}

__END__


=head1 NAME

addtosamba - Adds users in /etc/passwd to smbpasswd

=head1 VERSION

This documentation refers to addtosamba version 0.0.3

=head1 USAGE

sudo ./addtosamba

=head1 REQUIRED ARGUMENTS

None 

=head1 OPTIONS
 
None

=head1 DESCRIPTION
 
This program compares the /etc/passwd file and the smbpasswd file and then 
removes the user entries that are present in the smbpasswd file but not in the 
/etc/passwd file. It then adds any users that are present in the /etc/passwd
file but not in the smbpasswd file to the smbpasswd file.

=head1 DIAGNOSTICS

=head2 The /etc/passwd file or the smbpasswd file does not exist:

This means that either one or the other of these files is not present. If you
don't have an /etc/passwd you are in trouble. If you don't have an smbpasswd
file simply 'sudo touch /usr/local/samba/private/smbpasswd'.

=head2 This program must be run with root privileges:

Explains itself. You must be root in order to modify the smbpasswd file.

=head2 Can't tie to smbpasswd file:

Means that for some reason the program is not able to open the smbpasswd file.
Check the permissions on the smbppasswd file, this program requires rw access
to this file as root.

=head2 Unable to open passwd file:

Means that addtosamba was unable to read the /etc/passwd file. This shouldn't
happen if it exists and falls under "normal" permissions. However, if this 
does happen you should probably check the permissions of the file.

=head2 Unable to close passwd file:

You are in trouble here something at the system level is probably going wrong.

=head2 Unable to open smbpasswd file:

Check the permissions for the smbpasswd file, is root able to write to it?

=head2 Unable to create temporary file:

Check the permissions of the directory where the smbpasswd file is housed. Is
root able to create a file in this directory? Also make sure the permissions 
on the directory are tight, mode 700 for root suggested.

=head2 Unable to write to temporary file:

Issues with permissions though this should not happen because 
addtosamba is creating the temporary file and opening it read, write.

=head2 Unable to close smbpasswd file:

You are in trouble here something at the system level is probably going wrong.

=head2 Unable to close temporary file:

You are in trouble here something at the system level is probably going wrong.
 
=head1 CONFIGURATION AND ENVIRONMENT

The /etc/passwd file and the /usr/local/samba/private/smbpasswd file must be 
present in order for this script to work. 
 
=head1 DEPENDENCIES
 
    addtosamba depends on the following modules:
    Tie::File           Part of Perl 5.8 core modules
    File::Basename      Part of Perl 5.8 core modules
    List::Compare       Not a standard module
    File::Temp          Part of Perl 5.8 core modules

=head1 INCOMPATIBILITIES

None known yet.

=head1 BUGS AND LIMITATIONS

Bugs, never heard of 'em ;).
If you encounter any bugs let me know. (erinn.looneytriggs@gmail.com)

=head1 AUTHOR

Erinn Looney-Triggs (erinn.looneytriggs@gmail.com)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007 Erinn Looney-Triggs (erinn.looneytriggs@gmail.com). 
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License. 
See L<http://www.fsf.org/licensing/licenses/gpl.html>.
 
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
