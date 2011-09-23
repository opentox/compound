OpenTox Compound
================

- An [OpenTox](http://www.opentox.org) REST Webservice 
- Implements the [OpenTox compound API 1.2](http://opentox.org/dev/apis/api-1.2/structure)

REST operations
---------------

    Get the representation of a compound  GET   /compound/{id}  -                         Compound representation   200,404,500
    Create a new compound                 POST  /compound       Compound representation   URIs for new compounds    200,400,500

Supported MIME formats (http://chemical-mime.sourceforge.net/)[http://chemical-mime.sourceforge.net/]
--------------------------------------------------------------

- chemical/x-daylight-smiles (default)
- chemical/x-inchi
- chemical/x-mdl-sdfile
- text/plain (chemical names)
- image/gif (returns image uri, output only)

Examples
--------

### Create a compound_uri from smiles

    curl -X POST  -H "Content-Type:chemical/x-daylight-smiles" --data-binary "c1ccccc1" http://webservices.in-silico.ch/compound

### Create a compound_uri from a SD file

    curl -X POST -H "Content-Type:chemical/x-mdl-sdfile" --data-binary @my.sdf http://webservices.in-silico.ch/compound

### Create a compound_uri from name (or any other identifier that can be resolved with the Cactus service)

    curl -X POST  -H "Content-Type:text/plain" --data-binary "Benzene" http://webservices.in-silico.ch/compound

### Create a compound_uri from CAS

    curl -X POST  -H "Content-Type:text/plain" --data-binary "71-43-2" http://webservices.in-silico.ch/compound

### Get SMILES for a compound_uri

    curl http://webservices.in-silico.ch/compound/InChI=1S/C6H6/c1-2-4-6-5-3-1/h1-6H

### Get a SD file for a compound_uri:

    curl -H "Accept:chemical/x-mdl-sdfile" http://webservices.in-silico.ch/compound/InChI=1S/C6H6/c1-2-4-6-5-3-1/h1-6H

### Get all names for a compound_uri

    curl -H "Accept:text/plain" http://webservices.in-silico.ch/compound/InChI=1S/C6H6/c1-2-4-6-5-3-1/h1-6H

[API documentation](http://rdoc.info/github/opentox/compound)
-------------------------------------------------------------

Copyright (c) 2009-2011 Christoph Helma, Martin Guetlein, Micha Rautenberg, Andreas Maunz, David Vorgrimmler, Denis Gebele. See LICENSE for details.

