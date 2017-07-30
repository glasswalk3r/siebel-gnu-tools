package ETL::SQL::Info::GUI::ApplicationView;

# only initializes WxPerl application for the Frame to be shown
use warnings;
use strict;
use ETL::SQL::Info::GUI::FrameView;
use ETL::SQL::Info::DAO;
use base qw(Wx::App);

# VERSION

=pod

=head1 NAME

ETL::SQL::Info::GUI::ApplicationView - implements an Wx application

=head1 DESCRIPTION

This class inherits from L<Wx::App> to be able to override the C<OnInit> method.

It also combine object in other to setup the GUI.

=head1 METHODS

=head2 OnInit

Overrided from parent class to define specifics of the GUI interface.

Also registries the L<ETL::SQL::Info::DAO> model to underline view events.

=cut

sub OnInit {
    my $self  = shift;
    my $frame = ETL::SQL::Info::GUI::FrameView->new(
        undef,                                    # Parent window
        -1,                                       # Window id
        'Documentation for export interfaces',    # Title
        [ 300, 300 ],                             # position X, Y
        [ 600, 480 ]                              # size X, Y
    );
    $self->SetTopWindow($frame);                  # Define the toplevel window
    $frame->Show(1);                              # Show the frame
    ETL::SQL::Info::DAO->add_subscriber( 'new_query',
        $frame->get_query_callback() );
}

=head1 SEE ALSO

=over

=item *

L<Wx::App>

=item *

L<ETL::SQL::Info::DAO>

=back

=head1 AUTHOR

Alceu Rodrigues de Freitas Junior, E<lt>arfreitas@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 of Alceu Rodrigues de Freitas Junior, E<lt>arfreitas@cpan.orgE<gt>

This file is part of Siebel GNU Tools project.

Siebel GNU Tools is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Siebel GNU Tools is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Siebel GNU Tools.  If not, see <http://www.gnu.org/licenses/>.

=cut

1;
