
package FieldDay::ObjectType::Blog;
use strict;
use Data::Dumper;

use base qw( FieldDay::ObjectType );

sub insert_before {
	return qq{<mt:setvarblock name="action_buttons">};
}

sub object_form_id {
	return 'cfg_form';
}

sub insert_before_html_head {
	return q{<mt:include name="include/header.tmpl">};
}

1;
