
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
	return {
		'status' => MT::Entry::RELEASE(),
		$ctx->stash('blog') ? ('blog_id' => $ctx->stash('blog')->id) : (),
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
	local $ctx->{__stash}{entries} = \@entries;
	return _hdlr_entries($ctx, $args, $cond);
}

sub sort_by {
	return 'created_on';
}

sub sort_order {
	return 'descend';
}

sub _hdlr_entries {
    my($ctx, $args, $cond) = @_;
    return $ctx->error(MT->translate('sort_by="score" must be used in combination with namespace.'))
        if ((exists $args->{sort_by}) && ('score' eq $args->{sort_by}) && (!exists $args->{namespace}));

    my $cfg = $ctx->{config};
    my $at = $ctx->{current_archive_type} || $ctx->{archive_type};
    my $entries = $ctx->stash('entries');
    if ($at && !$entries) {
        my $archiver = MT->publisher->archiver($at);
        if ( $archiver && $archiver->group_based ) {
            $entries = $archiver->archive_group_entries( $ctx, %$args );
            # $ctx->stash( 'entries', $entries );
        }
    }
    my $blog_id = $ctx->stash('blog_id');
    my $blog = $ctx->stash('blog');
    my (@filters, %blog_terms, %blog_args, %terms, %args);

    $ctx->set_blog_load_context($args, \%blog_terms, \%blog_args)
        or return $ctx->error($ctx->errstr);
    %terms = %blog_terms;
    %args = %blog_args;

    my $class_type = $args->{class_type} || 'entry';
    my $class = MT->model($class_type);
    my $cat_class_type = $class_type eq 'entry' ? 'category' : 'folder';
    my $cat_class = MT->model($cat_class_type);

    my %fields;
    foreach my $arg ( keys %$args ) {
        if ($arg =~ m/^field:(.+)$/) {
            $fields{$1} = $args->{$arg};
        }
    }

    if ($entries && @$entries) {
        my $entry = @$entries[0];
        $entries = undef if $entry->class ne $class_type;

        if ( $entries && %fields ) {
            $entries = undef;
        }
    }
    local $ctx->{__stash}{entries};

    # handle automatic offset based on 'offset' query parameter
    # in case we're invoked through mt-view.cgi or some other
    # app.
    if (($args->{offset} || '') eq 'auto') {
        $args->{offset} = 0;
        if (($args->{lastn} || $args->{limit}) && (my $app = MT->instance)) {
            if ($app->isa('MT::App')) {
                if (my $offset = $app->param('offset')) {
                    $args->{offset} = $offset;
                }
            }
        }
    }

    if (($args->{limit} || '') eq 'auto') {
        my ($days, $limit);
        my $blog = $ctx->stash('blog');
        if ($blog && ($days = $blog->days_on_index)) {
            my @ago = offset_time_list(time - 3600 * 24 * $days,
                $blog_id);
            my $ago = sprintf "%04d%02d%02d%02d%02d%02d",
                $ago[5]+1900, $ago[4]+1, @ago[3,2,1,0];
            $terms{authored_on} = [ $ago ];
            $args{range_incl}{authored_on} = 1;
        } elsif ($blog && ($limit = $blog->entries_on_index)) {
            $args->{lastn} = $limit;
        } else {
            delete $args->{limit};
        }
    } elsif ($args->{limit} && ($args->{limit} > 0)) {
        $args->{lastn} = $args->{limit};
    }

    $terms{status} = MT::Entry::RELEASE();

    if (!$entries) {
        if ($ctx->{inside_mt_categories}) {
            if (my $cat = $ctx->stash('category')) {
                $args->{category} ||= [ 'OR', [ $cat ] ]
                    if $cat->class eq $cat_class_type;
            }
        } elsif (my $cat = $ctx->stash('archive_category')) {
            $args->{category} ||= [ 'OR', [ $cat ] ];
        }
    }

    # kinds of <MTEntries> uses...
    #     * from an index template
    #     * from an archive context-- entries are prepopulated

    # Adds a category filter to the filters list.
    if (my $category_arg = $args->{category} || $args->{categories}) {
        my ($cexpr, $cats);
        if (ref $category_arg) {
            my $is_and = (shift @{$category_arg}) eq 'AND';
            $cats = [ @{ $category_arg->[0] } ];
            $cexpr = $ctx->compile_category_filter(undef, $cats, { 'and' => $is_and,
                children => 
                    $class_type eq 'entry' ?
                        ($args->{include_subcategories} ? 1 : 0) :
                        ($args->{include_subfolders} ? 1 : 0)
            });
        } else {
            if (($category_arg !~ m/\b(AND|OR|NOT)\b|[(|&]/i) &&
                (($class_type eq 'entry' && !$args->{include_subcategories}) ||
                 ($class_type ne 'entry' && !$args->{include_subfolders})))
            {
                if ($blog_terms{blog_id}) {
                    $cats = [ $cat_class->load(\%blog_terms, \%blog_args) ];
                } else {
                    my @cats = cat_path_to_category($category_arg, [ \%blog_terms, \%blog_args ], $class_type);
                    if (@cats) {
                        $cats = \@cats;
                        $cexpr = $ctx->compile_category_filter(undef, $cats, { 'and' => 0 });
                    }
                }
            } else {
                my @cats = $cat_class->load(\%blog_terms, \%blog_args);
                if (@cats) {
                    $cats = \@cats;
                    $cexpr = $ctx->compile_category_filter($category_arg, $cats,
                        { children => $class_type eq 'entry' ?
                            ($args->{include_subcategories} ? 1 : 0) :
                            ($args->{include_subfolders} ? 1 : 0)
                        });
                }
            }
            $cexpr ||= $ctx->compile_category_filter($category_arg, $cats,
                { children => $class_type eq 'entry' ?
                    ($args->{include_subcategories} ? 1 : 0) :
                    ($args->{include_subfolders} ? 1 : 0) 
                });
        }
        if ($cexpr) {
            my %map;
            require MT::Placement;
            for my $cat (@$cats) {
                my $iter = MT::Placement->load_iter({ category_id => $cat->id });
                while (my $p = $iter->()) {
                    $map{$p->entry_id}{$cat->id}++;
                }
            }
            push @filters, sub { $cexpr->($_[0]->id, \%map) };
        } else {
            return $ctx->error(MT->translate("You have an error in your '[_2]' attribute: [_1]", $args->{category} || $args->{categories}, $class_type eq 'entry' ? 'category' : 'folder'));
        }
    }
    # Adds a tag filter to the filters list.
    if (my $tag_arg = $args->{tags} || $args->{tag}) {
        require MT::Tag;
        require MT::ObjectTag;

        my $terms;
        if ($tag_arg !~ m/\b(AND|OR|NOT)\b|\(|\)/i) {
            my @tags = MT::Tag->split(',', $tag_arg);
            $terms = { name => \@tags };
            $tag_arg = join " or ", @tags;
        }
        my $tags = [ MT::Tag->load($terms, {
            binary => { name => 1 },
            join => MT::ObjectTag->join_on('tag_id', {
                object_datasource => $class->datasource,
                %blog_terms
            }, \%blog_args)
        }) ];
        my $cexpr = $ctx->compile_tag_filter($tag_arg, $tags);
        if ($cexpr) {
            my @tag_ids = map { $_->id, ( $_->n8d_id ? ( $_->n8d_id ) : () ) } @$tags;
            my $preloader = sub {
                my ($entry_id) = @_;
                my $terms = { 
                    tag_id => \@tag_ids,
                    object_id => $entry_id,
                    object_datasource => $class->datasource,
                    %blog_terms,
                };
                my $args = { %blog_args,
                    fetchonly => ['tag_id'] };
                my @ot_ids = MT::ObjectTag->load($terms, $args);
                my %map;
                $map{$_->tag_id} = 1 for @ot_ids;
                \%map;
            };
            push @filters, sub { $cexpr->($preloader->($_[0]->id)) };
        } else {
            return $ctx->error(MT->translate("You have an error in your 'tag' attribute: [_1]", $tag_arg));
        }
    }

    # Adds an author filter to the filters list.
    if (my $author_name = $args->{author}) {
        require MT::Author;
        my $author = MT::Author->load({ name => $author_name }) or
            return $ctx->error(MT->translate(
                "No such user '[_1]'", $author_name ));
        if ($entries) {
            push @filters, sub { $_[0]->author_id == $author->id };
        } else {
            $terms{author_id} = $author->id;
        }
    }

    # Adds an ID filter to the filter list.
    if ((my $target_id = $args->{id}) && (ref($args->{id}) || ($args->{id} =~ m/^\d+$/))) {
        if ($entries) {
            if (ref $target_id eq 'ARRAY') {
                my %ids = map { $_ => 1 } @$target_id;
                push @filters, sub { exists $ids{$_[0]->id} };
            } else {
                push @filters, sub { $_[0]->id == $target_id };
            }
        } else {
            $terms{id} = $target_id;
        }
    }

    if ($args->{namespace}) {
        my $namespace = $args->{namespace};

        my $need_join = 0;
        for my $f qw( min_score max_score min_rate max_rate min_count max_count scored_by ) {
            if ($args->{$f}) {
                $need_join = 1;
                last;
            }
        }
        if ($need_join) {
            my $scored_by = $args->{scored_by} || undef;
            if ($scored_by) {
                require MT::Author;
                my $author = MT::Author->load({ name => $scored_by }) or
                    return $ctx->error(MT->translate(
                        "No such user '[_1]'", $scored_by ));
                $scored_by = $author;
            }

            $args{join} = MT->model('objectscore')->join_on(undef,
                {
                    object_id => \'=entry_id',
                    object_ds => 'entry',
                    namespace => $namespace,
                    (!$entries && $scored_by ? (author_id => $scored_by->id) : ()),
                }, {
                    unique => 1,
            });
            if ($entries && $scored_by) {
                push @filters, sub { $_[0]->get_score($namespace, $scored_by) };
            }
        }

        # Adds a rate or score filter to the filter list.
        if ($args->{min_score}) {
            push @filters, sub { $_[0]->score_for($namespace) >= $args->{min_score}; };
        }
        if ($args->{max_score}) {
            push @filters, sub { $_[0]->score_for($namespace) <= $args->{max_score}; };
        }
        if ($args->{min_rate}) {
            push @filters, sub { $_[0]->score_avg($namespace) >= $args->{min_rate}; };
        }
        if ($args->{max_rate}) {
            push @filters, sub { $_[0]->score_avg($namespace) <= $args->{max_rate}; };
        }
        if ($args->{min_count}) {
            push @filters, sub { $_[0]->vote_for($namespace) >= $args->{min_count}; };
        }
        if ($args->{max_count}) {
            push @filters, sub { $_[0]->vote_for($namespace) <= $args->{max_count}; };
        }
    }

    my $published = $ctx->{__stash}{entry_ids_published} ||= {};
    if ($args->{unique}) {
        push @filters, sub { !exists $published->{$_[0]->id} }
    }

    my $namespace = $args->{namespace};
    my $no_resort = 0;
    my $score_limit = 0;
    my $score_offset = 0;
    my @entries;
    if (!$entries) {
        my ($start, $end) = ($ctx->{current_timestamp},
                         $ctx->{current_timestamp_end});
        if ($start && $end) {
            $terms{authored_on} = [$start, $end];
            $args{range_incl}{authored_on} = 1;
        }
        if (my $days = $args->{days}) {
            my @ago = offset_time_list(time - 3600 * 24 * $days,
                $blog_id);
            my $ago = sprintf "%04d%02d%02d%02d%02d%02d",
                $ago[5]+1900, $ago[4]+1, @ago[3,2,1,0];
            $terms{authored_on} = [ $ago ];
            $args{range_incl}{authored_on} = 1;
        } else {
            # Check attributes
            my $found_valid_args = 0;
            foreach my $valid_key (
                'lastn',      'category',
                'categories', 'tag',
                'tags',       'author',
                'days',       'recently_commented_on',
                'min_score',  'max_score',
                'min_rate',    'max_rate',
                'min_count',  'max_count'
              )
            {
                if (exists($args->{$valid_key})) {
                    $found_valid_args = 1;
                    last;
                }
            }

            if (!$found_valid_args) {
                # Uses weblog settings
                if (my $days = $blog ? $blog->days_on_index : 10) {
                    my @ago = offset_time_list(time - 3600 * 24 * $days,
                        $blog_id);
                    my $ago = sprintf "%04d%02d%02d%02d%02d%02d",
                        $ago[5]+1900, $ago[4]+1, @ago[3,2,1,0];
                    $terms{authored_on} = [ $ago ];
                    $args{range_incl}{authored_on} = 1;
                } elsif (my $limit = $blog ? $blog->entries_on_index : 10) {
                    $args->{lastn} = $limit;
                }
            }
        }

        # Adds class_type
        $terms{class} = $class_type;

        $args{'sort'} = 'authored_on';
        if ($args->{sort_by}) {
            $args->{sort_by} =~ s/:/./; # for meta:name => meta.name
            $args->{sort_by} = 'ping_count' if $args->{sort_by} eq 'trackback_count';
            if ($class->is_meta_column($args->{sort_by})) {
                $no_resort = 0;
            } elsif ($class->has_column($args->{sort_by})) {
                $args{sort} = $args->{sort_by};
                $no_resort = 1;
            } elsif ($args->{limit} && ('score' eq $args->{sort_by} || 'rate' eq $args->{sort_by})) {
                $score_limit = delete($args->{limit}) || 0;
                $score_offset = delete($args->{offset}) || 0;
                if ( $score_limit || $score_offset ) {
                    delete $args->{lastn};
                }
                $no_resort = 0;
            }
        }

        if ( %fields ) {
            # specifies we need a join with entry_meta;
            # for now, we support one join
            my ( $col, $val ) = %fields;
            my $type = MT::Meta->metadata_by_name($class, 'field.' . $col);
            $args{join} = [ $class->meta_pkg, undef,
                { type => 'field.' . $col,
                  $type->{type} => $val,
                  'entry_id' => \'= entry_id' } ];
        }

        if (!@filters) {
            if ((my $last = $args->{lastn}) && (!exists $args->{limit})) {
                $args{direction} = 'descend';
                $args{sort} = 'authored_on';
                $args{limit} = $last;
                $no_resort = 0 if $args->{sort_by};
            } else {
                $args{direction} = $args->{sort_order} || 'descend'
                  if exists($args{sort});
                $no_resort = 1 unless $args->{sort_by};
                if ((my $last = $args->{lastn}) && (exists $args->{limit})) {
                    $args{limit} = $last;
                }
            }
            $args{offset} = $args->{offset} if $args->{offset};
            @entries = $class->load(\%terms, \%args);
        } else {
            if (($args->{lastn}) && (!exists $args->{limit})) {
                $args{direction} = 'descend';
                $args{sort} = 'authored_on';
                $no_resort = 0 if $args->{sort_by};
            } else {
                $args{direction} = $args->{sort_order} || 'descend';
                $no_resort = 1 unless $args->{sort_by};
            }
            my $iter = $class->load_iter(\%terms, \%args);
            my $i = 0; my $j = 0;
            my $off = $args->{offset} || 0;
            my $n = $args->{lastn};
            ENTRY: while (my $e = $iter->()) {
                for (@filters) {
                    next ENTRY unless $_->($e);
                }
                next if $off && $j++ < $off;
                push @entries, $e;
                $i++;
                $iter->('finish'), last if $n && $i >= $n;
            }
        }
        if ($args->{recently_commented_on}) {
            my @e = sort {$b->comment_latest->created_on <=>
                          $a->comment_latest->created_on}
                    grep {$_->comment_latest} @entries;
            @entries = splice(@e, 0, $args->{recently_commented_on});
            $no_resort = 1;
        }
    } else {
        # Don't resort a predefined list that's not in a published archive
        # page when we didn't request sorting.
        if ($args->{sort_by} || $args->{sort_order} || $ctx->{archive_type}) {
            my $so = $args->{sort_order} || ($blog ? $blog->sort_order_posts : undef) || '';
            my $col = $args->{sort_by} || 'authored_on';
            if ( $col ne 'score' ) {
                if (my $def = $class->column_def($col)) {
                    if ($def->{type} =~ m/^integer|float$/) {
                        @$entries = $so eq 'ascend' ?
                            sort { $a->$col() <=> $b->$col() } @$entries :
                            sort { $b->$col() <=> $a->$col() } @$entries;
                    } else {
                        @$entries = $so eq 'ascend' ?
                            sort { $a->$col() cmp $b->$col() } @$entries :
                            sort { $b->$col() cmp $a->$col() } @$entries;
                    }
                    $no_resort = 1;
                } elsif ($class->is_meta_column($col)) {
                    my $type = MT::Meta->metadata_by_name($class, $col);
                    no warnings;
                    if ($type->{type} =~ m/integer|float/) {
                        @$entries = $so eq 'ascend' ?
                            sort { $a->$col() <=> $b->$col() } @$entries :
                            sort { $b->$col() <=> $a->$col() } @$entries;
                    } else {
                        @$entries = $so eq 'ascend' ?
                            sort { $a->$col() cmp $b->$col() } @$entries :
                            sort { $b->$col() cmp $a->$col() } @$entries;
                    }
                    $no_resort = 1;
                }
            }
        } else {
            $no_resort = 1;
        }

        if (@filters) {
            my $i = 0; my $j = 0;
            my $off = $args->{offset} || 0;
            my $n = $args->{lastn};
            ENTRY2: foreach my $e (@$entries) {
                for (@filters) {
                    next ENTRY2 unless $_->($e);
                }
                next if $off && $j++ < $off;
                push @entries, $e;
                $i++;
                last if $n && $i >= $n;
            }
        } else {
            my $offset;
            if ($offset = $args->{offset}) {
                if ($offset < scalar @$entries) {
                    @entries = @$entries[$offset..$#$entries];
                } else {
                    @entries = ();
                }
            } else {
                @entries = @$entries;
            }
            if (my $last = $args->{lastn}) {
                if (scalar @entries > $last) {
                    @entries = @entries[0..$last-1];
                }
            }
        }
    }

    # $entries were on the stash or were just loaded
    # based on a start/end range.
    my $res = '';
    my $tok = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    if (!$no_resort && (scalar @entries)) {
        my $col = $args->{sort_by} || 'authored_on';
        if ('score' eq $col) {
            my $so = $args->{sort_order} || '';
            my %e = map { $_->id => $_ } @entries;
            my @eid = keys %e;
            require MT::ObjectScore;
            my $scores = MT::ObjectScore->sum_group_by(
                { 'object_ds' => $class_type, 'namespace' => $namespace, object_id => \@eid },
                { 'sum' => 'score', group => ['object_id'],
                  $so eq 'ascend' ? (direction => 'ascend') : (direction => 'descend'),
                });
            my @tmp;
            my $i = 0;
            while (my ($score, $object_id) = $scores->()) {
                $i++, next if $score_offset && $i < $score_offset;
                push @tmp, delete $e{ $object_id } if exists $e{ $object_id };
                $scores->('finish'), last unless %e;
                $i++;
                $scores->('finish'), last if $score_limit && (scalar @tmp) >= $score_limit;
            }

            if (!$score_limit || (scalar @tmp) < $score_limit) {
                foreach (values %e) {
                    if ($so eq 'ascend') {
                        unshift @tmp, $_;
                    } else {
                        push @tmp, $_;
                    }
                    last if $score_limit && (scalar @tmp) >= $score_limit;
                }
            }
            @entries = @tmp;
        } elsif ('rate' eq $col) {
            my $so = $args->{sort_order} || '';
            my %e = map { $_->id => $_ } @entries;
            my @eid = keys %e;
            require MT::ObjectScore;
            my $scores = MT::ObjectScore->avg_group_by(
                { 'object_ds' => $class_type, 'namespace' => $namespace, object_id => \@eid },
                { 'avg' => 'score', group => ['object_id'],
                  $so eq 'ascend' ? (direction => 'ascend') : (direction => 'descend'),
                });
            my @tmp;
            my $i = 0;
            while (my ($score, $object_id) = $scores->()) {
                $i++, next if $score_offset && $i < $score_offset;
                push @tmp, delete $e{ $object_id } if exists $e{ $object_id };
                $scores->('finish'), last unless %e;
                $i++;
                $scores->('finish'), last if $score_limit && (scalar @tmp) >= $score_limit;
            }
            if (!$score_limit || (scalar @tmp) < $score_limit) {
                foreach (values %e) {
                    if ($so eq 'ascend') {
                        unshift @tmp, $_;
                    } else {
                        push @tmp, $_;
                    }
                    last if $score_limit && (scalar @tmp) >= $score_limit;
                }
            }
            @entries = @tmp;
        } else {
            my $so = $args->{sort_order} || ($blog ? $blog->sort_order_posts : 'descend') || '';
            if (my $def = $class->column_def($col)) {
                if ($def->{type} =~ m/^integer|float$/) {
                    @entries = $so eq 'ascend' ?
                        sort { $a->$col() <=> $b->$col() } @entries :
                        sort { $b->$col() <=> $a->$col() } @entries;
                } else {
                    @entries = $so eq 'ascend' ?
                        sort { $a->$col() cmp $b->$col() } @entries :
                        sort { $b->$col() cmp $a->$col() } @entries;
                }
            } elsif ($class->is_meta_column($col)) {
                my $type = MT::Meta->metadata_by_name($class, $col);
                no warnings;
                if ($type->{type} =~ m/integer|float/) {
                    @entries = $so eq 'ascend' ?
                        sort { $a->$col() <=> $b->$col() } @entries :
                        sort { $b->$col() <=> $a->$col() } @entries;
                } else {
                    @entries = $so eq 'ascend' ?
                        sort { $a->$col() cmp $b->$col() } @entries :
                        sort { $b->$col() cmp $a->$col() } @entries;
                }
            }
        }
    }
    my($last_day, $next_day) = ('00000000') x 2;
    my $i = 0;
    local $ctx->{__stash}{entries} = \@entries;
    my $glue = $args->{glue};
    my $vars = $ctx->{__stash}{vars} ||= {};
    for my $e (@entries) {
        local $vars->{__first__} = !$i;
        local $vars->{__last__} = !defined $entries[$i+1];
        local $vars->{__odd__} = ($i % 2) == 0; # 0-based $i
        local $vars->{__even__} = ($i % 2) == 1;
        local $vars->{__counter__} = $i+1;
        local $ctx->{__stash}{blog} = $e->blog;
        local $ctx->{__stash}{blog_id} = $e->blog_id;
        local $ctx->{__stash}{entry} = $e;
        local $ctx->{current_timestamp} = $e->authored_on;
        local $ctx->{modification_timestamp} = $e->modified_on;
        my $this_day = substr $e->authored_on, 0, 8;
        my $next_day = $this_day;
        my $footer = 0;
        if (defined $entries[$i+1]) {
            $next_day = substr($entries[$i+1]->authored_on, 0, 8);
            $footer = $this_day ne $next_day;
        } else { $footer++ }
        my $allow_comments ||= 0;
        $published->{$e->id}++;
        my $out = $builder->build($ctx, $tok, {
            %$cond,
            DateHeader => ($this_day ne $last_day),
            DateFooter => $footer,
            EntriesHeader => $class_type eq 'entry' ?
                (!$i) : (),
            EntriesFooter => $class_type eq 'entry' ?
                (!defined $entries[$i+1]) : (),
            PagesHeader => $class_type ne 'entry' ?
                (!$i) : (),
            PagesFooter => $class_type ne 'entry' ?
                (!defined $entries[$i+1]) : (),
        });
        return $ctx->error( $builder->errstr ) unless defined $out;
        $last_day = $this_day;
        $res .= $glue if defined $glue && $i && length($res) && length($out);
        $res .= $out;
        $i++;
    }
    if (!@entries) {
        return MT::Template::Context::_hdlr_pass_tokens_else(@_);
    }

    $res;
}



1;
