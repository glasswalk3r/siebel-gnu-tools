# NAME

ETL::SQL::Info - provides data information about SQL based ETL

# DESCRIPTION

This module is Pod only. Check out other modules for implementation details.

The main functionaly of this distribution is to enable automatic retrieval of information
from queries used for ETL processed on relational databases.

It was created to generate automatic documentation for queries used in ETL: the end user
provides a SQL query, that is submitted to the database to be evaluated, and if it is valid, 
metadata is recovered from the columns described in the query.

This is useful if it is necessary to describe the expected format of data to be exported/imported
into different systems. Since the data is automatically recovered, very little needs to be done to
provide such information. It is specially useful if you have several columns `JOIN`ed from different
tables in the database (or several databases, it doesn't matter).

That being said, it only makes sense to use this project with `SELECT` statements.

# INSTALL

This program depends on wxWidgets, Perl and some Perl modules.

In order to work, first install the wxWidgets (refer to it's [documentation](http://wxwidgets.org/) for that).

Then, install [Perl](http://perl.org) and finally, choose your prefered way to install this distribution itself.

For that, you can use [CPAN](http://cpan.org), or `git clone` this repository and it's `cpanfile` (and avoid the many
dependencies from `Dist::Zilla`). Both ways, your CPAN client will take care of the dependencies for you (assuming you have
a connection to the Internet or a local CPAN repository).

Of course, the good and old `perl Makefile.PL`, `make` and `make install` is still available, but it is not much fun these days.

# AUTHOR

Alceu Rodrigues de Freitas Junior, <arfreitas@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 of Alceu Rodrigues de Freitas Junior, <arfreitas@cpan.org>

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
along with Siebel GNU Tools.  If not, see (http://www.gnu.org/licenses/).
