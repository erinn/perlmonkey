#!/usr/local/perl/bin/perl

#   This product includes software developed by
#   The Apache Software Foundation (http://www.apache.org/).

#####################################################
#Script to split out virtual hosts from an apache log file. It is assumed
#that the first item in a line will be the vhost name. This script 
#was originally supposed to be a minor tweak of the apache split-logfile
#script, but ended up being a large re-write of that work, adding features
#here and there. This work is licensed under the terms of the APL. Take a 
#look here for more info: http://www.apache.org/licenses/LICENSE-2.0
#Created: 03/06/2008
#Version: 1.0.0             
#If you change the version number change it in variables as well as in POD
#Revised: 
#Revised by: 
#Author: Erinn Looney-Triggs
#####################################################

use strict;                         #Do it right
use warnings;                       #Give warnings to help out
use English qw( -no_match_vars );   #Do it in plain english
use Getopt::Long;
use IO::File;                       #Lower level open for files
use Pod::Usage;

my %output_handles;                 #Holds output filhandles for the log files

my $VERSION = '1.0.0';  #Version number
my $access_log;         #Location for the central access_log
my $default_hostname;   #Default hostname 
my $log_directory;      #Where to write logfiles

GetOptions( 'accesslog|a=s'         => \$access_log,
            'directory|d=s'         => \$log_directory,
            'defaulthostname|n=s'   => \$default_hostname,                  
            'version|V'             => sub { VersionMessage() },
            'help|h'                => sub { pod2usage(1) },
);

if ( !defined $access_log || !defined $log_directory || !defined $default_hostname){
    pod2usage(1);
}

#Open the central log file for writes, this logs all requests
my $ACCESS_LOG = IO::File->new("$access_log", '>>') 
    or die "Unable to open $access_log: $OS_ERROR\n";

#Flush to disk ASAP
$ACCESS_LOG->autoflush;

while (my $log_line = <>) {

    #Pull the first entry from the line and make it lowercase
    my $vhost = lc((split (/\s/, $log_line))[0]);
    
    #If the vhost entry is blank than assign it the default hostname.
    if ($vhost eq ''){
        $vhost = $default_hostname; 
    }
    
    #Define the location where the output log file should be written to.
    my $vhost_directory = $log_directory . (split (/\./, $vhost))[0] . "/";
    
    
    # if the vhost contains a "/" or "\", it is illegal so just use 
    # the default log to avoid any security issues due if it is interprted
    # as a directory separator.
    
    if ($vhost =~ m#[/\\]#) { 
        $vhost = $default_hostname; 
    }
    
    #If the file is not open, open it and assign the reference to the hash
    #to keep it open for the entire run or fail if unable to open. If hash is
    #already defined pass that reference to $FILE for writing.

    my $FILE = $output_handles{$vhost} 
        ||= IO::File->new("${vhost_directory}${vhost}_access_log", '>>' )
        ||  die "Cannot create ${vhost_directory}${vhost}_access_log: $OS_ERROR\n";            
    
    #Flush to disk ASAP
    $FILE->autoflush;
    
    #I don't like the two prints, thought about IO::Tee but I want to remove 
    #the vhost from the line before placing it in the vhost logfile yet leave
    #the vhost in for the central log file.
    
    print $ACCESS_LOG $log_line;    #Put the unedited line into the central log
    
    $log_line =~ s/^\S*\s+//;       #Edit the line and remove the vhost
    printf $FILE "%s", $log_line;   #Place line into vhost log file
}

#Be OCD and close the files before exiting.
$ACCESS_LOG->close or die "Unable to close $access_log: $OS_ERROR \n";

for my $filehandle (keys %output_handles){
    $output_handles{$filehandle}->close
        or die "Unable to close $output_handles{$filehandle}: $OS_ERROR\n"; 
}

sub main::VersionMessage {
    print <<"EOF";
This is version $VERSION of split-logfile.

This product includes software developed by
The Apache Software Foundation (http://www.apache.org/)

Copyright 2008 Erinn Looney-Triggs
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

EOF

    exit 1;
}

__END__
=head1 NAME

split-logfile - Splits apache logfiles out by virtual host. 

=head1 VERSION

This documentation refers to split-logfile version 1.0.0

=head1 USAGE

split-logfile <location of logfile to be split> or pipe in input.

=head1 REQUIRED ARGUMENTS

None 

=head1 OPTIONS

    --accesslog         (-a) Location of the logfile with all entries
    --directory         (-d) Specify the output logfile directory
    --defaulthostname   (-n) Sets the default hostname for null entries in logs
    --version           (-V) Display version information
    --help              (-h) Display help information

=head1 DESCRIPTION
 
Split-logfile examines each line of a given input, pulls the first entry from
that line and assumes that to be the virtual host name. It then opens a file
in a specified directory (via -d) or defaults to /web/logs/<vhost_name>/ as 
<vhost>_access_log and strips the the virtaulhost entry off of the line and 
writes the line to the file. It simultaneously maintains a central log file
with all the log entries and their associated vhost in a user specified 
location (via -a). The program is designed to be piped into by apache but can
be used standalone to split out log-file entries.

=head1 DIAGNOSTICS

=head2

=head1 CONFIGURATION AND ENVIRONMENT


 
=head1 DEPENDENCIES

    English                 Standard Perl 5.8 module
    Getopt::Long            Standard Perl 5.8 module
    Pod::Usage              Standard Perl 5.8 module
    IO::File                Standard Perl 5.8 module
    
=head1 INCOMPATIBILITIES

None known yet.

=head1 BUGS AND LIMITATIONS

Bugs, never heard of 'em ;).
If you encounter any bugs let me know. (erinn.looneytriggs@gmail.com)

=head1 AUTHOR

Erinn Looney-Triggs (erinn.looneytriggs@gmail.com)

=head1 LICENCE AND COPYRIGHT
This product includes software developed by
The Apache Software Foundation (http://www.apache.org/)

Copyright 2008 Erinn Looney-Triggs
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
 
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.