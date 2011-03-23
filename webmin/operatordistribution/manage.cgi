#!/usr/bin/perl

require 'operatordistribution-lib.pl';
use File::Basename;
use Net::DBus;
use Net::DBus::Reactor;
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
  while (my ($k, $v) = each(%in)) {
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

  # Stage1, detect and confirm the usb device
  # TODO: can we disable any file manager popups here?
  if (!$in{'stage'} || $in{'stage'} eq 1) {
    $| = 1;
    process_create_usb_stage1();
    $reactor = Net::DBus::Reactor->main();
    $reactor->run();

    my $device_filename = basename($device);

    print '<pre>'.Dumper(%in).'</pre>';
    print &ui_form_start("manage.cgi", "POST");
    print '<form method="get" action="manage.cgi" class="ui_form">';
    $in{'stage'} = 2;
    while (my ($k, $v) = each(%in)) {
      print ui_hidden($k, $v);
    }
    $in{'stage'} = 1;
    print '<br />'. $text{'device_we_recieved'} ." $device_filename?";
    print ui_hidden('device', $device_path);
    print ui_submit('confirm', 'stage1', 0, undef) .'<br />';
    print '</form>';
    ui_form_end(undef, undef);
  }

  # Prompt for a password
  process_create_usb_stage2()
    if ($in{'stage'} eq 2);

  # Create usb device
  process_create_usb_finalize();
}

# TODO: it would be nice to have some signal indicator on the screen to let the user
# know we are waiting for input.
sub process_create_usb_stage1 {
  print $text{'insert_usb'};

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

  # make sure we have a OD-client directory to customize
 
  # generate the ekiga config file with gconftool-2: 
  # /apps/ekiga/protocols/accounts_list
  # auto register | 1 | 7c08ebb0-161e-e011-946f-0019d2acd12c | Connection Name
  # SIP | registrar | registrar | extension | extension | password | timeout(3600)
  # 0|1|7c08ebb0-161e-e011-946f-0019d2acd12c|Burke (vpn)|
  # SIP|10.66.11.1|10.66.11.1|101|101|welcome|3600
  #
  # gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.defaults \
  # --type list --list-type=string --set /apps/ekiga/protocols/accounts_list \
  # "[1|1|7c08ebb0-161e-e011-946f-0019d2acd12c|Gconf|SIP|10.66.6.1|10.66.6.1|101|101|welcome|3600]"
  #
  # This command will likely have to be done in a chroot
  
  print &ui_form_start("manage.cgi", "POST");
  $in{'stage'} = 3;
  while (my ($k, $v) = each(%in)) {
    print ui_hidden($k, $v);
  }
  print ui_submit('confirm', 'stage1', 0, undef) .'<br />';
  print ui_form_end(undef, undef);
}

sub process_create_usb_finalize {}
