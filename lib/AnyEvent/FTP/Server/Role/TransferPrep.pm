package AnyEvent::FTP::Server::Role::TransferPrep;

use strict;
use warnings;
use 5.010;
use Moo::Role;
use AnyEvent;
use AnyEvent::Socket qw( tcp_server tcp_connect );
use AnyEvent::Handle;

# ABSTRACT: Interface for PASV, PORT and REST commands
# VERSION

=head1 SYNOPSIS

 package AnyEvent::FTP::Server::Context::MyContext;
 
 use Moo;
 extends 'AnyEvent::FTP::Server::Context';
 with 'AnyEvent::FTP::Server::Role::TransferPrep';

=head1 DESCRIPTION

This role provides the FTP transfer preparation commands C<PORT>, C<PASV> and C<REST>
to your FTP server context.  It isn't really useful by itself, and needs a transfer
role, like L<AnyEvent::FTP::Server::Role::TransferFetch> or
L<AnyEvent::FTP::Server::Role::TransferPut>.

=head1 ATTRIBUTES

=head2 data

 my $connection = $context->data

The data connection prepared from the FTP C<PASV> or C<PORT> command.
This is an L<AnyEvent::Handle>.

=cut

has data => (
  is => 'rw',
);

=head2 restart_offset

 my $offset = $context->restart_offset;

The offset specified in the last FTP C<REST> command.
This should be a positive integer.

=cut

has restart_offset => (
  is => 'rw',
);

=head1 METHODS

=head2 clear_data

 $context->clear_data;

Clears the C<data> and C<restart_offset> attributes.

=cut

sub clear_data
{
  my($self) = @_;
  $self->data(undef);
  $self->restart_offset(undef);
}

=head1 COMMANDS

=over 4

=item PASV

=cut

sub help_pasv { 'PASV (returns address/port)' }

sub cmd_pasv
{
  my($self, $con, $req) = @_;

  my $count = 0;

  tcp_server undef, undef, sub {
    my($fh, $host, $port) = @_;
    return close $fh if ++$count > 1;

    my $handle;
    $handle = AnyEvent::Handle->new(
      fh => $fh,
      on_error => sub {
        $_[0]->destroy;
        undef $handle;
      },
      on_eof => sub {
        $handle->destroy;
        undef $handle;
      },
      autocork => 1,
    );

    $self->data($handle);
    # TODO this should be with the 227 message below.
    # demoting this to a TODO (was a F-I-X-M-E)
    # since I can't remember why I thought it needed
    # doing. plicease 12-05-2014
    $self->done;

  }, sub {
    my($fh, $host, $port) = @_;
    my $ip_and_port = join(',', split(/\./, $con->ip), $port >> 8, $port & 0xff);

    my $w;
    $w = AnyEvent->timer(after => 0, cb => sub {
      $con->send_response(227 => "Entering Passive Mode ($ip_and_port)");
      undef $w;
    });

  };

  return;
}

=item PORT

=cut

sub help_port { 'PORT <sp> h1,h2,h3,h4,p1,p2' }

sub cmd_port
{
  my($self, $con, $req) = @_;

  if($req->args =~ /(\d+,\d+,\d+,\d+),(\d+),(\d+)/)
  {
    my $ip = join '.', split /,/, $1;
    my $port = $2*256 + $3;

    tcp_connect $ip, $port, sub {
      my($fh) = @_;
      unless($fh)
      {
        $con->send_response(500 => "Illegal PORT command");
        $self->done;
        return;
      }

      my $handle;
      $handle = AnyEvent::Handle->new(
        fh => $fh,
        on_error => sub {
          $_[0]->destroy;
          undef $handle;
        },
        on_eof => sub {
          $handle->destroy;
          undef $handle;
        },
      );

      $self->data($handle);
      $con->send_response(200 => "Port command successful");
      $self->done;

    };

  }
  else
  {
    $con->send_response(500 => "Illegal PORT command");
    $self->done;
    return;
  }
}

=item REST

=cut

sub help_rest { 'REST <sp> byte-count' }

sub cmd_rest
{
  my($self, $con, $req) = @_;

  if($req->args =~ /^\s*(\d+)\s*$/)
  {
    my $offset = $1;
    $con->send_response(350 => "Restarting at $offset.  Send STORE or RETRIEVE to initiate transfer");
    $self->restart_offset($offset);
  }
  else
  {
    $con->send_response(501 => "REST requires a value greater than or equal to 0");
  }
  $self->done;
}

1;

=back

=cut
