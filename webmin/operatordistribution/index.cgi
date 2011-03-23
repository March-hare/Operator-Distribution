#!/usr/bin/perl

require 'operatordistribution-lib.pl';
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

print "<link type=\"text/css\" rel=\"StyleSheet\" href=\"operatordistribution.css\" />";

# If we were passed some action, process it
process_action() if ($in{'action'});

# If the ca has not been created then create it prompting the user for needed 
# info
$ca = &foreign_call('openvpn', "ReadCAtoList");
if ((scalar @$ca) < 1) {
  new_openvpn_ca();
  ui_print_footer('/', $text{'index'});
  exit;
}

else {
  list_clients();
  new_client();
}

ui_print_footer('/', $text{'index'});

# TODO: is there a way to change this form depending on what features are enabled?
# List a page with a table of all exisitng accounts.  An account consistes of 
# the following info: handle, backdoor contact info, openvpn keys, a asterisk
# sip account.  For each account there should be a button for generating a 
# new distribution for this user and disabling their account.

# Note: Don't even look at the contents of this function unless you want your head
# to spin.  If there is even a bug here it is prolly better to just rewrite this.
sub list_clients {
  my %users = ();
  while (my ($key, $value) = each(%config)) {
    next unless ($key =~ /:/);
    @subkeys = split(':', $key);
    next unless (scalar(@subkeys) eq 3);
    $users{$subkeys[0] .':'. $subkeys[1]}{$subkeys[2]} = $value;
  }

  return if (scalar(keys(%users)) eq 0);

  print &ui_form_start("manage.cgi", "POST");
  print ui_hidden('action', 'manage_account');

  print &ui_table_start($text{'manage_accounts_title'}, 'class="manage_account"');
  print "<tr><th>email</th><th>host</th><th>details</th><th></th></tr>";

  while (my ($email_host, $kv) = each(%users)) {
    my ($email, $host) = split(':', $email_host);
    my $details = '';
    while (my ($k, $v) = each(%$kv)) {
      $details .= "$k=$v<br />";
    }
    print '<tr><td>'.$email.'</td><td>'.$host.'</td><td>'.$details.'</td><td>'.
      ui_submit('delete', $email .':'. $host .':delete', 0, undef) .'<br />'.
      ui_submit('create usb', $email .':'. $host .':usb', 0, undef) .'<br />'
      .'</td></tr>';
  }
  print ui_table_end();
  print ui_form_end(undef, undef);

}

# After that table display a button for creating a new account.
sub new_client{
  print &ui_form_start("index.cgi", "POST");
  print ui_hidden('action', 'new_account');

  print &ui_table_start($text{'new_account_title'}, undef, 2);

  print &ui_table_row($text{'edit_client_email'}, 
    &ui_textbox('KEY_EMAIL', 'ie. username@'. $config{'ca_name'} .'.org',50));

  print &ui_table_row($text{'edit_client_computer'}, 
    &ui_textbox('KEY_OU', undef, 50));

  print &ui_table_row($text{'backdoor_label'}, 
    &ui_textbox('BACKDOR','ie. (888) dead-cop, carrier pidgin named siesl',50));

  print &ui_table_end();
  print ui_form_end([ [ undef, $text{'create'} ] ]);
  print $text{'edit_client_computer_note'};
}

sub new_openvpn_ca {
	$ca = { };

  print ui_form_start('index.cgi', 'POST');
  print ui_hidden('action', 'new_openvpn_ca');

  print ui_table_start($text{'new_openvpn_ca'}, undef, 2);
  # Input for collective name
  print ui_table_row($text{'edit_collective_name'},
    ui_textbox('KEY_ORG', '', 40));

  # Input for site admin email
  print ui_table_row($text{'edit_administrative_email'},
    ui_textbox('KEY_EMAIL', '', 40));

  # Show buttons at the end of the form
  print ui_table_end();
  print ui_form_end([ [ undef, $text{'create'} ] ]);
}

sub process_action {
  if ($in{'action'} eq 'new_openvpn_ca') {
    create_new_openvpn_ca();
    $in{'KEY_EMAIL'} =~ /^([^@]+)@/;
    my $handle = $1;
    $extension = create_asterisk_sip_account($handle);
    update_config($in{'KEY_EMAIL'} .':'. $in{'KEY_OU'} .':extension', $extension);

    # TODO: configure ekiga on this box to use this account.
    # TODO: set the system hostname to KEY_CN
  }

  process_new_account() if ($in{'action'} eq 'new_account');

  process_manage_account() if ($in{'action'} eq 'manage_account');
}

sub process_new_account {
  # make sure this is a unique account
  error('create_account_eunique')
    if (!is_account_unique());

  # Create a new openvpn key pair
  create_new_openvpn_key();

  # Create a asterisk sip account
  $in{'KEY_EMAIL'} =~ /^([^@]+)@/;
  my $handle = $1;
  $extension = create_asterisk_sip_account($handle);

  # save extension info
  update_config($in{'KEY_EMAIL'} .':'. $in{'KEY_OU'} .':extension', $extension);
   
  # save backdoor info
  update_config($in{'KEY_EMAIL'} .':'. $in{'KEY_OU'} .':backdoor', $in{'BACKDOOR'});

  # save key location
}

