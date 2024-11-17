#!/bin/bash

if [ -f "$0" ]; then
	# if run script as...
	# 1. "./{path}/main.sh"
	# 2. "bash {path}/main.sh"
	StartupPath="`pwd`/$(dirname "$0")"
else
	# 3. ". ./main.sh" (default shell = bash)
	StartupPath="`pwd`/$(dirname "$BASH_SOURCE")"
fi

if [ -z "$StartupPath" ]; then
	exit
fi

getKey(){
	# $1 = time out
	if read -p "$msg" -n 1 -t $1 -s key; then
		if [ "$key" = $'\e' ]; then
			if ! read -n 2 -t 0.001 -s key; then
				key="\e"
			fi

			case $key in
				"[A")	key="up";;
				"[C")	key="right";;
				"[B")	key="down";;
				"[D")	key="left";;
				"\e")	key="esc";;
			esac
		elif [ "$key" = "" ]; then
			key="enter"
		fi
	else
		key="none"
	fi
}

getUsers(){
	unset users
	iUsersNum=0
	while read line; do
		users+=("$line")
		iUsersNum=`expr $iUsersNum + 1`
	done < <(ps -eo user= --sort +user | uniq)
}
getDetails(){
	# $1 = username
	unset details
	iDetailsNum=0
	while read line; do
		details+=("$line")
		iDetailsNum=`expr $iDetailsNum + 1`
	done < <(ps -U $1 -o stat:4=,cmd:20=,pid:7=,stime:9= --sort -pid)
}

show(){
	clear
	cat ""$StartupPath"/asset/title.txt"

	for ((i=0; i<$SCROLL_MAX; ++i)); do
		local user="${users[`expr $usersTopLine + $i`]}"

		local detail="${details[`expr $detailsTopLine + $i`]}"
		local stat="${detail:0:4}"
		case $stat in
			"") unset stat;;
			*+*) stat="F";;
			*) stat="B";;
		esac
		local cmd="${detail:5:20}"
		local pid="${detail:26:7}"
		local stime="${detail:34:9}"

		if [ `expr $iUsersSelected - $usersTopLine` = $i ]; then
			if [ $mode = "user" ]; then
				printf "|\e[42m%20s\e[0m" "$user"
			else
				printf "|\e[41m%20s\e[0m" "$user"
			fi
		else
			printf "|%20s\e[0m" $user
		fi

		if [ `expr $iDetailsSelected - $detailsTopLine` = $i ]; then
			if [ $mode = "detail" ]; then
				printf "|\e[42m%1s %20s|%7s|%9s\e[0m|" "$stat" "$cmd" "$pid" "$stime"
			else
				printf "|\e[41m%1s %20s|%7s|%9s\e[0m|" "$stat" "$cmd" "$pid" "$stime"
			fi
		else
			printf "|%1s %20s|%7s|%9s|" "$stat" "$cmd" "$pid" "$stime"
		fi

		printf "\n"
	done

	echo "---------------------------------------------------------------"
	if [ -z "$msg" ]; then
		echo "If you want to exit, Please Type 'q' or 'Q'"
	else
		echo -e "$msg"
		unset msg
	fi
}

updateData(){
	getUsers

	if [ $iUsersSelected -lt 0 ]; then
		iUsersSelected=0
	elif [ $iUsersSelected -ge $iUsersNum ]; then
		iUsersSelected=`expr $iUsersNum - 1`
	fi
	
	local user="${users[$iUsersSelected]}"
	getDetails $user

	if [ $iDetailsSelected -lt 0 ]; then
		iDetailsSelected=0
	elif [ $iDetailsSelected -ge $iDetailsNum ]; then
		iDetailsSelected=`expr $iDetailsNum - 1`
	fi
}

checkBoundary(){
	if [ $usersTopLine -gt $iUsersSelected ]; then
		usersTopLine=$iUsersSelected
	elif [ `expr $usersTopLine + $SCROLL_MAX` -le $iUsersSelected ]; then
		usersTopLine=`expr $iUsersSelected - $SCROLL_MAX + 1`
	fi

	if [ $detailsTopLine -gt $iDetailsSelected ]; then
		detailsTopLine=$iDetailsSelected
	elif [ `expr $detailsTopLine + $SCROLL_MAX` -le $iDetailsSelected ]; then
		detailsTopLine=`expr $iDetailsSelected - $SCROLL_MAX + 1`
	fi
}

killSelectedProcess(){
	local temp="${details[$iDetailsSelected]}"
	local pid=${temp:26:7}

	if kill -0 $pid 2> /dev/null; then
		kill $pid
		msg="\e[42;30mProcess(PID:$pid) has killed.\e[0m"
	else
		clear
		cat ""$StartupPath"/asset/warning.txt"
		sleep 3
	fi
}


# set terminal window size
defaultCols=`tput cols`
defaultLines=`tput lines`

printf "\e[8;37;72t"
# set lines=37, cols=72

trap 'dtor' EXIT

dtor(){
	unset StartupPath
	unset usersTopLine DetailsTopLine iUsersSelected iDetailsSelected mode
	unset iUsersNum iDetailsNum

	printf "\e[8;${defaultLines};${defaultCols}t"
	unset defaultCols defaultLines

	clear
}

main(){
	declare -i usersTopLine=0
	declare -i detailsTopLine=0

	SCROLL_MAX=20

	declare -i iUsersSelected=0
	declare -i iDetailsSelected=0

	mode="user"

	updateData
	show

	while true; do
		getKey 3
		case $key in
			"none")	updateData;;
			"q"|"Q")break;;
			"up"|"down")
				case $key in
					"up") dy=-1;;
					"down") dy=1;;
				esac
				if [ $mode = "user" ]; then
					iUsersSelected=`expr $iUsersSelected + $dy`
				else
					iDetailsSelected=`expr $iDetailsSelected + $dy`
				fi
				updateData
				checkBoundary;;
			"left") mode="user";;
			"right") mode="detail";;
			"enter")
				if [ $mode = "detail" ]; then
					killSelectedProcess
				fi;;
			":")
			# terminal command mode(pause update)
				while true; do
					read -p "`whoami`(type 'exit'): " cmd
					if [ "$cmd" = "exit" ]; then
						break
					fi
					$cmd
				done
		esac
	
		show
	done
}
main
