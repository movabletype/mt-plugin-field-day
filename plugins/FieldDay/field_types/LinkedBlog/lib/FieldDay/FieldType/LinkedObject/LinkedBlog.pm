
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
		'limit_fields' => undef,
	};
}

sub label {
	return 'Linked Blog';
}

sub load_objects {
	my $class = shift;
	my ($param) = @_;
	require MT::Blog;
	my $args = {};
	if ($param->{'limit_fields'}) {
		my ($key, $value) = split(/=/, $param->{'limit_fields'});
		$value ||= [1, 'on'];
		require FieldDay::Value;
		$args->{'join'} = FieldDay::Value->join_on(
			undef,
			{
				object_id => \'= blog_id', #'
				object_type => 'blog',
				key => $key,
				value => $value,
			},
		);
	}
	return MT::Blog->load(undef, $args);
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
