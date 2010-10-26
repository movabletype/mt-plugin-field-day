
package FieldDay::FieldType::ChoiceList::SelectMenu;
use strict;

use base qw( FieldDay::FieldType::ChoiceList );

sub label {
    return 'Select Menu';
}

sub options_tmpl_type {
# the field type that contains the options template, used for subclasses
    return 'ChoiceList';
}

1;
