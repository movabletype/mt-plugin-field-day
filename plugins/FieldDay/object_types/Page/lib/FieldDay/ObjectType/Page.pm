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

package FieldDay::ObjectType::Page;

use strict;

use Data::Dumper;

use base qw( FieldDay::ObjectType::Entry );

sub sort_by {
    return 'title';
}

sub sort_order {
    return 'ascend';
}

# called when a tag needs to loop through objects of this type
sub block_loop {
    my $class = shift;
    my ($iter, $ctx, $args, $cond) = @_;
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    my $out = '';
    my @pages;
    while (my $p = $iter->()) {
        push (@pages, $p);
    }
    @pages = @{$class->sort_objects('MT::Page', \@pages, $ctx, $args)};
    local $ctx->{__stash}{entries} = \@pages;
    return MT::Template::Context::_hdlr_pages($ctx, $args, $cond);
}

sub val {
    my $class = shift;
    my ($ctx, $args, $e) = @_;
    local $ctx->{__stash}->{entry} = $e;
    local $ctx->{__stash}->{entry_id} = $e->id;
    local $ctx->{__stash}->{blog_id} = $e->blog_id;
    return $ctx->tag('PageFieldValue', $args);
}

1;
