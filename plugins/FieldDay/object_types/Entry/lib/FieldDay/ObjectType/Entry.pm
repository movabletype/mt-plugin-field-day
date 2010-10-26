package FieldDay::ObjectType::Entry;

use strict;
use Data::Dumper;

use base qw( FieldDay::ObjectType );

sub callbacks {
    return {
        'cms_pre_preview' => \&cms_pre_preview,
    };
}

sub insert_before {
    return qq{<mt:setvarblock name="show_metadata">};
}

sub object_form_id {
    return 'entry_form';
}

sub stashed_id {
    my $class = shift;
    my ($ctx, $args) = @_;
    return $ctx->stash('entry') ? $ctx->stash('entry')->id : 0;
}

# specify terms to use when a tag loads objects
sub load_terms {
    my $class = shift;
    my ($ctx, $args) = @_;
    my %terms;
    if ($args->{'no_blog_id'}) {
    } elsif ($args->{'blog_ids'}) {
        $terms{'blog_id'} = [ split(/,/, $args->{'blog_ids'}) ];
    } elsif ($ctx->stash('blog')) {
        $terms{'blog_id'} = $ctx->stash('blog')->id;
    }
    if (!$args->{'preview'}) {
        $terms{'status'} = MT::Entry::RELEASE();
    }
    return \%terms;
}

# called when a tag needs to loop through objects of this type
sub block_loop {
    my $class = shift;
    my ($iter, $ctx, $args, $cond) = @_;
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    my $out = '';
    my @entries;
    while (my $e = $iter->()) {
        push (@entries, $e);
    }
    @entries = @{$class->sort_objects('MT::Entry', \@entries, $ctx, $args)};
    local $ctx->{__stash}{entries} = \@entries;
    return MT::Template::Context::_hdlr_entries($ctx, $args, $cond);
}

sub val {
    my $class = shift;
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

sub cms_pre_preview {
    my ($cb, $app, $obj, $data) = @_;
    return 1 unless ($app->param('fieldday'));
    for my $param ($app->param()) {
        
    }
}

1;
