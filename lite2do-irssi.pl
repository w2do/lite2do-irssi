# lite2do-irssi, a lightweight todo manager for irssi
# Copyright (C) 2008, 2009 Jaromir Hradilek

# This program is free software;  you can redistribute it  and/or modify it
# under the  terms of the  GNU General Public License  as published  by the
# Free Software Foundation; version 3 of the License.
# 
# This  program is  distributed  in the  hope that  it will be useful,  but
# WITHOUT ANY WARRANTY;  without even the implied warranty of  MERCHANTABI-
# LITY  or  FITNESS FOR A PARTICULAR PURPOSE.  See  the  GNU General Public
# License for more details.
# 
# You should have received a copy of the  GNU General Public License  along
# with this program. If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use Irssi;
use locale;
use File::Copy;
use File::Spec::Functions;

# General script information:
our $VERSION  = '1.1.0';
our %IRSSI    = (
  authors     => 'Jaromir Hradilek',
  contact     => 'jhradilek@gmail.com',
  name        => 'lite2do-irssi',
  description => 'A lightweight todo manager.  Being based on w2do and '.
                 'fully compatible with its save file format, it tries '.
                 'to provide a simple alternative for IRC network well '.
                 'capable of collaborative task management. ',
  url         => 'http://w2do.blackened.cz/',
  license     => 'GNU General Public License, version 3',
  changed     => '2009-03-07',
);

# General script settings:
our $HOMEDIR  = Irssi::get_irssi_dir();          # Irssi's  home directory.
our $SAVEFILE = catfile($HOMEDIR, 'lite2do');    # Save file location.
our $BACKEXT  = '.bak';                          # Backup file extension.
our $TRIGGER  = ':todo';                         # Script invoking command.
our $COLOURED = 0;                               # Whether to use colours.
our $LISTALL  = 0;                               # Whether to allow listing
                                                 # all tasks at once.
# Access control:
our @ALLOWED  = qw( *!*@* );                     # Allowed IRC masks.
our @BANNED   = qw( );                           # Banned IRC masks.

# Load selected data from the save file:
sub load_selection {
  my ($selected, $rest, $id, $group, $task) = @_;

  # Escape reserved characters:
  $group =~ s/([\\\^\.\$\|\(\)\[\]\*\+\?\{\}])/\\$1/g if $group;
  $task  =~ s/([\\\^\.\$\|\(\)\[\]\*\+\?\{\}])/\\$1/g if $task;

  # Use default pattern when none is provided:
  $id    ||= '\d+';
  $group ||= '[^:]*';
  $task  ||= '';

  # Open the save file for reading:
  if (open(SAVEFILE, "$SAVEFILE")) {

    # Process each line:
    while (my $line = <SAVEFILE>) {

      # Check whether the line matches given pattern:
      if ($line =~ /^$group:[^:]*:[1-5]:[ft]:.*$task.*:$id$/i) {
        # Add the line to selected tasks:
        push(@$selected, $line);
      }
      else {
        # Add the line to unselected tasks:
        push(@$rest, $line);
      }
    }

    # Close the save file:
    close(SAVEFILE);
  }
}

# Save given data to the save file:
sub save_data {
  my $data = shift;

  # Backup the save file:
  copy($SAVEFILE, "$SAVEFILE$BACKEXT") if (-r $SAVEFILE);

  # Open the save file for writing:
  if (open(SAVEFILE, ">$SAVEFILE")) {

    # Write data to the save file:
    foreach my $line (@$data) {
      print SAVEFILE $line;
    }

    # Close the save file:
    close(SAVEFILE);
  }
  else {
    # Report failure:
    Irssi::print($IRSSI{name} . ": Unable to write to `$SAVEFILE'.");
  }
}

# Add given data to the end of the save file:
sub add_data {
  my $data = shift;

  # Backup the save file:
  copy($SAVEFILE, "$SAVEFILE$BACKEXT") if (-r $SAVEFILE);

  # Open the save file for appending:
  if (open(SAVEFILE, ">>$SAVEFILE")) {

    # Write data to the save file:
    foreach my $line (@$data) {
      print SAVEFILE $line;
    }

    # Close the save file:
    close(SAVEFILE);
  }
  else {
    # Report failure:
    Irssi::print($IRSSI{name} . ": Unable to write to `$SAVEFILE'.");
  }
}

# Get list of all groups:
sub get_groups {
  my %groups = ();

  # Open the save file for reading:
  if (open(SAVEFILE, "$SAVEFILE")) {

    # Build the list of used groups:
    while (my $line = <SAVEFILE>) {
      $groups{lc($1)} = 1 if ($line =~ /^([^:]*):/);
    }

    # Close the save file:
    close(SAVEFILE);
  }

  # Return the result:
  return keys(%groups);
}

# Choose first available ID:
sub choose_id {
  my @used   = ();
  my $chosen = 1;

  # Open the save file for reading:
  if (open(SAVEFILE, "$SAVEFILE")) {

    # Build the list of used IDs:
    while (my $line = <SAVEFILE>) {
      push(@used, int($1)) if ($line =~ /:(\d+)$/);
    }

    # Close the save file:
    close(SAVEFILE);

    # Find first unused ID:
    foreach my $id (sort {$a <=> $b} @used) {
      $chosen++ if ($chosen == $id);
    }
  }

  # Return the result:
  return $chosen;
}

# Display script help:
sub display_help {
  return <<"END_HELP"
Usage: $TRIGGER command [argument...]
  list [\@group] [text...]  display items in the task list
  add  [\@group] text...    add new item to the task list
  change id \@group|text... change item in the task list
  finish id                finish item in the task list
  revive id                revive item in the task list
  remove id                remove item from the task list
END_HELP
}

# Display script version:
sub display_version {
  return $IRSSI{name} . " $VERSION";
}

# List items in the task list:
sub list_tasks {
  my ($group, $task) = @_;
  my (@selected, $state, $tasks);

  # Load matching tasks:
  load_selection(\@selected, undef, undef, $group, $task);

  # Check whether the list is not empty:
  if (@selected) {

    # Process each task:
    foreach my $line (sort @selected) {

      # Parse the task record:
      $line   =~ /^([^:]*):[^:]*:[1-5]:([ft]):(.*):(\d+)$/;
      $state  = ($2 eq 'f') ? '-' : 'f';

      # Check whether to use coloured output:
      if ($COLOURED) {

        # Decide which colour to use:
        my $col = ($2 eq 'f') ? '06' : '03';

        # Create the task entry:
        $tasks .= sprintf("\x02%2d.\x0F ", $4) .
                  "\x02\x03$col\@$1\x0F " .
                  "\x02[$state]\x0F" .
                  "\x03$col: $3\x0F\n";
      }
      else {
        # Create the task entry:
        $tasks .= sprintf("%2d. @%s [%s]: %s\n", $4, $1, $state, $3);
      }
    }

    # Return the result:
    return $tasks;
  }
  else {
    # Report empty list:
    return "No matching task found.";
  }
}

# Add new item to the task list:
sub add_task {
  my $task  = shift || '';
  my $group = shift || 'general';
  my $id    = choose_id();

  # Create the task record:
  my @data  = (substr($group, 0, 10) . ":anytime:3:f:$task:$id\n");

  # Add data to the end of the save file:
  add_data(\@data);

  # Report success:
  return "Task has been successfully added with id $id.";
}

# Change selected item in the task list:
sub change_task {
  my $id     = shift;
  my $text   = shift;
  my $group  = shift || 0;
  my (@selected, @rest);

  # Load tasks:
  load_selection(\@selected, \@rest, $id);

  # Check whether the list is not empty:
  if (@selected) {

    # Parse the task record:
    pop(@selected) =~ /^([^:]*):([^:]*):([1-5]):([ft]):(.*):\d+$/;

    # Decide which part to edit:
    unless ($group) {

      # Update the task record:
      push(@rest, "$1:$2:$3:$4:$text:$id\n");
    }
    else {
      # Update the group record:
      push(@rest, substr($text, 0, 10) . ":$2:$3:$4:$5:$id\n");
    }

    # Store data to the save file:
    save_data(\@rest);

    # Report success:
    return "Task has been successfully changed.";
  }
  else {
    # Report empty list:
    return "No matching task found.";
  }
}

# Mark selected item in the task list as finished:
sub finish_task {
  my $id = shift;
  my (@selected, @rest);

  # Load tasks:
  load_selection(\@selected, \@rest, $id);

  # Check whether the list is not empty:
  if (@selected) {

    # Parse the task record:
    pop(@selected) =~ /^([^:]*):([^:]*):([1-5]):[ft]:(.*):\d+$/;

    # Update the task record:
    push(@rest, "$1:$2:$3:t:$4:$id\n");

    # Store data to the save file:
    save_data(\@rest);

    # Report success:
    return "Task has been finished.";
  }
  else {
    # Report empty list:
    return "No matching task found.";
  }
}

# Mark selected item in the task list as unfinished:
sub revive_task {
  my $id = shift;
  my (@selected, @rest);

  # Load tasks:
  load_selection(\@selected, \@rest, $id);

  # Check whether the list is not empty:
  if (@selected) {

    # Parse the task record:
    pop(@selected) =~ /^([^:]*):([^:]*):([1-5]):[ft]:(.*):\d+$/;

    # Update the task record:
    push(@rest, "$1:$2:$3:f:$4:$id\n");

    # Store data to the save file:
    save_data(\@rest);

    # Report success:
    return "Task has been revived.";
  }
  else {
    # Report empty list:
    return "No matching task found.";
  }
}

# Remove selected item from the task list:
sub remove_task {
  my $id = shift;
  my (@selected, @rest);

  # Load tasks:
  load_selection(\@selected, \@rest, $id);

  # Check whether the list is not empty:
  if (@selected) {

    # Store data to the save file:
    save_data(\@rest);

    # Report success:
    return "Task has been successfully removed.";
  }
  else {
    # Report empty list:
    return "No matching task found.";
  }
}

# Send given IRC message:
sub send_message {
  my ($server, $target, $message) = @_;

  # Process each line:
  foreach my $line (split(/\n/, $message)) {

    # Send it as an IRC message:
    $server->command("MSG $target $line") if $line;
  }
}

# Perform proper action and return its response:
sub run_command {
  my $command = shift;

  # Parse command:
  if ($command =~ /^(|list|ls)\s*$/) {

    # Check whether the all tasks listing is allowed:
    unless ($LISTALL) {

      # Get list of all groups:
      my $groups = join(', ', get_groups());

      # Make sure the task list is not empty:
      if ($groups) {

        # Ask user to specify the group:
        return "Please specify one of the following groups: $groups.";
      }
      else {
        # Report empty list:
        return "No matching task found.";
      }
    }
    else {
      # List all tasks:
      return list_tasks();
    }
  }
  elsif ($command =~ /^(list|ls)\s+@(\S+)\s*(\S.*|)$/) {
    # List tasks in the selected group:
    return list_tasks($2, $3);
  }
  elsif ($command =~ /^(list|ls)\s+([^@\s].*)$/) {
    # List tasks matching given pattern:
    return list_tasks(undef, $2);
  }
  elsif ($command =~ /^add\s+@(\S+)\s+(\S.*)/) {
    # Add new task to selected group:
    return add_task($2, $1);
  }
  elsif ($command =~ /^add\s+([^@\s].*)/) {
    # Add new task to default group:
    return add_task($1);
  }
  elsif ($command =~ /^(change|mv)\s+(\d+)\s+@(\S+)\s*$/) {
    # Change selected task group:
    return change_task($2, $3, 1);
  }
  elsif ($command =~ /^(change|mv)\s+(\d+)\s+([^@\s].*)/) {
    # Change selected task:
    return change_task($2, $3);
  }
  elsif ($command =~ /^(finish|fn)\s+(\d+)/) {
    # Mark selected task as finished:
    return finish_task($2);
  }
  elsif ($command =~ /^(revive|re)\s+(\d+)/) {
    # Mark selected task as unfinished:
    return revive_task($2);
  }
  elsif ($command =~ /^(remove|rm)\s+(\d+)/) {
    # Remove selected task:
    return remove_task($2);
  }
  elsif ($command =~ /^version\s*$/) {
    # Display version information:
    return display_version();
  }
  elsif ($command =~ /^help\s*$/) {
    # Display help information:
    return display_help();
  }
  else {
    # Report invalid command:
    return "Invalid command or argument.\n" .
           "Try `$TRIGGER help' for more information.";
  }
}

# Handle incoming public messages:
sub message_public {
  my ($server,  $message, $nick, $address, $target) = @_;
  my ($command, $response);

  # Check whether to respond:
  return unless ($message =~ /^$TRIGGER/);

  # Check user's access permission:
  if ($server->masks_match(join(' ', @ALLOWED), $nick, $address) &&
     !$server->masks_match(join(' ', @BANNED),  $nick, $address)) {

    # Strip message:
    $command = $message;
    $command =~ s/^$TRIGGER\s*//;

    # Perform proper action:
    $response = run_command($command);
  }
  else {
    # Report denial:
    $response = "Access denied.";
  }

  # Send response:
  Irssi::signal_continue($server, $message, $nick, $address, $target);
  send_message($server, $target, $response);
}

# Handle incoming private messages:
sub message_private {
  my ($server, $message, $nick, $address) = @_;

  # Otherwise same as in public message:
  message_public($server, $message, $nick, $address, $nick);
}

# Handle outcoming public messages:
sub message_own_public {
  my ($server, $message, $target) = @_;
  my $nick    = $server->{nick};
  my $address = $server->{userhost};

  # Otherwise same as in public message:
  message_public($server, $message, $nick, $address, $target);
}

# Handle /todo command:
sub cmd_todo {
  my ($args, $server, $witem) = @_;

  # Strip args:
  $args =~ s/^\s*//;

  # Perform proper action:
  Irssi::print(run_command($args));
}

# Register signals:
Irssi::signal_add('message public',     'message_public');
Irssi::signal_add('message private',    'message_private');
Irssi::signal_add('message own_public', 'message_own_public');

# Register commands:
Irssi::command_bind('todo', 'cmd_todo');

=head1 NAME

lite2do-irssi - a lightweight todo manager for irssi

=head1 SYNOPSIS

In public channel or private query:

  :todo command [argument...]

or anywhere in Irssi:

  /todo command [argument...]

=head1 DESCRIPTION

B<lite2do-irssi> is a lightweight todo manager for Irssi written in Perl 5.
Being based on C<w2do> and fully compatible with its save file format, it
tries to provide a simple alternative for IRC network capable of
collaborative task management.

=head1 COMMANDS

=over

=item B<list> [I<@group>] [I<text>...]

=item B<ls> [I<@group>] [I<text>...]

Display items in the task list. Desired subset can be easily selected
giving a I<group> name, I<text> pattern, or combination of both; listing
all tasks is usually disabled to avoid unnecessary flood.

=item B<add> [I<@group>] I<text>...

Add new item to the task list.

=item B<change> I<id> I<text>...

=item B<mv> I<id> I<text>...

Change item with selected I<id> in the task list.

=item B<change> I<id> @I<group>

=item B<mv> I<id> @I<group>

Change I<group> the item with selected I<id> belongs to.

=item B<finish> I<id>

=item B<fn> I<id>

Mark item with selected I<id> as finished.

=item B<revive> I<id>

=item B<re> I<id>

Mark item with selected I<id> as unfinished.

=item B<remove> I<id>

=item B<rm> I<id>

Remove item with selected I<id> from the task list.

=item B<help>

Display usage information.

=item B<version>

Display version information.

=back

=head1 FILES

=over

=item F<~/.irssi/lite2do>

Default save file.

=back

=head1 SEE ALSO

B<w2do>(1), B<lite2do>(1), B<irssi>(1).

=head1 BUGS

To report bugs or even send patches, you can either add new issue to the
project bugtracker at <http://code.google.com/p/w2do/issues/>, visit the
discussion group at <http://groups.google.com/group/w2do/>, or you can
contact the author directly via e-mail.

=head1 AUTHOR

Written by Jaromir Hradilek <jhradilek@gmail.com>.

Permission is granted to copy, distribute and/or modify this document under
the terms of the GNU Free Documentation License, Version 1.3 or any later
version published by the Free Software Foundation; with no Invariant
Sections, no Front-Cover Texts, and no Back-Cover Texts.

A copy of the license is included as a file called FDL in the main
directory of the lite2do-irssi source package.

=head1 COPYRIGHT

Copyright (C) 2008, 2009 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
