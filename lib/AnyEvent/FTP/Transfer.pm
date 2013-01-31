package AnyEvent::FTP::Transfer;

use strict;
use warnings;
use v5.10;
use AnyEvent;

# ABSTRACT: Transfer class for asynchronous ftp client
# VERSION

# FIXME: implement ABOR

sub new
{
  my($class) = shift;
  my $args   = ref $_[0] eq 'HASH' ? (\%{$_[0]}) : ({@_});
  bless {
    cv          => $args->{cv} // AnyEvent->condvar,
    client      => $args->{client},
    remote_name => $args->{command}->[1],
  }, $class;
}

sub cb { shift->{cv}->cb(@_) }
sub ready { shift->{cv}->ready }
sub recv { shift->{cv}->recv }

sub handle
{
  my($self, $fh) = @_;
  
  my $handle;
  $handle = AnyEvent::Handle->new(
    fh => $fh,
    on_error => sub {
      my($hdl, $fatal, $msg) = @_;
      $_[0]->destroy;
    },
    on_eof => sub {
      $handle->destroy;
    },
  );
}

sub remote_name { shift->{remote_name} }

1;