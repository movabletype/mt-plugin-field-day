
package FieldDay::ObjectType::Template;
use strict;
use Data::Dumper;

use base qw( FieldDay::ObjectType );

sub insert_before {
	return qq{<mt:if name="archive_types">};
}

sub object_form_id {
	return 'template-listing-form';
}

sub stashed_id {
	my $class = shift;
	my ($ctx, $args) = @_;
	return $ctx->stash('template')->id;
}

1;
