package FieldDay::FieldType::Text;

use strict;

use base qw( FieldDay::FieldType );

sub label {
    return 'Text';
}

sub options {
    return {
        'width' => 400,
        'length' => undef
    };
}

# before the field is rendered in the CMS
sub pre_render {
    my $class = shift;
    my ($param) = @_;
    
}

1;
