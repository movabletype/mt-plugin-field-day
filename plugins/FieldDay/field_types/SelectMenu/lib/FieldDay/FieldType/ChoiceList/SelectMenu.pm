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
