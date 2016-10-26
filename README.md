# Panda
A Pandora client to save your favorite songs locally!
_Because who needs a terms of service_

## Dependencies
- `Cwd`
- `File::Path`
- `LWP::Simple`
  - `Mozilla::CA` If you get the error about not knowing which certificates to trust, update this module.
- `WebService::Pandora`
  - `Crypt::Blowfish`
  - `Crypt::ECB`
- `MP3::Tag`
- `MP3::Info`

## Usage
Simply run the script and it'll walk you through setting up the configuration.

`perl panda.pl`


### With Arguments

`perl panda.pl [<directory> <email> <all?>]`
- `directory`
  - This is where the music gets saved. if the directory doesn't exist, it'll create it. Panda will automatically sort your music in this directory as `./Artist/Album/Track.xxx`
- `email`
  - This is your pandora email. As of some version of this program, you can no longer use email as a command line argument. This is for privacy, now we hide the input while you type your password to login.
- `all`
  - This value should either be 0 or 1. 0 will use the classic behavior of choosing individual stations to download from, but 1 will automatically select every station and rip from those. **warning** This causes some weird behavior with a lot of stations if your terminal isn't large enough to show all lines.


## Errors
Currently there's only one error it handles, 13: Bad Connectivity. It'll try to re-login and continue downloading. This may or may not be the correct way to handle it.

For every other error, a thread will die. Hopefully it'll tell you about that.

## Compiling
I've tested compiling only on linux and OSX and it seems PP is able to do this quite fine. Assuming you have the pure perl JSON implementation things go well.

## Disclaimer
I am not responsible for your dumbass actions. If you manage to get banned from Pandora by using this utility it's your own fault. This software is provided as is, yada yada yada. If anything good or bad happens, it's your fault not mine. This is probably for educational purposes or something.
