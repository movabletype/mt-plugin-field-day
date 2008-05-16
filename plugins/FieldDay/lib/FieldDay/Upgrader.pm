
package FieldDay::Upgrader;
use strict;
use Data::Dumper;

my $plugin_key = 'rightfields';
my @standard_elems = qw( label type rows width length choices weblog 
	upload_path url_path overwrite date_order date_y_start date_y_end
	date_show_hms date_time	date_minutes date_ampm
	filenames category_ids show_buttons text_filters );

	# types that we can't just ucfirst
my %type_map = (
	'entry' => 'LinkedEntry',
	'radio' => 'RadioButtons',
	'menu' => 'SelectMenu',
	'textarea' => 'TextArea',
);

my %option_map = (
	'checkbox' => {
	},
	'date' => {
		'date_order' => 'date_order',
		'date_time' => 'time',
		'date_minutes' => 'minutes',
		'date_show_hms' => 'show_hms',
		'date_ampm' => 'ampm',
		'date_y_start' => 'y_start',
		'date_y_end' => 'y_end',
	},
	'file' => {
		'upload_path' => 'upload_path',
		'url_path' => 'url_path',
		'overwrite' => 'overwrite',
		'filenames' => 'filenames',
	},
	'entry' => {
		'weblog' => 'linked_blog_id',
		'category_ids' => 'category_ids',
	},
	'radio' => {
		'choices' => 'choices',
	},
	'menu' => {
		'choices' => 'choices',
	},
	'text' => {
		'width' => 'width',
		'length' => 'length',
	},
	'textarea' => {
		'rows' => 'height',
		'width' => 'width',
	},
);

sub do_upgrade {
	my $upg = shift;
	require MT::Blog;
	require FieldDay::Setting;
		# first get default settings
	my $cfg_key = config_key(-1, 'extra');
	my $default_cfg = load_plugindata($cfg_key);
	my $saved_defaults = 0;
	my $iter = MT::Blog->load_iter;
	my $debug;
	while (my $blog = $iter->()) {
		my $cfg_key = config_key($blog->id, 'extra');
		my $cfg = load_plugindata($cfg_key);
		my $is_default = 0;
		if (!$cfg && $default_cfg && !$saved_defaults) {
				# assign defaults to this blog
			$cfg = $default_cfg;
			$is_default = 1;
			my $setting = FieldDay::Setting->set_by_key({
				'object_type' => 'entry',
				'type' => 'default',
			}, {
				'blog_id' => $blog->id,
				'name' => 'default'
			});
			$saved_defaults = 1;
		}
		if ($cfg) {
			if ($default_cfg && !$is_default) {
				my $setting = FieldDay::Setting->set_by_key({
					'object_type' => 'entry',
					'type' => 'override',
				}, {
					'blog_id' => $blog->id,
					'name' => 'override'
				});
			}
			for my $field (keys %{$cfg->{'cols'}}) {
				my $col = $cfg->{'cols'}->{$field};
				my $rf_type = $col->{'type'};
				my $fd_type = $type_map{$rf_type} || ucfirst($rf_type);
				my $options = {};
				for my $option (keys %{$option_map{$rf_type}}) {
					if (($rf_type eq 'textarea') && ($option eq 'rows')) {
							# convert from rows to pixels
						$col->{$option} *= 18;
					}
					$options->{$option_map{$rf_type}{$option}} = $col->{$option};
				}
				my $data = {
					'label' => $col->{'label'},
					'type' => $fd_type,
					'options' => $options,
				};
				my $terms = {
					'type' => 'field',
					'blog_id' => $blog->id,
					'object_type' => 'entry',
					'name' => $field,
				};
				my $setting = FieldDay::Setting->get_by_key($terms);
				$setting->order($col->{'sort'});
				$setting->data($data);
				$setting->save || die $setting->errstr;
			}
		}
		if ($cfg || $default_cfg) {
			$cfg ||= $default_cfg;
			require MT::Entry;
			require FieldDay::Value;
			my $iter = MT::Entry->load_iter({ 'blog_id' => $blog->id });
			while (my $entry = $iter->()) {
				my $rf = load_obj($cfg, $entry->id);
				next unless $rf;
				$debug .= Dumper($rf);
				for my $field (keys %{$cfg->{'cols'}}) {
					next unless $rf->$field;
					my $terms = {
						'object_type' => 'entry',
						'blog_id' => $blog->id,
						'object_id' => $entry->id,
						'key' => $field,
						'instance' => 1,
					};
					my $value = FieldDay::Value->get_by_key($terms);
					$value->set_value($rf->$field);
					$value->save || die $value->errstr;
				}
			}
		}
	}
}

sub config_key {
	my ($blog_id, $type) = @_;
	if ($blog_id == -1) {
		return "default_$type";
	} else {
		return "blog_${blog_id}_cfg_$type";
	}
}

sub load_plugindata {
	my ($key) = @_;
	require MT::PluginData;
	my $data = MT::PluginData->load({
		plugin => $plugin_key, key => $key
	});
	return 0 unless $data;
	return $data->data;
}

sub load_obj {
	my ($blog_config, $entry_id) = @_;
	my $obj;
	my $class = ($blog_config->{'datasource'} eq '_pseudo')
		? 'RightFieldsPseudo' : 'RightFieldsObject';
	{
	# need to clear previously installed props
	no strict 'refs';
	*{"${class}::__properties"} = sub { {} };
	}
	$class->set_properties(obj_properties($blog_config));
	if ($entry_id) {
		$obj = $class->load(
			($class eq 'RightFieldsPseudo') ? { 'key' => $entry_id } : $entry_id
		);
	}
	return $obj;
}

sub obj_properties {
	my ($blog_config) = @_;
	my @e_id = ($blog_config->{'datasource'} eq '_pseudo') ? ('entry_id' => 'integer') : ();
	return {
		'column_defs' => { 'id' => 'integer', @e_id, map { $_ => 'text' } keys %{$blog_config->{'cols'}} },
		'datasource', $blog_config->{'datasource'},
		'primary_key', 'id'
	};
}


# RightFieldsObject class:
# simply extends MT::Object, allowing data access through MT's object model

package RightFieldsObject;
use strict;
use MT::Object;
@RightFieldsObject::ISA = qw( MT::Object );
{
	local $SIG{__WARN__} = sub {  }; 
	__PACKAGE__->install_properties({});
}

sub set_properties {
	my $class = shift;
	my ($properties) = @_;
	$properties->{'audit'} = 0;
	__PACKAGE__->install_properties($properties);
}

	# need to override this to get rid of the "unknown column" check
	# introduced in MT 3.3
use vars qw( $AUTOLOAD );
sub AUTOLOAD {
    my $obj = $_[0];
    (my $col = $AUTOLOAD) =~ s!.+::!!;
    no strict 'refs';
    *$AUTOLOAD = sub {
        shift()->column($col, @_);
    };
    goto &$AUTOLOAD;
}

package RightFieldsPseudo;
use strict;
@RightFieldsPseudo::ISA = qw( MT::Object::Pseudo );
{
	local $SIG{__WARN__} = sub {  }; 
	__PACKAGE__->install_properties({});
}

sub set_properties {
	my $class = shift;
	my ($properties) = @_;
	$properties->{'audit'} = 0;
	__PACKAGE__->install_properties($properties);
}

sub key {
	my $obj = shift;
	return $obj->entry_id;
}

sub blog_id {
# to prevent callbacks from dying in MT::App::cb_mark_blog()
	return 0;
}

# Copyright 2004-2005 Appnel Internet Solutions LLC, Timothy
# Appnel, tim@appnel.com. This code cannot be redistributed
# without permission of the author.

package MT::Object::Pseudo;
use strict;

use vars qw($VERSION);
$VERSION = '0.03';

use MT::PluginData;
use MT::ErrorHandler;
@MT::Object::Pseudo::ISA = qw( MT::ErrorHandler );

# This class would be a MT::PluginData subclass candidate however
# the embedded callback routines inherited through MT::Object would
# execute with each call to the superclass using the subclass as the
# classname -- not when we need it to run. This abstract class acts as
# a controller for MT::PluginData records. MT::PluginData callbacks are
# still fired in addition to subclass callbacks that we manage.

#--- callbacks

sub add_callback {
    my $class = shift;
    my ($meth, $priority, $plugin, $code) = @_;
    return $class->error(  "4th argument to add_callback must be "
                         . "an object of type MT::Callback")
      if (ref($code) ne 'CODE');
    MT->add_callback("$class::$meth", $priority, $plugin, $code);
    1;
}

sub run_callbacks {
    my $class = shift;
    $class = ref($class) if ref($class);
    my $meth = shift;
    $meth = $class . '::' . $meth;
    unshift @_, $meth;
    MT->run_callbacks(@_);
}

#--- properties

sub install_properties {
    my $class = shift;
    no strict 'refs';
    ${"${class}::__properties"} = shift;
}

sub properties {
    my $this = shift;
    my $class = ref($this) || $this;
    no strict 'refs';
    ${"${class}::__properties"};
}

#--- generic construction and initialization

sub new {
    my $class = shift;
    my $obj = bless {}, $class;
    $obj->init(@_);
}

sub init {
    my $obj  = shift;
    my %args = @_;
    $obj->{'column_values'} = {};
    $obj;
}

sub install_columns {    # deprecated method. use install_properties.
    my $class = shift;
    no strict 'refs';
    @{"${class}::__columns"} = @_;
}

sub column_values { $_[0]->{'column_values'} }

sub column_names {
    my $this = shift;
    my $props = $this->properties || {};
    my @cols;
    if ($props->{columns}) {
        @cols = @{$props->{columns}};
    } else {    #deprecated use handler
        my $class = ref($this) || $this;
        no strict 'refs';
        @cols = @{"${class}::__columns"};
    }
    push @cols, 'id';
    push @cols, qw( created_on created_by modified_on modified_by )
      if (!$props || $props->{audit});    #deprecated use handler
    @cols;
}

sub column {
    my $obj = shift;
    my ($col, $value) = @_;
    return unless defined $col;
    $obj->{'column_values'}->{$col} = $value if (defined $value);
    $obj->{'column_values'}->{$col};
}

sub set_values {
    my $obj      = shift;
    my ($values) = @_;
    my @cols     = $obj->column_names;
    for my $col (@cols) {
        next unless exists $values->{$col};
        $obj->column($col, $values->{$col});
    }
}

sub clone {
    my $obj   = shift;
    my $clone = ref($obj)->new();
    $clone->set_values($obj->column_values);
    $clone;
}

#--- Pseudo MT::Object-like interface methods.

# We attempt to emulate the MT::Object interface, but some limitations
# apply. join along with the unique flag are not implemented. slower.
# All fields are treated as indexed. count_by_group functions as not
# implemented.

sub load {
    my ($class, $t, $args) = @_;
    $class->run_callbacks('pre_load', \@_);
    return $class->load_by_id($t) if (!ref($t) || $t->{id});
    return $class->load_by_key($t) if ($t->{key});
    my @objs =
      map { $class->unserialize($_) }
      MT::PluginData->load({plugin => $class})
      ;    # if t is empty but not args, pass args. and skip filter
    $class->filter(\@objs, @_);
    if (wantarray) {
        foreach my $o (@objs) {
            $class->run_callbacks('post_load', \@_, $o);
        }
        @objs;
    } else {
        my $o = $objs[0];
        $class->run_callbacks('post_load', \@_, $o);
        $o;
    }
}

sub load_iter {
    my ($class, $t, $args) = @_;
    $class->run_callbacks('pre_load', \@_);
    my @objs =
      map { $class->unserialize($_) }
      MT::PluginData->load({plugin => $class});    # same as load here.
    $class->filter(\@objs, @_);
    my @ids = map { $_->id } @objs;
    my $i = 0;
    sub {
        return if ($i > $#ids);
        my $pdo = MT::PluginData->load($ids[$i++]) or return;
        my $o = $class->unserialize($pdo);
        $class->run_callbacks('post_load', \@_, $o);
        $o;
      }
}

sub count {    # needs work. utilize other loads
    my ($class, $t, $args) = @_;

    #return ($class->load_by_id($t)?1:0) if (!ref($t) || $t->{id});
    #return ($class->load_by_key($t)?1:0) if ($t->{key});
    my @objs =
      map { $class->unserialize($_) } MT::PluginData->load({plugin => $class});
    $class->filter(\@objs, @_);
    scalar @objs;
}

sub exists {
    my $self = shift;
    return unless $self->id;
    my $class = ref($self);
    my $t     = {};
    $t->{id}     = $self->id;
    $t->{plugin} = $class;
    MT::PluginData->load($t) ? 1 : 0;
}

sub save {
    my $self = shift;

    # TBD: do we need to clone here????
    $self->run_callbacks('pre_save', $self);
    if (!$self->properties || $self->properties->{audit})
    {    # deprecated behavior handler
          # Since PluginData does not have system auditing turned on we
          # spoof it here. We use GMT as the timezone because timezone is
          # determined on a per blog basis and our data is not blog specific.
          # (Which is why PluginData doesn't have system auditing enabled in the
          # first place.)
        my @ts = gmtime;
        my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $ts[5] + 1900, $ts[4] + 1,
          @ts[3, 2, 1, 0];
        $self->column('modified_on', $ts);
        $self->column('created_on',  $ts)
          unless $self->column('created_on');
    }
    my $pdo = $self->serialize();
    $pdo->save()
      or return $self->error($pdo->errstr);
    $self->column('id', $pdo->id);
    $self->run_callbacks('post_save', $self);
    1;
}

sub remove {
    my $self = shift;
    $self->run_callbacks('pre_remove', $self);
    my $o = MT::PluginData->load($self->column('id'));
    $o ? $o->remove : return;
    $self->run_callbacks('post_remove', $self);
    1;
}

sub remove_all {
    my $class = shift;
    $class->run_callbacks('pre_remove_all', $class);
    map { $_->remove } MT::PluginData->load({plugin => $class});
    $class->run_callbacks('post_remove_all', $class);
    1;
}

# Because of the unique nature of how a Pseudo object persists their
# data through the MT::PluginData class we add these methods to the
# interface for...

# ...a generating and accessing a primary key (to be overridden by
# each subclass) and...
sub key {
    die "The key function must be overridden " . "and return a unique string";
}

# ...and some added efficiency with simple loads.
sub load_by_id {
    my ($class, $t) = @_;
    $t = {id => $t} unless ref($t);
    $t->{plugin} = $class;
    my $o = $class->unserialize(MT::PluginData->load($t));
    $class->run_callbacks('post_load', \@_, $o);
    $o;
}

sub load_by_key {
    my $class = shift;
    my $key   = $_[0]->{key};
    my $t     = {plugin => $class, key => $key};
    my $o     = $class->unserialize(MT::PluginData->load($t));
    $class->run_callbacks('post_load', \@_, $o);
    $o;
}

# Access to the PluginData object that is persisted.
sub pdo { MT::PluginData->load($_[0]->column('id')) }

#--- explicit column accessors.

# For developers, these are the preferred means of working with the
# objects data as opposed to the generic means such as the column,
# column_values or set_values methods.

# ID should always be treated as a get only accessor;
sub id { $_[0]->column('id') }

sub DESTROY { }

use vars qw( $AUTOLOAD );

sub AUTOLOAD {
    my $obj = $_[0];
    (my $col = $AUTOLOAD) =~ s!.+::!!;
    my $class = ref($obj);
    die "$col is not a method of $class"
      unless grep $col eq $_, $class->column_names;
    {
        no strict 'refs';
        *$AUTOLOAD = sub { shift()->column($col, @_) };
    }
    goto &$AUTOLOAD;
}

#--- utilities

sub unserialize {
    my ($class, $pdo) = @_;
    return undef unless $pdo;
    my $o = $class->new;
    $o->set_values($pdo->data);
    $o->column('id', $pdo->id);

    #$o->{__pdo_key} = $pdo->key;
    $o;
}

sub serialize {
    my $self = shift;
    my $pdo;
    if ($self->id) {
        $pdo = MT::PluginData->load($self->id);
    } else {
        $pdo = MT::PluginData->new;
        $pdo->plugin(ref($self));
    }
    my $data = $self->column_values;
    delete $data->{id} if exists $data->{id};
    $pdo->data($data);
    $pdo->key($self->key);
    $pdo;
}

# Loosely emulates the selection functions of MT::Object::load
# albeit not as feature complete or as efficient.
sub filter {
    my ($caller, $o, $class, $t, $args) = @_;
    $t    ||= {};
    $args ||= {};
    my @objs = @$o;    # clone it.
    foreach my $term (keys %$t) {
        if (ref($t->{$term}) eq 'ARRAY') {
            if ($args->{range} && $args->{range}{$term}) {
                my ($start, $end) = @{$t->{$term}};
                @objs = grep { $_->$term >= $start && $_->$term <= $end } @objs;
            }
        } else {
            @objs = grep { $_->$term && $_->$term eq $t->{$term} } @objs;
        }
    }
    if ($args->{sort}) {
        my $sort = $args->{sort};
        my $dir = $args->{direction} || 'ascend';
        if (exists($args->{start_val})) {
            @objs =
              $dir eq 'ascend'
              ? grep { $_->$sort ge $args->{start_val} } @objs
              : grep { $_->$sort le $args->{start_val} } @objs;
        }
        @objs =
          $dir eq 'ascend'
          ? sort { $a->$sort cmp $b->$sort } @objs
          : sort { $b->$sort cmp $a->$sort } @objs;
    }
    if ($args->{offset} || $args->{limit}) {
        my $o = $args->{offset} || 0;
        my $c = scalar @objs;
        my $l = $args->{limit} || $c;
        $l = $c - 1 if ($o + $l > $c);
        $l-- unless $o;
        @objs = @objs[$o .. $l];
    }
    @{$o} = @objs;
}

1;

__END__

=cut

=head1 NAME

MT::Object::Pseudo - a module that is to be used as a base class for
creating MT::Object-like classes using the MT::PluginData
data store instead of a class-specific database table.


=head1 DESCRIPTION

MT::Object::Pseudo is a module that is to be used as a base class for
creating MT::Object-like classes using the C<MT::PluginData>
data store instead of a class-specific database table. This provides a more 
flexible means of data storage and eases the issue of creating data tables 
at installation and maintaining them over time.

This mechanism is for use with small datasets in which
simple queries qil be performed. This is not meant to be a
complete replacement for MT::Object-based classes.

The programmers interface works almost entirely as the C<MT::Object> found 
in version MT 3.1 except for a few exceptions.

=over

=item Performance is not as good as a direct MT::Object
descendant. (Performance was not a focus of this module
flexibility was.)

=item C<id> is a read-only.

=item IDs are not issued in sequentially per class. Instead
the ID of the underlying C<MT::PluginData> object is used.

=item Includes a C<pdo> accessor for access to the
underlying C<MT::PluginData> object that the pseudo object is persisted with.

=item Because of the unique nature of how a pseudo object
persists their data through the C<MT::PluginData> class, a
C<MT::Object::Pseudo> subclass is required to implement a key
method which should generate a unique identifier for the
object.

=item The load method does not recognize C<join> along with the
C<unique> flag.

=item All fields are treated as indexed.

=item The C<count_by_group> function as not implemented.

=back

=head1 TO DO

=over 

=item Implement C<count_by_group> method.

=item Clean-up count method.

=item Better documentation.

=item  

=head1 LICENSE

This code cannot be redistributed without permission of the
author.

=head1 AUTHOR & COPYRIGHT

Except where otherwise noted, MT::Object::Pseudo is
copyright 2004-2005 Appnel Internet Solutions LLC, Timothy
Appnel, tim@appnel.com.

=cut

1;
