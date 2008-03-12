
package FieldDay::FieldType::LinkedObject::LinkedCategory;
use strict;

use base qw( FieldDay::FieldType::LinkedObject );

sub tags {
	return {
		'per_type' => {
			'block' => {
				'LinkedCategories' => sub { __PACKAGE__->hdlr_LinkedObjects('category', @_) },
				'IfLinkedCategories?' => sub { __PACKAGE__->hdlr_LinkedObjects('category', @_) },
				'LinkingCategories' => sub { __PACKAGE__->hdlr_LinkingObjects('category', @_) },
				'IfLinkingCategories?' => sub { __PACKAGE__->hdlr_LinkingObjects('category', @_) },
			},
		},
	};
}

sub options {
	return {
		'linked_blog_id' => undef,
	};
}

sub label {
	return 'Linked Category';
}

sub load_objects {
	my $class = shift;
	my ($param) = @_;
	require MT::Category;
	return MT::Category->load({ $param->{'linked_blog_id'}
		? (blog_id => $param->{'linked_blog_id'})
		: () });
}

sub object_label {
	my $class = shift;
	my ($obj) = @_;
	require MT::Util;
	return MT::Util::remove_html($obj->label);
}

1;
