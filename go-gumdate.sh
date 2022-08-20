#/bin/bash

#
# This is a small pretty script to update an install of Go.
#
# Usage:   update-go.sh <version>
# Example: update-go.sh 1.9
#
# Thanks Gum! You were fun :)
#

set -euo pipefail

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

print_error() {
	gum style --bold \
		  --foreground $RED \
		  "$1"
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

# Regex to parse Go version from output of `go version`
REG="go version go([0-9]+.[0-9]+.[0-9]*).*"

# Pretty arg parsing
[[ -z ${1+x} ]] && print_error "No args :( Please specify a Go version" && exit 1
DESIRED_GO_VERSION=$1

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
DOWNLOAD_URL=https://go.dev/dl/go${DESIRED_GO_VERSION}.linux-amd64.tar.gz
DOWNLOAD_OUTPUT=$HOME/Downloads/go${DESIRED_GO_VERSION}.linux-amd64.tar.gz
[[ -f $DOWNLOAD_OUTPUT ]] || \
	# Okay file isn't downloaded. Fetch it and show spinner
	gum spin --spinner points --title "Downloading Go version $DESIRED_GO_VERSION..." -- \
	wget --directory-prefix $HOME/Downloads/ $DOWNLOAD_URL

# Gum components can't handle more than 1 command so this function helps
do_install() {
	# The spin component is even more limited! It would need an external script
	# to spin during multiple commands. So, spin multiple times and post a checked message when complete.
	gum spin --spinner points --title "Removing old Go..." -- \
		sudo rm -rf /usr/local/go
	print_checked "Removed old Go!"
	gum spin --spinner points --title "Installing Go..." -- \
		sudo tar -C /usr/local -xf $DOWNLOAD_OUTPUT
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
