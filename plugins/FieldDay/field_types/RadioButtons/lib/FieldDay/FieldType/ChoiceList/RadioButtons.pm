package FieldDay::FieldType::ChoiceList::RadioButtons;

use strict;

use base qw( FieldDay::FieldType::ChoiceList );

sub label {
    return 'Radio Buttons';
}

# the field type that contains the options template, used for subclasses
sub options_tmpl_type {
    return 'ChoiceList';
}

1;
