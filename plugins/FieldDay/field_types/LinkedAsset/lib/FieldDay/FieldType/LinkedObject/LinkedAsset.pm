##########################################################################
# Copyright (C) 2008-2010 Six Apart Ltd.
# This program is free software: you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# version 2 for more details. You should have received a copy of the GNU
# General Public License version 2 along with this program. If not, see
# <http://www.gnu.org/licenses/>.

package FieldDay::FieldType::LinkedObject::LinkedAsset;

use strict;

use Data::Dumper;

use base qw( FieldDay::FieldType::LinkedObject );
use MT::Util qw( encode_url );

sub tags {
    return {
        'per_type' => {
            'block' => {
                'LinkedAssets' => sub { __PACKAGE__->hdlr_LinkedObjects('asset', @_) },
                'IfLinkedAssets?' => sub { __PACKAGE__->hdlr_LinkedObjects('asset', @_) },
                'LinkingAssets' => sub { __PACKAGE__->hdlr_LinkingObjects('asset', @_) },
                'IfLinkingAssets?' => sub { __PACKAGE__->hdlr_LinkingObjects('asset', @_) },
            },
        },
    };
}

sub options {
    my $class = shift;
    return {
        'linked_blog_id' => undef,
        'asset_type' => undef,
        'overwrite' => undef,
        'upload_path' => '',
        'upload_path_relative' => 1,
        'url_path' => '',
        'url_path_relative' => 1,
        %{$class->SUPER::options()}
    };
}

sub label {
    return 'Linked Asset';
}

sub object_type {
    return 'asset';
}

sub core_fields {
    my $class = shift;
    my ($blog_id) = @_;
    return {
        'file_name' => {
            'type' => 'Text',
            'label' => 'Filename',
        },
        'description' => {
            'type' => 'TextArea',
            'label' => 'Description',
            'options' => {
                'label_display' => 'above',
            },
        },
    };
}

# before FieldDay displays the config screen
sub pre_edit_options {
    my $class = shift;
    $class->SUPER::pre_edit_options(@_);
    my ($param) = @_;
    my @asset_type_loop;
    for my $type (qw( image audio video )) {
        push (@asset_type_loop, {
            'value' => $type,
            'label' => ucfirst($type),
            'selected' => ($param->{'asset_type'} && ($param->{'asset_type'} eq $type)) ? 1 : 0,
        });
    }
    $param->{'asset_type_loop'} = \@asset_type_loop;
}

sub pre_render {
    my $class = shift;
    $class->SUPER::pre_render(@_);
    my ($param) = @_;
    $param->{'create_label'} = 'Upload';
    $param->{'create_form'} = <<"HTML";
<mtapp:setting
    id="$param->{'field'}-file"
    label="Select File:"
>
    <input type="file" name="$param->{'field'}-file" id="$param->{'field'}-file" />
</mtapp:setting>
$param->{'create_form'}
HTML
    $param->{'no_ajax'} = 1;
    $param->{'ac_field_width'} = 150;
    my $asset = MT->model('asset')->load($param->{'value'});
    my $url = ($asset && $asset->class eq 'image') ? $asset->url : '';
    $param->{'preview'} = <<"HTML";
<a href="$url" id="<mt:var name="field">-link" name="<mt:var name="field">-link"><img src="$url" id="<mt:var name="field">-img" name="<mt:var name="field">-img" width="100" align="top" style="padding-left:20px;" border="0" /></a>
HTML
}

# before the CMS saves a value from the editing screen
sub pre_save_value {
    my $class = shift;
    my ($app, $i_name, $obj, $options) = @_;
    if ($app->param($i_name . '-file')) {
        # uploaded file
        require MT::Asset;
        my ($fh, $info) = $app->upload_info($i_name . '-file');
        my $mimetype;
        if ($info) {
            $mimetype = $info->{'Content-Type'};
        }
        my $basename = $app->param($i_name . '-file_name') || $app->param($i_name . '-file');
        $basename =~ s!\\!/!g;    ## Change backslashes to forward slashes
        $basename =~ s!^.*/!!;    ## Get rid of full directory paths
        if ( $basename =~ m!\.\.|\0|\|! ) {
            die "Invalid filename $basename";
        }
        if ($options->{asset_type}) {
            my $asset_pkg = MT::Asset->handler_for_file($basename);
            my $class = 'MT::Asset::' . ucfirst($options->{asset_type});
            if (!$asset_pkg->isa($class)) {
                die "Wrong file type";
            }
        }
        my ($blog_id, $blog, $fmgr, $local_file, $asset_file, $base_url,
          $asset_base_url, $relative_url, $relative_path, $path, $asset_path);
        if ($blog_id = $app->param('blog_id')) {
            require MT::Blog;
            $blog = MT::Blog->load($blog_id);
            $fmgr = $blog->file_mgr;
            my $root_path = $options->{upload_path_relative} ? $blog->site_path : '';
            $relative_path = _build_path($app, $obj, $options->{upload_path});
            if ( $relative_path =~ m!\.\.|\0|\|! ) {
                die "Invalid path";
            }
            $asset_path = $options->{url_path_relative} ? '%r' : '';
            $base_url = $root_path;
            $asset_base_url = $options->{url_path_relative} ? '%r/' : '';
            $asset_base_url .= '/' unless (!$asset_base_url || ($asset_base_url =~ m{/$}));
            $asset_base_url .= $options->{url_path};
            $asset_base_url =~ s{/$}{};
            $path = File::Spec->catdir($root_path, $relative_path);
            # untaint
            ($path) = $path =~ /(.+)/s;
            unless ( $fmgr->exists($path) ) {
                $fmgr->mkpath($path) || die "Couldn't create path $path: " . $fmgr->errstr;
            }
        } else {
            $blog_id        = 0;
            $asset_base_url = '%s/support/uploads';
            $asset_path = File::Spec->catfile( '%s', 'support', 'uploads');
            $base_url       = $app->static_path . 'support/uploads';
            my $base_path =
              File::Spec->catdir( $app->static_file_path, 'support', 'uploads' );

            require MT::FileMgr;
            $fmgr = MT::FileMgr->new('Local');
            unless ( $fmgr->exists( $base_path ) ) {
                $fmgr->mkpath( $base_path );
                unless ( $fmgr->exists( $base_path ) ) {
                    die( $app->translate(
                        "Could not create upload path '[_1]': [_2]",
                            $base_path, $fmgr->errstr
                    ) );
                }
            }
            $relative_path = _build_path($app, $obj, $options->{upload_path});
            $path = File::Spec->catdir($base_path, $relative_path);
        }
        require File::Basename;
        my ($stem, undef, $type) = File::Basename::fileparse( $basename,
            qr/\.[A-Za-z0-9]+$/ );
        my $unique_stem = $stem;
        $local_file = File::Spec->catfile( $path,
            $unique_stem . $type );
        my $i = 1;
        while (!$options->{overwrite} && $fmgr->exists($local_file)) {
            $unique_stem = join q{-}, $stem, $i++;
            $local_file = File::Spec->catfile( $path,
                $unique_stem . $type );
        }

        my $unique_basename = $unique_stem . $type;
        $asset_file = File::Spec->catfile( $asset_path, $relative_path, $unique_basename );
        $relative_path  = $unique_basename;
        $relative_url   = encode_url($unique_basename);

        # untaint
        ($local_file) = $local_file =~ /(.+)/s;

        require MT::Image;
        my ($w, $h, $id, $write_file) = MT::Image->check_upload(
            Fh => $fh, Fmgr => $fmgr, Local => $local_file,
        );

        die (MT::Image->errstr)
            unless $write_file;

        ## File does not exist, or else we have confirmed that we can overwrite.
        my $umask = oct $app->config('UploadUmask');
        my $old   = umask($umask);
        defined( my $bytes = $write_file->() )
          or die(
            $app->translate(
                "Error writing upload to '[_1]': [_2]", $local_file,
                $fmgr->errstr
            )
          );
        umask($old);

        ## Close up the filehandle.
        close $fh;

        ## We are going to use $relative_path as the filename and as the url passed
        ## in to the templates. So, we want to replace all of the '\' characters
        ## with '/' characters so that it won't look like backslashed characters.
        ## Also, get rid of a slash at the front, if present.
        $relative_path =~ s!\\!/!g;
        $relative_path =~ s!^/!!;
        $relative_url  =~ s!\\!/!g;
        $relative_url  =~ s!^/!!;
        my $url = $base_url;
        $url .= '/' unless $url =~ m!/$!;
        $url .= $relative_url;
        my $asset_url = $asset_base_url . '/' . $relative_url;

        require File::Basename;
        my $local_basename = File::Basename::basename($local_file);
        my $ext =
          ( File::Basename::fileparse( $local_file, qr/[A-Za-z0-9]+$/ ) )[2];

        require MT::Asset;
        my $asset_pkg = MT::Asset->handler_for_file($local_basename);
        my $is_image  = defined($w)
          && defined($h)
          && $asset_pkg->isa('MT::Asset::Image');
        my $asset;
        if (
            !(
                $asset = $asset_pkg->load(
                    { file_path => $asset_file, blog_id => $blog_id }
                )
            )
          )
        {
            $asset = $asset_pkg->new();
            $asset->file_path($asset_file);
            $asset->file_name($local_basename);
            $asset->file_ext($ext);
            $asset->blog_id($blog_id);
            $asset->created_by( $app->user->id );
        }
        else {
            $asset->modified_by( $app->user->id );
        }
        my $original = $asset->clone;
        $asset->url($asset_url);
        if ($is_image) {
            $asset->image_width($w);
            $asset->image_height($h);
        }
        $asset->mime_type($mimetype) if $mimetype;
        $asset->description($app->param($i_name . '-description'));
        $asset->save;
        # TODO: munge the params so we can save extra asset fields
        #$app->run_callbacks( 'cms_post_save.asset', $app, $asset, $original );

        if ($is_image) {
            $app->run_callbacks(
                'cms_upload_file.' . $asset->class,
                File  => $local_file,
                file  => $local_file,
                Url   => $url,
                url   => $url,
                Size  => $bytes,
                size  => $bytes,
                Asset => $asset,
                asset => $asset,
                Type  => 'image',
                type  => 'image',
                Blog  => $blog,
                blog  => $blog
            );
            $app->run_callbacks(
                'cms_upload_image',
                File       => $local_file,
                file       => $local_file,
                Url        => $url,
                url        => $url,
                Size       => $bytes,
                size       => $bytes,
                Asset      => $asset,
                asset      => $asset,
                Height     => $h,
                height     => $h,
                Width      => $w,
                width      => $w,
                Type       => 'image',
                type       => 'image',
                ImageType  => $id,
                image_type => $id,
                Blog       => $blog,
                blog       => $blog
            );
        }
        else {
            $app->run_callbacks(
                'cms_upload_file.' . $asset->class,
                File  => $local_file,
                file  => $local_file,
                Url   => $url,
                url   => $url,
                Size  => $bytes,
                size  => $bytes,
                Asset => $asset,
                asset => $asset,
                Type  => 'file',
                type  => 'file',
                Blog  => $blog,
                blog  => $blog
            );
        }

        return $asset->id;
    }
    return $app->param($i_name);
}

sub load_objects {
    my $class = shift;
    my ($param, %terms) = @_;
    require MT::Asset;
    if ($terms{id}) {
        return MT::Asset->load($terms{id});
    }
    return MT::Asset->load({
        class => $param->{'asset_type'} || '*',
        $param->{'linked_blog_id'}
            ? (blog_id => $param->{'linked_blog_id'})
            : (),
        %terms
    });
}

sub do_query {
    my $class = shift;
    my ($setting, $q) = @_;
    my $query = '%' . $q->param('query') . '%';
    my %terms = (
        file_name => { like => $query },
    );
    my $options = $setting->data->{'options'};
    my @assets = $class->load_objects($options, %terms);
    my @rows;
    for my $asset (@assets) {
        push(@rows, join("\t", map { $_->file_name, $_->id, $_->blog_id, $_->url } $asset));
    }
    return join("\n",  @rows);
}

sub object_label {
    my $class = shift;
    my ($obj) = @_;
    return $obj->file_name;
}

sub _build_path {
    my ($app, $obj, $path) = @_;
    my $tmpl_text = qq{<mt:FileTemplate format="$path">};
    my $tmpl = MT->model('template')->new('type' => 'scalarref', 'source' => \$tmpl_text);
    require MT::Template::Context;
    my $ctx = MT::Template::Context->new;
    if ($app->param('blog_id')) {
        $ctx->stash('blog', MT->model('blog')->load($app->param('blog_id')));
    }
    my $class = ref $obj;
    $class =~ s/^MT:://;
    $ctx->stash(lc($class), $obj);
    if ($obj->can('created_on')) {
        $ctx->{current_timestamp} = $obj->created_on;
    }
    $tmpl->context($ctx);
    return $tmpl->output;
}

1;
