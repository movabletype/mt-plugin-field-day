
package FieldDay::FieldType::LinkedObject::LinkedFolder;
use strict;

use base qw( FieldDay::FieldType::LinkedObject::LinkedCategory );

sub tags {
	return {
		'per_type' => {
			'block' => {
				'LinkedFolders' => sub { __PACKAGE__->hdlr_LinkedObjects('folder', @_) },
				'IfLinkedFolders?' => sub { __PACKAGE__->hdlr_LinkedObjects('folder', @_) },
				'LinkingFolders' => sub { __PACKAGE__->hdlr_LinkingObjects('folder', @_) },
				'IfLinkingFolders?' => sub { __PACKAGE__->hdlr_LinkingObjects('folder', @_) },
			},
		},
	};
}

sub label {
	return 'Linked Folder';
}

sub options_tmpl_type {
# the field type that contains the options template, used for subclasses
	return 'LinkedCategory';
}

sub load_objects {
	my $class = shift;
	my ($param) = @_;
	require MT::Folder;
	return MT::Folder->load({ $param->{'linked_blog_id'}
		? (blog_id => $param->{'linked_blog_id'})
		: () });
}

1;
