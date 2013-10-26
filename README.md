vhost-updater
=============

Perl script to add/delete virtual hosts to a debian/ubuntu system.

#Instructions
* Edit the predefined settings.
        our $interface        = 'eth0';
        our $ifconfig         = '/sbin/ifconfig';
        our $apacheConfigDir  = '/etc/apache2';
        our $sitesAvailable   = 'sites-available';
        our $docRootPrefix    = '/var/www/vhosts';
        our $docRoot          = 'public_html';
        our $logsDir          = 'logs';
        our $user 			  = 'ivan';
* Place the script on /usr/local/bin and give it permissions to execute.

chmod +x /usr/local/bin/vhost-updater.pl

run the script with sudo

sudo vhost-updater.pl --add --domain testing.chango

#Syntax
* --summary - Create an html table with all the virtual hosts in sites-enabled folder
* --add     - Create a new virtual host with all the file structure
* --del     - Remove a virtual host from apache
  * -- rm   - Used with --del switch, also removes the directory for that virtual host.
* --domain  - Used with (add | del) to specify the name of the new virtual host to be added or removed.
* --php     - (Optional) used with add to specfy php version 5.2, 5.3 or 5.4
* --desc    - (Optional) used with add argument to  add a description as comment to the virtual host.
