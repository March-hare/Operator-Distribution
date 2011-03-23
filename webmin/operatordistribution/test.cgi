#!/usr/bin/perl

require 'operatordistribution-lib.pl';

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

# If we were passed some action, process it
print '%in:'. Dumper(%in);

