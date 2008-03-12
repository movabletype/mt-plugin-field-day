
package FieldDay::ObjectType::Page;
use strict;
use Data::Dumper;

use base qw( FieldDay::ObjectType::Entry );

sub sort_by {
	return 'title';
}

sub sort_order {
	return 'ascend';
}

1;
