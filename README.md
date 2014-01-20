Google Doc => Latex parser
=========================
Does some simple parsing of google drive documents into latex.
Don't expect this to do all the work for you, but it should produce a base for you to do the final touch up on.

Features
------
* Formulas
* Images
* Headings
* Tables
* Lists
* References lables etc are handled with some hacks (todo: describe these)

TODO
------------------
* Text styling (Italic/bold/underline etc)
* Reference list
* Better detection of inline equation

Setup
=====
1. Register a app in the google cloud console: https://cloud.google.com/console
1. Make sure to activate the drive api
1. Download the client_secrets.json and put it in this directory
1. bundle install
1. Run the program: bundle exec ruby convert.rb [google-doc-id] (doc id is the string after /document/d/ in the document url)
1. Log in the first time


