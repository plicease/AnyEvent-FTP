package AnyEvent::FTP::Server::OS::UNIX;

use strict;
use warnings;
use 5.010;
use Moo;

# ABSTRACT: UNIX implementations for AnyEvent::FTP
# VERSION

=head1 SYNOPSIS

 use AnyEvent::FTP::Server::OS::UNIX;
 
 # interface using user fred
 my $unix = AnyEvent::FTP::Server::OS::UNIX->new('fred');
 $unix->jail;            # chroot
 $unix->drop_privileges; # transform into user fred

=head1 DESCRIPTION

This class provides some utility functionality for interacting with the
UNIX and UNIX like operating systems.

=cut

sub BUILDARGS
{
  my($class, $query) = @_;
  my($name, $pw, $uid, $gid, $quota, $comment, $gcos, $dir, $shell, $expire) = getpwnam $query;
  die "user not found" unless $name;

  return {
    name  => $name,
    uid   => $uid,
    gid   => $gid,
    home  => $dir,
    shell => $shell,
  }
}

=head1 ATTRIBUTES

=head2 name

The user's username

=head2 uid

The user's UID

=head2 gid

The user's GID

=head2 home

The user's home directory

=head2 shell

The user's shell

=cut

has $_ => ( is => 'ro', required => 1 ) for (qw( name uid gid home shell ));

=head2 groups

List of groups (as GIDs) that the user also belongs to.

=cut

has groups => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $name = shift->name;
    my @groups;
    setgrent;
    my @grent;
    while(@grent = getgrent)
    {
      my($group,$pw,$gid,$members) = @grent;
      foreach my $member (split /\s+/, $members)
      {
        push @groups, $gid if $member eq $name;
      }
    }
    \@groups;
  },
);

=head1 METHODS

=head2 jail

 $unix->jail;

C<chroot> to the users' home directory.  Requires root and the chroot function.

=cut

sub jail
{
  my($self) = @_;
  chroot $self->home;
  return $self;
}

=head2 drop_privileges

 $unix->drop_privileges;

Drop super user privileges

=cut

sub drop_privileges
{
  my($self) = @_;

  $) = join ' ', $self->gid, $self->gid, @{ $self->groups };
  $> = $self->uid;

  $( = $self->gid;
  $< = $self->uid;

  return $self;
}

1;
