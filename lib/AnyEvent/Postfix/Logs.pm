package AnyEvent::Postfix::Logs;

use warnings;
use strict;

=head1 NAME

AnyEvent::Postfix::Logs - Event based parsin of Postfix log files

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use AnyEvent::Postfix::Logs;

    my $cv = AnyEvent->condvar;

    AnyEvent::Postfix::Logs->new(
        fh => \*STDIN,
        on_mail   => sub { say "Mail from $_[0]->{from} to ", join(", ", @{ $_[0]->{to} } ) },
        on_finish => sub { $cv->send() },
    );

    # do some more stuff

    $cv->recv;
    ...

=cut

use AnyEvent;
use AnyEvent::Handle;

sub new {
    my ($class, %args) = @_;
    my $self = bless { }, $class;

    $self->{on_mail}   = delete $args{on_mail}   || sub { };
    $self->{on_finish} = delete $args{on_finish} || sub { };

    $self->{fh}        = delete $args{fh} || die "Need an filehandle";

    $self->{messages}  = { };

    $self->{handle} = AnyEvent->io(
        fh     => $self->{fh},
        poll   => 'r',
        cb     => sub { $self->parseline },
    );

    return $self;
}

sub parseline {
    my $self = shift;
    my $line = readline $self->{fh};

    if ( $line =~ m!^(\w\w\w \d\d \d\d:\d\d:\d\d) (\w+) postfix/(\w+)\[\d+\]: ([0-9A-F]+): (.*)! ) {
        my ($time, $server, $cmd, $id, $line) = ($1, $2, $3, $4, $5);

        # Find the message or create a fresh message hash
        my $mail = $self->{messages}->{$id} ||= { id => $id, time => $1, to => [ ] };

        if ( $cmd eq 'qmgr' ) {

            if ($line =~ /^removed$/) {

                $self->{on_mail}->($mail);
                delete $self->{messages}->{$id};

            } else {
                $mail->{from} = $1 if $line =~ /^from=<([^>]+)>/;
            }

        } elsif ( $cmd eq 'cleanup' ) {
            $mail->{msgid} = $1 if $line =~ /^message-id=(<[^>]+>)/;
        } elsif ( $cmd eq 'virtual' ) {
            push @{ $mail->{to} }, $1 if $line =~/^to=<([^>]+)>/
        }

    }

    if ( eof $self->{fh} ) {
        $self->{handle} = undef;
        $self->{on_finish}->();
    }
}

=head1 AUTHOR

Peter Makholm, C<< <peter at makholm.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-anyevent-postfix-logs at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=AnyEvent-Postfix-Logs>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AnyEvent::Postfix::Logs


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=AnyEvent-Postfix-Logs>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/AnyEvent-Postfix-Logs>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/AnyEvent-Postfix-Logs>

=item * Search CPAN

L<http://search.cpan.org/dist/AnyEvent-Postfix-Logs/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Peter Makholm.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of AnyEvent::Postfix::Logs
