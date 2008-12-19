
package FieldDay::ObjectType::Page;
use strict;
use Data::Dumper;

use base qw( FieldDay::ObjectType::Entry );

sub sort_by {
	return 'title';
}

sub sort_order {
	return 'ascend';
}

sub block_loop {
# called when a tag needs to loop through objects of this type
	my $class = shift;
	my ($iter, $ctx, $args, $cond) = @_;
	my $builder = $ctx->stash('builder');
	my $tokens  = $ctx->stash('tokens');
	my $out = '';
	my @pages;
	while (my $p = $iter->()) {
		push (@pages, $p);
	}
	@pages = @{$class->sort_objects('MT::Page', \@pages, $ctx, $args)};
	local $ctx->{__stash}{entries} = \@pages;
	return MT::Template::Context::_hdlr_pages($ctx, $args, $cond);
}

sub val {
	my $class = shift;
	my ($ctx, $args, $e) = @_;
	local $ctx->{__stash}->{entry} = $e;
	local $ctx->{__stash}->{entry_id} = $e->id;
	local $ctx->{__stash}->{blog_id} = $e->blog_id;
	return $ctx->tag('PageFieldValue', $args);
}

1;
