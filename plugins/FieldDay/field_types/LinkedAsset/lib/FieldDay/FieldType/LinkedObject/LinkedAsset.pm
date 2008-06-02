
package FieldDay::FieldType::LinkedObject::LinkedAsset;
use strict;
use Data::Dumper;

use base qw( FieldDay::FieldType::LinkedObject );

sub tags {
	return {
		'per_type' => {
			'block' => {
				'LinkedAssets' => sub { __PACKAGE__->hdlr_LinkedObjects('asset', @_) },
				'IfLinkedAssets?' => sub { __PACKAGE__->hdlr_LinkedObjects('asset', @_) },
				'LinkingAssets' => sub { __PACKAGE__->hdlr_LinkingObjects('asset', @_) },
				'IfLinkingAssets?' => sub { __PACKAGE__->hdlr_LinkingObjects('asset', @_) },
			},
		},
	};
}

sub options {
	return {
		'linked_blog_id' => undef,
		'asset_type' => undef,
	};
}

sub label {
	return 'Linked Asset';
}

sub pre_edit_options {
# before FieldDay displays the config screen
	my $class = shift;
	$class->SUPER::pre_edit_options(@_);
	my ($param) = @_;
	my @asset_type_loop;
	for my $type (qw( image audio video )) {
		push (@asset_type_loop, {
			'value' => $type,
			'label' => ucfirst($type),
			'selected' => ($param->{'asset_type'} && ($param->{'asset_type'} eq $type)) ? 1 : 0,
		});
	}
	$param->{'asset_type_loop'} = \@asset_type_loop;
}

sub load_objects {
	my $class = shift;
	my ($param) = @_;
	require MT::Asset;
	return MT::Asset->load(
		{ 
		class => $param->{'asset_type'} || '*',
		$param->{'linked_blog_id'}
		? (blog_id => $param->{'linked_blog_id'})
		: ()
	});
}

sub object_label {
	my $class = shift;
	my ($obj) = @_;
	require MT::Util;
	return MT::Util::remove_html($obj->label);
}

1;
