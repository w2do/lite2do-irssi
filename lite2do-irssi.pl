# lite2do-irssi, an irssi script providing access to w2do task list via IRC
# Copyright (C) 2008 Jaromir Hradilek

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
use File::Spec::Functions;

# General script information:
our $VERSION  = '0.1.3';
our %IRSSI    = (
  authors     => 'Jaromir Hradilek',
  contact     => 'jhradilek@gmail.com',
  name        => 'lite2do-irssi',
  description => 'Access your w2do task list from anywhere via IRC! See ' .
                 '<http://code.google.com/p/w2do/> for more information.' ,
  url         => 'http://gitorious.org/projects/lite2do-irssi',
  license     => 'GNU General Public License, version 3',
  changed     => '2008-08-17',
);

# General script settings:
our $HOMEDIR  = Irssi::get_irssi_dir();          # Irssi's  home directory.
our $SAVEFILE = catfile($HOMEDIR, 'w2do');       # Save file location.
our $TRIGGER  = ':todo';                         # Script invoking command.

# Access control:
our @ALLOWED  = qw( *!*@* );

# Load selected data from the save file:
sub load_selection {
  my ($selected, $rest, $id, $group, $task) = @_;

  $group =~ s/([\\\^\.\$\|\(\)\[\]\*\+\?\{\}])/\\$1/g if $group;
  $task  =~ s/([\\\^\.\$\|\(\)\[\]\*\+\?\{\}])/\\$1/g if $task;

  $id    ||= '\d+';
  $group ||= '[^:]*';
  $task  ||= '';

  if (open(SAVEFILE, "$SAVEFILE")) {
    while (my $line = <SAVEFILE>) {
      if ($line =~ /^$group:[^:]*:[1-5]:[ft]:.*$task.*:$id$/i) {
        push(@$selected, $line);
      }
      else {
        push(@$rest, $line);
      }
    }

    close(SAVEFILE);
  }
}

# Save given data to the save file:
sub save_data {
  my $data = shift;

  if (open(SAVEFILE, ">$SAVEFILE")) {
    foreach my $line (@$data) {
      print SAVEFILE $line;
    }

    close(SAVEFILE);
  }
  else {
    Irssi::print($IRSSI{name} . ": Unable to write to `$SAVEFILE'.");
  }
}

# Add given data to the end of the save file:
sub add_data {
  my $data = shift;

  if (open(SAVEFILE, ">>$SAVEFILE")) {
    foreach my $line (@$data) {
      print SAVEFILE $line;
    }

    close(SAVEFILE);
  }
  else {
    Irssi::print($IRSSI{name} . ": Unable to write to `$SAVEFILE'.");
  }
}

# Choose first available ID:
sub choose_id {
  my @used   = ();
  my $chosen = 1;

  if (open(SAVEFILE, "$SAVEFILE")) {
    while (my $line = <SAVEFILE>) {
      push(@used, int($1)) if ($line =~ /:(\d+)$/);
    }

    close(SAVEFILE);

    foreach my $id (sort {$a <=> $b} @used) {
      $chosen++ if ($chosen == $id);
    }
  }

  return $chosen;
}

# Display script help:
sub display_help {
  return <<"END_HELP"
Usage: $TRIGGER command [args...]
  list [\@group] [text]   display items in the task list
  add  [\@group] text     add new item to the task list
  change id text         change item in the task list
  finish id              finish item in the task list
  remove id              remove item from the task list
END_HELP
}

# Display script usage:
sub display_usage {
  return "Usage: $TRIGGER command [args...]";
}

# Display script version:
sub display_version {
  return $IRSSI{name} . " $VERSION";
}

# List items in the task list:
sub list_tasks {
  my ($group, $task) = @_;
  my (@selected, $state, $tasks);

  load_selection(\@selected, undef, undef, $group, $task);

  if (@selected) {
    foreach my $line (sort @selected) {
      $line   =~ /^([^:]*):[^:]*:[1-5]:([ft]):(.*):(\d+)$/;
      $state  = ($2 eq 'f') ? '-' : 'f';
      $tasks .= sprintf("%2d. @%s [%s]: %s\n", $4, $1, $state, $3);
    }

    return $tasks;
  }
  else {
    return "No matching task found.";
  }
}

# Add new item to the task list:
sub add_task {
  my $task  = shift || '';
  my $group = shift || 'general';
  my $id    = choose_id();

  my @data  = ("$group:anytime:3:f:$task:$id\n");

  add_data(\@data);
  return "Task has been successfully added.";
}

# Change selected item in the task list:
sub change_task {
  my ($id, $task) = @_;
  my (@selected, @rest);

  load_selection(\@selected, \@rest, $id);

  if (@selected) {
    pop(@selected) =~ /^([^:]*):([^:]*):([1-5]):([ft]):.*:\d+$/;
    push(@rest, "$1:$2:$3:$4:$task:$id\n");

    save_data(\@rest);
    return "Task has been successfully changed.";
  }
  else {
    return "No matching task found.";
  }
}

# Mark selected item in the task list as finished:
sub finish_task {
  my $id = shift;
  my (@selected, @rest);

  load_selection(\@selected, \@rest, $id);

  if (@selected) {
    pop(@selected) =~ /^([^:]*):([^:]*):([1-5]):[ft]:(.*):\d+$/;
    push(@rest, "$1:$2:$3:t:$4:$id\n");

    save_data(\@rest);
    return "Task has been finished.";
  }
  else {
    return "No matching task found.";
  }
}

# Remove selected item from the task list:
sub remove_task {
  my $id = shift;
  my (@selected, @rest);

  load_selection(\@selected, \@rest, $id);

  if (@selected) {
    save_data(\@rest);
    return "Task has been successfully removed.";
  }
  else {
    return "No matching task found.";
  }
}

# Send given IRC message:
sub send_message {
  my ($server, $target, $message) = @_;

  foreach my $line (split(/\n/, $message)) {
    $server->command("MSG $target $line") if $line;
  }
}

# Handle incoming public messages:
sub message_public {
  my ($server,  $message, $nick, $address, $target) = @_;
  my ($command, $response);

  # Check whether to respond:
  return unless ($message =~ /^$TRIGGER/);

  # Check user's access permission:
  if ($server->masks_match(join(' ', @ALLOWED), $nick, $address)) {
    # Strip message:
    $command = $message;
    $command =~ s/^$TRIGGER\s*//;

    if ($command =~ /^(|list)\s*$/) {
      $response = list_tasks();
    }
    elsif ($command =~ /^list\s+@(\S+)\s*(\S.*|)$/) {
      $response = list_tasks($1, $2);
    }
    elsif ($command =~ /^list\s+(\S.*)$/) {
      $response = list_tasks(undef, $1);
    }
    elsif ($command =~ /^add\s+@(\S+)\s+(\S.*)/) {
      $response = add_task($2, $1);
    }
    elsif ($command =~ /^add\s+(\S.*)/) {
      $response = add_task($1);
    }
    elsif ($command =~ /^change\s+(\d+)\s+(\S.*)/) {
      $response = change_task($1, $2);
    }
    elsif ($command =~ /^finish\s+(\d+)/) {
      $response = finish_task($1);
    }
    elsif ($command =~ /^remove\s+(\d+)/) {
      $response = remove_task($1);
    }
    elsif ($command =~ /^version\s*$/) {
      $response = display_version();
    }
    elsif ($command =~ /^help\s*$/) {
      $response = display_help();
    }
    else {
      $response = display_usage();
    }
  }
  else {
    $response = "Access denied.";
  }

  # Send response:
  Irssi::signal_continue($server, $message, $nick, $address, $target);
  send_message($server, $target, $response);
}

# Handle incoming private messages:
sub message_private {
  my ($server, $message, $nick, $address) = @_;

  message_public($server, $message, $nick, $address, $nick);
}

# Handle outcoming public messages:
sub message_own_public {
  my ($server, $message, $target) = @_;
  my $nick    = $server->{nick};
  my $address = $server->{userhost};

  message_public($server, $message, $nick, $address, $target);
}

# Register signals:
Irssi::signal_add('message public',     'message_public');
Irssi::signal_add('message private',    'message_private');
Irssi::signal_add('message own_public', 'message_own_public');
