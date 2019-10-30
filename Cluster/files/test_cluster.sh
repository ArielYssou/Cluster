#!/bin/bash

clear
echo -e "Running tests..."

if [[ $HOSTNAME -eq "abax" ]]; then
	for f_test in $(find /home/ariel/Aurora/tests -\maxdepth 1 -type f -name *_test.sh ); do
		echo -e "Test: \e[93m$f_test\e[0m"
		bash $f_test
	done
else
	for f_test in $(find /home/ariel/Desktop/Aurora/Aurora/tests -\maxdepth 1 -type f -name *_test.sh ); do
		echo -e "Test: \e[93m$f_test\e[0m"
		bash $f_test
	done
fi

exit 0
