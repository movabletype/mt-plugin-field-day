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

package FieldDay::FieldType::LinkedObject::LinkedUser;

use strict;

use base qw( FieldDay::FieldType::LinkedObject );


sub tags {
    return {
        'per_type' => {
            'block' => {
                'LinkedUsers' => sub { __PACKAGE__->hdlr_LinkedObjects('user', @_) },
                'IfLinkedUsers?' => sub { __PACKAGE__->hdlr_LinkedObjects('user', @_) },
                'LinkingUsers' => sub { __PACKAGE__->hdlr_LinkingObjects('user', @_) },
                'IfLinkingUsers?' => sub { __PACKAGE__->hdlr_LinkingObjects('user', @_) },
            },
        },
    };
}

sub options {
    my $class = shift;
    return {
        'active' => 1,
        %{$class->SUPER::options()},
        # override default
        'allow_create' => 0,
    };
}

sub label {
    return 'Linked User';
}

sub object_type {
    return 'user';
}

# the field type that contains the render template, used for subclasses
sub render_tmpl_type {
    return 'LinkedObject';
}

sub load_objects {
    my $class = shift;
    my ($param, @terms) = @_;
    require MT::Author;
    if (ref($terms[0])) {
        push(@terms, '-and', { 'type' => MT::Author::AUTHOR() });
        if ($param->{'active'}) {
            push(@terms, '-and', { 'status' => 1 });
        }
        return MT::Author->load(\@terms);
    } else {
        my %terms = @terms;
        return MT::Author->load(\%terms);
    }
}

sub has_blog_id {
    0;
}

sub object_label {
    my $class = shift;
    my ($obj) = @_;
    return $obj->nickname || $obj->name;
}

sub core_fields {
    my $class = shift;
    # don't need type and label because create is not currently allowed
    return { map { $_ => 1 } qw( name nickname email ) };
}

sub pre_render {
    my $class = shift;
    $class->SUPER::pre_render(@_);
    my ($param) = @_;
    $param->{'linked_object_type'} = 'author';
}

sub do_query {
    my $class = shift;
    my ($setting, $q) = @_;
    my @terms = (
        [
            {
                name => { like => '%' . $q->param('query') . '%' },
            },
            '-or',
            {
                nickname => { like => '%' . $q->param('query') . '%' },
            },
        ]
    );
    my $data = $setting->data;
    my $options = $setting->data->{'options'};
    $options->{'type'} = $data->{'type'};
    my @authors = $class->load_objects($options, @terms);
    return join("\n", map { $class->map_obj($_, $options) } @authors);
}

sub map_obj {
    my $class = shift;
    my ($author, $options) = @_;
    my @values = ($author->name, $author->id, undef);
    push(@values, $class->autocomplete_values($author, $options));
    return join("\t", @values);
}

1;
