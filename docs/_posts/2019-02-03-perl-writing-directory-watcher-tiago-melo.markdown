---
layout: post
title:  "Perl: writing a directory watcher"
date:   2019-02-03 13:26:01 -0300
categories: perl
---
![Perl: writing a directory watcher](/assets/images/2019-02-03-58be17aa-21ab-401e-9f23-5fa6fb6f81df/2019-02-03-banner.jpeg)

Have you ever needed to watch a directory for changes? Let's do this.

## Introduction

Sometimes is useful to monitor a directory and take some action when files or subdirectories are created, deleted or updated. Once I used this approach to write a script whose mission was to generate three different formats of an incoming image file and store them in an Amazon's S3 bucket. In this article we'll see how to effectively monitor a directory.

## Perl modules

- [AnyEvent](https://metacpan.org/pod/AnyEvent)
- [AnyEvent::Loop](https://metacpan.org/pod/AnyEvent::Loop)
- [AnyEvent::Filesys::Notify](https://metacpan.org/pod/AnyEvent::Filesys::Notify)
- [Config::INI::Reader](https://metacpan.org/pod/Config::INI::Reader)

## The script

Let's take a look at a script that monitors a certain directory and prints what were the changes.

```
#!/usr/bin/perl

# This script monitors a directoty for changes.
# Author: Tiago Melo (tiagoharris@gmail.com)

use common::sense;
use AnyEvent;
use AnyEvent::Loop;
use AnyEvent::Filesys::Notify;
use Cwd 'abs_path';
use Config::INI::Reader;
use sigtrap qw/die normal-signals/;

my $config    	= Config::INI::Reader->read_file('../conf/configuration.ini');
my $watch_dir 	= abs_path $config->{general}->{watch_dir};

# this is the function that will process the notifications.
sub process {
  my @notifications = @{$_[0]};

  foreach my $notification (@notifications) {
    my $file_type = $notification->is_dir ? "directory" : "regular file";

    say $notification->path . " was " . $notification->type . " -> $file_type";
  }
}

# here we setup the notifier, specifying 'process' function as the callback.
# we pass to 'process' function a reference of an array of notifications.
my $notifier = AnyEvent::Filesys::Notify->new(
  dirs => [ $watch_dir ],
    cb   => sub {
	  process \@_;
	},

  # http://search.cpan.org/~mgrimes/AnyEvent-Filesys-Notify-1.14/lib/AnyEvent/Filesys/Notify.pm
  #In backends that support it (currently INotify2), parse the events instead of rescanning file system for changed stat() information.
  #Note, that this might cause slight changes in behavior.
  #In particular, the Inotify2 backend will generate an additional 'modified' event
  #when a file changes (once when opened for write, and once when modified).

  parse_events => 0,
);

# Event loop. This script will run until it is interrupted.
AnyEvent::Loop::run;

```

Time to walk through it.

```
my $config    	= Config::INI::Reader->read_file('../conf/configuration.ini');
my $watch_dir 	= abs_path $config->{general}->{watch_dir};

```

Here we are using Config::INI::Reader module to read a property from a .ini file, in order to parameterize our script.

This is how 'configuration.ini' looks like:

```
[general]
watch_dir = ../watched_dir

```

I like to use namespaces in configuration files to keep it more organized. But if you don't want to use one, like this:

```
watch_dir = ../watched_dir

```

Then you'd read the property like this:

```
my $watch_dir 	= abs_path $config->{_}->{watch_dir};

```

Next:

```
# this is the function that will process the notifications.
sub process {
  my @notifications = @{$_[0]};

  foreach my $notification (@notifications) {
    my $file_type = $notification->is_dir ? "directory" : "regular file";

    say $notification->path . " was " . $notification->type . " -> $file_type";
  }
}

```

This function is called with an array of notifications everytime changes occurs in the specified directory. Here we are only printing them; this is the point where we can take actions upon the files.

Next:

```
# here we setup the notifier, specifying 'process' function as the callback.
# we pass to 'process' function a reference of an array of notifications.
my $notifier = AnyEvent::Filesys::Notify->new(
  dirs => [ $watch_dir ],
    cb   => sub {
	  process \@_;
	},

  # http://search.cpan.org/~mgrimes/AnyEvent-Filesys-Notify-1.14/lib/AnyEvent/Filesys/Notify.pm
  #In backends that support it (currently INotify2), parse the events instead of rescanning file system for changed stat() information.
  #Note, that this might cause slight changes in behavior.
  #In particular, the Inotify2 backend will generate an additional 'modified' event
  #when a file changes (once when opened for write, and once when modified).

  parse_events => 0,
);

```

Here we are configuring the notifier. We pass an array of notifications to 'process' function.

Finally:

```
# Event loop. This script will run until it is interrupted.
AnyEvent::Loop::run;

```

We are using an event loop. This script will run until it is interrupted.

## Running

This is the suggested directory structure:

![No alt text provided for this image](/assets/images/2019-02-03-58be17aa-21ab-401e-9f23-5fa6fb6f81df/1549220920929.png)

**bin:** this is were the script is located

**conf:** this is were the configuration file is located

**watched\_dir:** the directory that we are monitoring

Open up a terminal and run the script:

```
$ perl directory_watcher.pl

```

Then, when we drop a file in the 'watched\_dir', this is the output:

```
/home/tiago/desenv/perl/tutorial/watched_dir/image.png was created -> regular file

```

If we modify this file (renaming it to 'image2.png', for example), we will get:

```
/home/tiago/desenv/perl/tutorial/watched_dir/image.png was deleted -> regular file
/home/tiago/desenv/perl/tutorial/watched_dir/image2.png was created -> regular file

```

Finally, if we delete this file we will get:

```
/home/tiago/desenv/perl/tutorial/watched_dir/image2.png was deleted -> regular file

```

It works with directories too. Suppose we have the 'files' directory with this files:

![No alt text provided for this image](/assets/images/2019-02-03-58be17aa-21ab-401e-9f23-5fa6fb6f81df/1549221862030.png)

Then if we drop the 'files' directory to 'watched\_dir', the output will be:

```
/home/tiago/desenv/perl/tutorial/watched_dir/files/image1.png was created -> regular file
/home/tiago/desenv/perl/tutorial/watched_dir/files/image3.png was created -> regular file
/home/tiago/desenv/perl/tutorial/watched_dir/files/image2.png was created -> regular file
/home/tiago/desenv/perl/tutorial/watched_dir/files was created -> directory

```

Likewise, if we modify a file in the 'files' subdirectory, the output will be:

```
/home/tiago/desenv/perl/tutorial/watched_dir/files/image1.png was deleted -> regular file
/home/tiago/desenv/perl/tutorial/watched_dir/files/image11.png was created -> regular file

```

And if we delete the subdirectory 'files', the output will be:

```
/home/tiago/desenv/perl/tutorial/watched_dir/files was deleted -> directory
/home/tiago/desenv/perl/tutorial/watched_dir/files/image2.png was deleted -> regular file
/home/tiago/desenv/perl/tutorial/watched_dir/files/image3.png was deleted -> regular file
/home/tiago/desenv/perl/tutorial/watched_dir/files/image11.png was deleted -> regular file

```

## Conclusion

Through this simple example we learnt how we can monitor a directory for changes in a fast and reliable way.

## Download the source code

Here: [https://bitbucket.org/tiagoharris/directory-watcher/src/master/](https://bitbucket.org/tiagoharris/directory-watcher/src/master/)
