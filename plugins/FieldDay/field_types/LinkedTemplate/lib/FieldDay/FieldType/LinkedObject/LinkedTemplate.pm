
package FieldDay::FieldType::LinkedObject::LinkedTemplate;
use strict;

use base qw( FieldDay::FieldType::LinkedObject );

sub options {
	return {
		'linked_blog_id' => undef,
	};
}

sub label {
	return 'Linked Template';
}

sub render_tmpl_type {
# the field type that contains the render template, used for subclasses
	return 'LinkedObject';
}

sub load_objects {
	my $class = shift;
	my ($param) = @_;
	require MT::Template;
	return () unless ($param->{'linked_blog_id'});
	return MT::Template->load({ blog_id => $param->{'linked_blog_id'} },
		{ 'sort' => 'name' }
	);
}

sub object_label {
	my $class = shift;
	my ($obj) = @_;
	return $obj->name;
}


1;
