#!/usr/bin/perl -w

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
