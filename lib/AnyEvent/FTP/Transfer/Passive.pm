package AnyEvent::FTP::Transfer::Passive;

use strict;
use warnings;
use v5.10;
use base qw( AnyEvent::FTP::Transfer );
use AnyEvent::Socket qw( tcp_connect );

# ABSTRACT: Passive transfer class for asynchronous ftp client
# VERSION

# args:
#  - command
#  - destination
#  - restart
sub new
{
  my($class) = shift;
  my $args   = ref $_[0] eq 'HASH' ? (\%{$_[0]}) : ({@_});
  $args->{restart} //= 0;
  my $self = $class->SUPER::new($args);
  
  my $destination = $self->convert_destination($args->{destination});
  
  my $data_connection = sub {
    my $res = shift;
    return if $res->is_preliminary;
    my($ip, $port) = $res->get_address_and_port;
    if(defined $ip && defined $port)
    {
      tcp_connect $ip, $port, sub {
        my($fh) = @_;
        unless($fh)
        {
          return "unable to connect to data port: $!";
        }
        
        $self->xfer($fh,$destination);
      };
      return;
    }
    else
    {
      $res;
    }
  };

  $self->{client}->push_command(
    [ 'PASV', undef, $data_connection ],
    ($args->{restart} > 0 ? ([ REST => $args->{restart} ]) : ()),
    $args->{command},
    $self->{cv},
  );

  $self->{cv}->cb(sub {
    my $res = eval { shift->recv } // $@;
    $self->emit('close' => $res);
  });
  
  $self;
}

package AnyEvent::FTP::Transfer::Passive::Fetch;

use base qw( AnyEvent::FTP::Transfer::Passive );
use Role::Tiny::With;

with 'AnyEvent::FTP::Role::FetchTransfer';

package AnyEvent::FTP::Transfer::Passive::Store;

use base qw( AnyEvent::FTP::Transfer::Passive );
use Role::Tiny::With;

with 'AnyEvent::FTP::Role::StoreTransfer';

package AnyEvent::FTP::Transfer::Passive::List;

use base qw( AnyEvent::FTP::Transfer::Passive );
use Role::Tiny::With;

with 'AnyEvent::FTP::Role::ListTransfer';

1;
