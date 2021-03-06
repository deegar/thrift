#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#

use 5.10.0;
use strict;
use warnings;

use Thrift;
use Thrift::Exception;
use Thrift::Transport;

use IO::Socket::INET;
use IO::Select;

package Thrift::Socket;
use base qw( Thrift::Transport );
use version 0.77; our $VERSION = version->declare("$Thrift::VERSION");

#
# Construction and usage
#
# my $opts = {}
# my $socket = Thrift::Socket->new(\%opts);
#
# options:
#
# host        => host to connect to
# port        => port to connect to
# sendTimeout => timeout used for send and for connect
# recvTimeout => timeout used for recv
#

sub new
{
    my $classname = shift;
    my $opts      = shift;

    # default settings:
    my $self = {
        host         => 'localhost',
        port         => 9090,
        recvTimeout  => 10000,
        sendTimeout  => 10000,
        proto        => 'tcp',
        handle       => undef
    };

    if (defined $opts and ref $opts eq ref {}) {

      # argument is a hash of options so override the defaults
      $self->{$_} = $opts->{$_} for keys %$opts;

    } else {

      # older style constructor takes 3 arguments, none of which are required
      $self->{host} = $opts || 'localhost';
      $self->{port} = shift || 9090;

    }

    return bless($self,$classname);
}


sub setSendTimeout
{
    my $self    = shift;
    my $timeout = shift;

    $self->{sendTimeout} = $timeout;
}

sub setRecvTimeout
{
    my $self    = shift;
    my $timeout = shift;

    $self->{recvTimeout} = $timeout;
}


#
# Tests whether this is open
#
# @return bool true if the socket is open
#
sub isOpen
{
    my $self = shift;

    if( defined $self->{handle} ){
        return ($self->{handle}->handles())[0]->connected;
    }

    return 0;
}

#
# Connects the socket.
#
sub open
{
    my $self = shift;

    my $sock = $self->__open() || do {
        my $error = ref($self).': Could not connect to '.$self->{host}.':'.$self->{port}.' ('.$!.')';
        die Thrift::TTransportException->new($error, Thrift::TTransportException::NOT_OPEN);
    };

    $self->{handle} = IO::Select->new( $sock );
}

#
# Closes the socket.
#
sub close
{
    my $self = shift;
    if( defined $self->{handle} ) {
      $self->__close();
    }
}

#
# Uses stream get contents to do the reading
#
# @param int $len How many bytes
# @return string Binary data
#
sub readAll
{
    my $self = shift;
    my $len  = shift;


    return unless defined $self->{handle};

    my $pre = "";
    while (1) {

        my $sock = $self->__wait();
        my $buf = $self->__recv($sock, $len);

        if (!defined $buf || $buf eq '') {

            die Thrift::TTransportException->new(ref($self).': Could not read '.$len.' bytes from '.
                               $self->{host}.':'.$self->{port}, Thrift::TTransportException::END_OF_FILE);

        }
        elsif ((my $sz = length($buf)) < $len) {

            $pre .= $buf;
            $len -= $sz;

        }
        else {
            return $pre.$buf;
        }
    }
}

#
# Read from the socket
#
# @param int $len How many bytes
# @return string Binary data
#
sub read
{
    my $self = shift;
    my $len  = shift;

    return unless defined $self->{handle};

    my $sock = $self->__wait();
    my $buf = $self->__recv($sock, $len);

    if (!defined $buf || $buf eq '') {

        die Thrift::TTransportException->new(ref($self).': Could not read '.$len.' bytes from '.
                           $self->{host}.':'.$self->{port}, Thrift::TTransportException::END_OF_FILE);

    }

    return $buf;
}


#
# Write to the socket.
#
# @param string $buf The data to write
#
sub write
{
    my $self = shift;
    my $buf  = shift;

    return unless defined $self->{handle};

    while (length($buf) > 0) {
        #check for timeout
        my @sockets = $self->{handle}->can_write( $self->{sendTimeout} / 1000 );

        if(@sockets == 0){
            die Thrift::TTransportException->new(ref($self).': timed out writing to bytes from '.
                                       $self->{host}.':'.$self->{port}, Thrift::TTransportException::TIMED_OUT);
        }

        my $sent = $self->__send($sockets[0], $buf);

        if (!defined $sent || $sent == 0 ) {

            die Thrift::TTransportException->new(ref($self).': Could not write '.length($buf).' bytes '.
                                 $self->{host}.':'.$self->{host}, Thrift::TTransportException::END_OF_FILE);

        }

        $buf = substr($buf, $sent);
    }
}

#
# Flush output to the socket.
#
sub flush
{
    my $self = shift;

    return unless defined $self->{handle};

    my $ret = ($self->{handle}->handles())[0]->flush;
}

###
### Overridable methods
###

#
# Open a connection to a server.
#
sub __open
{
    my $self = shift;
    return IO::Socket::INET->new(PeerAddr => $self->{host},
                                 PeerPort => $self->{port},
                                 Proto    => $self->{proto},
                                 Timeout  => $self->{sendTimeout} / 1000);
}

#
# Close the connection
#
sub __close
{
  my $self = shift;
    CORE::close(($self->{handle}->handles())[0]);
}

#
# Read data
#
# @param[in] $sock the socket
# @param[in] $len the length to read
# @returns the data buffer that was read
#
sub __recv
{
  my $self = shift;
  my $sock = shift;
  my $len = shift;
  my $buf = undef;
  $sock->recv($buf, $len);
  return $buf;
}

#
# Send data
#
# @param[in] $sock the socket
# @param[in] $buf the data buffer
# @returns the number of bytes written
#
sub __send
{
    my $self = shift;
    my $sock = shift;
    my $buf = shift;
    return $sock->send($buf);
}

#
# Wait for data to be readable
#
# @returns a socket that can be read
#
sub __wait
{
    my $self = shift;
    my @sockets = $self->{handle}->can_read( $self->{recvTimeout} / 1000 );

    if (@sockets == 0) {
        die Thrift::TTransportException->new(ref($self).': timed out reading from '.
                                   $self->{host}.':'.$self->{port}, Thrift::TTransportException::TIMED_OUT);
    }

    return $sockets[0];
}


1;
