#!/usr/bin/perl
use warnings;

use Net::DBus;
use Net::DBus::Dumper;
use Net::DBus::Reactor;
use Net::DBus::RemoteObject;
use Data::Dumper;

my $SERVICE = "org.freedesktop.UDisks";
my $PATH = "/org/freedesktop/UDisks";
my $bus = Net::DBus->system();
my $service = $bus->get_service($SERVICE);
my $object = $service->get_object($PATH, $SERVICE);
$object->connect_to_signal('DeviceAdded', \&foundIt);

sub foundIt() {
  print Dumper(@_);
  my ($device) = @_;

  # connect to the properties interface on the dbus service and get a handle
#  my $iface = $bus
#    ->get_service('org.freedesktop.DBus.Properties')
#    ->get_object('/org/freedesktop/DBus/Properties');

  #print "\n". Dumper($iface) ."\n";
  #print "\n". Dumper($iface->Properties->Get()) ."\n";
  print "Found $device\n";
  $reactor->shutdown();
}

$| = 1;
print "Insert a device...";
our $reactor = Net::DBus::Reactor->main();
$reactor->run();
print "hey...";

sub tmp2{
#my $names = $device->Get('/org/freedesktop/UDisks/devices/sdc', 'DeviceIsRemoveable');
#my $names = $device->GetAll();
#my $names = $device->GetAllProperties();
#print Dumper($names);
exit;
}


sub tmp {


# get the Dbus service on the system bus
my $device = $bus
  ->get_service(
    #'org.freedesktop.UDisks')
    'org.freedesktop.UDisks', '/org/freedesktop/UDisks/devices/sdc')
  ->get_object(
    '/org/freedesktop/UDisks/Device');
    #'/org/freedesktop/UDisks/Device', '/org/freedesktop/UDisks/devices/sdc');

$udisk_service = $bus->get_service('org.freedesktop.UDisks');
$device = $udisk_service->get_object('/org/freedesktop/UDisks/devices/sdc');
#print dbus_dump($service);
#print dbus_dump($object);

#$dbus_service = $bus->get_service('org.freedesktop.DBus');
  #'org.freedesktop.DBus', '/org/freedesktop/UDisks/devices/sdc');
#$properties = $udisk_service->get_object(
  #'/org/freedesktop/UDisks/devices/sdc', 'org.freedesktop.DBus.Properties');
  #'/org/freedesktop/UDisks/devices/sdc', '/org/freedesktop/DBus/Properties');
  #'/org/freedesktop/DBus/Properties', '/org/freedesktop/UDisks/devices/sdc');
  #'/org/freedesktop/DBus/Properties');

#print $object->GetAll('/org/freedesktop/UDisks/devices/sdc');
#print $properties->GetAll('/org/freedesktop/UDisks/devices/sdc');
#print $properties->GetAll('/org/freedesktop/UDisks/devices/sdc');
print dbus_dump($properties);
print $properties->GetAll('org.freedesktop.UDisks.devices');
#print dbus_dump($service);

# Get a handle on the Dbus service

exit;
}
