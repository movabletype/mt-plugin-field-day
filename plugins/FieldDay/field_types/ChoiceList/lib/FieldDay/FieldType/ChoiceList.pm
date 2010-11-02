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

package FieldDay::FieldType::ChoiceList;

use strict;

use Data::Dumper;

use base qw( FieldDay::FieldType );

sub options {
    return {
        'choices' => undef
    };
}

sub hdlr_FieldKey {
    my ($ctx, $args) = @_;

}

# before the field is rendered in the CMS
sub pre_render {
    my $class = shift;
    my ($param) = @_;
    my @choice_loop = ();
    for my $choice (split(/[\n\r]+/, $param->{'choices'})) {
        next unless $choice;
        my ($key, $label) = split(/=/, $choice);
        $label ||= $key;
        push(@choice_loop, {
            'value' => $key,
            'selected' => ($param->{'value'} &&
                (($param->{'value'} eq $key) ||
                    $param->{'value'} eq $label)) ? 1 : 0,
            'label' => $label
        });
    }
    $param->{'choice_loop'} = \@choice_loop;
}

sub pre_publish {
    my $class = shift;
    my ($ctx, $args, $value, $field) = @_;
    return $value if ($args->{'show_key'});
    my $choices = $field->data->{'options'}->{'choices'};
    my $find = quotemeta($value);
    for my $choice (split(/\n/, $choices)) {
        if ($choice =~ /^$find=/) {
            next unless $choice;
            (undef, $value) = split(/=/, $choice);
            return $value || '';
        }
    }
    return $value;
}

1;
