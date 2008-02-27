
package FieldDay::ObjectType::User;
use strict;
use Data::Dumper;

use base qw( FieldDay::ObjectType );

sub insert_before {
	return qq{<fieldset>
                <h3><__trans phrase="System Permissions">};
}

sub object_form_id {
	return 'profile';
}

sub insert_before_html_head {
	return q{<mt:include name="include/header.tmpl">};
}

1;
