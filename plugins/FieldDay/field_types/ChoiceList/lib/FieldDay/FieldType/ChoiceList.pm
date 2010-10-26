package FieldDay::FieldType::ChoiceList;

use strict;

use Data::Dumper;

use base qw( FieldDay::FieldType );

sub options {
    return {
        'choices' => undef
    };
}

sub hdlr_FieldKey {
    my ($ctx, $args) = @_;

}

# before the field is rendered in the CMS
sub pre_render {
    my $class = shift;
    my ($param) = @_;
    my @choice_loop = ();
    for my $choice (split(/[\n\r]+/, $param->{'choices'})) {
        next unless $choice;
        my ($key, $label) = split(/=/, $choice);
        $label ||= $key;
        push(@choice_loop, {
            'value' => $key,
            'selected' => ($param->{'value'} &&
                (($param->{'value'} eq $key) ||
                    $param->{'value'} eq $label)) ? 1 : 0,
            'label' => $label
        });
    }
    $param->{'choice_loop'} = \@choice_loop;
}

sub pre_publish {
    my $class = shift;
    my ($ctx, $args, $value, $field) = @_;
    return $value if ($args->{'show_key'});
    my $choices = $field->data->{'options'}->{'choices'};
    my $find = quotemeta($value);
    for my $choice (split(/\n/, $choices)) {
        if ($choice =~ /^$find=/) {
            next unless $choice;
            (undef, $value) = split(/=/, $choice);
            return $value || '';
        }
    }
    return $value;
}

1;
