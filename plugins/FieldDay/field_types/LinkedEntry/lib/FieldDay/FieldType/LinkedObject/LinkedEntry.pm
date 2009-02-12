
package FieldDay::FieldType::LinkedObject::LinkedEntry;
use strict;
use Data::Dumper;

use base qw( FieldDay::FieldType::LinkedObject );
use FieldDay::Util qw( app_setting_terms load_fields require_type mtlog );

sub tags {
	return {
		'per_type' => {
			'block' => {
				'LinkedEntries' => sub { __PACKAGE__->hdlr_LinkedObjects('entry', @_) },
				'IfLinkedEntries?' => sub { __PACKAGE__->hdlr_LinkedObjects('entry', @_) },
				'LinkingEntries' => sub { __PACKAGE__->hdlr_LinkingObjects('entry', @_) },
				'IfLinkingEntries?' => sub { __PACKAGE__->hdlr_LinkingObjects('entry', @_) },
			},
		},
	};
}

sub options {
	my $class = shift;
	return {
		'linked_blog_id' => undef,
		'category_ids' => undef,
		'subcats' => undef,
		'lastn' => undef,
		'search' => undef,
		'published' => 1,
		%{$class->SUPER::options()}
	};
}

sub label {
	return 'Linked Entry';
}

sub object_type {
	return 'entry';
}

sub load_objects {
	my $class = shift;
	my ($param, %terms) = @_;
	require MT::Entry;
	my $terms = { %terms };
	$terms->{'class'} ||= 'entry';
	if ($param->{'linked_blog_id'}) {
		$terms->{'blog_id'} = $param->{'linked_blog_id'};
	}
	if ($param->{'published'}) {
		$terms->{'status'} = MT::Entry::RELEASE();
	}
	my $args = {};
	if ($param->{'lastn'}) {
		$args = {
			'sort' => 'authored_on',
			'direction' => 'descend',
			'limit' => $param->{'lastn'},
		};
	} else {
		$args = {
			'sort' => 'title',
			'direction' => 'ascend',
		};
	}
	if ($param->{'category_ids'}) {
		my %cat_ids = map { $_ => 1 } split(/,/, $param->{'category_ids'});
		if ($param->{'subcats'}) {
			require MT::Category;
			for my $cat_id (keys %cat_ids) {
				my $cat = MT::Category->load($cat_id);
				for my $subcat ($cat->_flattened_category_hierarchy) {
					next unless ref $subcat;
					$cat_ids{$subcat->id} = 1;
				}
			}
		}
		require MT::Placement;
		$args->{'join'} =  MT::Placement->join_on(
				'entry_id',
				{ category_id => [ keys %cat_ids ],
				},
				{ unique => 1 }
			);
	}
	return MT::Entry->load($terms, $args)
}

sub object_label {
	my $class = shift;
	my ($obj) = @_;
	return '' unless $obj;
	require MT::Util;
	require MT::Blog;
	return $obj->title ? MT::Util::remove_html($obj->title) : '[untitled]';
}

sub core_fields {
	my $class = shift;
	my ($blog_id) = @_;
	return {
		'title' => {
			'type' => 'Text',
			'label' => 'Title',
		},
		'text' => {
			'type' => 'TextArea',
			'label' => 'Body',
			'options' => {
				'label_display' => 'above',
			},
		},
		'text_more' => {
			'type' => 'TextArea',
			'label' => 'Extended',
			'options' => {
				'label_display' => 'above',
			},
		},
		'status' => {
			'type' => 'RadioButtons',
			'label' => 'Status',
			'options' => {
				'label_display' => 'hide',
				'choices' => "1=Unpublished\n2=Published",
			},
		},
		'category' => {
			'type' => 'SelectMenu',
			'label' => 'Category',
			'options' => {
				'choices' => $class->cat_choices($blog_id),
			},
		},
	};
}

sub cat_choices {
	my $class = shift;
	my ($blog_id) = @_;
	my %terms;
	$terms{blog_id} = $blog_id if $blog_id;
	my @cats = MT->model('category')->load(\%terms);
	return join("\n", map { $_->id . '=' . $_->label } @cats);
}

sub save_object {
	my $class = shift;
	my ($setting, $app) = @_;
	(my $blog_id = $app->param('blog_id'))
		|| return $app->json_error('No blog_id');
	my $core_fields = $class->core_fields;
	my $data = $setting->data;
	require MT::Entry;
	require FieldDay::Value;
	if ($data->{'options'}->{'required_fields'}) {
		for my $req (split(/,/, $data->{'options'}->{'required_fields'})) {
			$req =~ s/ +//g;
			next unless $req;
			if (!$app->param($req)) {
				return $app->json_error("$req is required");
			}
		}
	}
	if ($data->{'options'}->{'unique_fields'}) {
		my $found_entry;
		for my $unique (split(/,/, $data->{'options'}->{'unique_fields'})) {
			$unique =~ s/ +//g;
			# unique fields are not necessarily required
			next unless $app->param($unique);
			if ($core_fields->{$unique}) {
				$found_entry = MT::Entry->load(
					{
						blog_id => $blog_id,
						$unique => $app->param($unique)
					}
				);
				last if $found_entry;
			} else {
				$found_entry = MT::Entry->load(
					{
						blog_id => $blog_id
					},
					{
						join => FieldDay::Value->join_on(
							undef,
							{
								object_id => \'= entry_id', #'
								blog_id => $blog_id,
								object_type => 'entry',
								key => $unique,
								value => $app->param($unique),
							},
						),
					}
				);
				last if $found_entry;
			}
		}
		if ($found_entry) {
			return $app->json_result({
				code => 'found',
				id => $found_entry->id,
				label => $found_entry->title,
				msg => 'Entry already exists; using existing entry.',
			});
		}
	}
	my $entry = MT::Entry->new;
	$entry->author_id($app->user->id);
	$entry->status(2);
	$entry->blog_id($blog_id);
	# have to save now so we have an ID
	$entry->save || return $app->json_error($entry->errstr);
	for my $field (split(/,/, $data->{'options'}->{'create_fields'})) {
		if ($core_fields->{$field}) {
			if ($field eq 'category') {
				require MT::Placement;
				my $place = MT::Placement->new;
				$place->entry_id($entry->id);
				$place->blog_id($entry->blog_id);
				$place->category_id($app->param($field));
				$place->is_primary(1);
				$place->save || die $place->errstr;
			} else {
				$entry->$field($app->param($field));
			}
		} else {
			save_field_for_entry($entry, $field, $app->param($field));
		}
	}
	$entry->save || return $app->json_error($entry->errstr);
	return $app->json_result({
		code => 'added',
		id => $entry->id,
		label => $entry->title,
		blog_id => $entry->blog_id,
	});
}

sub save_linked_object {
	my $class = shift;
	my ($app, $i_name, $obj, $options) = @_;
	my $core_fields = $class->core_fields;
	require MT::Entry;
	require FieldDay::Setting;
	my $save = 0;
	my %ef_values = ();
	# create an entry, but we won't necessarily save it
	# unless and until we have at least one field value
	my $entry = MT::Entry->new;
	$entry->author_id($app->user->id);
	$entry->status(1);
	$entry->blog_id($options->{'linked_blog_id'});
	for my $field (split(/,/, $options->{'create_fields'})) {
		my $param_key = $i_name . '-' . $field;
		if ($core_fields->{$field}) {
			if ($app->param($param_key)) {
				if ($field eq 'category') {
					if (!$entry->id) {
						$entry->save || die $entry->errstr;
					}
					require MT::Placement;
					my $place = MT::Placement->new;
					$place->entry_id($entry->id);
					$place->blog_id($entry->blog_id);
					$place->category_id($app->param($param_key));
					$place->is_primary(1);
					$place->save || die $place->errstr;
				} else {
					$entry->$field($app->param($param_key));
				}
				$save = 1;
			}
		} else {
			my $setting = FieldDay::Setting->load({
				object_type => 'entry',
				blog_id => $options->{'linked_blog_id'},
				name => $field,
			});
			my $data = $setting->data;
			my $class = require_type($app, 'field', $data->{'type'});
			my $value = $class->pre_save_value($app, $param_key, $entry, $data->{'options'});
			if ($value) {
				$save = 1;
				$ef_values{$field} = $value;
			}
		}
	}
	if ($save) {
		$entry->save || die $entry->errstr;
		for my $field (keys %ef_values) {
			save_field_for_entry($entry, $field, $ef_values{$field});
		}
		return $entry->id;
	}
	return undef;
}

sub save_field_for_entry {
	my ($entry, $key, $value) = @_;
	require FieldDay::Value;
	my $val_obj = FieldDay::Value->set_by_key(
		{
			object_id => $entry->id,
			object_type => 'entry',
			key => $key,
		},
		{
			blog_id => $entry->blog_id,
			value => $value,
		}
	);
	$val_obj->save || die $val_obj->errstr;
}

sub field_value_for_entry {
	my ($entry, $key, $data) = @_;
	my $id = (ref $entry) ? $entry->id : $entry;
	require FieldDay::Value;
	my $val_obj = FieldDay::Value->load(
		{
			object_id => $id,
			object_type => 'entry',
			key => $key,
		},
	);
	return '' unless $val_obj;
	if ($data->{'type'} =~ /^Linked/) {
		my $linked_class = require_type(MT->instance, 'field', $data->{'type'});
		my $obj = MT->model($linked_class->object_type)->load($val_obj->value);
		return $obj ? $linked_class->object_label($obj) : '';
	}
	return $val_obj->value;
}

sub do_query {
	my $class = shift;
	my ($setting, $q) = @_;
	my %terms = (
		title => { like => '%' . $q->param('query') . '%' },
	);
	my $data = $setting->data;
	my $options = $setting->data->{'options'};
	$options->{'type'} = $data->{'type'};
	my @entries = $class->load_objects($options, %terms);
	return join("\n", map { $class->map_entry($_, $options) } @entries);
}

sub map_entry {
	my $class = shift;
	my ($entry, $options) = @_;
	my @values = ($entry->title, $entry->id, $entry->blog_id);
	push(@values, $class->autocomplete_values($entry, $options));
	return join("\t", @values);
}

sub autocomplete_values {
	my $class = shift;
	my ($entry, $options) = @_;
	my @values;
	if ($options->{'autocomplete_fields'}) {
		require FieldDay::Setting;
		my %settings = map { $_->name => $_ }
			FieldDay::Setting->load({
				blog_id => $entry->blog_id,
				object_type => 'entry',
				type => 'field',
			});
		my $core_fields = $class->core_fields;
		for my $field (split(/,/, $options->{'autocomplete_fields'})) {
			if ($core_fields->{$field}) {
				push(@values, $entry->$field);
			} else {
				my $data = $settings{$field} ? $settings{$field}->data : {};
				push(@values, field_value_for_entry($entry, $field, $data));
			}
		}
	}
	return @values;
}

1;
