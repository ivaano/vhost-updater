vhost-updater
=============

Perl script to add/delete virtual hosts to a debian/ubuntu system.

#Instructions
* Edit the predefined settings.
* Place the script on /usr/local/bin and give it permissions to execute.

chmod +x /usr/local/bin/vhost-updater.pl

run the script with sudo

sudo vhost-updater.pl --add --domain testing.chango
