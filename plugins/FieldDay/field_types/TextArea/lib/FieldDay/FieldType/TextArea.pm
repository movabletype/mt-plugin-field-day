
package FieldDay::FieldType::TextArea;
use strict;
use Data::Dumper;

use base qw( FieldDay::FieldType );

sub label {
    return 'Text Area';
}

sub options {
    my $class = shift;
    return {
        'height' => 200,
        'width' => undef,
    };
}

sub pre_render {
# before the field is rendered in the CMS
    my $class = shift;
    my ($param) = @_;
    if ($param->{'width'}) {
        $param->{'wrapper_width'} = $param->{'width'} + 20;
    }
}

sub pre_publish {
    my $class = shift;
    my ($ctx, $args, $value, $field) = @_;
    return $value unless ($field->object_type =~ /^entry|page$/);
    my $entry = $ctx->stash('entry');
    return $value unless $entry;
    my $convert_breaks = exists $args->{convert_breaks} ?
        $args->{convert_breaks} :
            defined $entry->convert_breaks ? $entry->convert_breaks :
                $ctx->stash('blog')->convert_paras;
    if ($convert_breaks) {
        my $filters = $entry->text_filters;
        push @$filters, '__default__' unless @$filters;
        $value = MT->apply_text_filters($value, $filters, $_[0]);
    }
    return $value;
}

1;
