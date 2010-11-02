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

package FieldDay::Value;

use strict;

use MT::Object;
@FieldDay::Value::ISA = qw(MT::Object);
__PACKAGE__->install_properties({
    column_defs => {
        'id' => 'integer not null auto_increment',
        'blog_id' => 'integer default 0',
        'object_id' => 'integer not null default 0',
        'object_type' => 'string(15)',
        'key' => 'string(75) not null',
        'value' => 'string(255)',
        'value_text' => 'text',
        'instance' => 'integer'
    },
    indexes => {
        'blog_id' => 1,
        'object_id' => 1,
        'object_type' => 1,
        'key' => 1,
        'value' => 1
    },
    audit => 0,
    datasource => 'fdvalue',
    primary_key => 'id'
});

sub populate {
    my $self = shift;
    my ($app, $key, $value, $object_type, $instance) = @_;
    $app->param('blog_id') && $self->blog_id($app->param('blog_id'));
    $self->object_id($app->param('id') || -1);
    $self->object_type($object_type || 'system');
    $self->key($key);
    $self->set_value($value);
    $instance && $self->instance($instance);
}

sub set_value {
    my $self = shift;
    my ($value) = @_;
    if (length($value) > 255) {
        $self->value_text($value);
        $self->value(undef);
    } else {
        $self->value($value);
        $self->value_text(undef);
    }
}

sub value {
    my $self = shift;
    if (@_) {
        return $self->column('value', @_);
    } else {
        return $self->value_text || $self->column('value');
    }
}

1;
