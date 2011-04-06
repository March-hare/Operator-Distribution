
=head1 march-hare-lib.pl

Functions for managing the March-Hare Operator Distribution.

=cut

BEGIN { push(@INC, ".."); };
use WebminCore;
init_config();
&foreign_require("openvpn", "openvpn-lib.pl");
use Asterisk::config;
use Email::Valid;
use Data::Dumper;
use File::Path;
use File::Copy;

=head2 get_operatordistribution_config()

Returns the Foobar Webserver configuration as a list of hash references with name and value keys.

=cut
sub get_operatordistribution_config {
  my $lref = &read_file_lines($config{'operatordistribution_conf'});
  my @rv;
  my $lnum = 0;
  foreach my $line (@$lref) {
    my ($n, $v) = split(/\s+/, $line, 2);
    if ($n) {
      push(@rv, { 'name' => $n, 'value' => $v, 'line' => $lnum });
    }
    $lnum++;
  }
  return @rv;
}

# Secure sip passwords do not satisfy any of the concerns of our threat model.  
# Everything is sent in the clear once the vpn connection is established.
sub create_asterisk_sip_account {
  my ($handle) = @_;

  my $sip_conf = new Asterisk::config(file=>$config{'sip_conf'});
  error('Could not open '. $config{'sip_conf'}) unless $sip_conf;
  my $sections = $sip_conf->fetch_sections_hashref();

  # TODO: the sip extension pattern shoulf come from the module config.  For now we 
  # will assume 3 digit extensions from 101 to 199.
  my $extension = 100;
  foreach (keys %$sections) {
    next unless $_ =~ /^1\d\d$/;
    $extension = $_ if $_ >= $extension;
  }
  $extension++;

  # TODO: there is likely some better way to handle the config for new sip
  # extesnions.
  $section = "[$extension]
nat=Y
secret=welcome
host=dynamic
callerid=\"$handle\" <$extension>
dtmfmode=rfc2833
context=default
type=friend";
  $sip_conf->assign_append(point=>'down', data=>$section);
  $sip_conf->save_file();

  # Then add the new sip number to the extensions file
  my $e_conf = new Asterisk::config(file=>$config{'extensions_conf'});
  error('Could not open '. $config{'ext_conf'}) unless $e_conf;
  $ext = "exten => $extension,1,Dial(SIP,$extension)";
  $e_conf->assign_append(point=>'down', data=>$ext);
  $e_conf->save_file();

  # TODO: this should be moved to a function call
  `asterisk -r -x 'sip reload'`;
  `asterisk -r -x 'dialplan reload'`;

  return $extension;
}

sub is_account_unique {
  while (my ($k, $v) = each(%config)) {
    next unless ($k =~ /:keyname$/);
    @subkeys = split(/:/, $k);
    next unless (scalar(@subkeys) eq 3);
    $users{$subkeys[0]} = $v;
  }

  $in{'KEY_EMAIL'} =~ /([^@]+)@/;
  my $handle = $1;

  return !grep(/$handle/, values(%users));
}

sub asterisk_reload_sip {
  foreign_call('openvpn', "PrintCommandWEB", "asterisk -r -x 'sip reload'", "Reload Asterisk Sip Module");
}

sub start_asterisk {
}

sub stop_asterisk {
}

sub get_next_asterisk_sip_extension {
  # TODO: the sip file should come from the module config
  my $sip_conf_file = '/home/evoltech/src/contract/impact/etc/asterisk/sip.conf';
  my $sip_conf = new Asterisk::config(file=>$sip_conf_file);
  error('Could not open '. $sip_conf_file) unless $sip_conf;
  my $sections = $sip_conf->fetch_sections_hashref();

  # TODO: the sip extension pattern shoulf come from the module config.  For now we 
  # will assume 3 digit extensions from 101 to 199.
  my $next_extension = 100;
  foreach (keys %$sections) {
    next unless $_ =~ /^1\d\d$/;
    $next_extension = $_ if $_ >= $next_extension;
  }
  print Dumper($sections->{$next_extension});
  return ++$next_extension;
}

sub create_asterisk_conference {
}

sub reload_asterisk_sip {
}

# TODO: comment this out when we uncomment the WebminCore module above
sub error {
  my ($message) = @_;
  print $message ."\n";
  exit;
}

sub create_client_usb {
}

sub create_new_openvpn_ca {
  # Build out the argument list for the creation of the CA
  %info = ();
  while (my ($key, $value) = each(%in)) {
    next unless ($key =~ /^KEY_/);
    $info{$key} = $value;
  }

  # sanity check a few of the arguments
  error($text{'create_client_eaddress'}) 
    unless Email::Valid->address($info{'KEY_EMAIL'});

  $info{'KEY_OU'} = 'Certificate Authority';

  error($text{'create_ca_ecollectivename'})
    unless ($info{'KEY_ORG'} =~ /[\w\d- ]+/);

  # We reject the state.
  $info{'KEY_COUNTRY'} = 
    $info{'KEY_PROVINCE'} = 
    $info{'KEY_CITY'} = '';

  # Load addition configuration options from the openvpn config
  $info{'KEY_DIR'} = $openvpn::config{'openvpn_home'} .'/'.
    $openvpn::config{'openvpn_keys_subdir'};
  $info{'CA_NAME'} = $info{'KEY_ORG'};
  $info{'CA_NAME'} =~ s/\W//g;
  $info{'CA_NAME'} = lc($info{'CA_NAME'});
  $info{'KEY_SIZE'} = 2048;
  $info{'CA_EXPIRE'} = 3560;
  $info{'KEY_CONFIG'} = $openvpn::config{'openssl_home'};

  # make sure the pre-requisite directories exist
  mkpath($info{'KEY_DIR'});

  # make sure the openvpn ssl config file exists
  unless (-s $openvpn::config{'openssl_home'}) { 
    $mdir = &module_root_directory("openvpn");
    File::Copy::copy($mdir.'/openvpn-ssl.cnf',$openvpn::config{'openssl_home'}); 
  }

  $ca = &foreign_call('openvpn', 'create_CA', \%info);

  # If this succeeds we want to write this info to a config file
  # CA_NAME.
  update_config('ca_name', $info{'CA_NAME'});
  update_config('collective_name', $info{'KEY_ORG'});
  update_config('routable_address', $info{'KEY_ADDR'});

  create_ca_config(%info);
}

sub create_new_openvpn_key {
  my (%info) = @_;
  # Load addition configuration options from the openvpn config
  $info{'KEY_DIR'} = $openvpn::config{'openvpn_home'} .'/'.
    $openvpn::config{'openvpn_keys_subdir'} .'/'. $config{'ca_name'};
  $info{'KEY_SIZE'} = 2048;
  $info{'KEY_EXPIRE'} = 3560;
  $info{'KEY_CONFIG'} = $openvpn::config{'openssl_home'};

  # verify default arguments
  error($text{'create_key_eca_name'})
    unless (
      ($config{'ca_name'}) && 
      (-d $info{'KEY_DIR'}) &&
      ($info{'CA_NAME'} = $config{'ca_name'})
    );

  error($text{'create_client_eaddress'}) 
    unless (
      (Email::Valid->address($in{'KEY_EMAIL'})) &&
      ($info{'KEY_EMAIL'} = $in{'KEY_EMAIL'})
    );

  error($text{'create_ca_eservername'})
    unless (($info{'KEY_CN'} =~ /\w+/) || (!length($info{'KEY_CN'})));

  $in{'KEY_EMAIL'} =~ /^([^@]+)@/;
  $in{'KEY_NAME'} = $info{'KEY_NAME'} = $1;
  $info{'KEY_CN'} = $info{'KEY_NAME'};
  #This file nameing convention is not supported by the opevpn webmin module
  #$in{'KEY_NAME'} = $info{'KEY_NAME'} .= $in{'KEY_OU'} ? '.'.$in{'KEY_OU'} : '';
  $info{'KEY_OU'} = $in{'KEY_OU'};

  $info{'KEY_ORG'} = $config{'collective_name'};

  # We reject the state.
  $info{'KEY_COUNTRY'} = 
    $info{'KEY_PROVINCE'} = 
    $info{'KEY_CITY'} = '';

  $ca = &foreign_call('openvpn', 'create_key', \%info);

  # If this succeeds we want to write this info to a config file
  update_config($in{'KEY_EMAIL'} .':'. $in{'KEY_OU'} .':keyname', $info{'KEY_NAME'});
}

sub create_new_openvpn_server_key {
  $in{'KEY_OU'} = $config{'ca_name'};
  create_new_openvpn_key(('KEY_SERVER' => 1));
  $dir = $openvpn::config{'openvpn_home'} .'/'. 
    $openvpn::config{'openvpn_keys_subdir'} .'/'. $config{'ca_name'} .'/'
    .$in{'KEY_NAME'}.".server";
  open S,">".$dir;
  print S "Do not remove this file. It will be used from webmin ".
    "OpenVPN Administration interface.";
  close S;
}

# There is a bunch of error checking that is done by ../openvpn/create_vpn.cgi
# that we do not do here.  This may come back to bite us in the ass later.
# Since we are a one trick pony in that we are really only supporting one server
# with this configuration, we should likely force clear all other vpn configs
# when this runs. TODO
sub create_new_openvpn_server_conf {
  $ca_dir = $openvpn::config{'openvpn_home'} .'/'. 
    $openvpn::config{'openvpn_keys_subdir'} .'/'.
    $config{'ca_name'};
  $network = '10.'. int(rand(255)) .'.'. int(rand(255)) .'.0';
  $cert =  $ca_dir .'/'. $in{'KEY_NAME'} .'.crt';
  $key = $ca_dir .'/'. $in{'KEY_NAME'} .'.key';
  $dh = $ca_dir .'/dh'. $info{'KEY_SIZE'} .'.pem';
  $ca = "$ca_dir/ca.crt";
  $conf = $openvpn::config{'openvpn_home'} .'/'. $config{'ca_name'} .'.conf';

  # TODO
  # create the tls key, we are putting the TA key in a different directory then
  # were the openvpn module puts it.  Will this cause us problems in the 
  # future?
  $ta = $ca_dir .'/ta.key';
  &system_logged($openvpn::config{'openvpn_path'}." --genkey --secret $ta".
   ' >/dev/null 2>&1 </dev/null'); 
  chmod(0644,$ta);
 
$config = <<CONFIG;
float
port 1194
proto udp
dev tun
ca $ca
cert $cert
key $key
dh $dh
crl-verify $ca_dir/crl.pem
server $network 255.255.255.0
tls-auth $ta 0
keepalive 10 120
comp-lzo
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
log-append  /var/log/openvpn/openvpn.log
client-to-client
CONFIG

  open (F, '>', $conf) or die("Unable to open config file: $conf: $!");
  print F $config;
  close F;

  # Save the private network interface address to the config file
  $network =~ s/0$/1/;
  update_config('private_address', $network);

  # Start the vpn server
  $rv = &system_logged("$openvpn::config{'start_cmd'} $config{'ca_name'}>/dev/null 2>&1 </dev/null");

  print $text{'estart_vpn'} if ($rv);

  # Make sure the server starts across reboots.
  $autostart = 'AUTOSTART="'. $config{'ca_name'} .'"';
  $command = "grep -q '^$autostart' /etc/default/openvpn";
  `$command`;
  if ($?) {
    $command = "echo $autotart >> /etc/default/openvpn";
    `$command`;
  }
}

sub update_config {
  my ($key, $value) = @_;
  &lock_file("$config_directory/operatordistribution/config");
  &read_file("$config_directory/operatordistribution/config", \%newconfig);
  $newconfig{$key} = $value;
  &write_file("$config_directory/operatordistribution/config", \%newconfig);
  &unlock_file("$config_directory/operatordistribution/config");
  $config{$key} = $value;
}

sub create_ca_config {
  my (%vars) = @_;
  my $dir = $openvpn::config{'openvpn_home'} .'/'.
    $openvpn::config{'openvpn_keys_subdir'} .'/'. $config{'ca_name'};

  @fields = ('CA_NAME','CA_EXPIRE','KEY_SIZE','KEY_CONFIG',
    'KEY_DIR','KEY_COUNTRY','KEY_PROVINCE','KEY_CITY','KEY_ORG','KEY_EMAIL');
  open CONFIG,">$dir/ca.config";
  print CONFIG "\$info_ca = {\n";
  foreach $key (@fields) {
      print CONFIG $key."=>'".$vars{$key}."',\n";
  }
  print CONFIG "}\n";
  close CONFIG;
}
