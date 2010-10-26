package MT::App::Search::FieldDay;

use strict;

use base qw( MT::App::Search );
use MT::ObjectDriver::SQL qw( :constants );
use FieldDay::Value;
use FieldDay::YAML qw( object_type );
use FieldDay::Util qw( use_type );
use Data::Dumper;

sub id { 'new_search' }

sub core_methods {
    my $app = shift;
    return {
        'linked' => \&process_link,
        'linking' => \&process_link,
        %{ $app->SUPER::core_methods() },
    };
}

sub core_parameters {
    my $app = shift;
    my $params = $app->SUPER::core_parameters();
    my %filter_types = %{$params->{types}->{entry}->{filter_types}};
    $params->{types}->{entry}->{filter_types} = {
        linking_ids => \&_join_linking_ids,
        linked_ids => \&_join_linked_ids,
        category_basename => \&_join_category_basename,
        %filter_types,
    };
    $params;
}

# need to defer this until after we munge the params
sub generate_cache_keys {
}

sub query_parse {
    my $app = shift;
    my ( %columns ) = @_;
    my $parsed = $app->SUPER::query_parse(%columns);
    my %ids;
    if ($app->param('object_ids')) {
        %ids = map { $_ => 1 } split(/,/, $app->param('object_ids'));
    }
    my $type = $app->{searchparam}{Type};
    my $ot = FieldDay::YAML->object_type(use_type($type));
    my $args = {};
    if ($app->param('search') && ($app->param('search') ne '%')) {
        my $terms = $app->def_terms;
        my $like = $parsed->{'terms'}->[0]->[0]->{[keys %{$parsed->{'terms'}->[0]->[0]}]->[0]}->{like};
        my $id_col = id_col($ot);
        $args->{join} = FieldDay::Value->join_on(
            undef,
            {
                'object_id' => \"= $id_col", #"
                'value' => { like => $like },
                'object_type' => $ot->{'object_type'},
                $app->param('fields') ? ('key' => [ split(/,/, $app->param('fields')) ]) : (),
                ($ot->{'has_blog_id'} && exists $app->{searchparam}{IncludeBlogs})
                    ? ('blog_id' => [ keys %{ $app->{searchparam}{IncludeBlogs} } ])
                    : (),
            }
        );
        eval("require $ot->{'object_class'};");
        my $iter = $ot->{'object_class'}->load_iter($terms, $args);
        my @ids;
        while (my $obj = $iter->()) {
            $ids{$obj->id} = 1;
        }
        if (%ids) {
            push(@{$parsed->{terms}->[0]}, '-or', { id => [ keys %ids ] });
        }
    }
    $parsed;
}

sub execute {
    my $app = shift;
    return $app->SUPER::execute(@_) unless $app->param('sort_field');
    my ( $terms, $args ) = @_;

    my $class = $app->model( $app->{searchparam}{Type} )
        or return $app->errtrans('Unsupported type: [_1]', encode_html($app->{searchparam}{Type}));

    my $count = $app->count( $class, $terms, $args );
    return $app->errtrans("Invalid query: [_1]", $app->errstr) unless defined $count;

    my $offset = $args->{offset} || 0;
    my $limit = $args->{limit} || 0;
    delete $args->{offset};
    delete $args->{limit};
    my @results = $class->load( $terms, $args )
        or $app->error($class->errstr);
    my @ids = map { $_->id } @results;
    require FieldDay::YAML;
    require FieldDay::Value;
    my $ot = FieldDay::YAML->object_type_by_class($class);
    my @values = FieldDay::Value->load({
        key => $app->param('sort_field'),
        object_type => $ot->{object_type},
        object_id => \@ids,
    });
    my %values = map { $_->object_id => lc($_->value || $_->value_text || '') } @values;
    my $max;
    if ($limit) {
        $max = $limit + $offset - 1;
    }
    if (!$max || ($max > $#results)) {
        $max = $#results;
    }
    if ($app->param('SearchResultDisplay') && ($app->param('SearchResultDisplay') eq 'descend')) {
        if ($app->param('sort_numeric')) {
            @results = sort { ($values{$a->id} || 0) <=> ($values{$b->id} || 0) } @results;
        } else {
            @results = sort { ($values{$b->id} || '') cmp ($values{$a->id} || '') } @results;
        }
    } else {
        if ($app->param('sort_numeric')) {
            @results = sort { ($values{$a->id} || 0) <=> ($values{$b->id} || 0) } @results;
        } else {
            @results = sort { ($values{$a->id} || '') cmp ($values{$b->id} || '') } @results;
        }
    }
    @results = @results[$offset .. $max];
    my $iter = sub { shift @results; };
    ( $count, $iter );
}

sub process_link {
    my $app = shift;

    if (!$app->param('search')) {
        $app->{search_string} = '%';
        $app->param('search', '%');
    }
    my @arguments = $app->search_terms();
    return $app->error($app->errstr) if $app->errstr;
    my $count = 0;
    my $iter;
    if ( @arguments ) {
        ( $count, $iter ) = $app->execute( @arguments );
        return $app->error($app->errstr) unless $iter;

        $app->run_callbacks( 'search_post_execute', $app, \$count, \$iter );
    }
    my @ids;
    while (my $obj = $iter->()) {
        push(@ids, $obj->id);
    }
    $app->param('IncludeBlogs', $app->param(ucfirst($app->mode) . 'Blogs'));
    my $blog_list = $app->create_blog_list;
    $app->{searchparam}{IncludeBlogs} = $blog_list->{IncludeBlogs};
    for my $key (qw( searchTerms search category category_basename author fields )) {
        $app->param($key, '');
    }
    for my $key ($app->param) {
        if ($key =~ /^link(ed|ing)_/) {
            my $val = $app->param($key);
            $key =~ s/^link(ed|ing)_//;
            $app->param($key, $val);
        }
    }
    if (@ids) {
        $app->param($app->mode . '_ids', join(',', @ids));
        $app->{search_string} = $app->param('search') || '%';
    } else {
        # if no linked/linking objects were found, we want the next search to find nothing
        $app->{search_string} = 'mnfn87n4uinbv8hkmsdboiuhne4v8jnvrimn0s8rjvopmfv89jsrgj';
    }
    $app->param('search', $app->{search_string});
    $app->SUPER::generate_cache_keys();
    return $app->process();
}

sub def_terms {
    my $app = shift;
    my $params = $app->registry( $app->mode, 'types', $app->{searchparam}{Type} );
    my %def_terms = exists( $params->{terms} )
          ? %{ $params->{terms} }
          : ();
    #FIXME: why is this in here?
    delete $def_terms{'plugin'};

    if ( exists $app->{searchparam}{IncludeBlogs} ) {
        $def_terms{blog_id} = [ keys %{ $app->{searchparam}{IncludeBlogs} } ];
    }
    my @terms;
    if (%def_terms) {
        # If we have a term for the model's class column, add it separately, so
        # array search() doesn't add the default class column term.
        my $type = $app->{searchparam}{Type};
        my $model_class = MT->model($type);
        if (my $class_col = $model_class->properties->{class_column}) {
            if ($def_terms{$class_col}) {
                push @terms, { $class_col => delete $def_terms{$class_col} };
            }
        }
        push @terms, \%def_terms;
    }
    return \@terms;
}

sub id_col {
    my ($ot) = @_;
    return ($ot->{'object_datasource'} || $ot->{'object_mt_type'} || $ot->{'object_type'}) . '_id'
}

sub _join_category_basename {
    my ( $app, $term ) = @_;

    # search for exact match
    my $terms = [[ { basename => $term->{term} } ]];
    return unless $terms && @$terms;
    push @$terms, '-and', {
        id => \'= placement_category_id',
        blog_id => \'= entry_blog_id',
    };
    require MT::Placement;
    require MT::Category;
    return MT::Placement->join_on( undef,
        { entry_id => \'= entry_id', blog_id => \'= entry_blog_id' },
        { join => MT::Category->join_on( undef, $terms, {} ),
          unique => 1 }
    );
}

sub _join_linked_ids {
    my ($app, $term) = @_;
    return unless $term->{term};
    return unless $app->param('LinkField');
    my @ids = split(/,/, $term->{term});
    my $type = $app->param('LinkedType') || $app->{searchparam}{Type};
    my $ot = FieldDay::YAML->object_type(use_type($type));
    my $id_col = id_col($ot);
    require FieldDay::Value;
    return FieldDay::Value->join_on(
        undef,
        {
            'value'        => \"= $id_col", #"
            'key' => $app->param('LinkField'),
            'object_type' => $ot->{'object_mt_type'} || $ot->{'object_type'},
            'object_id' => \@ids,
        },
        {
            'unique' => 1,
        }
    );
}

sub _join_linking_ids {
    my ($app, $term) = @_;
    return unless $term->{term};
    return unless $app->param('LinkField');
    my @ids = split(/,/, $term->{term});
    my $type = $app->param('LinkingType') || $app->{searchparam}{Type};
    my $ot = FieldDay::YAML->object_type(use_type($type));
    my $id_col = id_col($ot);
    require FieldDay::Value;
    return FieldDay::Value->join_on(
        undef,
        {
            'object_id' => \"= $id_col", #"
            'value'        => \@ids,
            'key' => $app->param('LinkField'),
            'object_type' => $ot->{'object_mt_type'} || $ot->{'object_type'},
        },
        {
            'unique' => 1,
        }
    );
}

1;
