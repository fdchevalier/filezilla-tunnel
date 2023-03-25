# filezilla-tunnel

This script creates an SSH tunnel and starts Filezilla to use it. The goal is to connect to servers located behind a gateway server.


## Prerequisites

To run the script properly, you need to install:
* `openssh`
* `filezilla`
* `sshpass` (optional)


## Installation

To download the latest version of the files:
```
git clone https://github.com/fdchevalier/filezilla-tunnel
```

For convenience, the script should be accessible system-wide by either including the folder in your `$PATH` or by moving the script in a folder present in your path (e.g. `$HOME/local/bin/`).


## Usage

Run `./filezilla-tunnel.sh -h` to list available options.

Common usage: `filezilla-tunnel.sh -u username -s server1 server2`
