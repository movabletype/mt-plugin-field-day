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

package FieldDay::FieldType::ChoiceList::SelectMenu;

use strict;

use base qw( FieldDay::FieldType::ChoiceList );

sub label {
    return 'Select Menu';
}

# the field type that contains the options template, used for subclasses
sub options_tmpl_type {
    return 'ChoiceList';
}

1;
