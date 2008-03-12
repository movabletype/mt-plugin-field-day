
package FieldDay::FieldType::ChoiceList::RadioButtons;
use strict;

use base qw( FieldDay::FieldType::ChoiceList );

sub label {
	return 'Radio Buttons';
}

sub options_tmpl_type {
# the field type that contains the options template, used for subclasses
	return 'ChoiceList';
}

1;
