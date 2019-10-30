#!/bin/bash

if ! [[ -f ./aurora.sh ]]; then
	echo -e "\e[91maurora.sh not found. Make sure you're in the right directory\e[0m"
	exit 1
fi

function progress_barr () {
	# Prints a progress bar of $1 out of $2 completed
	# Accepts optional inputs:
	# $3 = Color (101 to 109. Default is 102 green)
	# $4 = length of bar ( Default is 30 )

	if [[ -z $1 ]] || [[ -z $2 ]] && (( $2 < $1 )); then
		return 1
	fi
	
	completed="$1"
	total="$2"
	if ! (( $3 )); then color=102; else color=$3; fi
	if ! (( $4 )); then bar_size=30; else bar_size=$4; fi

	if (( $(tput cols) - bar_size - 16 <= 0 )); then
		# 30 is the default size of the bar and 16 is a sensible
		# value to a progress print; "Progress: <bar> 000%". Just
		# a guess so we can resize the bar so it fits the screen.
		# This loop ajust the size of the bar to the terminal size.
		let bar_size=$(tput cols)-16 
		if (( bar_size < 0 )); then bar_size=0; fi
	fi

	percentage="$(printf "%.0f" $( echo '('$completed'/'$total')*'100 | bc -l | tr '.' ','))"
	bar_hilight="$(printf "%.0f" $( echo '('$percentage'/'100')*'$bar_size | bc -l | tr '.' ','))"
	let bar_darkened=bar_size-bar_hilight

	for i in $(seq 1 $bar_hilight); do
		printf "\e["$color"m \e[0m"
	done
	for i in $(seq 1 $bar_darkened); do
		printf "\e[40m \e[0m"
	done
	printf "\e["$((color-10))"m  $percentage%%\e[0m"
}


declare -a QUESTIONS ANS
declare flag='-ac'

QUESTIONS[0]='0 5000 10'
ANS[0]='0'
QUESTIONS[1]='0 a 10'
ANS[1]='1'
QUESTIONS[2]='0 500 -10'
ANS[2]='1'
QUESTIONS[3]='-1 a 1'
ANS[3]='1'
QUESTIONS[4]='1 2'
ANS[4]='1'
QUESTIONS[5]='1 2 3 4'
ANS[5]='1'
QUESTIONS[6]='5000 1 10'
ANS[6]='1'
QUESTIONS[7]='6 -3 !@#$%*()_2_3_4'
ANS[7]='1'
QUESTIONS[8]='1.0 1000 10'
ANS[8]='1'
QUESTIONS[9]='5000 10000 10'
ANS[9]='0'

declare -i assert=0
declare -i errors=0
declare -i ext
declare -a FAILS

running_color=""

while (( assert < ${#QUESTIONS[@]} )); do
	printf "\r"
	printf "Running tests: %s" "$(progress_barr $((assert+1-${#FAILS[@]})) ${#QUESTIONS[@]} $running_color)"
	bash "./aurora.sh" "$flag" "${QUESTIONS[$assert]}"
	ext=$?
	if (( $ext != ${ANS[$assert]} )); then
		running_color="101"
		FAILS[${#FAILS[@]}]=$assert
	fi
	let assert+=1
done
printf "\n"
if ! (( ${#FAILS[@]} )); then
	echo -e "\e[92mCompleted! All tests sucessfull.\e[0m"
else
	echo -e "\e[91mFailed at ${#FAILS[@]} tests. Failed to pass: ${FAILS[@]}\e[0m"
fi

unset FAILS

exit 0
