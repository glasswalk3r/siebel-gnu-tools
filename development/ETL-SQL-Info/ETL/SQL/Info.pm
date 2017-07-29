package ETL::SQL::Info;
# VERSION

=pod

=head1 NAME

ETL::SQL::Info - provides data information about SQL based ETL

=head1 DESCRIPTION

This module is Pod only. Check out other modules for implementation details.

The main functionaly of this distribution is to enable automatic retrieval of information
from queries used for ETL processed on relational databases.

It was created to generate automatic documentation for queries used in ETL: the end user
provides a SQL query, that is submitted to the database to be evaluated, and if it is valid, 
metadata is recovered from the columns described in the query.

This is useful if it is necessary to describe the expected format of data to be exported/imported
into different systems. Since the data is automatically recovered, very little needs to be done to
provide such information. It is specially useful if you have several columns C<JOIN>ed from different
tables in the database (or several databases, it doesn't matter).

The data that is recovered is described at L<ETL::SQL::Info::Result>.

=head1 SEE ALSO

=over

=item *

L<ETL::SQL::Info::Result>

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
