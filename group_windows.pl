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
# - keep the status window in all groups
# - bind window commands (move, goto) to make them group-aware
# - add settings to statically assign groups
# - add a window switcher command (/ws name|id|regex, scope: group)
# - get real ctrl+n/ctrl+v bindings from irssi
# - display a window list

use constant {
	PREV	=> 0,
	NEXT	=> 1,
};

my @windows = ();
my $active_w = undef;

sub refresh_window_list {
	my $index = 0;
	my $current = Irssi::active_win();

	@windows = ();
	foreach my $w (Irssi::windows()) {
		push @windows, $w->{refnum};

		if ($current->{refnum} == $w->{refnum}) {
			$active_w = $index;
		}
		$index++;
	}
}

sub change_window {
	my $index = undef;
	my $dir = shift;
	if ($dir != PREV && $dir != NEXT) {
		return;
	}

	$index = $active_w;
	$index += ($dir == PREV) ? -1 : 1;
	if ($index < 0) {
		$index = $#windows;
	} elsif ($index > $#windows) {
		$index = 0;
	}

	Irssi::command('window goto ' . $windows[$index]);
	$active_w = $index;
}

sub sig_window {
	refresh_window_list($@);
}

sub sig_key {
	my $key = shift;
	if ($key == 14)	{		# ctrl+n
		Irssi::signal_stop();
		change_window(NEXT);
	} elsif ($key == 16) {		# ctrl+p
		Irssi::signal_stop();
		change_window(PREV);
	}
}

refresh_window_list();

Irssi::signal_add('window created', 'sig_window');
Irssi::signal_add('window destroyed', 'sig_window');
Irssi::signal_add('window refnum changed', 'sig_window');
Irssi::signal_add('gui key pressed', 'sig_key');
