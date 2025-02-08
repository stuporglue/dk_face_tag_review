DK Face Tag Review
==================

This is a bash script/program that makes it possible to review recent digiKam face tagging sessions. 

It is not official or supported by digiKam. 

What is the use case? 
---------------------

I have hundreds of thousands of photos. Some of my People have 12,000 or more photos tagged to them. 

As I tag additional photos, sometimes I type the wrong name, sometimes I have an extra photo selected. Sometimes I'm tagging while distracted and just want to double check my work!

digiKam doesn't currently offer *undo* or *recently tagged* type functionality for face tagging. 

This tool provides a way to find those mistakes or to review a tagging session. 

### Other use cases

* Now that I can review recent tagging, I can let my kids tag their cousins or something, then review their work. 

How it works
------------

The script has a menu option titled "Setup" which will add a new column (`created_ts`) to the ImageTags table. New columns will have `created_ts` set to the time the tag was added. 

Later, after a tagging session, you can come back into the script and add a review tag (named **DK Face Tag Review**) to photos in two ways. 


Features
--------


Requirements and Installation
-----------------------------

### Requirements

* Bash
* MySQL command-line client
* A config file at ~/.config/digikamrc

This bash script assumes that your digiKam database is in MySQL, and that your config file is at ~/.config/digikamrc. You will need the mysql client available in your path. 

### Setup
Exit digiKam. 

Download `dk_face_tag_review` and put it somewhere convenient. 

Make `dk_face_tag_review` executable and run it. 

![The first run options are pretty simple](img/first_run.png)

Press `c` to connect to your database. DK Face Tag Review will get the database info from your digikamrc file. The password there is encrypted, so you will be prompted for your password. 

![Getting the database connected](img/first_run_2.png)

After you enter your database password, DK Face Tag Review will ask if you want to be prompted before it runs any SQL. Press `y` or `enter` to see all the SQL. Press `n` to just trust what it is running. 


![Backup the database before using](img/first_run_3.png)

When you ask DK Face Tag Review to run Setup, it will ask if you want to make a database backup first. This will be put in the current working directory. 

![Backup the database before using](img/first_run_3.png)

After running the backup, a new timestamp column will be added to the ImageTags table. Existing rows will have a NULL value. New rows will get the current timestamp. 

You can now re-launch digiKam!

Usage
-----

With DK Face Tag Review set up, you can now tag as normal. 

![Tagging a bunch of photos](img/tagging.png)

When you want to review some tagging, run `dk_face_tag_review` again. 

![We can use `i` to see info about the status.](img/info.png)

In the info we can now see that there are 61 markable photos. These are photos which have been tagged since DK Face Tag Review was set up. 

I think I just made a mistake within the last few faces I tagged. 

![Marking the last 30 photos for review](img/last_n.png)

I can either mark the last N photos tagged for review, or I can mark all photos tagged in the last N minutes/hours/days.

![Now I navigate to the DK Face Tag Review tag to check](img/reviewing.png)

The images I marked should now appear under the tag **DK Face Tag Review**


Questions
---------

Q: I accidentally tagged 1000 faces as "John" which is probably wrong. Can this tool help me? 
A: If you ran Setup before tagging, then yes! If you just found this tool, then run Setup now and we'll be there for you next time. 
