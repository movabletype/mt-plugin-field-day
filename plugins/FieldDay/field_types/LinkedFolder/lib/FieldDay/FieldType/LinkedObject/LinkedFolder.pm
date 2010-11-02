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

package FieldDay::FieldType::LinkedObject::LinkedFolder;

use strict;

use base qw( FieldDay::FieldType::LinkedObject::LinkedCategory );

sub tags {
    return {
        'per_type' => {
            'block' => {
                'LinkedFolders' => sub { __PACKAGE__->hdlr_LinkedObjects('folder', @_) },
                'IfLinkedFolders?' => sub { __PACKAGE__->hdlr_LinkedObjects('folder', @_) },
                'LinkingFolders' => sub { __PACKAGE__->hdlr_LinkingObjects('folder', @_) },
                'IfLinkingFolders?' => sub { __PACKAGE__->hdlr_LinkingObjects('folder', @_) },
            },
        },
    };
}

sub label {
    return 'Linked Folder';
}

# the field type that contains the options template, used for subclasses
sub options_tmpl_type {
    return 'LinkedCategory';
}

sub load_objects {
    my $class = shift;
    my ($param) = @_;
    require MT::Folder;
    return MT::Folder->load({ $param->{'linked_blog_id'}
        ? (blog_id => $param->{'linked_blog_id'})
        : () });
}

1;
