vhost-updater
=============

Perl script to add/delete virtual hosts to a debian/ubuntu system.

#Instructions
* Edit the predefined settings.
* Place the script on /usr/local/bin and give it permissions to execute.

chmod +x /usr/local/bin/vhost-updater.pl

run the script with sudo

sudo vhost-updater.pl --add --domain testing.chango

#Syntax
* --add     - Create a new virtual host with all the file structure
* --del     - Remove a virtual host from apache
  * -- rm   - Used with --del switch, also removes the directory for that virtual host
* -- domain - specify the name of the virtual host
* -- php    - (Optional) Specfy php version 5.2, 5.3 or 5.4
