
package FieldDay::FieldType::LinkedObject::LinkedBlog;
use strict;

use base qw( FieldDay::FieldType::LinkedObject );

sub options {
	return {
	};
}

sub label {
	return 'Linked Blog';
}

sub render_tmpl_type {
# the field type that contains the render template, used for subclasses
	return 'LinkedObject';
}

sub load_objects {
	my $class = shift;
	my ($param) = @_;
	require MT::Blog;
	return MT::Blog->load();
}

sub has_blog_id {
	return 0;
}

sub object_label {
	my $class = shift;
	my ($obj) = @_;
	return $obj->name;
}


1;
