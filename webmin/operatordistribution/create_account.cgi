#!/usr/bin/perl
require 'operatordistribution-lib.pl';

# TODO: This page should not be listed if a CA has not been created yet.
# This can be accomplished with a call to openvpn's &create_CA(\%in);

# Show main page
ui_print_header(undef, $text{'create_client_title'}, "");
my @sites = list_foobar_websites();

# We have begun the submission process
if ($in{'step'}) {
  step_dispatcher();
	}
else {
	display_new_client_form();
 }

# Show new client form
sub display_new_client_form {
  my $client = {};
  print ui_form_start('create_client.cgi', 'POST');
  print ui_hidden('step', $in{'step'}=1);
  print ui_table_start($text{'create_client_header'}, undef, 2);

  # Input for client email addr
  print ui_table_row($text{'edit_client_email'},
    ui_textbox('email', $client->{'email'}, 40));

  # Input for client password
  print ui_table_row($text{'edit_client_password'},
    ui_password('password', $client->{'password'}, 40));

  print ui_table_end();
  print ui_form_end([ [ undef, $text{'create'} ] ]);
}

# TODO: Can we use the USBCreator DBUS interface?  via Net::DBus?  Maybe also
# org.freedesktop.UDisks?  yup, see dbus.pl.  This could be a multi step cgi
# first step is to enter useful info for the user, next step is to prompt for
# and select a usb drive using the DBus interface, next step is a confirmation,
# final step is the actual creation of the device (we may even be able to use
# someof usb-cdcreator's interfaces?

# responsible for actually creating the client, will make use of unbuffered 
# output because commands may run for a long time. $| = 1;  Also checkout
# Webmin::Dynamic*, and openvpn's PrintCommandWEB()

# process the steps of creating a new client
sub step_dispatcher {
  # There should be some way to do this with dynamic method calls
  step1() if ($in{'step'} eq 1);
}

sub step1 {
  use Email::Valid;
  use Data::Password qw(IsBadPassword);

  # sanity checks
  # make sure we have all required input and that it is valid: email addr, password
  if (!$in{'email'} || !Email::Valid->address($in{'email'})) {
    error($text{'create_client_eaddress'});
  }

  $result = IsBadPassword($in{'password'});
  error($text{'create_client_epassword'}. ': '. $result) if $result;

  # create openvpn keys using the openvpn module
  # we can let the openvpn module call webmin_log for its actions?

  # create asterisk sip account
  # we should call webmin_log for any file modification

  # make sure a usb is connected
}

sub step2 {
# create OD-client

# redirect back to index when done
ui_print_footer('', $text{'index_return'});
}
