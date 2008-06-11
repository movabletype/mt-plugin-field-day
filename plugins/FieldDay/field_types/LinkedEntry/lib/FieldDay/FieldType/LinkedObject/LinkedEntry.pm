
package FieldDay::FieldType::LinkedObject::LinkedEntry;
use strict;
use Data::Dumper;

use base qw( FieldDay::FieldType::LinkedObject );

sub tags {
	return {
		'per_type' => {
			'block' => {
				'LinkedEntries' => sub { __PACKAGE__->hdlr_LinkedObjects('entry', @_) },
				'IfLinkedEntries?' => sub { __PACKAGE__->hdlr_LinkedObjects('entry', @_) },
				'LinkingEntries' => sub { __PACKAGE__->hdlr_LinkingObjects('entry', @_) },
				'IfLinkingEntries?' => sub { __PACKAGE__->hdlr_LinkingObjects('entry', @_) },
			},
		},
	};
}

sub options {
	return {
		'linked_blog_id' => undef,
		'category_ids' => undef,
		'subcats' => undef,
		'lastn' => undef,
		'search' => undef,
		'published' => 1,
	};
}

sub label {
	return 'Linked Entry';
}

sub object_type {
	return 'entry';
}

sub load_objects {
	my $class = shift;
	my ($param) = @_;
	require MT::Entry;
	my $terms = {};
	if ($param->{'linked_blog_id'}) {
		$terms->{'blog_id'} = $param->{'linked_blog_id'};
	}
	if ($param->{'published'}) {
		$terms->{'status'} = MT::Entry::RELEASE();
	}
	my $args = {};
	if ($param->{'lastn'}) {
		$args = {
			'sort' => 'authored_on',
			'direction' => 'descend',
			'limit' => $param->{'lastn'},
		};
	} else {
		$args = {
			'sort' => 'title',
			'direction' => 'ascend',
		};
	}
	if ($param->{'category_ids'}) {
		my %cat_ids = map { $_ => 1 } split(/,/, $param->{'category_ids'});
		if ($param->{'subcats'}) {
			require MT::Category;
			for my $cat_id (keys %cat_ids) {
				my $cat = MT::Category->load($cat_id);
				for my $subcat ($cat->_flattened_category_hierarchy) {
					next unless ref $subcat;
					$cat_ids{$subcat->id} = 1;
				}
			}
		}
		require MT::Placement;
		$args->{'join'} =  MT::Placement->join_on(
				'entry_id',
				{ category_id => [ keys %cat_ids ],
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
	require MT::Blog;
	return $obj->title ? MT::Util::remove_html($obj->title) : '[untitled]';
}


1;
