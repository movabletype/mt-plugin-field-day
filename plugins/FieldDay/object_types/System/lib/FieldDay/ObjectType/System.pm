
package FieldDay::ObjectType::System;
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

sub stashed_id {
    return -1;
}

sub edit_template_source {
    my $class = shift;
    my ($cb, $app, $template) = @_;
    my $old = quotemeta(q{<form action="<mt:var name="script_url">" method="post" onsubmit="return validate(this);">});
    my $new = q{<form action="<mt:var name="script_url">" method="post" name="cfg_form" id="cfg_form" onsubmit="return validate(this);">
    <input type="hidden" name="fieldday" value="1" />
    };
    $$template =~ s/$old/$new/;
    $class->SUPER::edit_template_source(@_);
}

sub callbacks {
    return {
        'MT::Config::post_save' => \&post_save_config,
    };
}

sub post_save_config {
    my ($cb, $obj) = @_;
    my $mode = MT->instance->param('__mode');
    return unless ($mode && ($mode eq 'save_cfg_system_general'));
    $obj->id(undef);
    return FieldDay::ObjectType->cms_post_save($cb, MT->instance, $obj);
}

1;
