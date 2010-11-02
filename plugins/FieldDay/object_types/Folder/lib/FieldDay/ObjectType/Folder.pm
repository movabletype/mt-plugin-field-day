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

package FieldDay::ObjectType::Folder;

use strict;

use Data::Dumper;

use base qw( FieldDay::ObjectType::Category );

sub insert_before {
    return qq{<mt:setvarblock name="action_buttons">};
}

sub object_form_id {
    return 'folder_form';
}

sub stashed_id {
    my $class = shift;
    my ($ctx, $args) = @_;
    my $e;
    my $cat = ($ctx->stash('category') || $ctx->stash('archive_category'))
        || (($e = $ctx->stash('entry')) && $e->category);
    return $cat ? $cat->id : 0;
}

sub edit_template_source {
    my $class = shift;
    my ($cb, $app, $template) = @_;
    $$template =~ s/<form method="post"/<form method="post" name="folder_form" id="folder_form"/;
    $class->SUPER::edit_template_source(@_);
}

sub insert_before_html_head {
    return q{<mt:include name="include/header.tmpl">};
}

1;
