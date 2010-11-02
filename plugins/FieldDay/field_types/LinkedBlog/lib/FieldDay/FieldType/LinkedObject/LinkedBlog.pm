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

package FieldDay::FieldType::LinkedObject::LinkedBlog;

use strict;

use base qw( FieldDay::FieldType::LinkedObject );

sub tags {
    return {
        'per_type' => {
            'block' => {
                'LinkedBlogs' => sub { __PACKAGE__->hdlr_LinkedObjects('blog', @_) },
                'IfLinkedBlogs?' => sub { __PACKAGE__->hdlr_LinkedObjects('blog', @_) },
                'LinkingBlogs' => sub { __PACKAGE__->hdlr_LinkingObjects('blog', @_) },
                'IfLinkingBlogs?' => sub { __PACKAGE__->hdlr_LinkingObjects('blog', @_) },
            },
        },
    };
}

sub options {
    my $class = shift;
    return {
        'limit_fields' => undef,
        %{$class->SUPER::options()},
        # override default
        'allow_create' => 0,
    };
}

sub label {
    return 'Linked Blog';
}

sub load_objects {
    my $class = shift;
    my ($param, %terms) = @_;
    require MT::Blog;
    my $terms = { %terms };
    my $args = {};
    if ($param->{'limit_fields'}) {
        my ($key, $value) = split(/=/, $param->{'limit_fields'});
        my @values = split(/,/, $value || '');
        if (!@values) {
            @values = (1, 'on');
        }
        require FieldDay::Value;
        $args->{'join'} = FieldDay::Value->join_on(
            undef,
            {
                object_id => \'= blog_id', #'
                object_type => 'blog',
                key => $key,
                value => \@values,
            },
        );
    }
    return MT::Blog->load($terms, $args);
}

sub has_blog_id {
    return 0;
}

sub object_label {
    my $class = shift;
    my ($obj) = @_;
    return $obj->name;
}

sub pre_render {
    my $class = shift;
    $class->SUPER::pre_render(@_);
    my ($param) = @_;
    $param->{'linked_object_view_mode'} = 'dashboard';
    $param->{'blog_id'} = $param->{'value'};
}

sub do_query {
    my $class = shift;
    my ($setting, $q) = @_;
    my %terms = (
        name => { like => '%' . $q->param('query') . '%' },
    );
    my $data = $setting->data;
    my $options = $setting->data->{'options'};
    $options->{'type'} = $data->{'type'};
    my @blogs = $class->load_objects($options, %terms);
    return join("\n", map { $class->map_obj($_, $options) } @blogs);
}

sub map_obj {
    my $class = shift;
    my ($blog, $options) = @_;
    # use blog's id where blog_id expected
    my @values = ($blog->name, $blog->id, $blog->id);
    push(@values, $class->autocomplete_values($blog, $options));
    return join("\t", @values);
}

1;
