package DDGC::Web::Controller::Duckpan;
# ABSTRACT:

use Moose;
use namespace::autoclean;

use DDGC::Config;
use Dist::Data;
use Path::Class;
use Pod::Simple::XHTML;

BEGIN {extends 'Catalyst::Controller'; }

sub base :Chained('/base') :PathPart('duckpan') :CaptureArgs(0) {
	my ( $self, $c ) = @_;
	$c->stash->{title} = 'DuckPAN';
	$c->stash->{duckpan} = $c->d->duckpan;
	$c->add_bc('DuckPAN', $c->chained_uri('Duckpan','index'));
}

sub index :Chained('base') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;
	$c->bc_index;
	$c->stash->{duckpan_releases} = $c->d->rs('DuckPAN::Release')->search_rs({
		'me.current' => 1,
	},{
		prefetch => [qw( duckpan_modules )],
		order_by => [{ -desc => 'me.created' },{ -asc => 'duckpan_modules.name' }],
	});
}

sub release_base :Chained('base') :PathPart('release') :CaptureArgs(1) {
	my ( $self, $c, $release_name ) = @_;
	$c->stash->{release_name} = $release_name;
	$c->add_bc($release_name, $c->chained_uri('Duckpan','release_index',$release_name));
}

sub release_index :Chained('release_base') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;
	my $latest = $c->d->rs('DuckPAN::Release')->search_rs({
		name => $c->stash->{release_name},
		current => 1,
	},{
		order_by => { -asc => 'duckpan_modules.name' },
		prefetch => [qw( duckpan_modules )],
	})->first;
	if ($latest) {
		$c->response->redirect($c->chained_uri('Duckpan','release',$c->stash->{release_name},$latest->version));
	} else {
		$c->response->redirect($c->chained_uri('Duckpan','index',{ release_not_found => 1 }));
	}
	return $c->detach;
}

sub release_all :Chained('release_base') :PathPart('all') :Args(0) {
	my ( $self, $c ) = @_;
	$c->add_bc('All versions');
	$c->stash->{duckpan_releases} = $c->d->rs('DuckPAN::Release')->search_rs({
		'me.name' => $c->stash->{release_name},
	},{
		prefetch => [qw( duckpan_modules )],
		order_by => [{ -desc => 'me.created' },{ -asc => 'duckpan_modules.name' }],
	});
}

sub release :Chained('release_base') :PathPart('v') :Args(1) {
	my ( $self, $c, $version ) = @_;
	$c->add_bc($version);
	$c->stash->{duckpan_release} = $c->d->rs('DuckPAN::Release')->search_rs({
		'me.name' => $c->stash->{release_name},
		'me.version' => $version,
	},{
		prefetch => [qw( duckpan_modules )],
	})->first;
}

sub logged_in :Chained('base') :PathPart('') :CaptureArgs(0) {
	my ( $self, $c ) = @_;
	if (!$c->user) {
		$c->response->redirect($c->chained_uri('My','login'));
		return $c->detach;
	}
}

sub upload :Chained('logged_in') :Args(0) {
	my ( $self, $c ) = @_;
	$c->add_bc('Upload');
	if (!$c->user) {
		$c->res->code(403);
		$c->stash->{no_user} = 1;
		return $c->detach;
	}
	my $uploader = $c->user->username;
	my $upload = $c->req->upload('pause99_add_uri_httpupload');
	my $filename = $c->d->config->cachedir.'/'.$upload->filename;
	$upload->copy_to($filename);
	$c->stash->{duckpan_return} = $c->d->duckpan->add_user_distribution($c->user,$filename);
	$c->res->code(403) if (ref $c->stash->{duckpan_return} eq 'HASH');
}

__PACKAGE__->meta->make_immutable;

1;
