#!/usr/bin/perl
# TODO: add a install feature that tests for the required libs and installs them
# if they are not already installed.
#
# TODO: add command line options for increasing the verbosity.
#
# TODO: add a way to add descriptions to the configuration settings.
#
# TODO: we will have to store user information in the database.  This will allow
# us to easily associate names and emails with sip extensions and ssl certs
#
# TODO: this tool will not work well for inserting into an existing PKI infrastructure
# because it depends on a naming convention for the openssl files.  Is there a way
# around this? Could we update the config to point to the openssl cert file and import
# all of the certs in there?  Do certs get deleted when they are revoked?  Will this 
# have to be checked against the openssl database file?
#
# Perl5+Curses ONLY!
# Comment these lines for use with Perl4/curseperl
BEGIN { $Curses::OldCurses = 1; }
use Curses;                     # PerlMenu needs "Curses"
use perlmenu;                   # Main menu package (Perl5 only)
use Log::Log4perl qw(:easy);    # http://bit.ly/hC55v0
use DBI;
use DBD::SQLite;
use FindBin;
use File::Basename;
use Email::Valid;
use File::Basename;
use File::Copy;
# we don't have any additional libs that we need to include yet, but we
# may need to.
#use lib $FindBin::Bin .'/lib';
use lib $FindBin::Bin;
use menuutil;
use Data::Dumper;

# requires Net::Telnet,but CPAN does not install by default.
use Net::OpenVPN::Manage;

# Global application variables / settings
my $config_database = $FindBin::Bin ."/.". basename($0) .".sqlite";

$| = 1;				# Flush after every write to stdout

# Set up logging
Log::Log4perl->easy_init(
  {
    file  => ">> error_log",
    level => $ERROR,
  },

  {
    file  => "STDERR",
    level => $DEBUG,
  }
);

# If the config database does not exist we consider this a first run
my $first_run = 0;
$first_run++ if (!-e $config_database);

# Get and handle for the apps config db, init if needed.
my $config_db_handler = get_config_db_handler();

if ($first_run) {
  initialize_openvpn();
}

# Prepare and display the main (top) menu
while (1) {
  &menu_init(
    1,"March-Hare Operator Distribution Manager",
    1,"'The Future is Unwritten'");
  &menu_item("Health Check", "health_check");
  &menu_item("Create User Account", "create_user");
  # Show connected asterisk users
  # Show connected VPN users
  # Disable VPN users
  # Boot user from server
  # Configure TC
  &menu_item("Edit Configuration", "editConfig");
  &menu_item("Exit", "quit");

  # Get selection
  $sel= &menu_display("");

  # Process selection (ignore "up" at top level)
  if ($sel ne "%UP%" && exists &$sel) {
    DEBUG('User selected: '. $sel);
    &$sel();
  }
}

sub quit {
  DEBUG("quit: START");
  exit;
}

# Setup the PKI infrastructure for Openvpn
sub initialize_openvpn {
  # Build out the main openvpn config file
  # pki_directory, openssl_bin_path = verify its existence
  # make pki_directory if not exist, as well as pki/certs
  # openssl_config, ca_key, ca_key_pass = gen a strong one
  # verify existence of ca key and create one if it does not exist,
  # organization_name,
  #
  # We will need to also create a openssl config file.  This should likely use
  # /etc/openssl as the basedir.  
  # TODO: How do we export crls for openssl?  Is there a way to do it without
  # opening up a website?
  #
  # generate and record openvpn's TA file, record it in the config table as 
  # openvpn_ta_file
}

# Make sure Openvpn and Asterisk are running, prompt user to change
# status of servers and get more information from servers like connected
# users, interface addresses, etc
sub health_check {
  DEBUG("health_check: START");
  DEBUG("health_check: END");
}

# Responsible for creating the vpn user account, generating the OD for the user
# and walking the manager through creating a bootable usb device.
sub create_user {
  DEBUG("create_user: START");
  create_openvpn_user_ssl();
  DEBUG("create_user: END");
}

# return a database handler
sub get_config_db_handler{
  DEBUG("get_config_db_handler: START");
  INFO("get_config_db_handler: opening database $config_database");
  # open the database
  # TODO: handle exceptions
  my $dbh = DBI->connect("dbi:SQLite:dbname=$config_database","","");

  # create the table if needed
  my $sth = $dbh->prepare('
    CREATE TABLE IF NOT EXISTS config (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )');
  #
  $sth->execute();

  # TODO: load the app configuration defaults

  # return the db handler 
  DEBUG("get_config_db_handler: END");
  return $dbh;
}

# create a new config database
sub create_config_db{
}

sub edit_user_accounts {
}

# TODO: this needs to be tested
sub revoke_openvpn_user_ssl {
  DEBUG("revoke_openvpn_user_ssl: START");
  # revoke the user from the cert itself, update the crl
  my ($subject) = @_;
  my $pkiDir = getConfig('pki_directory');
  my $certDir = $pkiDir .'/certs';
  my $openssl = getConfig('openssl_bin_path'); 

  DEBUG('revoke_openvpn_user_ssl: opening dir '. $certdir .'/*Cert.pem');
  if (!opendir(CERTS, $certdir .'/*Cert.pem')) {
    ERROR('revoke_openvpn_user_ssl: failed opening dir '. $certdir 
      .'/*Cert.pem: '. $!);
    return;
  }
  my $file;
  my $found = 0;
  while (defined ($file = readdir CERTS) ) {
    #openssl x509 -in certs/EvoltechCert.pem -noout -subject
    #subject= /O=Hackbloc/CN=Evoltech/emailAddress=evoltech@hackbloc.org
    my $cmd = "$openssl -in $file -noout -subject";
    DEBUG('revoke_openvpn_user_ssl: executing: '. $cmd);
    my $result = `$cmd`;
    DEBUG('revoke_openvpn_user_ssl: result: '. $result);

    if ($subject eq $result) {
      $found = 1;
      last;
    }
  }

  if ($found) {
    my $caPass = getConfig('openssl_ca_key_pass');
    my $caCert = getConfig('openssl_ca_cert');
    my $caKey = getConfig('openssl_ca_key');
    my $config = getConfig('openssl_config');
    my $cmd = "$openssl ca -config $config -revoke $file -keyfile $caKey -cert $caCert -passin pass:\"$caPass\"";
    DEBUG('revoke_openvpn_user_ssl: executing: '. $cmd);
    my $result = `$cmd`;
    DEBUG('revoke_openvpn_user_ssl: result: '. $result);

    $cmd = "$openssl ca -config $config -gencrl -keyfile $caKey -cert $caCert -out $pkiDir/crls/crl.pem";
    DEBUG('revoke_openvpn_user_ssl: executing: '. $cmd);
    my $result = `$cmd`;
    DEBUG('revoke_openvpn_user_ssl: result: '. $result);
  }

  DEBUG("revoke_openvpn_user_ssl: STOP");
}

sub create_openvpn_user_ssl {
  DEBUG("create_openvpn_user_ssl: START");

  # get a email address and an optional hostname (username as default)
  # TODO: if enter is hit here there will be a warning generated, this should
  # be suppressed.
  # Use of uninitialized value $params[0] in pattern match (m//) at 
  # /usr/share/perl5/Email/Valid.pm line 61.
  my $email = 'start';
  while (!Email::Valid->address($email)) {
    if ($email ne 'start') {
      $email = &popup_ask("Invalid email address, try again (q to exit):", 40);
    } elsif ($email eq 'q') {
      return;
    } else {
      $email = &popup_ask("Enter the email address for the new user (q to exit): ", 40);
    }
    chomp $email;
  }

  $email =~ /([^@]+)@/;
  my $username = $1;

  my $hostname = &popup_ask("Eneter a hostname for the user [$username]: ", 40);
  chomp $hostname;

  my $filePrefix;
  if (length($hostname)) {
    $filePrefix = $email.$hostname;
  } else {
    $hostname = $username;
  }
  $filePrefix =~ s/[@.]/_/g;

  INFO("create_openvpn_user_ssl: email=$email, hostname=$hostname");

  # TODO: add some sanity checks to make sure these dirs exist
  # TODO: pull off trailing slashes from the dirs we get from the config
  my $pkiDir = getConfig('pki_directory');
  my $certDir = $pkiDir .'/certs';
  my $initialPass = '1234';
  my $openssl = getConfig('openssl_bin_path'); 
  my $keyFile = $certDir .'/'. $filePrefix .'.key';
  my $reqFile = $certDir .'/'. $filePrefix .'Req.pem';
  my $certFile= $certDir .'/'. $filePrefix .'Cert.pem';

  my $config = getConfig('openssl_config');
  my $organization = getConfig('organization');
  my $caPass = getConfig('openssl_ca_key_pass');
  my $caCert = getConfig('openssl_ca_cert');
  my $caKey = getConfig('openssl_ca_key');

  my $result;
  INFO("create_openvpn_user_ssl: executing: $openssl req -config $config -passout pass:$initialPass -newkey rsa:1024 -keyout $keyFile -out $reqFile -subj '/O=$organization/CN=$hostname/emailAddress=$email'");
  $result = `$openssl req -config $config -passout pass:$initialPass -newkey rsa:1024 -keyout $keyFile -out $reqFile -subj '/O=$organization/CN=$hostname/emailAddress=$email' 2>&1`;
  DEBUG("create_openvpn_user_ssl: result: $result");

  #TODO: are we going to need to escape shell characters in the password here?
  INFO("create_openvpn_user_ssl: executing: echo \"y\ny\"|$openssl ca -config $config -passin pass:\"$caPass\" -in $reqFile -out $certFile -notext -keyfile $caKey");
  $result = `echo "y\ny"|$openssl ca -config $config -passin pass:"$caPass" -in $reqFile -outdir $certDir -out $certFile -notext -cert $caCert -keyfile $caKey 2>&1`;
  DEBUG("create_openvpn_user_ssl: result: $result");
  # TODO: check the result to see if we were successful here.  If we add a user
  # twice we will get: "TXT_DB error number 2"

  INFO("create_openvpn_user_ssl: executing: $openssl rsa -passin pass:$initialPass -in $keyFile -out $keyFile.unlocked");
  $result = `$openssl rsa -passin pass:$initialPass -in $keyFile -out $keyFile.unlocked 2>&1`;
  DEBUG("create_openvpn_user_ssl: result: $result");

  INFO("create_openvpn_user_ssl: executing: $mv $keyFile.unlocked $keyFile");
  $result = `mv $keyFile.unlocked $keyFile 2>&1`;
  DEBUG("create_openvpn_user_ssl: result: $result");

  DEBUG("create_openvpn_user_ssl: STOP");
}

# TODO: would it be better to load the cert files from the database?
sub create_openvpn_user_config_files {
  my ($email, $hostname) = @_;
  my $filePrefix = $email.$hostname;
  my $filePrefix =~ s/[@.]/_/g;
  my $base = getConfig('pki_directory');
  my $certDir = $pkiDir .'/certs';
  my $caPass = getConfig('openssl_ca_key_pass');
  my $caCert = getConfig('openssl_ca_cert');
  my $caKey = getConfig('openssl_ca_key');
  my $CACertDir = basename($caCert);
  my $organization = getConfig('organization');

  # TODO: if we do the import technique refered to at the top of the file this will
  # be a subroutine call to get the cert and key files from the db instead.
  my $certFile= $certDir .'/'. $filePrefix .'Cert.pem';
  my $keyFile = $certDir .'/'. $filePrefix .'.key';
  my $taFile = getConfig('openvpn_ta_file');

  # TODO: is this necesary or can we hardcode a template file into the script here?
  my $openvpnConf = getConfig('opevpn_config_file');

  my $pkgDir = "$base/$filePrefix";

  # TODO: handle fail case
  mkdir $pkgDir;
  cp($caCert, $pkgDir);
  cp($certFile, $pkgDir);
  cp($keyFile, $pkgDir);
  cp($taFile, $pkgDir);
  my $conf = $pkgDir ."/$organization.conf";

  # TODO: handle failcase here
  open CONFIN, $openvpnConf;

  # TODO: handle failcase here
  open CONFOUT, '>', $conf;

  while (<CONFIN>) {
    if (/^(cert .*?)[^\/]+$/) {
      print CONFOUT $1."$filePrefix". 'Cert.pem' ."\n";
    }
    elsif (/^(key .*?)[^\/]+$/) {
      print CONFOUT $1."$filePrefix.key\n";
    }
    else {
      print CONFOUT $_;
    }
  }

  chdir $base;
  `zip $filePrefix $filePrefix/*`;
}

{
  # This is how a persistent private (static) variable is defined in perl
  # http://docstore.mik.ua/orelly/perl/cookbook/ch10_04.htm
  my $getConfig_sth;
  sub getConfig {
    DEBUG("getConfig: START");
    my ($key) = @_;
    if (!defined($getConfig_sth)) {
      $getConfig_sth = $config_db_handler->prepare('
        SELECT value FROM config WHERE key = ?');
    }
    
    $result = $getConfig_sth->execute($key);
    $row = $getConfig_sth->fetchrow_hashref;
    DEBUG("getConfig: returning ". $row->{'value'} ." for $key");
    DEBUG("getConfig: STOP");
    return $row->{'value'};
  }

  my $editConfig_sth;
  sub editConfig {
    DEBUG("editConfig: START");
    if (!defined($editConfig_sth)) {
      $editConfig_sth = $config_db_handler->prepare('
        SELECT * FROM config');
    }

    while (1) {
      &clear_screen;
      &menu_init(
        1,"March-Hare Operator Distribution Manager",
        1,"Configuration Editor");
      $result = $editConfig_sth->execute();
      while($row = $editConfig_sth->fetchrow_hashref) {
        &menu_item($row->{'key'} .' : '. $row->{'value'}, $row->{'key'});
      }
      &menu_item("Add a new config entry", 'add');
      &menu_item("Return to previous menu", 'return');

      $sel= &menu_display("");
      if ($sel eq 'add') {
        addConfig();
      }
      elsif ($sel eq 'return') {
        return;
      }
      elsif ($sel ne "%UP%") {
        updateConfig($sel);
      }
    }
    DEBUG("editConfig: STOP");
  }

  my $updateConfig_sth;
  # TODO: there should be some sanity checking of the values the user sends us
  sub updateConfig {
    DEBUG("updateConfig: START");
    my ($key) = @_;

    if (!defined($updateConfig_sth)) {
      $updateConfig_sth = $config_db_handler->prepare('
        UPDATE config set value = ? WHERE key = ?');
    }

    my $value = getConfig($key);

    my $new_value = &popup_ask("$key [$value]: ", 80);

    if ($new_value ne '' and $new_value ne $value) {
      $updateConfig_sth->execute($new_value, $key);
    }

    DEBUG("updateConfig: STOP");
  }

  my $addConfig_sth;
  sub addConfig {
    DEBUG("addConfig: START");

    if (!defined($addConfig_sth)) {
      $addConfig_sth = $config_db_handler->prepare('
        INSERT INTO config(key, value) VALUES(?, ?)');
    }

    my $value = 'start';
    my $new_key;
    while ($value ne '') {
      if ($value eq 'start') {
        $new_key = &popup_ask("Enter the new key [r for return]: ", 80);
      } else {
        $new_key = &popup_ask("$new_key already exists. Enter a new key [r for return]: ", 80);
      }
      $value = getConfig($new_key);
      return if ($new_key eq 'r');
    }

    $value = &popup_ask("$new_key = ", 80);

    $addConfig_sth->execute($new_key, $value);

    DEBUG("addConfig: STOP");
  }
}


