
package MT::Plugin::FieldDay;
use strict;
use Data::Dumper;

use vars qw( $VERSION $SCHEMA_VERSION );
$VERSION = '1.0a1';
$SCHEMA_VERSION = '0.14';

use base qw( MT::Plugin );

use MT;
use FieldDay::YAML qw( types load_yamls );
use FieldDay::Util qw( require_type );

my $plugin = MT::Plugin::FieldDay->new({
	'id' => 'FieldDay',
	'name' => 'FieldDay',
	'author_name' => 'Apperceptive, LLC',
	'author_link' => 'http://www.apperceptive.com/',
	'description' => 'Add fields to Movable Type.',
	'version' => $VERSION,
	'schema_version' => $SCHEMA_VERSION,
});
MT->add_plugin($plugin);

sub init_registry {
	my $component = shift;
	load_yamls();
	my ($callbacks, $page_actions, $menus, $pub_tags) = init_object_types(@_);
	my $reg = {
		'object_types' => {
			'fdsetting' => 'FieldDay::Setting',
			'fdvalue' => 'FieldDay::Value',
			'entry' => {
				'testing' => 'integer',
			},
		},
		'init_request' => \&init_request,
		'callbacks' => $callbacks,
		'applications' => {
			'cms' => {
				'menus' => $menus,
				'methods' => {
					(map {
						my $action = $_;
						("fd_cfg_$_" => sub { mode_dispatch("cfg_$action", @_) }),
						("fd_save_$_" => sub { mode_dispatch("save_$action", @_) })
					} qw( fields groups )), #defaults tags listing )),
					(map {
						my $action = $_;
						"fd_${_}_default" => sub { mode_dispatch("${action}_default", @_) }			
					} qw( set clear override use )),
				},
				'page_actions' => $page_actions,
			}
		},
		'tags' => {
			'function' => {
				'fd_cmsfields' => sub { app_tag_dispatch('hdlr_cmsfields', @_) },
				'fd_htmlhead' => sub { app_tag_dispatch('hdlr_htmlhead', @_) },
				%{$pub_tags->{'function'}},
			},
			'block' => {
				%{$pub_tags->{'block'}},
			}
		},
	};
	$component->registry($reg);
}

my $global_cache = {};

sub init_request {
	my $app = shift;
	$global_cache = {};
}

sub global_cache {
	return $global_cache;
}

sub init_object_types {
	my $path = MT->instance->{'cfg'}->pluginpath . '/FieldDay';
	my $object_types = types('object');
	my ($cbs, $page_actions, $menus) = ({}, {}, {});
	my $pub_tags = {
		'function' => {},
		'block' => {},
	};
	my $order = 2000;
	for my $key (sort keys %$object_types) {
		my $ot = $object_types->{$key}->[0];
		next unless ($ot && %{$ot});
		my $orig_key = $key;
		my $use_type = $ot->{'object_mt_type'} || $ot->{'object_type'};
			# callbacks
		$cbs->{"cms_post_save.$use_type"} = 
			sub { callback_dispatch('cms_post_save', $key, $ot, @_) };
		$cbs->{"post_remove.$use_type"} = 
			sub { callback_dispatch('post_remove', $key, $ot, @_) };
		for my $tmpl (qw( edit_template )) { #list_template edit_template )) {
			for my $type (qw( source param )) {
				$cbs->{"MT::App::CMS::template_$type.$ot->{$tmpl}"} = 
					sub { callback_dispatch($tmpl . "_$type" , $orig_key, $ot, @_) };
			}
		}
		my $class = require_type(MT->instance, 'object', $key);
		if (my $class_cbs = $class->callbacks) {
			$cbs = { %$cbs, %$class_cbs };
		}
		if ($ot->{'other_templates'}) {
			for my $tmpl (keys %{$ot->{'other_templates'}}) {
				for my $type (qw( source param )) {
					$cbs->{"MT::App::CMS::template_$type.$tmpl"} = 
						sub { callback_dispatch($tmpl . "_$type", $orig_key, $ot, @_) };
				}
			}
		}
			# page actions
		$page_actions->{$ot->{'object_type'}} = {
			'configure_fields' => {
				'label' => 'Configure Fields',
				'code' => sub { mode_dispatch('cfg_fields', @_, $ot) },
				$ot->{'has_blog_id'}
					? ('permission' => 'administer_blog')
					: 'system_permission' => 'administer'
			}
		};
			# menus
		$menus->{"prefs:fd_$ot->{'object_type'}"} = {
			'label' => ucfirst($key) . ' Fields',
			'mode' => "fd_cfg_fields",
			'args' => { '_type' => $ot->{'object_type'} },
			'order' => $order,
			$ot->{'has_blog_id'}
				? ('permission' => 'administer_blog',
					'view' => 'blog')
				: ('system_permission' => 'administer',
					'view' => 'system')
		};
		$order += 100;
			# tags
		my $uckey = ucfirst($key);
		for my $tag (qw( FieldValue FieldLabel FieldGroupLabel FieldI FieldGroupI FieldCount FieldGroupCount )) {
			$pub_tags->{'function'}->{"$uckey$tag"} = sub { pub_tag_dispatch("hdlr_$tag", $key, @_) };

		}
		for my $tag (qw( Field FieldGroup )) {
			$pub_tags->{'block'}->{"$uckey$tag"} = sub { pub_tag_dispatch("hdlr_$tag", $key, @_) };
		}
		for my $tag (qw( IfField IfFieldGroup )) {
			$pub_tags->{'block'}->{"$uckey$tag?"} = sub { pub_tag_dispatch("hdlr_$tag", $key, @_) };
		}
		$pub_tags->{'block'}->{$uckey . 'ListByValue'} = sub { pub_tag_dispatch('hdlr_ListByValue', $key, @_) };
	}
	my $field_types = types('field');
	for my $key (keys %$field_types) {
		my $class = require_type(MT->instance, 'field', $key);
		my $tags = $class->tags;
		if ($tags && $tags->{'per_type'}) {
			for my $ot_key (keys %$object_types) {
				for my $tag_type (qw( block function )) {
					if ($tags->{'per_type'}->{$tag_type}) {
						my %add_tags = map { ucfirst($ot_key) . $_ => \&{$tags->{'per_type'}->{$tag_type}->{$_}} }
							keys %{$tags->{'per_type'}->{$tag_type}};
						$pub_tags->{$tag_type} = { %{$pub_tags->{$tag_type}}, %add_tags };
					}
				}
			}
		}
		if ($tags && $tags->{'block'}) {
			$pub_tags->{'block'} = { %{$pub_tags->{'block'}}, %{$tags->{'block'}} };
		}
		if ($tags && $tags->{'function'}) {
			$pub_tags->{'function'} = { %{$pub_tags->{'function'}}, %{$tags->{'function'}} };
		}
	}
	return ($cbs, $page_actions, $menus, $pub_tags);
}

sub callback_dispatch {
	my ($cb_type, $key, $ot, $cb, $app, $obj) = @_;
	require_type($app, 'object', $key);
	$ot->{'class'}->$cb_type($cb, $app, $obj);
}

sub app_tag_dispatch {
	my $hdlr = shift;
	require FieldDay::Template::AppTags;
	return FieldDay::Template::AppTags->$hdlr($plugin, @_);
}

sub pub_tag_dispatch {
	my $hdlr = shift;
	my $ot = shift;
	$_[1]->{'object_type'} = $ot;
	require FieldDay::Template::PubTags;
	return FieldDay::Template::PubTags->$hdlr($plugin, @_);
}

sub mode_dispatch {
	my $mode = shift;
	$_[0]->{'component'} = 'FieldDay'; # necessary why?
	require FieldDay::App;
	return FieldDay::App->$mode($plugin, @_);
}

1;
