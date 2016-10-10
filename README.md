# Panda Saver
A Pandora client to save your favorite songs locally!
_Because who needs a terms of service_

## Prerequisites
This script takes advantage of three modules.

  - `WebService::Pandora` [Github](https://github.com/defc0n/WebService-Pandora)
  - `MP3::Tag` Available via CPAN
  - `LWP::Simple` Available via CPAN

## Usage
Simply run the script and i'll walk you through setting up the configuration.

`perl panda-saver.pl`

Or, you can provide arguments for the configuration.

`perl panda-saver.pl [<directory> <email> <password>]`

It should give you a list of your stations, from there, enter in a number and it'll begin downloading and saving the files to the directory of your choosing.
