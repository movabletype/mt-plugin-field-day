
package FieldDay::FieldType::LinkedObject::LinkedPage;
use strict;

use base qw( FieldDay::FieldType::LinkedObject::LinkedEntry );

sub tags {
    return {
        'per_type' => {
            'block' => {
                'LinkedPages' => sub { __PACKAGE__->hdlr_LinkedObjects('page', @_) },
                'IfLinkedPages?' => sub { __PACKAGE__->hdlr_LinkedObjects('page', @_) },
                'LinkingPages' => sub { __PACKAGE__->hdlr_LinkingObjects('page', @_) },
                'IfLinkingPages?' => sub { __PACKAGE__->hdlr_LinkingObjects('page', @_) },
            },
        },
    };
}

sub label {
    return 'Linked Page';
}

sub options_tmpl_type {
    return 'LinkedEntry';
}

sub object_type {
    return 'page';
}

sub load_objects {
    my $class = shift;
    my ($param, %terms) = @_;
    $terms{'class'} = 'page';
    return $class->SUPER::load_objects($param, %terms);
}

1;
