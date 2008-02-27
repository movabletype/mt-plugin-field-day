
package FieldDay::FieldType::LinkedObject::LinkedUser;
use strict;

use base qw( FieldDay::FieldType::LinkedObject );

sub options {
	return {
	};
}

sub label {
	return 'Linked User';
}

sub render_tmpl_type {
# the field type that contains the render template, used for subclasses
	return 'LinkedObject';
}

sub load_objects {
	my $class = shift;
	my ($param) = @_;
	require MT::Author;
	return MT::Author->load;
}

sub object_label {
	my $class = shift;
	my ($obj) = @_;
	return $obj->nickname || $obj->name;
}


1;
