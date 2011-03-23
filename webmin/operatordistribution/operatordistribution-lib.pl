
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

sub create_asterisk_sip_account {
  my ($handle) = @_;

  my $sip_conf = new Asterisk::config(file=>$config{'sip_conf'});
  error('Could not open '. $sip_conf_file) unless $sip_conf;
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
context=home
type=friend";
  $sip_conf->assign_append(point=>'down', data=>$section);
  $sip_conf->save_file();

  return $extension;
}

sub is_account_unique {
  while (my ($k, $v) = each(%config)) {
    next unless ($key =~ /:/);
    @subkeys = split(':', $key);
    next unless (scalar(@subkeys) eq 3);
    $users{$subkeys[0] .':'. $subkeys[1]}{$subkeys[2]} = $value;
  }

  return 0 if (exists($users{$in{'KEY_EMAIL'}}{$in{'KEY_OU'}}));
  return 1;
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

  $ca = &foreign_call('openvpn', 'create_CA', \%info);

  # If this succeeds we want to write this info to a config file
  # CA_NAME.
  update_config('ca_name', $info{'CA_NAME'});
  update_config('collective_name', $info{'KEY_ORG'});

  create_ca_config(%info);
}

sub create_new_openvpn_key {
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
  $info{'KEY_NAME'} = $1;
  $info{'KEY_CN'} = $info{'KEY_NAME'};
  $info{'KEY_NAME'} .= $in{'KEY_OU'} ? '.'.$in{'KEY_OU'} : '';
  $info{'KEY_OU'} = $in{'KEY_OU'};

  $info{'KEY_ORG'} = $config{'collective_name'};

  $info{'Key_SERVER'} = 1;
  
  # We reject the state.
  $info{'KEY_COUNTRY'} = 
    $info{'KEY_PROVINCE'} = 
    $info{'KEY_CITY'} = '';

  $ca = &foreign_call('openvpn', 'create_key', \%info);

  # If this succeeds we want to write this info to a config file
  update_config($in{'KEY_EMAIL'} .':'. $in{'KEY_OU'} .':keyname', $info{'KEY_NAME'});
}

sub update_config {
  my ($key, $value) = @_;
  &lock_file("$config_directory/operatordistribution/config");
  &read_file("$config_directory/operatordistribution/config", \%newconfig);
  $newconfig{$key} = $value;
  &write_file("$config_directory/operatordistribution/config", \%newconfig);
  &unlock_file("$config_directory/operatordistribution/config");
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
      print CONFIG $key."=>'".$in{$key}."',\n";
  }
  print CONFIG "}\n";
  close CONFIG;
}
