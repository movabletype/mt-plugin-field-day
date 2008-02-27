
package FieldDay::FieldType::LinkedObject::LinkedFolder;
use strict;

use base qw( FieldDay::FieldType::LinkedObject );

sub options {
	return {
		'linked_blog_id' => undef,
	};
}

sub tags {
	return {
		'block' => {
			'LinkedFolders' => \&FieldDay::FieldType::LinkedObject::hdlr_LinkedObjects,
		},
	};
}

sub label {
	return 'Linked Folder';
}

sub render_tmpl_type {
# the field type that contains the render template, used for subclasses
	return 'LinkedObject';
}

sub load_objects {
	my $class = shift;
	my ($param) = @_;
	require MT::Category;
	return () unless ($param->{'linked_blog_id'});
	return MT::Category->load({ blog_id => $param->{'linked_blog_id'},
		class => 'folder',
	});
}

sub object_label {
	my $class = shift;
	my ($obj) = @_;
	require MT::Util;
	return MT::Util::remove_html($obj->label);
}


1;
