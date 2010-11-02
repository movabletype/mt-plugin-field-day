##########################################################################
# Copyright (C) 2008-2010 Six Apart Ltd.
# This program is free software: you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# version 2 for more details. You should have received a copy of the GNU
# General Public License version 2 along with this program. If not, see
# <http://www.gnu.org/licenses/>.

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

sub stashed_id {
    my $class = shift;
    my ($ctx, $args) = @_;
    return $ctx->stash('blog') ? $ctx->stash('blog')->id : 0;
}

# specify terms to use when a tag loads objects
sub load_terms {
    return {};
}

# called when a tag needs to loop through objects of this type
sub block_loop {
    my $class = shift;
    my ($iter, $ctx, $args, $cond) = @_;
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    my $out = '';
    while (my $blog = $iter->()) {
        local $ctx->{__stash}{blog} = $blog;
        local $ctx->{__stash}{blog_id} = $blog->id;
        my $text = $builder->build($ctx, $tokens, $cond);
        return $ctx->error( $builder->errstr ) unless defined $text;
        $out .= $text;
    }
    return $out;
}

sub edit_template_source {
    my $class = shift;
    my ($cb, $app, $template) = @_;
    $class->SUPER::edit_template_source($cb, $app, $template);
    $$template =~ s/<form name="cfg_form"/<form name="cfg_form" id="cfg_form"/;
}

sub sort_by {
    return 'name';
}

sub sort_order {
    return 'ascend';
}

1;
