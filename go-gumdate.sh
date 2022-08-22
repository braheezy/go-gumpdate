#/bin/bash

set -euo pipefail

#*************************************
# 	Styling stuff
#*************************************
GREEN='#a6e3a1'
RED='#f38ba8'
LAVENDER='#b4befe'
YELLOW='#f9e2af'
BASE='#1e1e2e'
TEAL='#94e2d5'

SELECT_TEXT=$BASE
SELECTION=$GREEN
UNSELECT_TEXT=$SELECT_TEXT
UNSELECTION=$LAVENDER

print_error_and_exit() {
	gum style --bold \
		  --foreground $RED \
		  "$1" >&2
	exit 1
}

print_msg() {
	gum style --foreground $GREEN \
		  --border "double" \
		  --border-foreground $LAVENDER \
		  "$1"
}

print_checked() {
	gum style --bold \
		"✅ $1"
}

print_help() {
	# Program title
	header=`gum style --bold --foreground $YELLOW "$1"`

	# Program help text
	gum style  \
		--foreground $LAVENDER --border-foreground $LAVENDER --border thick \
		--width 100 --padding "1" \
		"$header
		$2"
}
#*************************************
# 	Arg parsing stuff
#*************************************
DEFAULT_DOWNLOAD_DIR=$HOME/Downloads

title="`basename "$0"` [-h] [-d] VERSION"
usage="
Download and install a VERSION of Go.
Any existing installation of Go will be deleted! You have been warned...

Usage:
	-h	Print this help.
	-t	Specify the target directory for download files. Will be created if it doesn't exit.
		  Default is: $DEFAULT_DOWNLOAD_DIR"

while getopts :ht: option; do
	case "$option" in
		h)
			print_help "$title" "$usage"
		   	exit
		   	;;
	  	d)
			DOWNLOAD_DIR=$OPTARG
	  	   	;;
	  	\?)
			print_error_and_exit "Invalid option: -$OPTARG"
			;;
		:)
			print_error_and_exit "Option -$OPTARG requires an argument."
			exit 1
			;;
	esac
done
# Shift and throw away the parse options
shift $((OPTIND-1))
# If `-d` is supplied, use sane default
[[ -z "${DOWNLOAD_DIR+x}" ]] && DOWNLOAD_DIR=$DEFAULT_DOWNLOAD_DIR

# MUST provide a Go version or this script has nothing to do
[[ -z "${1+x}" ]] && print_error_and_exit "Please specify a Go version :)"
DESIRED_GO_VERSION=$1

#*************************************
# 	Main program logic
#*************************************
# Regex to parse Go version from output of `go version`
REG="go version go([0-9]+.[0-9]+.[0-9]*).*"

# Test if Go is available
if ! `command -V go &>/dev/null`
then
	print_msg "Couldn't find Go binary. Moving on... "
else
	# Get current Go version
	[[ `go version` =~ $REG ]] && CURRENT_GO_VERSION="${BASH_REMATCH[1]}"
	print_msg "Pre-install go version: $CURRENT_GO_VERSION"
fi

# Download requested Go version, if needed
DOWNLOAD_URL="https://go.dev/dl/go$DESIRED_GO_VERSION.linux-amd64.tar.gz"
DOWNLOAD_FILE="$DOWNLOAD_DIR/go$DESIRED_GO_VERSION.linux-amd64.tar.gz"
[[ -f $DOWNLOAD_FILE ]] || \
	# Okay file isn't downloaded. Fetch it and show spinner
	mkdir -p "$DOWNLOAD_DIR"
	gum spin --spinner points --title "Downloading Go version $DESIRED_GO_VERSION..." -- \
		wget --directory-prefix "$DOWNLOAD_DIR" $DOWNLOAD_URL ||
		print_error_and_exit "Hmm something went wrong with the download"

# Gum components can't handle more than 1 command so this function helps
do_install() {
	# The spin component is even more limited! It would need an external script
	# to spin during multiple commands. So, spin multiple times and post a checked message when complete.
	gum spin --spinner points --title "Removing old Go..." -- \
		sudo rm -rf /usr/local/go
	print_checked "Removed old Go!"
	gum spin --spinner points --title "Installing Go..." -- \
		sudo tar -C /usr/local -xf $DOWNLOAD_FILE
	print_checked "Installed new Go!"

	# Verify install
	[[ `go version` =~ $REG ]] && CURRENT_GO_VERSION="${BASH_REMATCH[1]}"
	print_msg "Success! Post-install go version: $CURRENT_GO_VERSION"
}

# Remove old Go install per docs and install new one
# 	Apple-style confirmations + default to non-destructive option
#	Customize the question to the user
#	Customize the selected option
#	Customize the un-selected option
#	Run this on positive confirmation || This on negative confirmation
gum confirm "About to delete old Go. Continue with update?" \
	--affirmative "Remove old files and update" --negative "Do nothing" --default=false \
	--prompt.foreground $RED --prompt.bold \
	--selected.foreground $SELECT_TEXT --selected.background $SELECTION --selected.bold \
	--unselected.foreground $UNSELECT_TEXT --unselected.background $UNSELECTION && \
	do_install || print_msg "Okay not updating Go"
