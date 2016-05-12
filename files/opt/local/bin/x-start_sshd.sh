#!/usr/bin/bash

/usr/bin/rm -f /etc/ssh/ssh_host_* && /usr/bin/ssh-keygen -A && exec /usr/bin/sshd -D

