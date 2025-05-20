#

1. - [ X ] Dependencies are being pulled every time you run a container (apt packages and git pull). The image is build ready.

RUN in docker has mount options. when RUN ends it is umounted?
bind-mount, not copying
mount cache // type - cache - docker's keyword. one directory, which is all apt's packages. this directory is somewhere in /home, .cache/...

RUN options

--init -i -t

2. - [ ] Something
