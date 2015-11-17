#  Copyright (C) 2015 Antoine Tenart <antoine.tenart@ack.tf>
# 
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; either version 2
#  of the License, or (at your option) any later version.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#  02110-1301, USA.

use Irssi;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '0.1';
%IRSSI = (
	name		=> 'group_windows',
	description	=> 'organize windows in groups, and navigate through them',
	authors		=> 'Antoine Tenart <antoine.tenart@ack.tf>',
	license		=> 'GPL v2',
	url		=> 'http://github.com/atenart/group_windows',
);

# group_windows irssi module
#
# usage:
# 
# FIXME

# TODO:
# - bind window commands (move, goto) to make them group-aware
# - add settings to statically assign groups
# - get real ctrl+n/ctrl+p bindings from irssi
# - display a window list

no warnings 'experimental::smartmatch';

use constant {
	PREV	=> 0,
	NEXT	=> 1,
};

my %windows = [];
my $active_g = 'default';
my $active_w = undef;

sub window_list {
	my $current = Irssi::active_win();

	%windows = [];
	foreach my $w (Irssi::windows()) {
		push @{$windows{'default'}}, $w->{refnum};

		if ($current->{refnum} == $w->{refnum}) {
			$active_w = $#{@windows{'default'}};
		}
	}
}

sub get_window_count {
	return keys %{Irssi::windows()};
}

window_list();

sub goto_window {
	my $index = undef;
	my $dir = shift;
	if ($dir != PREV && $dir != NEXT) {
		return;
	}

	$index = $active_w;
	$index += ($dir == PREV) ? -1 : 1;
	if ($index < 0) {
		$index = $#{@windows{$active_g}};
	} elsif ($index > $#{@windows{$active_g}}) {
		$index = 0;
	}

	Irssi::command('window goto ' . $windows{$active_g}[$index]);
	$active_w = $index;
}

sub sig_window_created {
	my $w = shift;
	my $refnum = defined($w->{refnum}) ? $w->{refnum} : get_window_count();

	push @{$windows{'default'}}, $refnum;
}

sub sig_window_destroyed {
	my $w = shift;
	foreach my $key (keys %windows) {
		if (defined(@windows{$key})) {
			my $index = 0;
			$index++ until ${@windows{$key}}[$index] == $w->{refnum};
			splice(@{$windows{$key}}, $index, 1);
		}
	}
}

sub sig_key {
	my $key = shift;
	if ($key == 14)	{		# ctrl+n
		Irssi::signal_stop();
		goto_window(NEXT);
	} elsif ($key == 16) {		# ctrl+p
		Irssi::signal_stop();
		goto_window(PREV);
	}
}

Irssi::signal_add({
	'window created'	=> 'sig_window_created',
	'window destroyed'	=> 'sig_window_destroyed',
});
Irssi::signal_add_first('gui key pressed', 'sig_key');

sub cmd_group_assign {
	my $group = shift;
	if (!defined($group)) { return; }

	my $current = Irssi::active_win();
	if ($current->{refnum} == 1) { return; }

	my $index = 0;
	$index++ until ${@windows{$active_g}}[$index] == $current->{refnum};
	splice(@{$windows{$active_g}}, $index, 1);

	if (!defined($windows{$group})) {
		push @{$windows{$group}}, 1;
	}
	push @{$windows{$group}}, $current->{refnum};

	$active_g = $group;
	$active_w = $#{@windows{$group}};
}

sub cmd_group_goto {
	my $group = shift;
	if (!defined($group)) { return; }
	if (!defined($windows{$group})) {
		print 'Undefined group';
		return;
	}

	Irssi::command('window goto ' . $windows{$group}[0]);

	$active_g = $group;
	$active_w = 0;
}

sub find_window {
	my $search = shift;
	my $regex = qr/^(.*?)(\Q$search\E)(.*?)$/i;
	my $current = Irssi::active_win();

	foreach my $w (Irssi::windows()) {
		if ($w->{refnum} ~~ @{$windows{$active_g}}) {
			if ($w->{refnum} == $search) { return $search; }

			# TODO: get the best match, not the first one.
			if ($w->{name} =~ $regex) {
				return $w->{refnum};
			}

			# TODO: get the best match, not the first one.
			my @items = $w->items();
			if ($items[0]->{visible_name} =~ $regex) {
				return $w->{refnum};
			}
		}
	}

	return $current->{refnum};
}

sub cmd_ws {
	my $refnum = find_window(shift);
	Irssi::command('window goto ' . $refnum);
	$active_w = $refnum;
}

Irssi::command_bind('group', sub {
	my ( $data, $server, $item ) = @_;
	$data =~ s/\s+$//g;
	Irssi::command_runsub ('group', $data, $server, $item);
});
Irssi::signal_add_first('default command group', sub {
	print (<<EOF
Usage:
  group assign <name>   - Assign the current window to the group <name>.
  group goto <name>     - Use <name> as the current group.
EOF
);});
Irssi::command_bind('group assign', 'cmd_group_assign');
Irssi::command_set_options('group assign', '+name');
Irssi::command_bind('group goto', 'cmd_group_goto');
Irssi::command_set_options('group goto', '+name');
Irssi::command_bind('ws', 'cmd_ws');
Irssi::command_set_options('ws', '+');
