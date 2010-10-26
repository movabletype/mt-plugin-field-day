#!/usr/bin/perl -w

use strict;

use lib '../../lib';
use lib $ENV{MT_HOME} ? "$ENV{MT_HOME}/lib" : 'lib';
use lib $ENV{MT_HOME} ? "$ENV{MT_HOME}/plugins/FieldDay/lib" : 'plugins/FieldDay/lib';
use MT::Bootstrap App => 'MT::App::Search::FieldDay';
