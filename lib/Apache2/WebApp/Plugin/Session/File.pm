#----------------------------------------------------------------------------+
#
#  Apache2::WebApp::Plugin::Session::File - Plugin providing session storage
#
#  DESCRIPTION
#  Store persistent data on the filesystem.
#
#  AUTHOR
#  Marc S. Brooks <mbrooks@cpan.org>
#
#  This module is free software; you can redistribute it and/or
#  modify it under the same terms as Perl itself.
#
#----------------------------------------------------------------------------+

package Apache2::WebApp::Plugin::Session::File;

use strict;
use base 'Apache2::WebApp::Plugin';
use Apache::Session::File;
use Apache::Session::Lock::File;
use File::Path;
use Params::Validate qw( :all );

our $VERSION = 0.10;

#~~~~~~~~~~~~~~~~~~~~~~~~~~[  OBJECT METHODS  ]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

#----------------------------------------------------------------------------+
# new()
#
# Constructor method used to instantiate a new Session object.

sub new {
    my $class = shift;
    return bless( {}, $class );
}

#----------------------------------------------------------------------------+
# create( \%controller, $name, \%data )
#
# Create a new file based session.

sub create {
    my ( $self, $c, $name, $data_ref )
      = validate_pos( @_,
          { type => OBJECT  },
          { type => HASHREF },
          { type => SCALAR  },
          { type => HASHREF }
          );

    my $doc_root = $c->config->{apache_doc_root};

    my $tmp1 = "$doc_root/tmp/$name/session";
    my $tmp2 = "$doc_root/tmp/$name/lock";

    if ( -d $tmp1 && -d $tmp2 ) {
        my $l = new Apache::Session::Lock::File;

        # remove files older than 1 hour
        $l->clean( $tmp2, 3600 );
    }
    else {

        # create new /tmp directories
        mkpath($tmp1);
        mkpath($tmp2);
    }

    my %session;

    eval {
        tie %session, 'Apache::Session::File', undef, {
            Directory     => $tmp1,
            LockDirectory => $tmp2,
        };
    };

    if ($@) {
        $self->error("Failed to create session: $@");
    }

    foreach my $key (keys %$data_ref) {
        $session{$key} = $data_ref->{$key};     # merge hash key/values
    }

    my $id = $session{_session_id};

    untie %session;

    $c->plugin('Cookie')->set( $c, {
        name    => $name,
        value   => $id,
        expires => $c->config->{session_expires} || '24h',
      });

    return $id;
}

#----------------------------------------------------------------------------+
# get( \%controller, $name )
#
# Return session data as a hash reference.

sub get {
    my ( $self, $c, $name )
      = validate_pos( @_,
          { type => OBJECT  },
          { type => HASHREF },
          { type => SCALAR  }
          );

    my $doc_root = $c->config->{apache_doc_root};

    my $cookie = $c->plugin('Cookie')->get($name);

    my $session_id = ($cookie) ? $cookie : "null";

    my %session;

    eval {
        tie %session, 'Apache::Session::File', $session_id, {
            Directory     => "$doc_root/tmp/$name/session",
            LockDirectory => "$doc_root/tmp/$name/lock",
        };
    };

    unless ($@) {
        my %values = %session;

        untie %session;

        return \%values;
    }

    return;
}

#----------------------------------------------------------------------------+
# delete( \%controller, $name )
#
# Delete an existing session.

sub delete {
    my ( $self, $c, $name )
      = validate_pos( @_,
          { type => OBJECT  },
          { type => HASHREF },
          { type => SCALAR  }
          );

    my $doc_root = $c->config->{apache_doc_root};

    my $cookie = $c->plugin('Cookie')->get($name);

    my $id = ($cookie) ? $cookie : "null";

    my %session;

    eval {
        tie %session, 'Apache::Session::File', $id, {
            Directory     => "$doc_root/tmp/$name/session",
            LockDirectory => "$doc_root/tmp/$name/lock",
        };
    };

    unless ($@) {
        tied(%session)->delete;

        $c->plugin('Cookie')->delete( $c, $name );
    }

    return;
}

#----------------------------------------------------------------------------+
# update( \%controller, $name, \%data );
#
# Update existing session data.

sub update {
    my ( $self, $c, $name, $data_ref )
      = validate_pos( @_,
          { type => OBJECT  },
          { type => HASHREF },
          { type => SCALAR  },
          { type => HASHREF }
          );

    my $doc_root = $c->config->{apache_doc_root};

    my $cookie = $c->plugin('Cookie')->get($name);

    my $id = ($cookie) ? $cookie : "null";

    my %session;

    eval {
        tie %session, 'Apache::Session::File', $id, {
            Directory     => "$doc_root/tmp/$name/session",
            LockDirectory => "$doc_root/tmp/$name/lock",
        };
    };

    if ($@) {
        $self->error("Failed to create session: $@");
    }

    foreach my $key (keys %$data_ref) {
        $session{$key} = $data_ref->{$key};     # merge hash key/values
    }

    untie %session;

    return;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~[  PRIVATE METHODS  ]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

#----------------------------------------------------------------------------+
# _init(\%params)
#
# Return a reference of $self to the caller.

sub _init {
    my ( $self, $params ) = @_;
    return $self;
}

1;

__END__

=head1 NAME

Apache2::WebApp::Plugin::Session::File - Plugin providing session storage

=head1 SYNOPSIS

  my $obj = $c->plugin('Session')->method( ... );     # Apache2::WebApp::Plugin::Session->method()

    or

  $c->plugin('Session')->method( ... );

=head1 DESCRIPTION

Store persistent data on the filesystem.

=head1 PREREQUISITES

This package is part of a larger distribution and was NOT intended to be used 
directly.  In order for this plugin to work properly, the following packages
must be installed:

  Apache2::WebApp
  Apache2::WebApp::Plugin::Cookie
  Apache2::WebApp::Plugin::Session
  Apache::Session::File
  Apache::Session::Lock::File
  Params::Validate

=head1 INSTALLATION

From source:

  $ tar xfz Apache2-WebApp-Plugin-Session-File-0.X.X.tar.gz
  $ perl MakeFile.PL PREFIX=~/path/to/custom/dir LIB=~/path/to/custom/lib
  $ make
  $ make test     <--- Make sure you do this before contacting me
  $ make install

Perl one liner using CPAN.pm:

  perl -MCPAN -e 'install Apache2::WebApp::Plugin::Session::File'

Use of CPAN.pm in interactive mode:

  $> perl -MCPAN -e shell
  cpan> install Apache2::WebApp::Plugin::Session::File
  cpan> quit

Just like the manual installation of Perl modules, the user may need root access during
this process to insure write permission is allowed within the installation directory.

=head1 CONFIGURATION

Unless it already exists, add the following to your projects I<webapp.conf>

  [session]
  storage_type = file
  expires = 1h

=head1 OBJECT METHODS

Please refer to L<Apache2::WebApp::Plugin::Session> for method info.

=head1 SEE ALSO

L<Apache2::WebApp>, L<Apache2::WebApp::Plugin>, L<Apache2::WebApp::Plugin::Cookie>,
L<Apache2::WebApp::Plugin::Session>, L<Apache::Session>, L<Apache::Session::File>,
L<Apache::Session::Lock::File>

=head1 AUTHOR

Marc S. Brooks, E<lt>mbrooks@cpan.orgE<gt> - L<http://mbrooks.info>

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
