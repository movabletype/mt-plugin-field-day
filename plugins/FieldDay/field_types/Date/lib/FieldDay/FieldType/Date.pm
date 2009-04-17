
package FieldDay::FieldType::Date;
use strict;
use Data::Dumper;

use base qw( FieldDay::FieldType );

sub label {
	return 'Date';
}

sub options {
	return {
		'text_entry' => 1,
		'date_order' => 'mdy',
		'default_year' => 1,
		'time' => 'hhmm',
		'minutes' => 5,
		'show_hms' => undef,
		'ampm' => 1,
		'ampm_default' => 'pm',
		'y_start' => 2008,
		'y_end' => 2010,
	};
}

sub tags {
	return {
		'block' => {
			'FormatDate' => \&hdlr_FormatDate,
		},
		'modifier' => {
			'adjust' => \&hdlr_adjust,
		},
	};
}

sub hdlr_adjust {
	my ($str, $val, $ctx) = @_;
	require MT::Util;
	my $time = MT::Util::ts2epoch($ctx->stash('blog'), $str);
	return $str unless $time;
    my %mult = ('s'=>1,
                 'M' => 60,
                 'h' => 60*60,
                 'd' => 60*60*24,
                 'w' => 60*60*24*7,
                 'm' => 60*60*24*30,
                 'y' => 60*60*24*365);
	my $offset = 0;
	if ($val =~ /^([+-]?(?:\d+|\d*\.\d*))([sMhdwmy]?)/) {
        $offset = ($mult{$2} || 1) * $1;
	}
	return MT::Util::epoch2ts($ctx->stash('blog'), $time + $offset);
}

sub hdlr_FormatDate {
	my ($ctx, $args, $cond) = @_;
	defined(my $text = $ctx->stash('builder')->build($ctx,
		$ctx->stash('tokens'), $cond)) || return $ctx->error($ctx->errstr);
		# strip whitespace
	$text =~ s/^\s+//;
	$text =~ s/\s+$//;
	return '' unless $text;
	$args->{'ts'} = $text;
	require MT::Template::ContextHandlers;
	return MT::Template::Context::_hdlr_date(@_);
}

sub html_head {
	return <<"HTML";
<script type="text/javascript" src="<mt:var name="static_uri">plugins/FieldDay/cal.js"></script>
<script type="text/javascript" src="<mt:var name="static_uri">plugins/FieldDay/date.js"></script>
HTML
}

sub pre_edit_options {
# before FieldDay displays the config screen
	my $class = shift;
	my ($param) = @_;
	for my $key (qw( date_order time minutes input_type ampm_default )) {
		$param->{$param->{$key} . '_selected'} = 1;
	}
}

sub pre_save_options {
# before FieldDay saves a field's settings
	my $class = shift;
	my ($app, $field, $options) = @_;
}

sub pre_render {
# before the field is rendered in the CMS
	my $class = shift;
	my ($param) = @_;
	my $tabindex = $param->{'tabindex'} ? ($param->{'tabindex'} - 1) : '';
	$param->{'show_min'} = $param->{'show_hms'};
	$param->{'show_sec'} = ($param->{'time'} eq 'hhmmss') ? 1 : 0;
	$param->{'date_order'} ||= 'mdy';
	for (split(//, $param->{'date_order'})) {
		$param->{"tabindex_$_"} = ++$tabindex;
	}
	$param->{'y_select'} = choice_tmpl('y', 'Year'); 
	$param->{'m_select'} = choice_tmpl('m', 'Month'); 
	$param->{'d_select'} = choice_tmpl('d', 'Day');
		# numerify it in case the field type was changed
		# and there's a text value in there
	$param->{'value'} = $param->{'value'} ? (eval("$param->{'value'} + 0") || '') : '';
	@{$param}{qw( y m d h min s )} = unpack('A4A2A2A2A2A2', $param->{'value'});
	if (!$param->{'y'} && $param->{'default_year'}) {
		$param->{'y'} = [localtime()]->[5] + 1900;
	}
	$param->{'y_loop'} = option_loop($param->{'y_start'}, $param->{'y_end'}, $param->{'y'});
	$param->{'m_loop'} = option_loop(1, 12, $param->{'m'});
	$param->{'d_loop'} = option_loop(1, 31, $param->{'d'});
	if ($param->{'show_hms'}) {
		my ($start_h, $end_h) = $param->{'ampm'} ? (1, 12) : (0, 23);
		if ($param->{'ampm'}) {
			if ($param->{'h'} && ($param->{'h'} > 12)) {
				$param->{'pm_selected'} = 1;
				$param->{'h'} = $param->{'h'} - 12;
			} elsif (($param->{'ampm_default'} || '') eq 'am') {
				$param->{'am_selected'} = 1;
			} else {
				$param->{'pm_selected'} = 1;
			}
		}
		$param->{'h_loop'} = option_loop($start_h, $end_h, $param->{'h'});
		$param->{'tabindex_h'} = ++$tabindex;
		$param->{'h_select'} = choice_tmpl('h', 'HH');
		if ($param->{'time'} ne 'hh') {
			$param->{'min_loop'} = option_loop_step(0, 59, $param->{'minutes'}, $param->{'min'});
			$param->{'tabindex_min'} = ++$tabindex;
			$param->{'min_select'} = choice_tmpl('min', 'MM');
			if ($param->{'time'} eq 'hhmmss') {
				$param->{'s_loop'} = option_loop(0, 59, $param->{'s'});
				$param->{'tabindex_s'} = ++$tabindex;
				$param->{'s_select'} = choice_tmpl('s', 'SS');
			}
		}
	}
	$param->{'tabindex'} = $tabindex;
}

sub pre_save_value {
# before the CMS saves a value from the editing screen
	my $class = shift;
	my ($app, $field_name) = @_;
	return params_to_ts($app, $field_name);
}

sub choice_tmpl {
	my ($type, $label) = @_;
	my $tabindex = "<mt:var name=tabindex_$type>";
	my $tmpl_text = <<TMPL;
<select name="<mt:var name="field">_$type" id="<mt:var name="field">_$type" tabindex="$tabindex" onchange="fd_date_menu_change(this);">
<option value="">$label</option>
<mt:loop name="${type}_loop">
<option value="<mt:var name="label">"<mt:if name="selected"> selected="selected"</mt:if>><mt:var name="label"></option>
</mt:loop>
</select>
TMPL
	my $tmpl = MT::Template->new('type' => 'scalarref', 'source' => \$tmpl_text);
	return $tmpl;
}

sub option_loop {
	my ($start, $end, $selected, $labels) = @_;
	$selected ||= 0;
	my @loop = ();
	for my $i ($start .. $end) {
		push(@loop, one_option($i, $selected, $labels));
	}
	return \@loop;
}

sub option_loop_step {
	my ($start, $end, $step, $selected, $labels) = @_;
	$selected ||= 0;
	my @loop = ();
	for my $i ($start .. $end) {
		next unless ($i % $step == 0);
		push(@loop, one_option($i, $selected, $labels));
	}
	return \@loop;
}

sub one_option {
	my ($i, $selected, $labels) = @_;
	return {
			'value' => $i,
			'selected' => (($i && ($i == $selected))
				|| (!$i && !($selected + 0))) ? 1 : 0,
			'label' => $labels ? $labels->{$i} : 
				($i < 10) ? "0$i" : $i
	};
}

sub params_to_ts {
	my ($app, $field) = @_;
	my %date = ();
	for my $key (qw( y m d h min s )) {
		$date{$key} = $app->param("${field}_$key") || 0;
	}
	if ($app->param("${field}_ampm") && ($app->param("${field}_ampm") eq 'pm')) {
		$date{'h'} += 12;
		if ($date{'h'} == 24) {
			$date{'h'} = 12;
		}
	}
	return '' unless ($date{'y'} && $date{'m'} && $date{'d'});
	my $ts = sprintf("%04d%02d%02d%02d%02d%02d", @date{qw( y m d h min s )});
	return ($ts ne '00000000000000') ? $ts : '';
}

1;
