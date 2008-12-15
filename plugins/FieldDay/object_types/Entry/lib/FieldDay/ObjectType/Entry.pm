
package FieldDay::ObjectType::Entry;
use strict;
use Data::Dumper;

use base qw( FieldDay::ObjectType );

sub insert_before {
	return qq{<mt:setvarblock name="show_metadata">};
}

sub object_form_id {
	return 'entry_form';
}

sub stashed_id {
	my $class = shift;
	my ($ctx, $args) = @_;
	return $ctx->stash('entry')->id;
}

sub load_terms {
# specify terms to use when a tag loads objects
	my $class = shift;
	my ($ctx, $args) = @_;
	my %blog_id;
	if ($args->{'blog_ids'}) {
		$blog_id{'blog_id'} = [ split(/,/, $args->{'blog_ids'}) ];
	} elsif ($ctx->stash('blog')) {
		$blog_id{'blog_id'} = $ctx->stash('blog')->id;
	}
	return {
		'status' => MT::Entry::RELEASE(),
		%blog_id
	};
}

sub block_loop {
# called when a tag needs to loop through objects of this type
	my $class = shift;
	my ($iter, $ctx, $args, $cond) = @_;
	my $builder = $ctx->stash('builder');
	my $tokens  = $ctx->stash('tokens');
	my $out = '';
	my @entries;
	while (my $e = $iter->()) {
		push (@entries, $e);
	}
	my $col = $args->{'sort_by'};
	if ($col && !MT::Entry->column_def($col) && !MT::Entry->is_meta_column($col)) {
		my $so = $args->{'sort_order'};
		local $args->{field} = $col;
		if ($args->{'numeric'}) {
			if ($so eq 'descend') {
				@entries = sort { val($ctx, $args, $b) <=> val($ctx, $args, $a) } @entries;
			} else {
				@entries = sort { val($ctx, $args, $a) <=> val($ctx, $args, $b) } @entries;
			}
		} else {
			if ($so eq 'descend') {
				@entries = sort { val($ctx, $args, $b) cmp val($ctx, $args, $a) } @entries;
			} else {
				@entries = sort { val($ctx, $args, $a) cmp val($ctx, $args, $b) } @entries;
			}
		}
	}
	local $ctx->{__stash}{entries} = \@entries;
	return MT::Template::Context::_hdlr_entries($ctx, $args, $cond);
}

sub val {
	my ($ctx, $args, $e) = @_;
	local $ctx->{__stash}->{entry} = $e;
	local $ctx->{__stash}->{entry_id} = $e->id;
	local $ctx->{__stash}->{blog_id} = $e->blog_id;
	return $ctx->tag('EntryFieldValue', $args);
}

sub sort_by {
	return 'created_on';
}

sub sort_order {
	return 'descend';
}

1;
