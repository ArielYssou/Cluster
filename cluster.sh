#!/bin/bash

# Global definitions
re='^-?[0-9]+([.][0-9]+)?$'
User='ariel'

# Global variables
VERBOSE=1
LOCK_FILES=1
DEBUG=1

# Temporary files
lock_queue="./Cluster/files/.lock_queue.txt"
lock_user="./Cluster/files/.lock_user.txt"
declare -a TEMP_FILES=("$lock_queue" "$lock_user")

# Permanent files
active_nodes="./Cluster/files/active_nodes.txt"
free_queue="./Cluster/files/free_queue.txt"
err_log="./Cluster/files/error_log.txt"
queue_file="./Cluster/files/queue.txt"
test_main="./Cluster/files/test_cluster.sh"

declare -a PERMA_FILES=(\
	"$active_nodes"\
	"$free_queue"\
	"$err_log"\
	"$queue_file"\
	"$test_main"\
	)

# Directories
declare -a DIRS=(\
	"./Cluster"\
	"./Cluster/docs"\
	"./Cluster/files"\
	"./Cluster/tests"\
	)

# Trap for <Ctrl+C> for cleaning
trap ctrl_c INT

function ctrl_c() {
	echo
	echo -e "\e[93m --- Trapped CTRL-C ---\e[0m"
	printf "\e[0m"
	for file in "${TEMP_FILES[@]}"; do
		if [[ -f $file ]]; then rm $file; fi
	done
	echo -e "\e[92mCleaned everything, you may go now :3\e[0m"
	exit 0
}

function tests () {
	bash "$test_main"
	return $?
}

function check_structure () {
	local -i errs=0
	for dir in ${DIRS[@]}; do
		if ! [[ -d $dir ]]; then
			if (( VERBOSE )); then echo -e "\e[91mMissing directory $dir\e[0m"; fi
			let errs+=1
		fi
	done
	for file in "${PERMA_FILES[@]}"; do
		if ! [[ -f $file ]]; then
			if (( VERBOSE )); then echo -e "\e[91mMissing file $file\e[0m"; fi
			let errs+=1
		fi
	done

	if [[ $(cat "$err_log" | wc -l ) -gt 200 ]]; then
		echo -e $( cat "$err_log" | grep -v '[OLD]') > "$err_log"
	fi

	if (( errs )); then
		return 0
	else
		return 1
	fi
}

function welcome_screen () {
	clear
	echo -e "\e[93mcluster.sh\e[0m"

	h=$(date +%H)
	if [ $h -lt 12 ]; then
	  echo "Good morning $USER :D"
	elif [ $h -lt 18 ]; then
	  echo "Good afternoon $USER :D"
	else
	  echo "Good night $USER :D"
	fi

	if [[ -n $(cat "$err_log" | grep -v '[OLD]') ]]; then
		echo "New errors reported:"
		 while read err_line; do
			echo -e "\e[91m$err_line\e[0m"
			sed -i "s|$err_line|\[OLD\] $err_line|g" "$err_log"
		done <<< $(cat "$err_log" | grep -v '[OLD]')
	else
		echo -e "\e[92mNo errors have been reported recently\e[0m"
	fi
	check_structure
	return 0
}

function menu () {
	local -a OPTIONS

	for entry in "$@"; do
		OPTIONS[${#OPTIONS[@]}]="$entry"
	done

	echo "Select an option:"
	valid_option=0
	while ! (( valid_option )); do
		for counter in $(seq 0 $(( ${#OPTIONS[@]}-1)) ); do
			echo "$counter) ${OPTIONS[$counter]}"
		done
		read -p "> " -n 1 -r
		if [[ -n ${OPTIONS[$REPLY]} ]]; then
			echo
			option="$REPLY"
			valid_option=1
		else
			echo
			echo -e "\e[31mInvalid option\e[0m"
		fi
	done

	printf "<awnser>${OPTIONS[$option]}"

	return 0
}

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
	if ! (( $3 )); then color=2; else color=$3; fi
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
		printf "\e[%sm \e[0m" "48;5;$color"
	done
	for i in $(seq 1 $bar_darkened); do
		printf "\e[40m \e[0m"
	done
	printf "\e[%sm  $percentage%%\e[0m" "38;5;$color"
}


function check_input () {
	# Expects: String with inputs
	# Returns: 0 if correct, 1 and prints error message othewise
	# Description: Checks if input is numerical or is in
	# the custom syntax (i)_(f)_(d). i.e. if as only
	# two "_", is numeric and if (f) >= (i)

	declare -a CHECK_IMPUT=$1
	
	local -i intervals=0
	
	for elem in ${CHECK_IMPUT[@]}; do
		if [[ $elem = *"_"* ]]; then
			if [[ $(awk -F"_" '{printf NF-1}' <<< "$elem") != 2 ]]; then
				err_message="$FUNCNAME: Interval in wrong synyax. Expected (i)_(f)_(d)"
				if (( VERBOSE )); then echo -e "\e[91m$err_message\e[0m"; fi
				if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
				return 1
			else
				if (( intervals )); then
					err_message="$FUNCNAME: Multiple intervals found. Oly one is supported"
					if (( VERBOSE )); then echo -e "\e[91m$err_message\e[0m"; fi
					if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
					return 1
				else
					let intervals+=1
					local -a params
					read -a PARAMS <<< "$( echo $elem | tr "_" " ")"
					for param in ${PARAMS[@]}; do
						if ! [[ $param =~ $re ]]; then
							err_message="$FUNCNAME: Non numeric input read."
							if (( VERBOSE )); then echo -e "\e[91m$err_message\e[0m"; fi
							if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
							return 1
						fi
					done
					if (( $(echo ${PARAMS[1]}'<'${PARAMS[0]} | bc -l ) )); then
						err_message="$FUNCNAME: Final parameter smaller than initial."
						if (( VERBOSE )); then echo -e "\e[91m$err_message\e[0m"; fi
						if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
						return 1
					fi
				fi
			fi
		else
			if ! [[ $elem =~ $re ]]; then
				err_message="$FUNCNAME: Non numeric input read."
				if (( VERBOSE )); then echo -e "\e[91m$err_message\e[0m"; fi
				if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
				return 1
			fi
		fi
	done

	return 0
}

function parse_input () { 
	# Parses the given input $1 for any custom syntax.
	# Expects: String containing input
	# Returns: Multi line string with input interval separated

	local -a INPUT
	IFS=',' read -a INPUT <<< "$(echo "$@" | tr ' ' ',')"
	#echo "INPUT: ${INPUT[@]} - Size: ${#INPUT[@]}"
	local -a PARSED INTER

	local -i param_position
	local -i counter=0
	for elem in ${INPUT[@]}; do
		if [[ $elem = *"_"* ]]; then
			read -r param_ini param_final param_inter <<< $(echo $elem | tr '_' ' ')
			PARSED[$counter]=$param_ini
			param_position=$counter
			let counter+=1
		else
			PARSED[$counter]=$elem
			let counter+=1
		fi
	done

	if [[ "$param_position" == "" ]]; then
		echo "${INPUT[@]}"
		return 0
	fi

	local -i mult=0
	while (( $(echo $param_ini+$param_inter'*'$mult'<='$param_final | bc -l) )); do
		INTER[${#INTER[@]}]=$(echo $param_ini+$param_inter'*'$mult | bc -l) 
		let mult+=1
	done

	output=""
	counter=0
	while (( counter < ${#INTER[@]} )); do
		PARSED[$param_position]=${INTER[$counter]}
		line=""
		for param in ${PARSED[@]}; do
			line="$(echo "$line $param")"
		done
		if (( counter != ${#INTER[@]}-1 )); then 
			line="$(echo "$line\n")"
		fi
		output="$output${line:1}" # Removes leading white space
		let counter+=1
	done

	echo "$output" 
	return 0
}

function free_nodes () {
	if ! [[ -f $free_queue ]]; then
		err_message="$FUNCNAME could not find free_queue file"
		if (( VERBOSE )); then echo -e "\e[91m$err_message\e[0m"; fi
		if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
		return 1
	fi
	sed -i "/^$/d" $free_queue

	#local -i sims
	while read node; do
		if [[ $node != "" ]]; then
			sims="$(cat "$active_nodes" | grep "$node" | cut -d' ' -f2 | bc -l)"
			if [[ $sims != "" ]] && [[ $(echo "$sims + 1 <= 4" | bc -l ) == 1 ]]; then
				sed -i "s/$node $sims/$node $((sims + 1))/g" $active_nodes
			fi
		fi
	done < "$free_queue"

	echo "" > $free_queue
	sed -i "/^$/d" $free_queue

	return 0
}

function request_free () {
	echo "$1" >> "$free_queue"
	return 0
}

function write_free_nodes () { 
	# Writes the $free_nodes file
	# which contains a list of active nodes and
	# how many jobs I can still summit there
	# Returns 0 if sucess, 1 if error.

	local -a NODES
	echo "" > "$active_nodes"

	if (( VERBOSE )); then printf "Establishing available nodes..."; fi
	for host in $( cat /etc/hosts | grep abaxnet | grep -v "#" | awk '{print $3}' | grep -v "abax" ); do	
		life_sign=$( ping -c 1 -w 1 $host | grep from)
		if ! [ -z "$life_sign" ]; then
			NODES[${#NODES[@]}]="$host"
		fi
	done
	if (( VERBOSE )); then printf "\r"; fi
	if (( VERBOSE)); then printf "Establishing available nodes... \e[92mDone!\e[0m\n"; fi

	if (( VERBOSE )); then echo "Establishing free space in nodes. This might take some time"; fi

	local -i counter=1
	local -i sims
	for node in ${NODES[@]}; do
		sims=4
		let sims-=$(ssh -n $node "ps auxr | grep "$User" | grep 'Simulacoes' | wc -l")
		if (( sims < 0 )); then
			err_message="$FUNCNAME: Node $node with more than 4 jobs. Aborted."
			if (( VERBOSE )); then echo -e "\033[91m$err_message\033[0m"; fi
			if (( LOCK_FILES )); then echo "In $(date +%c):$err_message" > "$err_log"; fi
			if (( VERBOSE )); then printf "\r"; fi
			if (( VERBOSE )); then printf "Progress: %s" "$(progress_barr $counter ${#NODES[@]}) 1"; fi
			return 1
		fi
		if (( VERBOSE )); then printf "\r"; fi
		if (( VERBOSE )); then printf "Progress: %s" "$(progress_barr $counter ${#NODES[@]})"; fi
		echo "$node $sims" >> "$active_nodes"
		let counter+=1
	done

	echo -e "$(grep -vw "0" $active_nodes)" > "$active_nodes"
	sed -i '/^$/d' "$active_nodes"

	unset NODES

	return 0
}

function abax_check () { 
	# Input: Initial sim, Final sim, jobs
	# Output: 0 if correct, 1 if not
	# Descriptions, cheks if:
	# 1) There are three inputs
	# 2) $2 >= $1
	# 3) All are numerical and positive

	local -a ABAX_INPUT
	IFS=',' read -a ABAX_INPUT <<< "$(echo "$@" | tr ' ' ',')"
	local -i counter=0

	if (( ${#ABAX_INPUT[@]} != 3 )); then
		err_message="$FUNCNAME called with wrong number of inputs"
		if (( VERBOSE )); then echo -e "\e[91m$err_message\e[0m"; fi
		if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
		return 1
	fi

	while (( counter < ${#ABAX_INPUT[@]} )); do
		if [[ -z "${ABAX_INPUT[$counter]}" ]] ; then
			err_message="$FUNCNAME called with missing argument $(( counter + 1 ))"
			if (( VERBOSE )); then echo -e "\e[91m$err_message\e[0m"; fi
			if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
			return 1
		fi
		if ! [[ ${ABAX_INPUT[$counter]} =~ $re ]]; then
			err_message="$FUNCNAME called with non numeric input ${ABAX_INPUT[$counter]}"
			if (( VERBOSE )); then echo -e "\e[91m$err_message\e[0m"; fi
			if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
			return 1
		fi
		if (( $(echo ${ABAX_INPUT[$counter]}'<'0 | bc -l) )) ; then
			err_message="$FUNCNAME called with negative argument $(( counter + 1 ))"
			if (( VERBOSE )); then echo -e "\e[91m$err_message\e[0m"; fi
			if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
			return 1
		fi
		if ! [[ "${ABAX_INPUT[$counter]}" =~ ^[0-9]+$  ]] ; then
			err_message="$FUNCNAME called with non integer argument ${ABAX_INPUT[$counter]}"
			if (( VERBOSE )); then echo -e "\e[91m$err_message\e[0m"; fi
			if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
			return 1
		fi
		let counter+=1
	done

	if (( ${ABAX_INPUT[1]} < ${ABAX_INPUT[0]} )); then
		err_message="$FUNCNAME: Final argument smaller than initial"
		if (( VERBOSE )); then echo -e "\e[91m$err_message\e[0m"; fi
		if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
		return 1
	fi

	return 0
}

function abax_parse () { 
	# Receives $1 input and separates it in a
	# multi-line string containing simulation
	# intervals. Divides <initial> and <final> values
	# in <jobs> intervals
	# Expects: String of inputs
	# Outputs: Multi-line string with parsed input
	# Returns: 0 if sucess, 1 if error

	local -i sim_ini sim_final sim_partition sim_inter

	if [[ -z "$1" ]]; then
		err_message="$FUNCNAME called without argument"
		if (( VERBOSE )); then echo -e "\e[91m$err_message\e[0m"; fi
		if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
		return 1
	fi

	IFS=',' read -r sim_ini sim_final sim_partition <<< "$(echo "$@" | tr ' ' ',')"

	sim_inter=$(( (sim_final-sim_ini)/sim_partition ))

	local output=""
	if (( sim_final <= sim_ini + sim_inter )) || ! (( sim_inter )); then
		output="$sim_ini $sim_final"
	else
		while (( sim_ini + sim_inter <= sim_final )); do
			output="$output$((sim_ini)) $(( sim_ini + sim_inter ))\n"
			let sim_ini+=sim_inter+1
		done
		if (( sim_ini <= sim_final )); then
			output="$output$((sim_ini)) $(( sim_final ))\n"
		fi
		output="$( echo $output | sed -r 's/(.*)\\n/\1/' )" # Removes last exceding \n
	fi

	echo "$output"

	return 0
}

function assemble_input () {
	# Expects 3 inputs in csv format:
	# $1: Target to simulation executable
	# $2: Specific simulation input (may be empty)
	# $3: Abax input: Initial and final simulations
	#				  and number of jobs to be used
	# Returns: Multi-lined string with formated input

	if [[ -z $1 ]]; then
		err_message="$FUNCNAME called with missing argument"
		if (( VERBOSE )); then echo -e "\e[91m$err_message\e[0m"; fi
		if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
		return 1
	fi

	IFS=',' read -r sim_name arg2 arg3 <<< "$@"

	local -a S_INPUT A_INPUT	# S for simulation, A for abax

	while read line; do
		S_INPUT[${#S_INPUT[@]}]="$line"	
	done <<< "$(echo -e "$arg2")"

	while read line; do
		A_INPUT[${#A_INPUT[@]}]="$line"	
	done <<< "$(echo -e "$arg3")"

	#echo "sim_name: $sim_name, S_input: ${S_INPUT[@]} -size: ${#S_INPUT[@]}, A_input: ${A_INPUT[@]}"

	local output=""
	for s_counter in $(seq 0 $((${#S_INPUT[@]} - 1 )) ) ; do
		for a_counter in $(seq 0 $(( ${#A_INPUT[@]}-1)) ); do
			output="$output$sim_name ${S_INPUT[$s_counter]} ${A_INPUT[$a_counter]}\\n"
		done
	done
	output="$( echo $output | sed -r 's/(.*)\\n/\1/' )" # Removes last exceding \n

	echo "$output"
	
	return 0
}

function add_to_queue () {
	# Adds $1 to queue file
	# Report errors if any

	if [[ -z "$1" ]] ; then
		err_message="$FUNCNAME: Called without argument" 
		if (( VERBOSE )); then echo -e "\033[91m$err_message\033[0m"; fi
		if (( LOCK_FILES )); then echo "In $(date +%c):$err_message" > "$err_log"; fi
		return 1
	else
		echo -e "$@" >> "$queue_file"
		if (( VERBOSE )); then echo -e "\e[93mQueue has been updated sucessfully!\e[0m"; fi
		return 0
	fi
	sed -i '/^$/d' "$queue_file"
}


function move_queue () {
	# Moves queue inserting jobs on abax
	# Returns 0 if sucess, 1 if error

	if [[ -f "$lock_queue" ]]; then
		if (( VERBOSE )); then printf "Queue beeing used...\n"; fi
		return 0
	else
		touch "$lock_queue"
	fi
	if (( VERBOSE )); then printf "Moving queue...\n"; fi

	#write_free_nodes
	free_nodes

	local -a extinguished

	if (( $? )); then return 1; fi

	sed -i '/^$/d' "$active_nodes"

	local -i current_free_nodes="$(cat $active_nodes | awk '{sum+=$2 } END{print sum}' )"
	local -i sims_in_queue="$(cat $queue_file | wc -l)"

	while [[ "$(echo "$current_free_nodes > 0" | bc -l)" == "1" ]] && [[ "$(echo "$sims_in_queue > 0" | bc -l) == 1" ]]; do
		read -r node free_sims <<< "$(shuf -n1 $active_nodes)"
		if ((free_sims == 0)); then
			echo -e "$(grep -v $node $active_nodes)" > "$active_nodes"
			extinguished[${#extinguished[@]}]="$node"
		else
			if [[ -z $node ]]; then
				err_message="$FUNCNAME: Could not read node and/or available free jobs"
				if (( VERBOSE )); then echo -e "\033[91m$err_message\033[0m"; fi
				if (( LOCK_FILES )); then echo "In $(date +%c):$err_message" > "$err_log"; fi
				return 1
			fi

			q_entry="$( head -n1 "$queue_file" )"
			if [[ $q_entry == "" ]]; then break; fi

			ssh -n $node "$q_entry $node" &
			sed -i '1d' "$queue_file"

			if (( free_sims == 1 )); then
				echo -e "$(grep -v $node $active_nodes)" > "$active_nodes"
				extinguished[${#extinguished[@]}]="$node"
			else
				sed -i "s/$node.*/$node $((free_sims-1))/g" "$active_nodes" 
			fi

			#current_free_nodes="$(cat $free_nodes | awk '{sum+=$2 } END{print sum}' )"
			#sims_in_queue="$(cat $queue_file | wc -l)"
			let current_free_nodes=current_free_nodes-1
			let sims_in_queue=sims_in_queue-1

#			cat $active_nodes
#			echo "Current free nodes: $current_free_nodes"
#			echo "awk free nodes: $(cat $active_nodes | awk '{sum+=$2 } END{print sum}' )"
#			echo "Sims in queue: $sims_in_queue"
#			sleep 2

		fi
	done

	if (( VERBOSE )); then
		if ! (( current_free_nodes )); then echo -e "\e[93mNo more available nodes. Itens remainded in queue.\e[0m"; fi
		if ! (( sims_in_queue )); then echo -e "\e[92mQueue has been emptied.\e[0m"; fi
	fi

	for node in ${extinguished[@]}; do
		echo "$node 0" >> "$active_nodes"
	done

	rm "$lock_queue"
	return 0
}

function kill_simulation () {
	# Kill simulaions in $1 mode, which can be:
	# 1) all: Kill all simulations in all nodes
	# 2) name: Kill simulations eich name contains
	#			string given in $2
	# 3) node: Kill simulation in node $2
	# Returns 0 if sucess, 1 if error

	local -a NODES

	if (( VERBOSE )); then echo "Establishing available nodes..."; fi
	for host in $(cat /etc/hosts | grep abaxnet | grep -v "#" | awk '{print $3}' | grep -v "abax" ); do
		life_sign=$(ping -c 1 -w 1 $host | grep from)
		if ! [ -z "$life_sign" ]; then
			NODES[${#NODES[@]}]="$host"
		fi
	done

	sim_name=""

	case $1 in
		all)
			if (( VERBOSE )); then printf "Terminating simulations in \e[93;1mall\e[0m nodes.\n"; fi
			;;
		name)
			if [[ -z $2 ]]; then
				err_message="$FUNCNAME: No name input given for termination"
				if (( VERBOSE )); then echo -e "\033[91m$err_message\033[0m"; fi
				if (( LOCK_FILES )); then echo "In $(date +%c):$err_message" > "$err_log"; fi
				return 1
			fi
			sim_name=$2
			if (( VERBOSE )); then printf "Terminating simulations containing \e[93;1m$sim_name\e[0m.\n"; fi
			;;
		node)
			if [[ -z $2 ]]; then
				err_message="$FUNCNAME: No node input given for termination"
				if (( VERBOSE )); then echo -e "\033[91m$err_message\033[0m"; fi
				if (( LOCK_FILES )); then echo "In $(date +%c):$err_message" > "$err_log"; fi
				return 1
			fi
			life_sign=$(ping -c 1 -w 1 $2 | grep from)
			if [ -z "$life_sign" ]; then
				err_message="$FUNCNAME: Node not found on abax"
				if (( VERBOSE )); then echo -e "\033[91m$err_message\033[0m"; fi
				if (( LOCK_FILES )); then echo "In $(date +%c):$err_message" > "$err_log"; fi
				return 1
			fi
			unset NODES
			local -a NODES
			NODES[0]="$2"
			if (( VERBOSE )); then printf "Terminating simulations in node \e[93;1m${NODES[@]}\e[0m.\n"; fi
			;;
		*)
			return 1
			;;
	esac
	echo ${#NODES[@]}

	local -i counter=0
	for node in ${NODES[@]}; do
		printf "\r"
		if (( VERBOSE )); then printf "Ending jobs in node $node: %s" "$(progress_barr $((counter+1)) ${#NODES[@]} 3)"; fi
		printf "Ending jobs in node $node: %s" "$(progress_barr $((counter+1)) ${#NODES[@]} 3)"
		let counter+=1
		list_to_kill="$(ssh -n "$node" pgrep -lu $User "$sim_name" | grep -v "sshd" )"
		if [[ -n "$list_to_kill" ]]; then
			while read -r line; do
				read -r p_pid p_name <<< "$line"
				ssh -n "$node" kill $p_pid
			done <<< "$( echo -e "$list_to_kill")"
		fi
	done
	echo

	return 0
}

function external_add () {
	# Adds arguement to queue immediately. Checks syntax but
	# expects a correct and complete set of arguments.
	# Returns 0 if sucess, 1 if error
	local -a INPUT_ARRAY
	VERBOSE=1
	for inpt in "$@"; do
		INPUT_ARRAY[${#INPUT_ARRAY[@]}]=$inpt
	done

	local sim_name
	sim_name="${INPUT_ARRAY[1]}"
	if ! [[ -f $sim_name ]]; then
		err_message="$FUNCNAME: Simulation $sim_name not found"
		if (( VERBOSE )); then echo -e "\e[91m$err_message\e[0m"; fi
		if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
		return 1
	fi

	local -a LOCAL_INPUT
	for pos in $(seq 2 $((($#-4))) ); do
		LOCAL_INPUT[${#LOCAL_INPUT[@]}]="${INPUT_ARRAY[$pos]}"
	done

	check_input "${LOCAL_INPUT[@]}"
	if (( $? )); then return $?; fi
	parsed_input="$(parse_input ${LOCAL_INPUT[@]})"
	if (( $? )); then return $?; fi

	local -a LOCAL_SIM
	for pos in $(seq $((($#-3))) $((($#-1)))) ; do
		LOCAL_SIM[${#LOCAL_SIM[@]}]=${INPUT_ARRAY[$pos]}
	done

	abax_check "${LOCAL_SIM[@]}"
	if (( $? )); then return $?; fi
	parsed_abax_input="$( abax_parse "${LOCAL_SIM[@]}" )"
	if (( $? )); then return $?; fi

	add_to_queue "$( assemble_input $sim_name,$parsed_input,$parsed_abax_input)"

	write_free_nodes
	move_queue

	return 0
}
	
function seek_queue () {
	# Tests if given string can be found in queue file
	# and if there is any job in abax with this name
	# i.e. sees if all instances of given job have finished

	# *Echoes* 1 if found (true) or 0 if no instance
	# Returns 0 if no errors, 1 otherwise

	if [[ -n $1 ]]; then
		to_seek="$1"
	else
		err_message="$FUNCNAME: Called without argument"
		if (( LOCK_FILES )); then echo "$err_message" >> "$err_log"; fi
		return 1
	fi

	if [[ -n $( grep $to_seek $queue_file ) ]]; then
		echo 1
		return 0
	fi

	local -a NODES

	for host in $(cat /etc/hosts | grep abaxnet | grep -v "#" | awk '{print $3}' | grep -v "abax" ); do
		life_sign=$(ping -c 1 -w 1 $host | grep from)
		if ! [ -z "$life_sign" ]; then
			NODES[${#NODES[@]}]="$host"
		fi
	done

	local -i counter=0
	local -i matches=0
	for node in ${NODES[@]}; do
		let counter+=1
		let matches+=$(ssh -n "$node" pgrep -lu $User "$to_seek" | grep -cv "sshd" )
		if [[ $matches > 0 ]]; then
			echo 1
			return 0
		fi
	done

	echo 0

	return 0
}

function help () {
	cat << EOF
Usage:
	cluster.sh [FLAGS] <OPTION...>
Description:
	Manages jobs on abax

Options
	-h|--help				Shows help text
	-c|--check				Checks given input
EOF
}

case $1 in
	-c|--check)
		VERBOSE=0
		check_input "$2"
		exit $?
		;;
	-ac|--acheck)
		VERBOSE=0
		abax_check "$2"
		exit $?
		;;
	-p|--parse)
		VERBOSE=0
		parse_input "$2"
		exit $?
		;;
	-ap|--aparse)
		VERBOSE=0
		abax_parse "$2"
		exit $?
		;;
	-as|--assemble)
		VERBOSE=0
		assemble_input "$2"
		exit $?
		;;
	-f|--free)
		VERBOSE=0
		free_nodes
		exit $?
		;;
	-h|--help)
		help
		exit $?
		;;
	-t|--test)
		tests
		exit $?
		;;
	-e|--external)
		VERBOSE=0
		external_add "$@"
		exit $?
		;;
	-s|--seek)
		VERBOSE=0
		seek_queue "$2"
		exit $?
		;;
	-m|--move)
		VERBOSE=0
		move_queue
		exit $?
		;;
	-r|--request)
		VERBOSE=0
		request_free "$2"
		exit $?
		;;
	-w|--write)
		write_free_nodes
		exit $?
		;;
esac

if (( VERBOSE )); then welcome_screen ; fi
echo "Select an option:"
COLUMNS=12
select action in "New job in queue" "Kill jobs" "Quit"; do
	case $action in
		"New job in queue")
			echo "Available simulations:"

			declare -a OPTIONS
			for code in $(find /home/ariel/Simulacoes/ -maxdepth 1 -executable -type f); do
				OPTIONS[${#OPTIONS[@]}]="$code"
			done

			declare -A SOURCES EXECUTABLES
			for opt in ${OPTIONS[@]}; do
				SOURCES[$opt]="$(find /home/ariel/Simulacoes/ -maxdepth 1 -wholename "$opt."* )"
				EXECUTABLES[${SOURCES[$opt]}]="$opt"
			done

			COLUMNS=2
			select opt in "${SOURCES[@]}" "Go back"; do
				case $opt in
					*.*)
						echo "Selected $opt"

						if [[ -z $( awk '/descr_begin/{flag=1;next}/descr_end/{flag=0}flag' "$opt" ) ]]; then
							echo "No description found!"
						else
							awk '/descr_begin/{flag=1;next}/descr_end/{flag=0}flag' "$opt" #
						fi

						declare -a INPUT
						
						rtrn=1
						while (( rtrn )); do
							echo -e "Enter the desired input \e[92;1mparameters\e[0m:"
							read -p "> " -a INPUT
							check_input "${INPUT[@]}"
							rtrn=$?
						done

						parsed_input="$(parse_input ${INPUT[@]})"

						declare -a SIM_INPUT

						rtrn=1
						while (( rtrn )); do
							echo -e "Enter the \e[92;1mInintial\e[0m and \e[92;1mFinal\e[0m simulations and in how many \e[92;1mjobs\e[0m "
							echo -e "we will distribute these simulations"
							read -p "> " -a SIM_INPUT
							abax_check "${SIM_INPUT[@]}"
							rtrn=$?
						done

						parsed_abax_input="$( abax_parse "${SIM_INPUT[@]}" )"

						add_to_queue "$( assemble_input ${EXECUTABLES[$opt]},$parsed_input,$parsed_abax_input)"

						write_free_nodes

						move_queue

						break
						;;
					"Go back")
						break
						;;
					*)
						echo -e "\e[91mInvalid option\e[0m"
						;;
				esac
			done
			;;
		"Kill jobs")
			echo "Select an option"
		select opt in "Kill by name" "Kill by node" "Execute order 66" "Quit"; do
				case $opt in
					"Kill by name")
						echo "Please, enter the name of the simulation you wish to terminate"
						read sim_name
						kill_simulation "name" "$sim_name"
						echo
						break
						;;
					"Kill by node")
						echo "Please, enter the name of the node"
						read ans
						kill_simulation "node" "$ans"
						echo
						break
						;;
					"Execute order 66")
						echo -e "\e[95mPOWAH, UNLIMITED POWAH\e[0m"
						kill_simulation "all"
						break
						;;
					"Quit")
						break
						;;
				esac
			done
			;;
		"Quit")
			echo -e "\e[92mSee ya $USER!\e[0m"
			break
			;;
		*)
			echo -e "\e[91mInvalid Option\e[0m"
			;;
	esac
done

exit 0
