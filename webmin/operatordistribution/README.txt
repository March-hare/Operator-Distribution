TODO
====
+ Migrate all TODO items as issues at march-hare.org and or github.com

+ grep TODO in the source

+ On Create USB after inserting the key the prompt is displayed a second time
and I have no idea why.  This should not happen.

+ Move all usb code to use DBUS

+ Push stable release to github

+ Delete should remove all keys, asterisk accounts, and make sure any current
connection to the server is severed.

+ Create a pluggable system where there can be webmin/operatordistribution
modules that implement hooks and are called at different times ie
init(), server_creation(), add_user(), create_client_config(), etc

+ Improve the default asterisk dialplan possibly with some helpful voice prompts.

+ We will likely need to provide a dyn dns client module.  We may want to
integrate or steal code from the webmin ddclient module:
http://tlabidouille.dyndns.org/ddclient.fr/index_uk.html

+ Internal errors should just die, not error()

+ customizations to the webmin openvpn module.

+ Call managers from the webmin UI would be
[easy to accomplish](http://bit.ly/hkdc1w).  Some functionality could be:
  + Show what extensions are connected
  + Show what extensions are currently on the line and with who
  + click to initiate a call.
  + Initiate a conference call
  + There could be a admin and a user interface to this that would allow
  users to log in with their extension info (maybe these creds are auto
  cached on users clients) so they can start making calls right away.
  Integration with firelane's asterisk module (for account management)
  would be really sweet.


limitations
===========
+ Based on how we handle the copying of our custom asterisk config files, if the webmin
operatordistribution module is installed on top of an existing system, not a
pre-made OD-server, then the module may not work as expected.  There is not
currently support for playing well with exisiting asterisk config files.

+ Based on how we create keys and associate them with file names we can not
support keys for users with the same handles.  This means that there is no
way to create a keys for evoltech@hackbloc.org for server johnwaters AND for
evoltech@hackbloc.org on server filth.  Also there is no way to create keys
for two different users one with clever-handle@yahoo.com and
clever-handle@hotmail.com since we derive handles from email addresses.
