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
use POSIX;
use Sys::Hostname;
use Scalar::Util qw(looks_like_number);

our $interface        = 'eth0';
our $ifconfig         = '/sbin/ifconfig';
our $apacheConfigDir  = '/etc/apache2';
our $sitesAvailable   = 'sites-available';

our $docRootPrefix    = '/var/www/vhosts';
our $docRoot          = 'public_html';
our $logsDir          = 'logs';
our $user 			  = 'ivan';
our $ipAddress;
#leave empty if you dont want the sites sumary file
our $sumaryFile       = '/var/www/default/sumary.html';



my $del = '';
my $rm  = '';
my $add = '';
my $sumaryTbl= '';
my $domain = '';
my $description = '';
my $php = '';

if (getpwuid( $< ) ne 'root') {
	print "Script needs root privileges \n";
	exit();
}

unless (GetOptions (
		'del' => \$del, 
		'add' => \$add, 
        'summary' => \$sumaryTbl,
		'domain=s' => \$domain,
		'desc=s' => \$description,
        'php=s' => \$php,
        'rm' => \$rm) or usage()) {
    usage();
}

#print $paramResults;
if ($add || $del) {
    if ($domain) {
        if ($add) {
            $php = ($php eq '') ? '5.4' : $php;
            if ($php eq '5.2' || $php eq '5.3' || $php eq '5.4') {
                print "Configuring a new virtual host with php $php \n";
                createVhost($domain, $php, $description);
            } else {
                print "unknown php version, please choose between 5.2, 5.3 or 5.4 \n";
                exit;
            }
        } elsif ($del) {
            deleteVhost($domain, $rm);
        }
    } else {
        usage();
    }
} elsif ($sumaryTbl){
    createSummaryTable(); 
}else {
    usage();
}


sub usage {
    print <<USAGE;
This program will add or remove apache virtual hosts.

usage: vhost-updater.pl [--add | --del [ --rm ] | --summary] [--php (5.2 | 5.3 | 5.4)] --domain newhost.tld --desc "My new site"
USAGE

    exit;
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
    my $php   = shift;
    my $desc  = shift;
    if ($desc eq '') {
        #the description was not passed as an arg
        #lets ask for one
        print "Enter a small description for this project: ";
        $desc = <>;
    }
    $desc =~ s/^\s+//;
    $desc =~ s/\s+$//;
    if ($desc ne '') {
        $desc = '#Description: '.$desc;
    }
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
    my $phpVersion = '';
    my $engineOff  = '';

    if ($php eq '5.2') {
        $engineOff = 'php_value engine off';
        $phpVersion = << "PHP";
        AddHandler php-cgi .php
        AddType application/x-httpd-php .php
        Action application/x-httpd-php "/php/php-cgi-5.2.17"
PHP

    }
    
    if ($php eq '5.3') {
        $engineOff = 'php_value engine off';
        $phpVersion = << "PHP";
        AddHandler php-cgi .php
        AddType application/x-httpd-php .php
        Action application/x-httpd-php "/php/php-cgi-5.3.16"
PHP

    }
    
    my $vhostContent = << "EOF";
$desc
<VirtualHost *:80>
    ServerName $vhost
    DocumentRoot $vhostInfo{'docRoot'}
    $engineOff
    <Directory $vhostInfo{'docRoot'}>
        $phpVersion
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
    createSummaryTable();
    informOut("new vhost ready at http://$vhost");
}

sub createSummaryTable 
{
    if ($sumaryFile eq '') {
        return;
    }
    my @vhosts;
    my @dir = split(/\//, $apacheConfigDir);
    push(@dir, $sitesAvailable);
    my $dir = join('/', @dir);
    #reed all files in sites-enabled
    opendir (DIR, $dir) or die $!;
    while (my $file = readdir(DIR)) {
        #omit . and .. files
        next if ($file =~ m/^\./);
        my %vhostData= ();
        $file = "$dir/$file";
        #read each file content
        my $vhostFile = do {
           local $/ = undef;
            open my $fh, "<", $file
            or die "could not open $file: $!";
            <$fh>;
        }; 
        #include only VirtualHosta with ServerName
        $vhostFile =~ /(?<=ServerName\s)(?:.*)/; 
        if (length( $& // '')) {
            $vhostData{'Date'} = POSIX::strftime("%m/%d/%y",localtime((stat $file)[10]));
            $vhostData{'ServerName'}=$&; 
            $vhostFile =~ /(?<=DocumentRoot\s)(?:.*)/; 
            $vhostData{'DocumentRoot'}=$&; 
            if ($vhostFile =~ /(?<=\#Description:\s)(?:.*)/) {
                $vhostData{'Description'}=$&; 
            } else {
                $vhostData{'Description'}=''; 
            }
            $vhostData{'SiteFile'} = $file;
            push(@vhosts, \%vhostData);
        }
    }
    closedir(DIR);
    #sort by ServerName
    @vhosts = sort{$a->{'ServerName'} cmp $b->{'ServerName'}} @vhosts;
    my $hostname = hostname;
    my $html = <<"HTML";
<!DOCTYPE HTML>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>Virtual Hosts</title>
<style type="text/css">

body
{
  line-height: 1.6em;
}

h1 {
  font-family: "Lucida Sans Unicode", "Lucida Grande", Sans-Serif;
  font-weight: bold;
  color: #000;
  font-size: 32px;
}

#box-table-a
{
  font-family: "Lucida Sans Unicode", "Lucida Grande", Sans-Serif;
  font-size: 14px;
  margin-left:auto; 
  margin-right:auto;
  width: 900px;
  text-align: left;
  border-collapse: collapse;
}
#box-table-a th
{
  font-size: 13px;
  font-weight: normal;
  padding: 8px;
  background: #b9c9fe;
  border-top: 4px solid #aabcfe;
  border-bottom: 1px solid #fff;
  color: #039;
}
#box-table-a td
{
  padding: 8px;
  background: #e8edff; 
  border-bottom: 1px solid #fff;
  color: #669;
  border-top: 1px solid transparent;
}
#box-table-a tr:hover td
{
  background: #d0dafd;
  color: #339;
}
</style>
</head>
<body>

<h1>$hostname Virtual Hosts</h1>

<table id="box-table-a" summary="Employee Pay Sheet">
    <thead>
      <tr>
          <th scope="col">Name</th>
            <th scope="col">Description</th>
            <th scope="col">Location</th>
            <th scope="col">Date</th>
        </tr>
    </thead>
    <tbody>
HTML
 
    #table generation
    foreach (@vhosts) {
        my %hashi = %{$_};
        #print $hashi{'ServerName'} . "\n";
        #print $hashi{'DocumentRoot'} . "\n";
        #print "Description: " . $hashi{'Description'} . "\n";
        #print $hashi{'SiteFile'} . "\n";
        #print $hashi{'Date'} . "\n";
        #print "=========================\n";
        $html .="        <tr>
            <td><a href=\"http://$hashi{'ServerName'}\">$hashi{'ServerName'}</a></td>
            <td>$hashi{'Description'}</td>
            <td>$hashi{'DocumentRoot'}</td>
            <td>$hashi{'Date'}</td>
        </tr>
";
        }
    $html .= <<"HTML";
    </tbody>
</table>
</body>
</html>
HTML
    
    informOut("Creating Sumary Table in $sumaryFile");
    open FILE, ">", $sumaryFile or die $!;
    print FILE $html;
    close FILE;
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
    my $rm = shift;
    #fix warning for empty args
    if (!looks_like_number($rm)) {
        $rm = 0;
    }

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
    
    if ($rm == 1) {
        rmtree($vhostInfo{'hostDir'}, { 
                verbose => 1});
    } else {
        print " manually remove $vhostInfo{'docRoot'}... \n";
    }
    restartApache();
    createSummaryTable();
}

sub informOut {
    my $message = shift;
    print "$message \n";
}
