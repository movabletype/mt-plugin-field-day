
package FieldDay::App;
use strict;
use Data::Dumper;
use FieldDay::YAML qw( types object_type field_type );
use FieldDay::Util qw( app_setting_terms require_type mtlog use_type );

sub plugin {
    return MT->component('FieldDay');
}

sub save_linked_obj {
	my $class = shift;
	my ($plugin, $app) = @_;
	require FieldDay::Setting;
	require FieldDay::Util;
	(my $setting_id = $app->param('setting_id')) || return $app->json_error('No setting ID');
	(my $setting = FieldDay::Setting->load($setting_id)) || return $app->json_error('Setting not found');
	my $type = $setting->data->{'type'};
	my $ft = FieldDay::Util::require_type($app, 'field', $type);
	return $ft->save_object($setting, $app);
}

sub cfg_fields {
	my $class = shift;
	my ($plugin, $app) = @_;
	my $ot = FieldDay::YAML->object_type(use_type($app->param('_type')));
	#if ($ot->{'object_mt_type'}) {
	#	$app->param('setting_object_mt_type', $ot->{'object_mt_type'});
	#}
	require FieldDay::FieldType;
	my $options_tmpls = FieldDay::FieldType::type_tmpls($plugin, $app, 'options');
	require FieldDay::Setting;
	my $hasher = sub {
		my ($obj, $row) = @_;
		$row->{'id'} = $obj->id;
		my $data = $obj->data;
		$row->{'field'} = $obj->name;
		$row->{'sort_order'} = $obj->order;
		for my $key (qw( type label group )) {
			$row->{$key} = $data->{$key};
		}
		$row->{'type'} ||= 'Text';
		my $ft_class = FieldDay::YAML->field_type($row->{'type'})->{'class'};
		$row->{"is_$row->{'type'}"} = 1;
		my $options = $ft_class->options;
		for my $key (keys %$options, 'label_display') {
			$row->{$key} = exists $data->{'options'}->{$key} ? $data->{'options'}->{$key} : $options->{$key};
		}
		$row->{'type_loop'} = field_type_loop($row->{'type'});
		$row->{'group_loop'} = group_loop($app, $data->{'group'});
		$ft_class->pre_edit_options($row);
		$row->{'options_tmpl'} = row_options($options_tmpls, $row);
	};
	$app->mode('fd_cfg_fields');
	return $app->listing({
		'type' => 'fdsetting',
		'template' => $plugin->load_tmpl('list_setting_field.tmpl'),
		'terms' => {
			'object_type' => $ot->{'object_type'}, #$ot->{'object_mt_type'} || $ot->{'object_type'},
			$ot->{'has_blog_id'} ? 
				('blog_id' => ($app->param('blog_id') || 0)) : (),
			'type' => 'field'
		},
		'args' => {
			'sort' => 'order',
			'direction' => 'ascend'
		},
		'code' => $hasher,
		'no_limit' => 1,
		'pre_build' => sub {
			my ($param) = @_;
				# prototype row
			my $row = {
				'type' => 'Text',
				'field' => 'prototype__',
				'is_text' => 1,
				'label' => 'New Field',
				'prototype' => 1,
				'sort_order' => 0,
				%{FieldDay::FieldType::Text->options},
				'type_loop' => field_type_loop('Text'),
				'group_loop' => group_loop($app),
			};
			$row->{'options_tmpl'} = row_options($options_tmpls, $row);
			unshift(@{$param->{'object_loop'}}, $row);
		},
		'params' => {
			'content_nav_loop' => content_nav_loop('fields'),
			'tmpl_loop' => 
				[ map { ( { 
					'type' => $_,
					'tmpl' => row_options($options_tmpls, { 
						'type' => $_,
						'field' => '__FIELDNAME__',
						%{FieldDay::YAML->field_type($_)->{'class'}->options}
					})
				} ) } keys %$options_tmpls ],
			'setting_object_type' => $ot->{'object_type'},
			'setting_object_mt_type' => $ot->{'object_mt_type'},
			'setting_object_type_uc' => ucfirst($ot->{'object_type'}),
			'setting_type_fields' => 1,
			'setting_label' => 'Extra Field',
			'setting_label_pl' => 'Extra Fields',
			'saved' => $app->param('saved') ? 1 : 0,
			default_params($app),
		}
	});
}

sub cfg_groups {
	my $class = shift;
	my ($plugin, $app) = @_;
	my $ot = FieldDay::YAML->object_type($app->param('_type'));
	#if ($ot->{'object_mt_type'}) {
	#	$app->param('setting_object_mt_type', $ot->{'object_mt_type'});
	#}
	require FieldDay::Setting;
	my $options = {
		'label' => '',
		'instances' => 1,
		'initial' => 1,
		'set' => 0,
	};
	my $hasher = sub {
		my ($obj, $row) = @_;
		$row->{'id'} = $obj->id;
		my $data = $obj->data;
		$row->{'group'} = $obj->name;
		$row->{'order'} = $obj->order;
		for my $key (keys %$options) {
			$row->{$key} = exists($data->{$key}) ? $data->{$key} : $options->{$key};
		}
		$row->{'new'} = 0;
		if (MT->component('blogset')) {
			$row->{'set_loop'} = set_loop($app, $data->{'set'});
		}
	};
	$app->mode('fd_cfg_groups');
	return $app->listing({
		'type' => 'fdsetting',
		'template' => $plugin->load_tmpl('list_setting_group.tmpl'),
		'terms' => {
			'object_type' => $ot->{'object_type'}, #$ot->{'object_mt_type'} || $ot->{'object_type'},
			$app->param('blog_id') ? ('blog_id' => $app->param('blog_id')) : (),
			'type' => 'group'
		},
		'args' => {
			'sort' => 'order',
			'direction' => 'ascend'
		},
		'code' => $hasher,
		'no_limit' => 1,
		'pre_build' => sub {
			my ($param) = @_;
				# prototype row
			my $row = {
				'type' => 'Text',
				'group' => 'prototype__',
				'is_text' => 1,
				'prototype' => 1,
				'order' => 0,
				MT->component('blogset') ? ('set_loop' => set_loop($app)) : (),
				%$options,
			};
			unshift(@{$param->{'object_loop'}}, $row);
		},
		'params' => {
			'content_nav_loop' => content_nav_loop('groups'),
			'setting_object_type' => $ot->{'object_type'},
			'setting_object_mt_type' => $ot->{'object_mt_type'},
			'setting_object_type_uc' => ucfirst($ot->{'object_type'}),
			'setting_type_fields' => 1,
			'setting_label' => 'Field Group',
			'setting_label_pl' => 'Field Groups',
			'saved' => $app->param('saved') ? 1 : 0,
			'has_sets' => MT->component('blogset') ? 1 : 0,
			default_params($app),
		}
	});
}

sub save_fields {
	my $class = shift;
	my ($plugin, $app) = @_;
	require FieldDay::Setting;
	my $type_options = type_options($app);
	for my $row_name (split(/,/, $app->param('fd_setting_list'))) {
		next unless $row_name;
		next if ($row_name eq 'prototype__');
		next unless $app->param($row_name . '_name');
		my $data = {};
		my $row_name_type = $app->param($row_name . '_type');
		if (!$app->param($row_name . '_label')) {
			$app->param($row_name . '_label', $app->param($row_name . '_name'));
		}
		for my $key (qw( type label group )) {
			$data->{$key} = $app->param($row_name . '_' . $key);
		}
		$data->{'options'} = {};
		for my $option (keys %{$type_options->{$row_name_type}}, 'label_display') {
			$data->{'options'}->{$option} = $app->param($row_name . "_$option");
		}
		FieldDay::YAML->field_type($row_name_type)->{'class'}->pre_save_options($app, $row_name, $data->{'options'});
		populate_setting($app, 'field', $row_name, $data);
	}
	for my $row_name (split(/,/, $app->param('fd_deleted_settings'))) {
		if (my $setting = FieldDay::Setting->load(app_setting_terms($app, 'field', $row_name))) {
			$setting->remove || die $setting->errstr;
		}
	}
	return $app->redirect($app->uri . '?' . $app->param('return_args') . '&saved=1');
}

sub save_groups {
	my $class = shift;
	my ($plugin, $app) = @_;
	require FieldDay::Setting;
	my $options = {
		'label' => '',
		'instances' => 1,
		'initial' => 1,
		'set' => 0,
	};
	for my $row_name (split(/,/, $app->param('fd_setting_list'))) {
		next unless $row_name;
		next if ($row_name eq 'prototype__');
		next unless $app->param($row_name . '_name');
		my $data = {};
		if (!$app->param($row_name . '_label')) {
			$app->param($row_name . '_label', $app->param($row_name . '_name'));
		}
		for my $key (keys %$options) {
			$data->{$key} = $app->param($row_name . '_' . $key);
		}
		populate_setting($app, 'group', $row_name, $data);
	}
	for my $row_name (split(/,/, $app->param('fd_deleted_settings'))) {
		if (my $setting = FieldDay::Setting->load(app_setting_terms($app, 'group', $row_name))) {
			$setting->remove || die $setting->errstr;
		}
	}
	return $app->redirect($app->uri . '?' . $app->param('return_args') . '&saved=1');
}

sub copy_settings {
	my $class = shift;
	my ($plugin, $app) = @_;
	my $blog_id = $app->param('blog_id');
	my $from_blog_id = $app->param('from_blog_id');
	return $app->error('Invalid blog_id') unless ($blog_id =~ /^\d+$/);
	return $app->error('Invalid from_blog_id') unless ($from_blog_id =~ /^\d+$/);
	my $ot = FieldDay::YAML->object_type($app->param('_type'));
	my %terms = (
		blog_id => $blog_id,
		object_type => $ot->{'object_type'},
	);
	require FieldDay::Setting;
	for my $setting (FieldDay::Setting->load(\%terms)) {
		$setting->remove;
	}
	$terms{blog_id} = $from_blog_id;
	$terms{type} = 'group';
	my %group_map;
	for my $orig (FieldDay::Setting->load(\%terms)) {
		my $old_id = $orig->id;
		my $new = $orig->clone;
		$new->id(undef);
		$new->blog_id($blog_id);
		$new->save || die $new->errstr;
		$group_map{$old_id} = $new->id;
	}
	$terms{type} = 'field';
	for my $orig (FieldDay::Setting->load(\%terms)) {
		my $old_id = $orig->id;
		my $new = $orig->clone;
		$new->id(undef);
		$new->blog_id($blog_id);
		my $data = $new->data;
		if ($data->{group}) {
			$data->{group} = $group_map{$data->{group}};
			$new->data($data);
		}
		$new->save || die $new->errstr;
	}
	return $app->redirect($app->uri . '?' . $app->param('return_args'));
}

sub set_default {
	my $class = shift;
	my ($plugin, $app) = @_;
	return $app->error('No blog_id passed') unless $app->param('blog_id');
	require FieldDay::Setting;
	my $ot = FieldDay::YAML->object_type($app->param('_type'));
	my $setting = FieldDay::Setting->set_by_key({
		'object_type' => $ot->{'object_type'},
		'type' => 'default',
	}, {
		'blog_id' => $app->param('blog_id'),
		'name' => 'default'
	});
	return $app->redirect($app->uri . '?' . $app->param('return_args'));
}

sub clear_default {
	my $class = shift;
	my ($plugin, $app) = @_;
	return $app->error('No blog_id passed') unless $app->param('blog_id');
	require FieldDay::Setting;
	my $ot = FieldDay::YAML->object_type($app->param('_type'));
	my $setting = FieldDay::Setting->load({
		'object_type' => $ot->{'object_type'},
		'type' => 'default',
	});
	$setting->remove if $setting;
	return $app->redirect($app->uri . '?' . $app->param('return_args'));
}

sub override_default {
	my $class = shift;
	my ($plugin, $app) = @_;
	return $app->error('No blog_id passed') unless $app->param('blog_id');
	require FieldDay::Setting;
	my $ot = FieldDay::YAML->object_type($app->param('_type'));
	my $setting = FieldDay::Setting->set_by_key({
		'object_type' => $ot->{'object_type'},
		'type' => 'override',
	}, {
		'blog_id' => $app->param('blog_id'),
		'name' => 'override'
	});
	return $app->redirect($app->uri . '?' . $app->param('return_args'));
}

sub use_default {
	my $class = shift;
	my ($plugin, $app) = @_;
	return $app->error('No blog_id passed') unless $app->param('blog_id');
	require FieldDay::Setting;
	my $ot = FieldDay::YAML->object_type($app->param('_type'));
	my $terms = {
		'object_type' => $ot->{'object_type'},
		'blog_id' => $app->param('blog_id'),
	};
	for my $setting (FieldDay::Setting->load($terms)) {
		$setting->remove || die $setting->errstr;
	}
	return $app->redirect($app->uri . '?' . $app->param('return_args'));
}

sub default_params {
	my ($app) = @_;
	return () unless $app->param('blog_id');
	my $d_id = default_blog_id($app);
	return () unless $d_id;
	if ($d_id eq $app->param('blog_id')) {
		return ('is_default' => 1);
	}
	require MT::Blog;
	require FieldDay::Setting;
		# see if there are any blog_specific settings
	my $ot = FieldDay::YAML->object_type($app->param('_type'));
	my $settings = FieldDay::Setting->count({
		'object_type' => $ot->{'object_type'},
		'blog_id' => $app->param('blog_id'),
	});
	my $d_blog = MT::Blog->load($d_id);
	return () unless $d_blog;
	return (
		'default_blog_id' => $d_id,
		'default_blog_name' => $d_blog->name,
		'using_default' => $settings ? 0 : 1,
	);
}

sub default_blog_id {
	my ($app) = @_;
	my $ot = FieldDay::YAML->object_type($app->param('_type'));
	return 0 unless ($app->param('blog_id'));
	my $setting = FieldDay::Setting->load({
		'object_type' => $ot->{'object_type'}, #$ot->{'object_mt_type'} || $ot->{'object_type'},
		'type' => 'default',
	});
	return $setting ? $setting->blog_id : 0;
}

sub populate_setting {
	my ($app, $setting_type, $row_name, $data, $updater) = @_;
	my $setting = FieldDay::Setting->get_by_key(app_setting_terms($app, $setting_type, $row_name));
	$setting->type($setting_type);
	$setting->blog_id($app->param('blog_id'));
	my $ot = FieldDay::YAML->object_type($app->param('setting_object_type'));
	$setting->object_type($ot->{'object_type'}); #$ot->{'object_mt_type'} || $ot->{'object_type'});
	$setting->name($app->param($row_name . '_name'));
	$setting->order($app->param($row_name . '_order'));
	$setting->data($data);
	if ($setting->id && ($row_name ne $app->param($row_name . '_name')) && $updater) {
		$updater->($row_name, $app->param($row_name . '_name')); 
	}
	$setting->save || return $app->error($setting->errstr);
}

sub row_options {
	my ($options_tmpls, $row) = @_;
	require MT::Template;
	my $tmpl = plugin()->load_tmpl('include/field_generic_options.tmpl');
	$tmpl->param($row);
	my $output = $tmpl->output;
	my $tmpl_text = $options_tmpls->{$row->{'type'}};
	FieldDay::YAML->field_type($row->{'type'})->{'class'}->pre_edit_options($row);
	$tmpl = MT::Template->new('type' => 'scalarref', 'source' => \$tmpl_text);
	$tmpl->param($row);
	return $output . $tmpl->output;
}

sub field_type_loop {
	my ($selected) = @_;
	my @loop = ();
	my $types = types('field');
	for my $type (sort keys %$types) {
		next if ($types->{$type}->[0]->{'abstract'});
		my $row = {
			'type' => $type,
			'label' => $types->{$type}->[0]->{'label'},
			'selected' => ($selected eq $type) ? 1 : 0
		};
		push (@loop, $row);
	}
	return \@loop;
}

sub group_loop {
	my ($app, $selected) = @_;
	my @loop = ({ 'label' => 'Select', 'group' => 0 });
	for my $group (FieldDay::Setting->load(app_setting_terms($app, 'group'))) {
		my $data = $group->data;
		push(@loop, {
			'group' => $group->id,
			'label'=> $data->{'label'} || $group->name,
			'selected' => ($selected && ($selected == $group->id)) ? 1 : 0
		});
	}
	return \@loop;
}

sub set_loop {
	my ($app, $selected) = @_;
	my @loop = ({ 'label' => 'Select', 'set' => 0 });
	for my $set (MT->model('blog_set')->load) {
		push(@loop, {
			'set' => $set->id,
			'label'=> $set->name,
			'selected' => ($selected && ($selected == $set->id)) ? 1 : 0
		});
	}
	return \@loop;
}


sub content_nav_loop {
	my ($active) = @_;
	my %actions = (
		'fields' => 'Extra Fields',
		'groups' => 'Groups',
		#'defaults' => 'Default Values',
		#'tags' => 'Template Tags',
		#'listing' => 'Listing Display'
	);
	my @loop = ();
	for my $key (qw( fields groups )) { #defaults tags listing )) {
		push(@loop, {
			'type' => $key,
			'label' => $actions{$key},
			'active' => ($active eq $key) ? 1 : 0
		});
	}
	return \@loop;
}

sub type_options {
	my ($app) = @_;
	my $row_name_types = types('field');
	my %options = ();
	for my $key (keys %$row_name_types) {
		require_type($app, 'field', $key);
		my $yaml = $row_name_types->{$key}->[0];
		$options{$yaml->{'field_type'}} = $yaml->{'class'}->options;
	}
	return \%options;
}

1;
