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

sub stashed_id {
    my $class = shift;
    my ($ctx, $args) = @_;
    if ($ctx->stash('author')) {
        return $ctx->stash('author')->id;
    }
    if ($ctx->stash('entry')) {
        return $ctx->stash('entry')->author_id;
    }
    return 0;
}

sub insert_before_html_head {
    return q{<mt:include name="include/header.tmpl">};
}

# specify terms to use when a tag loads objects
sub load_terms {
    my $class = shift;
    my ($ctx, $args) = @_;
    return {
        'type' => MT::Author::AUTHOR(),
    };
}

# called when a tag needs to loop through objects of this type
sub block_loop {
    my $class = shift;
    my ($iter, $ctx, $args, $cond) = @_;
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    my $out = '';
    my @authors;
    while (my $author = $iter->()) {
        push(@authors, $author);
    }
    @authors = @{$class->sort_objects('MT::Author', \@authors, $ctx, $args)};
    for my $author (@authors) {
        local $ctx->{__stash}{author} = $author;
        local $ctx->{__stash}{author_id} = $author->id;
        my $text = $builder->build($ctx, $tokens, $cond);
        return $ctx->error( $builder->errstr ) unless defined $text;
        $out .= $text;
    }
    return $out;
}

sub sort_by {
    return 'name';
}

sub sort_order {
    return 'ascend';
}

sub val {
    my $class = shift;
    my ($ctx, $args, $obj) = @_;
    local $ctx->{__stash}->{author} = $obj;
    return $ctx->tag('UserFieldValue', $args);
}

1;
