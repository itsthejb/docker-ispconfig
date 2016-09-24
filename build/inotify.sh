#!/bin/bash
#
# descr: /etc/passwd, /etc/group and /etc/shadow
#        are not linkable nor mountable in a docker container (1.11.x).
#        If inotfy detact changes, the changed file will be stored on the volume. 
#        While container startup the files will be copied from the volume.
#
list=`cat /start-data-inotify.dat`
echo "docker-ispconfig: starting inotify : " $list
while true ; do
  FI=`inotifywait -q -e modify -e attrib --format %w%f $list`
  echo "docker-ispconfig: inotify detects modification :  <$FI>"
  ndir=`echo $FI | sed -e  's/\//-/g'`
  ndir=${ndir#-}
  cp -va $FI /volume/data/inotify/$ndir
done

