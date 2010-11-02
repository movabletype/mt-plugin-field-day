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

package FieldDay::FieldType::LinkedObject::LinkedTemplate;

use strict;

use base qw( FieldDay::FieldType::LinkedObject );


sub tags {
    return {
        'per_type' => {
            'block' => {
                'LinkedTemplates' => sub { __PACKAGE__->hdlr_LinkedObjects('template', @_) },
                'IfLinkedTemplates?' => sub { __PACKAGE__->hdlr_LinkedObjects('template', @_) },
                'LinkingTemplates' => sub { __PACKAGE__->hdlr_LinkingObjects('template', @_) },
                'IfLinkingTemplates?' => sub { __PACKAGE__->hdlr_LinkingObjects('template', @_) },
            },
            'function' => {
                'LinkedTemplateName' => \&hdlr_LinkedTemplateName,
                'LinkedTemplate' => \&hdlr_LinkedTemplate,
            },
        },
    };
}

sub options {
    return {
        'linked_blog_id' => undef,
    };
}

sub label {
    return 'Linked Template';
}

sub load_objects {
    my $class = shift;
    my ($param) = @_;
    require MT::Template;
    return () unless ($param->{'linked_blog_id'});
    return MT::Template->load({ blog_id => $param->{'linked_blog_id'} },
        { 'sort' => 'name' }
    );
}

sub object_label {
    my $class = shift;
    my ($obj) = @_;
    return $obj->name;
}

sub hdlr_LinkedTemplateName {
    my ($ctx, $args) = @_;
    (my $template = $ctx->stash('template')) || return '';
    return $template->name;
}

sub hdlr_LinkedTemplate {
    my ($ctx, $args) = @_;
    (my $template = $ctx->stash('template')) || return '';
    if ($args->{'build'}) {
        $template->param($args);
        return $template->output;
    } else {
        return $template->text;
    }
}

1;
