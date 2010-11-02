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

package FieldDay::ObjectType::Comment;

use strict;
use Data::Dumper;

use base qw( FieldDay::ObjectType );

sub insert_before {
    return qq{<mt:if name="position_actions_bottom">};
}

sub object_form_id {
    return 'comment_form';
}

sub stashed_id {
    my $class = shift;
    my ($ctx, $args) = @_;
    my $comment = $ctx->stash('comment');
    return $comment ? $comment->id : 0;
}

sub callbacks {
    return {
        'MT::Comment::post_save' => \&post_save_comment,
    };
}

sub post_save_comment {
    my ($cb, $obj) = @_;
    my $app = MT->instance;
    return 1 unless (ref($app) eq 'MT::App::Comments');
    $app->param('setting_object_type', 'comment');
    FieldDay::ObjectType::Comment->cms_post_save($cb, $app, $obj);
}

sub edit_template_source {
    my $class = shift;
    my ($cb, $app, $template) = @_;
    $$template =~ s/<form method="post"/<form method="post" name="comment_form" id="comment_form"/;
    $class->SUPER::edit_template_source(@_);
}

sub insert_before_html_head {
    return q{<mt:include name="include/header.tmpl">};
}

# specify terms to use when a tag loads objects
sub load_terms {
    my $class = shift;
    my ($ctx, $args) = @_;
    return {
        $ctx->stash('blog') ? ('blog_id' => $ctx->stash('blog')->id) : (),
        'visible' => 1,
    };
}

# called when a tag needs to loop through objects of this type
sub block_loop {
    my $class = shift;
    my ($iter, $ctx, $args, $cond) = @_;
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    my $out = '';
    return $out;
}

sub sort_by {
    return 'created_on';
}

sub sort_order {
    return 'ascend';
}

1;
