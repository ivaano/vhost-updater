#!/usr/bin/perl -w

#############################################################
# The purpose of this script is to add/remove				# 
# virtual hosts easily, this script runs 					#
# on Ubuntu/Debian withouth modifications. 					#
#         													#	
#         													#	
# Author Ivan Villareal ivaano@gmail.com					#
#         													#	
#############################################################
use strict;
use File::Path qw(mkpath rmtree);
use Getopt::Long;


our $interface        = 'eth0';
our $ifconfig         = '/sbin/ifconfig';
our $apacheConfigDir  = '/etc/apache2';
our $sitesAvailable   = 'sites-available';

our $docRootPrefix    = '/var/www/vhosts';
our $docRoot          = 'public_html';
our $logsDir          = 'logs';
our $user 			  = 'ivan';
our $ipAddress;



my $del = '';
my $add = '';
my $domain = '';

if (getpwuid( $< ) ne 'root') {
	print "Script needs root privileges \n";
	exit();
}

unless (GetOptions (
		'del' => \$del, 
		'add' => \$add, 
		'domain=s' => \$domain) or usage()) {
    usage();
}

#print $paramResults;
if ($add || $del) {
    if ($domain) {
        if ($add) {
            createVhost($domain);
        } elsif ($del) {
            deleteVhost($domain);
        }
    } else {
        usage();
    }
} else {
    usage();
}


sub usage {
    print <<USAGE
This program will add or remove apache virtual hosts.

usage: vhost-updater.pl [--add | --del] --domain newhost.tld 
USAGE
}

sub determineIp 
{
    my @lines=qx|$ifconfig $interface| or die("Can't get info from ifconfig: ".$!);
    foreach(@lines){
        if(/inet addr:([\d.]+)/) {
            $ipAddress = $1;
        }
    }
}

sub returnVhostPaths
{
    my $vhost = shift;
    my @dir = split(/\//, $docRootPrefix);
    my %res;
    
    push(@dir, $vhost);

    my $hostDir = join('/', @dir);
    $res{'docRoot'} = $hostDir . '/' . $docRoot;
    $res{'logsDir'} = $hostDir . '/' . $logsDir;
	$res{'hostDir'} = $hostDir;
    #todo dir validation
    @dir = split(/\//, $apacheConfigDir);
    push(@dir, $sitesAvailable);
    push(@dir, $vhost);
    $res{'apacheConfig'} = join('/', @dir);
    
    return %res;   
}

sub createVhost {
    my $vhost = shift;
    #first create the docRoot
    my %vhostInfo = returnVhostPaths($vhost);
    
    informOut("Creating docroot dir: $vhostInfo{'docRoot'}");
    mkpath($vhostInfo{'docRoot'});
	my $uid  = getpwnam($user);
	my $gid  = getgrnam($user);
	chown $uid, $gid, $vhostInfo{'hostDir'};
	chown $uid, $gid, $vhostInfo{'docRoot'};
    informOut("Creating log dir: $vhostInfo{'logsDir'}");
    mkpath($vhostInfo{'logsDir'});
    

    informOut("Site File: $vhostInfo{'apacheConfig'}");
    
    my $vhostContent = << "EOF";
<VirtualHost *:80>
    ServerName $vhost
    DocumentRoot $vhostInfo{'docRoot'}
    <Directory $vhostInfo{'docRoot'}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Order allow,deny
        Allow from all
    </Directory>
        ErrorLog $vhostInfo{'logsDir'}/error_log
        CustomLog $vhostInfo{'logsDir'}/access_log "%h %l %u %t \\"%r\\" %>s %b \\"%{Referer}i\\" \\"%{User-agent}i\\""
        LogLevel error
</VirtualHost>

EOF
    informOut("Creating Vhost...");
    open FILE, ">", $vhostInfo{'apacheConfig'} or die $!;
    print FILE $vhostContent;
    close FILE;
    
    my $initialTemplate = << "PHP";
<?php
    phpinfo();
PHP
    informOut("Creating index.php file...");
    open FILE, ">", $vhostInfo{'docRoot'}.'/index.php' or die $!;
    print FILE $initialTemplate;
    close FILE;
	chown $uid, $gid, $vhostInfo{'docRoot'}.'/index.php';

    informOut("Adding host $vhost");
    determineIp();
    open FILE, ">>", '/etc/hosts' or die $!;
    print FILE $ipAddress ."\t". $vhost ."\n";
    close FILE;
      
    my $output = `/usr/sbin/a2ensite $vhost`;
    print $output;
   
    restartApache();
    #print $vhostConten t;
}

sub restartApache
{
    informOut("Restarting apache...");
    my $output = `/etc/init.d/apache2 restart`;
    print $output; 
    my $dnsmasq = `ps -eaf |grep dnsmasq |grep -v grep`;
    if ($dnsmasq ne "") {
        my $output = `/etc/init.d/dnsmasq restart`;
        print $output; 
    }
}

sub deleteVhost
{
    my $vhost = shift;
     my %vhostInfo = returnVhostPaths($vhost);
     
    informOut("Removing $vhost from hosts file");
    open IN, '<', '/etc/hosts' or die $!;
    my @hostsFile = <IN>;
    close IN;
    
    my @contents = grep(!/^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\t$vhost/, @hostsFile);
    
    open FILE, ">", '/etc/hosts' or die $!;
    print FILE @contents;
    close FILE;
    
    my $output = `/usr/sbin/a2dissite $vhost`;
    print $output;
    
    informOut("Removing  $vhostInfo{'apacheConfig'} file");
    unlink($vhostInfo{'apacheConfig'});
    
    restartApache();
        
    print " manually remove $vhostInfo{'docRoot'}... \n";
    
}

sub informOut {
    my $message = shift;
    print "$message \n";
}
