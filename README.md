Google Doc => Latex parser
=========================
Does some simple parsing of google drive documents into latex.
Don't expect this to do all the work for you, but it should produce a base for you to do the final touch up on.

Features
------
* Formulas
* Images
* Headings

Things that are not implemented
------------------
* Tables
* Text styling (Italic/bold/underline etc)
* Lists

These things might be implemented in the future

Setup
=====
1. Register a app in the google cloud console: https://cloud.google.com/console
1. Make sure to activate the drive api
1. Download the client_secrets.json and put it in this directory
1. bundle install
1. Run the program: bundle exec ruby convert.rb [google-doc-id] (doc id is the string after /document/d/ in the document url)
1. Log in the first time


