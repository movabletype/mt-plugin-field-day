
package FieldDay::FieldType::LinkedObject::LinkedPage;
use strict;

use base qw( FieldDay::FieldType::LinkedObject::LinkedEntry );

sub tags {
	return {
		'per_type' => {
			'block' => {
				'LinkedPages' => sub { __PACKAGE__->hdlr_LinkedObjects('page', @_) },
				'IfLinkedPages?' => sub { __PACKAGE__->hdlr_LinkedObjects('page', @_) },
				'LinkingPages' => sub { __PACKAGE__->hdlr_LinkingObjects('page', @_) },
				'IfLinkingPages?' => sub { __PACKAGE__->hdlr_LinkingObjects('page', @_) },
			},
		},
	};
}

sub options {
	return {
		'linked_blog_id' => undef,
		'published' => 1,
	};
}

sub label {
	return 'Linked Page';
}

sub load_objects {
	my $class = shift;
	my ($param) = @_;
	require MT::Page;
	require MT::Entry;
	return () unless ($param->{'linked_blog_id'});
	my $terms = {
		 blog_id => $param->{'linked_blog_id'},
	};
	my $args = {};
	if ($param->{'published'}) {
		$terms->{'status'} = MT::Entry::RELEASE();
	}
	$args = {
		'sort' => 'title',
		'direction' => 'ascend',
	};
	return MT::Page->load($terms, $args)
}

1;
