#!/usr/local/bin/perl

#####################################################
#Script to prepare the kernel sources directory for a system if it is an i386
#architecture, if not do nothing.
#Created: 12/14/2007
#Version: 1.0.0              
#If you change the version number change it in variables as well as in POD
#Revised: 
#Revised by: Erinn Looney-Triggs
#Author: 
#####################################################

use Carp;                       #Croak instead of die
use English qw( -no_match_vars );
use Getopt::Long;               #Grab command line switches
use Pod::Usage;                 
use POSIX qw( WIFEXITED );      #Fix system call's strange return values
use strict;                     #Do it right
use Sys::Hostname;
use warnings;

my $host                = hostname;              #Obtain the hostname
my $kernel_source;
my $VERSION             = '1.0.0';

GetOptions( 'kernel-source|k=s'     => \$kernel_source,
            'version|V'             => sub { VersionMessage() },
            'help|h'                => sub { pod2usage(1) },
);

sanity_checks();
kernel_prep();



#Does the kernel preperation.
sub kernel_prep {
   
    #Make sure the i386 kernel source exists.
    if ( ! -e "$kernel_source/arch/i386" ){
        die "Does not exist: $kernel_source/arch/i386 , aborting!\n";
    }
    if ( !-e "$kernel_source/arch/i686"){    
    symlink "$kernel_source/arch/i386", "$kernel_source/arch/i686" 
        or croak "Failed to symlink: $kernel_source/arch/i686, $OS_ERROR aborting! \n";
    }    
       
    return 0;    #Return nothing, and do it with meaning ;)
    
}
#Check to make sure the system is in the state we need
sub sanity_checks {
    #Mark sure kernel_source is defined from the command line.
    if ( ! defined $kernel_source){
       pod2usage(1);
    }
    #Make sure the kernel source directory actually exists.
    if ( ! -e "$kernel_source" ){
        die "Kernel source directory: $kernel_source does not exist, aborting!\n";    
    }
    #Make sure the user can write to the arch directory or symlink will fail.
    if ( ! -w "$kernel_source/arch/" ){
        die "Unable to write to $kernel_source/arch/, aborting!\n";
    }
    
}
sub main::VersionMessage {
    print <<"EOF";
This is version $VERSION of kernel-prep.

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

kernel-prep - Prepares the kernel sources directory for the NVidia installer

=head1 VERSION

This documentation refers to kernel-prep version 1.0.0

=head1 USAGE

kernel-prep.pl --kernel-source <kernel-source-directory>

=head1 REQUIRED ARGUMENTS

--kernel-source 

=head1 OPTIONS

    --kernel-source (-k) Specify the location of the kernel source directory
    --version       (-V) Display version information
    --help          (-h) Display help information

=head1 DESCRIPTION
 
Kernel-prep takes a look at the architecture of the system that it is being 
run on and if the architecture is i386 the script enters the kernel source 
directory specified and creates a symbolic link from i686 to i386. This link 
is necessary for the NVidia module to be able to compile on the i386 
architectures.

=head1 DIAGNOSTICS

=head2 Does not exist: <kernel_source>/arch/i386 , aborting!

This i386 directory does not exist in the kernel source arch directories. If
you are running an i386 system the i386 directory should exist in the kernel 
source directories. Try re-installing the kernel-source packages.

=head2 Failed to symlink: <kernel_source>/arch/i686, aborting!

Perl was unable to create a symlink in the <kernel_source>/arch/ directory 
from i386 to i686. This should not normally occur as the program checks to 
make sure that the directory is writable by the executing user. If this does
happen recheck to make sure that the directory is writable by the user 
running the script.

=head2 Kernel source directory: <kernel_source> does not exist, aborting!

Pretty self explanatory, the kernel source directory does not exist in the 
location that the program is searching for it. This parameter is passed by dkms
so either the directory does not exist because you need to install the kernel
sources or dkms is getting confused about where the kernel sources are.

=head2 Unable to write to <kernel_source>/arch/, aborting!

The directory is not writable by the user running the script. Either run the
script under the appropriate user or make sure that directory is writeable by
the user running the script.


=head1 CONFIGURATION AND ENVIRONMENT

dkms must be installed on the system
 
=head1 DEPENDENCIES

    Carp                    Standard Perl 5.8 module
    English                 Standard Perl 5.8 module
    Getopt::Long            Standard Perl 5.8 module
    Pod::Usage              Standard Perl 5.8 module
    POSIX                   Standard Perl 5.8 module
    Sys::Hostname           Standard Perl 5.8 module
    
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
