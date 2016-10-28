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
  - `Crypt::ECB`e
- `MP3::Tag`
- `MP3::Info`

## Usage
Simply run the script and it'll walk you through setting up the configuration.

`perl panda.pl`


### With Arguments
`perl panda.pl [<directory> <email>]`
- `directory`
  - This is where the music gets saved. if the directory doesn't exist, it'll create it. Panda will automatically sort your music in this directory as `./Artist/Album/Track.xxx`
- `email`
  - This is your pandora email. As of some version of this program, you can no longer use email as a command line argument. This is for privacy, now we hide the input while you type your password to login.

### Shell
Panda now has a shell! Here are the commands.
- `start`
  - Starts The default process of crawling pandora. It'll ask you if you want to add all stations, if you choose no, you can add individual stations.
- `search QUERY>`
  - Searches for music, artists, or genres matching your query. It'll ask you if you want to add each returned item. Every 5 it'll ask if you want to keep going down the list, it tends to be quite long.
- `help`
  - Lists commands.
  
## Errors
Currently there's only one error it handles, 13: Bad Connectivity. It'll try to re-login and continue downloading. This may or may not be the correct way to handle it. For every other error, a thread will die. Hopefully it'll tell you about that.

At the time of writing, I'm getting nothing but 500 errors. I honestly wouldn't be surprised if extended use of this has caused them to disable the api entry point.

## Compiling
I've tested compiling only on linux and OSX and it seems PP is able to do this quite fine. Assuming you have the pure perl JSON implementation things go well.

## Disclaimer
I am not responsible for your dumbass actions. If you manage to get banned from Pandora by using this utility it's your own fault. This software is provided as is, yada yada yada. If anything good or bad happens, it's your fault not mine. This is probably for educational purposes or something.
