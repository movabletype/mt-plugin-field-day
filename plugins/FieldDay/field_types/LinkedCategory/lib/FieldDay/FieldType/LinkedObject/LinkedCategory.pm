
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
		'category_ids' => undef,
		'subcats' => undef,
	};
}

sub label {
	return 'Linked Category';
}

sub load_objects {
	my $class = shift;
	my ($param) = @_;
	my %cat_ids;
	require MT::Category;
	if ($param->{'category_ids'}) {
		for my $cat_id (split(/,/, $param->{'category_ids'})) {
			$cat_ids{$cat_id} = 1;
			if ($param->{'subcats'}) {
				my $cat = MT::Category->load($cat_id);
				for my $subcat ($cat->_flattened_category_hierarchy) {
					next unless ref $subcat;
					$cat_ids{$subcat->id} = 1;
				}
			}
		}
	}
	return MT::Category->load({ $param->{'linked_blog_id'}
		? (blog_id => $param->{'linked_blog_id'}) : (),
		%cat_ids ? (id => [ keys %cat_ids ]) : (),
	});
}

sub object_label {
	my $class = shift;
	my ($obj) = @_;
	require MT::Util;
	return MT::Util::remove_html($obj->label);
}

1;
