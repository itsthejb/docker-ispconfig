#!/bin/bash

# Files.
FILE_IN=`mktemp`
FILE_OUT=`mktemp`
#
# Main.
#
HNAME=`hostname -f`
 
# Clear temp files.
rm -f $FILE_IN $FILE_OUT
 
# Incoming data.
cat > $FILE_IN
 
PASSWORD="$1"
SENDER=`egrep "^From: " $FILE_IN | head -1 | sed "s,^From: ,,"`
SUBJECT=`egrep "^Subject: " $FILE_IN | head -1 | sed "s,^Subject: ,,"`

if [[ ${SUBJECT} != "${PASSWORD}"* ]] ; then
   rm $FILE_IN
   exit 0
fi

S=${SUBJECT#${PASSWORD} }
for i in $S ; do
  if [ "$i" = "cmd=echo" ] ; then
    SUBJECT="$SUBJECT ts_reply=`date  +%s`"
  fi
done

# Check if sender is empty or if it is spam.
if [ "$SENDER" = "" ]
then
     # logger -t echo -i -p daemon.info "< From=<>, ignored."
     rm $FILE_IN
     exit 0
fi
# 
# Generate answer email.
#
echo "From: echo@${HNAME}" > $FILE_OUT
echo "Subject: $SUBJECT" >> $FILE_OUT
echo "To: $SENDER" >> $FILE_OUT
echo "Content-Type: text/html" >> $FILE_OUT
echo >> $FILE_OUT
cat <<EOT >> $FILE_OUT
Now, you have successfully reached ${HNAME} 
 
------ This is a copy of your message, including all the headers ------
 
EOT
 
sed 's/^/> /' $FILE_IN >> $FILE_OUT
cat <<EOT >> $FILE_OUT
 
------------------- End of the copy of your message -------------------
 
EOT
 
#/usr/sbin/sendmail -i -t -f "" < $FILE_OUT 
mailx -i -t -S ttycharset=UTF-8 -S sendcharsets=UTF-8 -S encoding=8bit < $FILE_OUT
# logger -t echo -i -p daemon.info ">   to=<$SENDER>"
rm  -f $FILE_IN $FILE_OUT
exit 0

