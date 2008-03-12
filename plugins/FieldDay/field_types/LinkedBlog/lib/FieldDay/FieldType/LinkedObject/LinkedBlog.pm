
package FieldDay::FieldType::LinkedObject::LinkedBlog;
use strict;

use base qw( FieldDay::FieldType::LinkedObject );

sub tags {
	return {
		'per_type' => {
			'block' => {
				'LinkedBlogs' => sub { __PACKAGE__->hdlr_LinkedObjects('blog', @_) },
				'IfLinkedBlogs?' => sub { __PACKAGE__->hdlr_LinkedObjects('blog', @_) },
				'LinkingBlogs' => sub { __PACKAGE__->hdlr_LinkingObjects('blog', @_) },
				'IfLinkingBlogs?' => sub { __PACKAGE__->hdlr_LinkingObjects('blog', @_) },
			},
		},
	};
}

sub options {
	return {
	};
}

sub label {
	return 'Linked Blog';
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
