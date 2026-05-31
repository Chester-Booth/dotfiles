#!/bin/bash

kitty --title "Fingerprint Enrollment" bash -c '
echo "enrolling right index finger"
fprintd-enroll -f right-index-finger
echo
echo "enrolling left index finger"
fprintd-enroll -f left-index-finger
echo
echo "done press enter to close"
read
'
