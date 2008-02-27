
package FieldDay::FieldType::LinkedObject::LinkedPage;
use strict;

use base qw( FieldDay::FieldType::LinkedObject );

sub options {
	return {
		'linked_blog_id' => undef,
		'folder_ids' => undef,
	};
}

sub label {
	return 'Linked Page';
}

sub render_tmpl_type {
# the field type that contains the render template, used for subclasses
	return 'LinkedObject';
}

sub load_objects {
	my $class = shift;
	my ($param) = @_;
	require MT::Entry;
	return () unless ($param->{'linked_blog_id'});
	my $terms = {
		 blog_id => $param->{'linked_blog_id'},
	};
	my $args = {};
	if ($param->{'category_ids'}) {
		my $cat_ids = [ split(/,/, $param->{'folder_ids'}) ];
		require MT::Placement;
		$args->{'join'} =  MT::Placement->join_on(
				'entry_id',
				{ category_id => $cat_ids,
				  class => 'folder'
				},
				{ unique => 1 }
			);
	}
	return MT::Entry->load($terms, $args)
}

sub object_label {
	my $class = shift;
	my ($obj) = @_;
	require MT::Util;
	return $obj->title ? MT::Util::remove_html($obj->title) : '[untitled]';
}

1;
