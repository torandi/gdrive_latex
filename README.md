Google Doc => Latex parser
=========================
Does some simple parsing of google drive documents into latex.
Don't expect this to do all the work for you, but it should produce a base for you to do the final touch up on.

In the beginning of convert.rb there is a variable, @use_chapters. Set that to false if you don't want to use chapters.

Features
------
* Formulas
* Images
* Headings
* Tables
* Lists
* References lables etc are handled with some hacks
* Text styling (Italic/bold/underline etc)
* Reference list

Setup
=====
1. Register a app in the google cloud console: https://cloud.google.com/console
1. Make sure to activate the drive api
1. Download the client_secrets.json and put it in this directory
1. Create the output directory (latex/) or symlink somewhere
1. bundle install
1. Run the program: bundle exec ruby convert.rb [google-doc-id] (doc id is the string after /document/d/ in the document url)
1. Log in the first time

Troubleshooting
==============
If you get an auth error, try deleting convert-oauth2.json

Template
=======
The default template is default.tex, you can specify your own as a second argument to the program.
The syntax is simple, #{keyword} is replaced with content.
The following keywords exists:

* title: The documents title
* author: The last user to modify the document
* yield: Insert the main content here
* abstract: Insert the abstract here


Markup and syntax
=============
Title, subtitle, Headings, Mathematical formulas, Images, Tables, List and text formating are all converted from the document.

For some more complex features, you can add some markup to your document.

* abstract: To specify a abstract, use <abstract>Your text</abstract>. Only one can be specified in a document
* Unnumbered heading: Add [nonumber] at the end of the heading. Ie: "Preface[nonumber]"
* References and labels: Add [label:name] to a heading: "My Heading[label:my_heading]" and reference with [ref:my_heading]
* Citation: Use {cite:...}, bibliography can be created with <reference>[list]</reference>, where [list] is a bulleted list in the document.
* Image caption: add [image_caption:Text] _Before_ a image, to add a caption

It should also be possible to inline latex in your document, if you need something special and don't want to give up on google doc just yet.
