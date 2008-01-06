#!/usr/local/perl/bin/perl

#####################################################
#Script to check if the latest version of the nvidia module is installed on
#the system, if not add it to dkms.
#Created: 12/7/2007
#Version: 1.1.0              
#If you change the version number change it in variables as well as in POD
#Revised: 12/28/2007
#Revised by: Erinn Looney-Triggs
#Author: Erinn Looney-Triggs
#####################################################

use Carp;                       #Croak instead of die
use English qw( -no_match_vars );
use Getopt::Long;               #Grab command line switches
use Pod::Usage;                 
use POSIX qw( WIFEXITED );      #Fix system call's strange return values
use strict;                     #Do it right
use Sys::Hostname;
use Tie::File;
use warnings;

$ENV{PATH}              = "/bin:/sbin:/usr/bin:/usr/sbin:"; #Safer path
my $NVidia_module       = "nvidia-current";
my $architecture        = architecture_check();  #Obtain architecture
my $host                = hostname;              #Obtain the hostname
my $NVidia_directory    = "/usr/local/$NVidia_module" . "_" . "$architecture";
my $NVidia_installer    = "$NVidia_directory/nvidia-installer";
my $NVidia_source       = "$NVidia_directory/usr/src/nv/";
my $NVidia_version;
my $version_file        = "$NVidia_directory/VERSIONS";
my $VERSION = "1.1.0";                  #Nvidia-install Version Number

GetOptions(
            'version|V'     => sub { VersionMessage() },
            'help|h'        => sub { pod2usage(1) },
);

#The heart of the matter
rpm_check( "dkms" );    #Check for the existance of the rpm
sanity_checks();        #Perform a number of sanity checks before starting
$NVidia_version = NVidia_version(); #Obtain the version of the NVidia module
dkms_check();           #Check dkms and perform the install


#Check for the architecture type of the system and return the value
sub architecture_check{
    #Capture the architecture output, similair to using uname -a
    my $arch = (POSIX::uname())[4];
    
    #If it is i686 i786 ix86 whatever return arch as i386
    if ($arch =~ /i.86/){
        return "i386";
    }
    #Else return x86_64 or whatever else it is
    else{
        return $arch;
    }
}

sub dkms_add{
    
    my $version = shift;    #Get the version number to be added
    
    #Add the module to dkms, note this will not build the module, that will 
    #happen on reboot as specified in the dkms.conf file
    WIFEXITED ( system "dkms add -m $NVidia_module -v $version --quiet" )
            or croak "Unable to run: dkms add, $CHILD_ERROR, aborting.\n";
    
    return 0;   #Return nothing and do it meaningfully ;)
}

#Checks the status of dkms
sub dkms_check{
    my $dkms_output;
    
    #Capture the output of dkms status to see if there are nvidia modules 
    #installed.

    chomp ($dkms_output = `dkms status -m $NVidia_module`); 
    if ($CHILD_ERROR) {
        croak "Unable to run: dkms status, $CHILD_ERROR, aborting!\n";
    }
    
    #If dkms_version exists then find out the version number and compare it to 
    #NVidia's version.
    if ( $dkms_output =~ /$NVidia_module,\s     #Module name comma space
                        ([\d]+                  #Capture digit(s)
                        (?:[\.|-])              #Non-capture either . or -
                        [\d]+                   #Digit(s)
                        (?:[\.|-][\d]+)?        #Optional . or - and digit(s)
                        ),                      #end capture and comma
                        /x ){
        my $dkms_version = $1;
        
        #Get version number and strip periods and hyphens
        my $dkms_version_numeric = $dkms_version;
        $dkms_version_numeric =~ s/[\.|-]//g;
        
        my $NVidia_version_numeric = $NVidia_version; 
        $NVidia_version_numeric =~ s/[\.|-]//g;
        
        #If the versions do not match remove the dkms version and add the 
        #NVidia version. This allows upgrades as well as downgrades.
        if ( $dkms_version_numeric != $NVidia_version_numeric ){
            
            #Remove the dkms version and remove the symlink in /usr/src
            dkms_remove($dkms_version);
            unlink "/usr/src/$NVidia_module-$dkms_version"
                or croak "Failed to unlink "
                . "/usr/src/$NVidia_module-$dkms_version, aborting!\n";
            
            #This create the symlink to the new version and adds it to dkms
            symlink "$NVidia_source", "/usr/src/$NVidia_module-$NVidia_version" 
                or croak "Failed to symlink: "
                . "/usr/src/$NVidia_module-$NVidia_version, aborting! \n";
            
            dkms_add($NVidia_version);
        }        
    }
    #If no version exists in dkms create one.
    else{
        #Create the symlink to the module source and add the module to dkms
        symlink "$NVidia_source", "/usr/src/$NVidia_module-$NVidia_version" 
            or croak "Failed to symlink: "
            . "/usr/src/$NVidia_module-$NVidia_version, aborting! \n";;
        
        dkms_add($NVidia_version);
    }
    
    return;
}


sub dkms_remove{
    my $dkms_version = shift;   #Get the version number to be removed
    
    #This will remove the module and place back any module that was existing
    #before dkms was installed, it will also remove all the associated NVidia
    #programs as specified in the dkms.conf file
    WIFEXITED ( 
        system "dkms remove -m $NVidia_module -v $dkms_version --all --quiet") 
            or croak "Unable to run: dkms remove, $CHILD_ERROR, aborting.\n";
    
    return;   #Return nothing and do it meaningfully ;)
}

sub NVidia_version{
    my $version;
    my @file;
    
    #Tie to the versions file readonly and search for the version number
    tie @file, 'Tie::File', $version_file, mode => "O_RDONLY"
        or croak "Can't tie to $version_file, $OS_ERROR, aborting!\n";
    
    for my $line (@file){
        #Ugly regex to match NVidias psychotic versioning scheme
        if ($line =~ /
                    \s([\d]+            #Space followed by one or more digits
                    (?:[\.|-])          #Non-capture either . or -
                    [\d]+               #One or more digits
                    (?:[\.|-][\d]+)?    #a . or - followed by digits possibly
                    )                   #Capture it and put it into a var
                    \s/x) {
                        
            $version = $1;
        }
    }
     
    untie @file 
        or croak "Unable to untie $version_file, $OS_ERROR, aborting!";
        
    return $version;    #Return the version number found
}

sub rpm_check{
    my $package = shift;    #Get the package name to be checked for
    my $result;             #Holds output of rpm command
    
    #Make the query to the rpm database to find out if dkms is installed
    chomp ($result = `rpm -q $package`);
    
    #rpm return 1 when the package is not found in the database so:
    if ($CHILD_ERROR){
        if ($result eq "package dkms is not installed"){
            die "The $package rpm is not installed on $host, aborting!\n";
        }
        else {
            croak "An unknown error has occured while attempting to run: "
            . "rpm -q $package, aborting";
        } 
    }
    else {
        return;
    }
    
    return; #Should never be reached but in place
    
}

sub sanity_checks{
    #The architecture must be either x86_64 or i386 nothing else at this time.
    unless (($architecture eq "i386") or ($architecture eq "x86_64")){
        die "Architecture: $architecture, is not supported at this time "
           . "on $host, aborting. \n";
    }
    #The nvidia directory has to exist, if not croak.
    if (!-d "$NVidia_directory") {
        die "$NVidia_directory does not exist on $host, aborting. \n";
    }
    #The version file has to exist, if not croak.
    if (!-e "$version_file"){
        die "The VERSIONS file does not exist in $NVidia_directory "
            . "on $host, aborting. \n";
    }
    #The nvidia-installer script has to exist, if not croak.
    if (!-e "$NVidia_installer"){
        die "$NVidia_installer does not exist on $host, aborting. \n";
    }
    #The nvidia-installer script has to be executable, if not croak.
    if (!-x "$NVidia_installer"){
        die "$NVidia_installer is not executable on $host, aborting. \n";
    }
    #The NVidia source directory has to exist, if not croak.
    if (!-d "$NVidia_source"){
        die "$NVidia_source does not exist on $host, aborting.\n";
    }
    #The dkms.conf file has to exist if not croak
    if (!-e "$NVidia_source/dkms.conf"){
        die "dkms.conf does not exist in $NVidia_source on $host, " 
        . "aborting. \n";
    }
    
return; #Return nothing and do it meaningfully ;)
}

sub main::VersionMessage {
    print <<"EOF";
This is version $VERSION of nvidia-install.

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

NVidia-install - Adds the latest distrbuted version of the nvidia module to dkms.

=head1 VERSION

This documentation refers to NVidia-install version 1.1.0

=head1 USAGE

NVidia-install.pl

=head1 REQUIRED ARGUMENTS

None

=head1 OPTIONS

    --version       (-V) Display version information
    --help          (-h) Display help information

=head1 DESCRIPTION
 
This is an installation script that will check to see if the nvidia module
has been installed via dkms. If not it will set up the environment for it and
add it to dkms so that upon the next reboot the nvidia module will be built
and installed on the system. If the nvidia module version is different than 
the existing dkms version the dkms version will be removed and the nvidia 
version will be added thus bringing the two inline and allowing upgrades.

=head1 DIAGNOSTICS

=head2 

=head1 CONFIGURATION AND ENVIRONMENT

dkms must be installed on the system
 
=head1 DEPENDENCIES

    Carp                    Standard Perl 5.8 module
    English                 Standard Perl 5.8 module
    Getopt::Long            Standard Perl 5.8 module
    Pod::Usage              Standard Perl 5.8 module
    POSIX                   Standard Perl 5.8 module
    Sys::Hostname           Standard Perl 5.8 module
    Tie::File               Standard Perl 5.8 module
    
=head1 INCOMPATIBILITIES

None known yet.

=head1 BUGS AND LIMITATIONS

Bugs, never heard of 'em ;).
If you encounter any bugs let me know. (erinn.looneytriggs@gmail.com)

=head1 AUTHOR

Erinn Looney-Triggs (erinn.looneytriggs@gmail.com)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007-2008 Erinn Looney-Triggs (erinn.looneytriggs@gmail.com). 
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License. 
See L<http://www.fsf.org/licensing/licenses/gpl.html>.
 
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
