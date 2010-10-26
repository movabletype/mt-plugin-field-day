package FieldDay::FieldType::Checkbox;

use strict;

use base qw( FieldDay::FieldType );

sub label {
    return 'Text';
}

sub options {
    return {
    };
}

# before the field is rendered in the CMS
sub pre_render {
    my $class = shift;
    my ($param) = @_;

}

1;
