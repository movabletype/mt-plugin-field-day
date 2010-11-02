#!/usr/bin/perl -w
##########################################################################
# Copyright (C) 2008-2010 Six Apart Ltd.
# This program is free software: you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# version 2 for more details. You should have received a copy of the GNU
# General Public License version 2 along with this program. If not, see
# <http://www.gnu.org/licenses/>.

use strict;

use lib '../../lib';
use lib $ENV{MT_HOME} ? "$ENV{MT_HOME}/lib" : 'lib';
use MT;
use CGI;
use Data::Dumper;

my $mt = new MT;
my $q = new CGI;
require FieldDay::Util;
require FieldDay::Setting;

print "Content-type: text/plain\n\n";

(my $setting_id = $q->param('setting_id')) || exit;
(my $setting = FieldDay::Setting->load($setting_id)) || exit;

my $type = $setting->data->{'type'};
my $ft = FieldDay::Util::require_type($mt, 'field', $type);
my $result = $ft->do_query($setting, $q);
print $result;
