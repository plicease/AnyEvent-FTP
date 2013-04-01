package AnyEvent::FTP::Server;

use strict;
use warnings;
use v5.10;
use Role::Tiny::With;
use AnyEvent::Handle;
use AnyEvent::Socket qw( tcp_server );
use AnyEvent::FTP::Server::Connection;
use Socket qw( unpack_sockaddr_in inet_ntoa );

# ABSTRACT: Simple asynchronous ftp server
# VERSION

$AnyEvent::FTP::Server::VERSION //= 'dev';

with 'AnyEvent::FTP::Role::Event';

__PACKAGE__->define_events(qw( bind connect ));

sub new
{
  my($class) = shift;
  my $args   = ref $_[0] eq 'HASH' ? (\%{$_[0]}) : ({@_});
  my $self = bless {
    hostname        => $args->{hostname},
    port            => $args->{port}            // 21,
    default_context => $args->{default_context} // 'AnyEvent::FTP::Server::Context::Full',
    welcome         => $args->{welcome}         // [ 220 => "aeftpd $AnyEvent::FTP::Server::VERSION" ],
    inet            => $args->{inet}            // 0,
  }, $class;
  
  eval 'use ' . $self->{default_context};
  die $@ if $@;
  
  $self;
}

sub start
{
  my($self) = @_;
  $self->{inet} ? $self->_start_inet : $self->_start_standalone;
}

sub _start_inet
{
  my($self) = @_;
  
  my $con = AnyEvent::FTP::Server::Connection->new(
    context => $self->{default_context}->new,
    ip      => do {
      my $sockname = getsockname STDIN;
      my ($sockport, $sockaddr) = unpack_sockaddr_in ($sockname);
      inet_ntoa ($sockaddr);
    },
  );

  my $handle;
  $handle = AnyEvent::Handle->new(
    fh => *STDIN,
      on_error => sub {
        my($hdl, $fatal, $msg) = @_;
        $_[0]->destroy;
        undef $handle;
        undef $con;
      },
      on_eof   => sub {
        $handle->destroy;
        undef $handle;
        undef $con;
      },
  );
  
  $self->emit(connect => $con);

  STDOUT->autoflush(1);
  STDIN->autoflush(1);

  $con->on_response(sub {
    my($raw) = @_;
    print STDOUT $raw;
  });
    
  $con->on_close(sub {
    close STDOUT;
    exit;
  });
    
  $con->send_response(@{ $self->{welcome} });
    
  $handle->on_read(sub {
    $handle->push_read( line => sub {
      my($handle, $line) = @_;
      $con->process_request($line);
    });
  });
  
  $self;
}

sub _start_standalone
{
  my($self) = @_;
  
  my $prepare = sub {
    my($fh, $host, $port) = @_;
    $self->{bindport} = $port;
    $self->emit(bind => $port);
  };
  
  my $connect = sub {
    my($fh, $host, $port) = @_;
    
    my $con = AnyEvent::FTP::Server::Connection->new(
      context => $self->{default_context}->new,
      ip => do {
        my($port, $addr) = unpack_sockaddr_in getsockname $fh;
        inet_ntoa $addr;
      },
    );
    
    my $handle;
    $handle = AnyEvent::Handle->new(
      fh       => $fh,
      on_error => sub {
        my($hdl, $fatal, $msg) = @_;
        $_[0]->destroy;
        undef $handle;
        undef $con;
      },
      on_eof   => sub {
        $handle->destroy;
        undef $handle;
        undef $con;
      },
    );
    
    $self->emit(connect => $con);
    
    $con->on_response(sub {
      my($raw) = @_;
      $handle->push_write($raw);
    });
    
    $con->on_close(sub {
      $handle->push_shutdown;
    });
    
    $con->send_response(@{ $self->{welcome} });
    
    $handle->on_read(sub {
      $handle->push_read( line => sub {
        my($handle, $line) = @_;
        $con->process_request($line);
      });
    });
  
  };
  
  delete $self->{port} if $self->{port} == 0;
  
  tcp_server $self->{hostname}, $self->{port}, $connect, $prepare;
  
  $self;
}

sub bindport { shift->{bindport} }

1;