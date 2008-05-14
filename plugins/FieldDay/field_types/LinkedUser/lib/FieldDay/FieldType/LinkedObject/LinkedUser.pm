
package FieldDay::FieldType::LinkedObject::LinkedUser;
use strict;

use base qw( FieldDay::FieldType::LinkedObject );


sub tags {
	return {
		'per_type' => {
			'block' => {
				'LinkedUsers' => sub { __PACKAGE__->hdlr_LinkedObjects('user', @_) },
				'IfLinkedUsers?' => sub { __PACKAGE__->hdlr_LinkedObjects('user', @_) },
				'LinkingUsers' => sub { __PACKAGE__->hdlr_LinkingObjects('user', @_) },
				'IfLinkingUsers?' => sub { __PACKAGE__->hdlr_LinkingObjects('user', @_) },
			},
		},
	};
}

sub options {
	return {
		'active' => 1,
	};
}

sub label {
	return 'Linked User';
}

sub object_type {
	return 'user';
}

sub render_tmpl_type {
# the field type that contains the render template, used for subclasses
	return 'LinkedObject';
}

sub load_objects {
	my $class = shift;
	my ($param) = @_;
	require MT::Author;
	return MT::Author->load({ 'type' => MT::Author::AUTHOR() });
}

sub has_blog_id {
	0;
}

sub object_label {
	my $class = shift;
	my ($obj) = @_;
	return $obj->nickname || $obj->name;
}


1;
