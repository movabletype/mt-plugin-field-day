
package FieldDay::FieldType::TextArea;
use strict;

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

1;