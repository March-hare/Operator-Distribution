#!/usr/bin/perl

require 'operatordistribution-lib.pl';
use File::Basename;
use File::Copy;
use File::Path;
use Net::DBus;
use Net::DBus::Reactor;
&foreign_require("openvpn", "openvpn-lib.pl");
our ($device, $reactor);

ReadParse();

# check to make sure a few pre-requisites are met:
# Openvpn and the openvpn webmin module are installed
# asterisk is installed

# generate and display the page header
&ui_print_header( 
  $text{'march-hare_tagline'},              #subtext
  $text{'title_od'},                        #title 
  "",                                       #image
  "",                                       #help
  1,                                        #linkto config page
  1,                                        #dont link to module index
  1,                                        #dont link to webmin index
  undef,                                    #right hand side links
                                            #start, stop, run all traffic through Tor
  undef,                                    #stuff to include in <head />
  undef,                                    #stuff to include in <body />
  undef,                                    #stuff to include below title
                                            #TODO: versions of all software for enabled
                                            #features. 
);

process_manage_account() if ($in{'action'} eq 'manage_account');

ui_print_footer('/', $text{'index'});
exit();

sub process_manage_account {
  %inbak = %in;
  while (my ($k, $v) = each(%inbak)) {
    next unless ($k =~ /:/);
    my ($email, $host, $action) = split(':', $k);
    process_delete_account($email, $host)
      if ($action eq 'delete');
    process_create_usb($email, $host)
      if ($action eq 'usb');
  }
}

sub process_delete_account {
  my ($email, $host) = @_;
}

sub process_create_usb {
  my ($email, $host) = @_;
  #process_create_usb_stage2(); exit;

  # Stage1, detect and confirm the usb device
  # TODO: can we disable any file manager popups here?
  if (!$in{'stage'} || $in{'stage'} eq 1) {
    print $text{'insert_usb'};
    $| = 1;
    process_create_usb_stage1();
    $reactor = Net::DBus::Reactor->main();
    $reactor->run();
    $reactor->shutdown();

    my $device_filename = basename($device);

    print &ui_form_start("manage.cgi", "POST");
    print '<form method="get" action="manage.cgi" class="ui_form">';
    $in{'stage'} = 2;
    while (my ($k, $v) = each(%in)) {
      print ui_hidden($k, $v);
    }
    $in{'stage'} = 1;
    print '<br />'. $text{'device_we_recieved'} ." $device_filename?";
    print ui_hidden('device', $device);
    print ui_submit('confirm', 'stage1', 0, undef) .'<br />';
    print '</form>';
    ui_form_end(undef, undef);
ui_print_footer('/', $text{'index'});
exit();
  }

  # Prompt for a password
  process_create_usb_stage2()
    if ($in{'stage'} eq 2);
  #if ($in{'stage'} eq 2) {
    #}
}

# TODO: it would be nice to have some signal indicator on the screen to let the user
# know we are waiting for input.
sub process_create_usb_stage1 {
  my $SERVICE = "org.freedesktop.UDisks";
  my $PATH = "/org/freedesktop/UDisks";
  my $bus = Net::DBus->system();
  my $service = $bus->get_service($SERVICE);
  my $object = $service->get_object($PATH, $SERVICE);
  $object->connect_to_signal('DeviceAdded', \&process_create_usb_stage1_2);
  
}

# TODO: use the properties interface to make sure we recieved removeable storage.
sub process_create_usb_stage1_2 {
  ($device) = @_;
  $reactor->shutdown();
}

# Sanity checks
# TODO: Call hooks for other modules that want to do stuff here
# TODO: prompt for a password to use to encrypt the persistent storage
#
sub process_create_usb_stage2 {
  $device = $in{'device'};
  # Get the user we are creating the distribution for
  my $key = '';
  foreach (keys %in) {
     $key = $_ if (/:usb$/);
  }
  error('process_create_usb_stage2: '. $text{'unknown_user_internal_error'}) 
    if (!length($key));
  my ($email, $host, $usb) = split(':', $key);

  # make sure we have the openvpn config files
  my $keyfile = $config{$email .':'. $host .':keyname'};
  error('process_create_usb_stage2: not in $config: '. $text{'unknown_user_config'})
    if (!length($keyfile));
  my $key_path = $openvpn::config{'openvpn_home'} .'/'.
    $openvpn::config{'openvpn_keys_subdir'} .'/'. $config{'ca_name'}; 
  opendir(my $dh, $key_path) || die "can't opendir $key_path: $!";
  @keys = grep { /^$keyfile/ && -f "$key_path/$_" } readdir($dh);
  closedir $dh;
  error('process_create_usb_stage2: could not find all of the required keys'.
    'for the user.'. $text{'user_keys_not_found'})
    if (scalar(@keys) ne 3);

  # make sure we have an extension,
  error('process_create_usb_stage2: The extension for this user was not '.
    'found.'. $text{'unknown_user_config'})
    if (!exists($config{$email .':'. $host .':extension'}));
  my $extension = $config{$email .':'. $host .':extension'};

  # make sure we have a OD-client directory to customize
  error('process_create_usb_stage2: could not find OD-client base directory: '.
    $text{'od_base_not_found'})
    if (
      ! -d $config{'uck_base'} ||
      ! -f $config{'uck_base'}.'/remaster-root/etc/apt/sources.list'
    );

  # make sure the OD-client universe repo is enabled
  $command = 'sed -i \'s/^#\s*\(.*universe\)$/\1/\' '. $config{'uck_base'} .'/remaster-root/etc/apt/sources.list';
  `$command`;

  # make sure the OD-client system software is updated and upgraded
  $command = 'uck-remaster-chroot-rootfs '. $config{'uck_base'} .' apt-get update';
  `$command`;
  $command = 'uck-remaster-chroot-rootfs '. $config{'uck_base'} .' apt-get upgrade';
  `$command`;

  # make sure ekiga and openvpn are installed on the client
  $command = 'uck-remaster-chroot-rootfs '. $config{'uck_base'} .' apt-get install openvpn ekiga';
  `$command`;

  # Read in the ekiga config template 
  $config_file = &module_root_directory("operatordistribution") .'/ekiga.xml.tmp';
  $config = generate_custom_ekiga_config(
    $config{'collective_name'},
    $config{'private_address'},
    $extension
  );
  open (F, ">$config_file") or
    die("Could not open temprary ekiga config ($config_file): $!");
  print F $config;
  close F;

  # Load the values into the clients default
  $command = 
    "gconftool-2 --direct --config-source xml:readwrite:". $config{'uck_base'}
    ."/remaster-root/etc/gconf/gconf.xml.defaults ".
    "--load $config_file";

  &error($text{'econfigure_ekiga'}) unless(
    foreign_call('openvpn', "PrintCommandWEB", $command, $text{'configure_ekiga'}));
  unlink($config_file);

  # Configure ekiga to autostart
  my $ekiga_path = $config{'uck_base'} ."/remaster-root/etc/skel/.config/autostart";
  mkpath($ekiga_path);
  open(F, ">$ekiga_path/ekiga.desktop")
    or die("Could not create the auto startup file for ekiga: $ekiga_path/ekiga.desktop");
$ekiga_autostart_config = <<CONFIG;
[Desktop Entry]
Type=Application
Exec=/usr/bin/ekiga
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=ekiga
Name=ekiga
Comment[en_US]=
Comment=
CONFIG

  print F $ekiga_autostart_config;
  close F;

  # Get openvpn configs on the client
  # TODO: use uck prefix
  my $cdir = $config{'uck_base'} ."/remaster-root/$key_path";
  mkpath($cdir);
  unlink glob("$cdir/*");
  foreach (@keys) {
    copy("$key_path/$_", $cdir);
  }
  copy("$key_path/ca.crt", $cdir);
  copy("$key_path/ta.key", $cdir);
  $dh = glob("$key_path/dh*.pem");
  copy($dh, $cdir);

  $host = $config{'routable_address'};
  $config_file = $config{'uck_base'} .'/remaster-root/'. 
    $openvpn::config{'openvpn_home'} .'/'. $config{'ca_name'} .'.conf';

$config = <<CONFIG;
remote $host 1194
proto udp
resolv-retry infinite
dev tun
client
ca $key_path/ca.crt
cert $key_path/$keyfile.crt
key $key_path/$keyfile.key
dh $dh
tls-auth $key_path/ta.key 1
keepalive 10 120
comp-lzo
persist-key
persist-tun
CONFIG

  open CONFOUT, '>', $config_file or
    die "Can not open $config_file";
  print CONFOUT $config;
  close CONFOUT;

  # Make sure the client auto starts the vpn.
  $autostart = 'AUTOSTART="'. $config{'ca_name'} .'"';
  $command = "grep -q '^$autostart' ". $config{'uck_base'} 
    .'/remaster-root/etc/default/openvpn';
  `$command`;
  if ($? ne 0) {
    $command = "echo $autostart >> ". $config{'uck_base'}
      .'/remaster-root/etc/default/openvpn';
    `$command`;
  } 

  # remaster the root filesystem
  # TODO: we need to not run this through the openvpn::PrintCommandWEB() method
  # because there is no way to disable the progress which will add a bunch of 
  # unneeded unformatted output to the webpage
  $command = "/usr/bin/uck-remaster-pack-rootfs ". $config{'uck_base'};
  &error($text{'eremaster_rootfs'}) unless(
    foreign_call('openvpn', "PrintCommandWEB", $command, $text{'remaster_rootfs'}));

  # TODO: this should all be dome with the DBus interface
  # Blow away all partitions on the device
  my $device_filename = '/dev/'. basename($device);
  $command = "for i in `ls $device_filename?`; do umount \$i; p=`echo \$i|grep -o '[0-9]\\+\$'`; parted $device_filename rm \$p; done";
  &error(&text('eremove_partitions', $device_filename)) unless(
    foreign_call('openvpn', "PrintCommandWEB", $command, 
      &text('remove_partitions', $device_filename))); 

  # Create one partition
  $command = "parted -s $device_filename p|grep ^Disk|awk -F': ' '{print \$2}'";
  $size = `$command`;
  $command = "parted -s $device_filename mkpart primary 1 $size";
  &error(&text('ecreate_partition', $device_filename)) unless(
    foreign_call('openvpn', "PrintCommandWEB", $command, 
      &text('create_partition', $device_filename)));

  # Make the first partition bootable
  $command = "/sbin/parted $device_filename set 1 boot on";
  &error($text{'emake_bootable'}) unless(
    foreign_call('openvpn', "PrintCommandWEB", $command, 
      $text{'make_bootable'}));

  # Make a filesystem on our new partition
  $command = "mkfs.vfat -n rescue ". $device_filename ."1";
  &error(&text('emkfs', $device_filename)) unless(
    foreign_call('openvpn', "PrintCommandWEB", $command, 
      &text('mkfs', $device_filename)));

  # mount the device and copy the files
  print $text{'please_be_patient'};
  $command = "mkdir -p /mnt/uck; mount ". $device_filename ."1 /mnt/uck;".
    'cd '. $config{'uck_base'} .'/remaster-iso; cp -r . /mnt/uck/;';
  &error(&text('emount_and_copy', $device_filename)) unless(
    foreign_call('openvpn', "PrintCommandWEB", $command, 
      &text('mount_and_copy', $device_filename)));

  # Install syslinux
  `mv /mnt/uck/isolinux /mnt/uck/syslinux`;
  `mv /mnt/uck/syslinux/isolinux.cfg /mnt/uck/syslinux/syslinux.cfg`;
  `mv  /mnt/uck/syslinux/isolinux.bin  /mnt/uck/syslinux/syslinux.bin`;
  open(F, ">/mnt/uck/syslinux/syslinux.cfg")
    or die('Could not re-write /mnt/uck/syslinux/syslinux.cfg');
  print F <<CONFIG;
prompt 0
timeout 1
totaltimeout 1
ontimeout linux
default linux
label linux
kernel /casper/vmlinuz
append  file=/cdrom/preseed/ubuntu.seed boot=casper initrd=/casper/initrd.lz quiet splash persistent noprompt cdrom-detect/try-usb=true --
CONFIG
  close F;
  `umount /mnt/uck`;
  `syslinux ${device_filename}1`;
  `mount ${device_filename}1 /mnt/uck`;

  #create the filesystem based on the amount of free space we will have
  $command = "df -m|grep ". $device_filename ."1|awk '{print \$4}'";
  $size = `$command`;
  die("Unable to determine available space left on ${device_filename}1")
    if ($size !~ /\d+/);
  #TODO: This needs to have better failure handling.
  `dd if=/dev/zero of=/mnt/uck/casper-rw bs=1M count=$size`;

  $command = "mkfs.ext4 -q -F -L casper-rw /mnt/uck/casper-rw;";
  &error(&text('ecreate_casper_rw_fs', $!)) unless(
    foreign_call('openvpn', "PrintCommandWEB", $command, 
      $text{'create_casper_rw_fs'}));

  $command="umount /mnt/uck";
  &error(&text('eumount', '/mnt/uck')) unless(
    foreign_call('openvpn', "PrintCommandWEB", $command, 
      &text('umount', '/mnt/uck')));
  
  # TODO: in later versions we will be setting this up as an encrypted 
  # partition from the casper initramfs startup scripts.
  # Create a filesystem on the persistent storage

  print &text('usb_ready', $email);
}

sub process_create_usb_finalize {}
