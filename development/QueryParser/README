QueryParser
=====================================================

This application can execute a SELECT query into any "DBI-connectable" database and return the metadata from the columns available in the table
(or tables, if there are multiple). This is handy to generate documentation for ETL process and the application can export such metadata to text,
CSV, HTML or XML.

Since the SELECT recovered data is just ignored, it is a good practice to limit the output from the query by using the related statement for your database
of choice (for example, "ROWNUM" in Oracle and "LIMIT" for MySQL).

The script "queryparser.plx" starts the application and it is a good idea to associate the extension "plx" to the wperl interpreter, where it is available
to avoid opening an additional command line window with application.

INSTALLATION

To install this module type the following:

   perl Makefile.PL
   make
   make test
   make install
   
Also check the config.ini file that must be edited to provide DB connection details. Beware that a valid DBI "driver" must be available to connect
to the desired database as well the SELECT must use a syntax understandble by the database. The "driver" key must have a value that always begins with
'DBI:'.

DEPENDENCIES

See Makefile.PL (PREREQ_PM) for details.

COPYRIGHT AND LICENCE

This software is copyright (c) 2013 of Alceu Rodrigues de Freitas Junior, arfreitas@cpan.org

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
along with Siebel COM.  If not, see http://www.gnu.org/licenses/.
