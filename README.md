# Panda Saver
A Pandora client to save your favorite songs locally!
_Because who needs a terms of service_

## Prerequisites
This script requires the following modules to run. All should be available via CPAN.

  - `File::Path`
  - `Cwd`
  - `Term::ReadKey`
  - `LWP::Simple`
    - `Mozilla::CA` If you get the error about not knowing which certificates to trust, update this module.
  - `WebService::Pandora`
    - `Crypt::Blowfish`
    - `Crypt::ECB`
  - `MP3::Tag`
  - `MP3::Info`

## Usage
Simply run the script and it'll walk you through setting up the configuration.

`perl panda-saver.pl`

Or, you can provide arguments for the configuration.

`perl panda-saver.pl [<directory> <email> <password>]`

It should give you a list of your stations, from there, enter in a number and it'll begin downloading and saving the files to the directory of your choosing.

## Errors
Currently there's only one error it handles, 13: Bad Connectivity. It'll try to re-login and continue downloading. This may or may not be the correct way to handle it.

For every other error, it'll die. For now this is the action until I run into one enough to automate fixing it.

## Disclaimer
I am not responsible for your dumbass actions. If you manage to get banned from Pandora by using this utility it's your own fault. This software is provided as is, yada yada yada. If anything good or bad happens, it's your fault not mine.
