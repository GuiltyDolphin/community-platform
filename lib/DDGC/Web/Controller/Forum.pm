package DDGC::Web::Controller::Forum;
# ABSTRACT: 

use Moose;
BEGIN {extends 'Catalyst::Controller'; }

use namespace::autoclean;

sub base : Chained('/base') PathPart('forum') CaptureArgs(0) {
  my ( $self, $c ) = @_;
  $c->add_bc("Forum", $c->chained_uri('Forum', 'index'));
  $c->stash->{page_class} = "page-forums  texture";
  $c->stash->{title} = 'DuckDuckGo Forums';
  $c->stash->{is_admin} = $c->user && $c->user->admin;
}

sub userbase : Chained('base') PathPart('') CaptureArgs(0) {
  my ( $self, $c ) = @_;
  push @{$c->stash->{template_layout}}, 'forum/base.tx';  
  $c->stash->{sticky_threads} = $c->d->rs('Thread')->search_rs({
    sticky => 1,
  },{
    cache_for => 3600,
  });
}

sub set_grouped_comments {
  my ( $self, $c, $action, $rs, @args ) = @_;
  $c->stash->{grouped_comments} = $c->table(
    $rs,['Forum',$action,@args],[],
    default_pagesize => 15,
    default_sorting => defined $c->stash->{default_sorting} ? $c->stash->{default_sorting} : '-me.updated',
    id => 'forum_threadlist_'.$action,
    defined $c->stash->{sorting_options} ? (sorting_options => $c->stash->{sorting_options}) : (),
  );
}

sub allow_user {
  my ( $self, $c ) = @_;
  my $user_filter = $c->stash->{ddgc_config}->forums->{$c->stash->{forum_index}}->{user_filter};
  return 0 if ($user_filter && (!$c->user || !$user_filter->($c->user)));
  return 1;
}

sub index : Chained('userbase') PathPart('') Args(0) {
  my ( $self, $c ) = @_;
  $c->bc_index;
  $c->response->redirect($c->chained_uri('Forum','general'));
  return $c->detach;
}

sub general : Chained('userbase') Args(0) {
  my ( $self, $c ) = @_;
  $c->stash->{forum_index} = $c->stash->{ddgc_config}->id_for_forum('general');
  $c->add_bc($c->stash->{ddgc_config}->forums->{$c->stash->{forum_index}}->{name});
  $self->set_grouped_comments($c,'index',$c->d->forum->comments_grouped_general_threads);
}

sub admins : Chained('userbase') Args(0) {
  my ( $self, $c ) = @_;
  use DDP; p @_;
  $c->stash->{forum_index} = $c->stash->{ddgc_config}->id_for_forum('admin');
  $c->add_bc($c->stash->{ddgc_config}->forums->{$c->stash->{forum_index}}->{name});
  if (!$self->allow_user($c)) {
    $c->response->redirect($c->chained_uri('Forum','general')) unless $self->allow_user($c);
    return $c->detach;
  }
  $self->set_grouped_comments($c,'index',$c->d->forum->comments_grouped_admin_threads);
}

sub community_leaders : Chained('userbase') Args(0) {
  my ( $self, $c ) = @_;
  $c->stash->{forum_index} = $c->stash->{ddgc_config}->id_for_forum('community');
  $c->add_bc($c->stash->{ddgc_config}->forums->{$c->stash->{forum_index}}->{name});
  if (!$self->allow_user($c)) {
    $c->response->redirect($c->chained_uri('Forum','general')) unless $self->allow_user($c);
    return $c->detach;
  }
  $self->set_grouped_comments($c,'index',$c->d->forum->comments_grouped_community_leaders_threads);
}

sub special : Chained('userbase') Args(0) {
  my ( $self, $c ) = @_;
  $c->stash->{forum_index} = $c->stash->{ddgc_config}->id_for_forum('special');
  $c->add_bc($c->stash->{ddgc_config}->forums->{$c->stash->{forum_index}}->{name});
  if (!$self->allow_user($c)) {
    $c->response->redirect($c->chained_uri('Forum','general')) unless $self->allow_user($c);
    return $c->detach;
  }
  $self->set_grouped_comments($c,'index',$c->d->forum->comments_grouped_special_threads);
}

sub ideas : Chained('userbase') Args(0) {
  my ( $self, $c ) = @_;
  $c->add_bc("Latest idea comments");
  $self->set_grouped_comments($c,'ideas',$c->d->forum->comments_grouped_ideas);
}

sub all : Chained('userbase') Args(0) {
  my ( $self, $c ) = @_;
  $c->add_bc("Latest comments");
  $self->set_grouped_comments($c,'all',$c->d->forum->comments_grouped);
}

sub blog : Chained('userbase') Args(0) {
  my ( $self, $c ) = @_;
  $c->add_bc("Latest company blog comments");
  $self->set_grouped_comments($c,'blog',$c->d->forum->comments_grouped_company_blog);
}

sub user_blog : Chained('userbase') Args(0) {
  my ( $self, $c ) = @_;
  $c->add_bc("Latest user blog comments");
  $self->set_grouped_comments($c,'user_blog',$c->d->forum->comments_grouped_user_blog);
}

sub translation : Chained('userbase') Args(0) {
  my ( $self, $c ) = @_;
  $c->add_bc("Latest translation comments");
  $self->set_grouped_comments($c,'translation',$c->d->forum->comments_grouped_translation);
}

sub search : Chained('userbase') Args(0) {
  my ( $self, $c ) = @_;

  $c->add_bc('Search');

  $c->stash->{query} = $c->req->params->{q};
  return unless length($c->stash->{query});

  my ($threads, $threads_rs, $order_by) = $c->d->forum->search_engine->rs(
      $c,
      $c->stash->{query},
      $c->d->rs('Thread')->ghostbusted,
  );

  $c->stash->{results} = $threads;
  $c->stash->{default_sorting} = 'id';
  $c->stash->{sorting_options} = [{
          label => 'Last Update',
          sorting => '-me.updated',
      },{
          label => 'Relevance',
          sorting => 'id',
          order_by => $order_by,
      }] if defined $order_by;
  $self->set_grouped_comments($c,'search',$threads_rs,{ q => $c->stash->{query} })
    if defined $threads_rs;
}

sub suggest : Chained('base') Args(0) {
    my ($self, $c) = @_;
    return unless length $c->req->params->{q};

    $c->stash->{not_last_url} = 1;
    $c->stash->{x} = $c->d->forum->search_engine->suggest($c->req->params->{q});
    $c->forward($c->view('JSON'));
}

sub thread_view : Chained('userbase') PathPart('') CaptureArgs(0) {
  my ( $self, $c ) = @_;
  push @{$c->stash->{template_layout}}, 'forum/thread.tx';
}

sub comment_view : Chained('userbase') PathPart('') CaptureArgs(0) {
  my ( $self, $c ) = @_;
  push @{$c->stash->{template_layout}}, 'forum/comment.tx';
}

# /forum/thread/$id
sub thread_id : Chained('thread_view') PathPart('thread') CaptureArgs(1) {
  my ( $self, $c, $id ) = @_;
  $c->stash->{thread} = $c->d->rs('Thread')->find($id+0);
  $c->stash->{forum_index} = $c->stash->{thread}->forum;
  unless ($c->stash->{thread}) {
    $c->response->redirect($c->chained_uri('Forum','index',{ thread_notfound => 1 }));
    return $c->detach;
  }
  if ($c->stash->{thread}->forum eq '5') { # Magic number = special announcements
    if (!$c->user) {
      $c->response->redirect($c->chained_uri('My','login'));
      return $c->detach;
    }
  }
  else {
    if (!$self->allow_user($c)) {
      $c->response->redirect($c->chained_uri('Forum','general'));
      return $c->detach;
    }
  }
  $c->stash->{title} = $c->stash->{thread}->title;
}

sub thread_redirect : Chained('thread_id') PathPart('') Args(0) {
  my ( $self, $c ) = @_;
  $c->response->redirect($c->chained_uri(@{$c->stash->{thread}->u}));
  return $c->detach;
}

sub thread : Chained('thread_id') PathPart('') Args(1) {
  my ( $self, $c, $key ) = @_;
  if (defined $c->req->params->{close} && $c->user->admin) {
    $c->stash->{thread}->readonly($c->req->params->{close});
    $c->stash->{thread}->update;
  }
  if (defined $c->req->params->{sticky} && $c->user->admin) {
    $c->stash->{thread}->sticky($c->req->params->{sticky});
    $c->stash->{thread}->update;
  }
  if ($c->user && $c->req->params->{unfollow}) {
    $c->user->delete_context_notification($c->req->params->{unfollow},$c->stash->{thread});
  } elsif ($c->user && $c->req->params->{follow}){
    $c->user->add_context_notification($c->req->params->{follow},$c->stash->{thread});
  }
  unless ($c->stash->{thread}->key eq $key) {
    $c->response->redirect($c->chained_uri(@{$c->stash->{thread}->u}));
    return $c->detach;
  }
  $c->add_bc($c->stash->{ddgc_config}->forums->{$c->stash->{thread}->forum}->{name},
    $c->chained_uri(
      'Forum',
      $c->stash->{ddgc_config}->forums->{$c->stash->{thread}->forum}->{url},
  ));
  $c->add_bc($c->stash->{title});
  $c->stash->{no_reply} = 1 if $c->stash->{thread}->readonly;
}

# /forum/comment/$id
sub comment_id : Chained('comment_view') PathPart('comment') CaptureArgs(1) {
  my ( $self, $c, $id ) = @_;
  $c->stash->{thread} = $c->d->rs('Comment')->find($id);
  unless ($c->stash->{thread}) {
    $c->response->redirect($c->chained_uri('Forum','index',{ comment_notfound => 1 }));
    return $c->detach;
  }
  $c->add_bc('Comment #'.$c->stash->{thread}->id,$c->chained_uri('Forum','comment',
    $c->stash->{thread}->id));
}

sub comment : Chained('comment_id') PathPart('') Args(0) {
  my ( $self, $c ) = @_;
  $c->bc_index;
}

1;

