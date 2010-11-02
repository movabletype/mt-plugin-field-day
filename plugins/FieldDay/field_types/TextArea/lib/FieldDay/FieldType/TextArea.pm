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

package FieldDay::FieldType::TextArea;

use strict;

use Data::Dumper;

use base qw( FieldDay::FieldType );

sub label {
    return 'Text Area';
}

sub options {
    my $class = shift;
    return {
        'height' => 200,
        'width' => undef,
    };
}

# before the field is rendered in the CMS
sub pre_render {
    my $class = shift;
    my ($param) = @_;
    if ($param->{'width'}) {
        $param->{'wrapper_width'} = $param->{'width'} + 20;
    }
}

sub pre_publish {
    my $class = shift;
    my ($ctx, $args, $value, $field) = @_;
    return $value unless ($field->object_type =~ /^entry|page$/);
    my $entry = $ctx->stash('entry');
    return $value unless $entry;
    my $convert_breaks = exists $args->{convert_breaks} ?
        $args->{convert_breaks} :
            defined $entry->convert_breaks ? $entry->convert_breaks :
                $ctx->stash('blog')->convert_paras;
    if ($convert_breaks) {
        my $filters = $entry->text_filters;
        push @$filters, '__default__' unless @$filters;
        $value = MT->apply_text_filters($value, $filters, $_[0]);
    }
    return $value;
}

1;
