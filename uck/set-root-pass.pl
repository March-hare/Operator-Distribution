#!/usr/bin/perl
use strict;
use warnings;

# How do we know if the passwd was actually set?  By checking to see if the
# password entry for root is still *
my $shadow = '/etc/shadow';
my $result = `sudo grep ^root: $shadow`;
$result =~ /^root:([^:]+):/;
my $crypted_password = $1;
exit unless ($crypted_password eq '*');
`/usr/bin/gnome-terminal --command="sudo passwd" --title="Set the system password"`;
