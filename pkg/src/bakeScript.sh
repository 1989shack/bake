#!/usr/bin/env bash

# @name Bake
# @brief Bake: A Bash-based Make alternative
# @description Bake is a dead-simple task runner used to quickly cobble together shell scripts
#
# In a few words, Bake lets you call the following 'print' task with './bake print'
#
# ```bash
# #!/usr/bin/env bash
# task.print() {
# printf '%s\n' 'Contrived example'
# }
# ```
#
# Learn more about it [on GitHub](https://github.com/hyperupcall/bake)

if [ "$0" != "${BASH_SOURCE[0]}" ] && [ "$BAKE_INTERNAL_CAN_SOURCE" != 'yes' ]; then
	printf '%s\n' 'Error: This file should not be sourced' >&2
	return 1
fi

# @description Prints `$1` formatted as an error and the stacktrace to standard error,
# then exits with code 1
# @arg $1 string Text to print
bake.die() {
	if [ -n "$1" ]; then
		__bake_error "$1. Exiting"
	else
		__bake_error 'Exiting'
	fi
	__bake_print_big '<- ERROR'

	__bake_print_stacktrace

	exit 1
}

# @description Prints `$1` formatted as a warning to standard error
# @arg $1 string Text to print
bake.warn() {
	if __bake_is_color; then
		printf "\033[1;33m%s:\033[0m %s\n" 'Warn' "$1"
	else
		printf '%s: %s\n' 'Warn' "$1"
	fi
} >&2

# @description Prints `$1` formatted as information to standard output
# @arg $1 string Text to print
bake.info() {
	if __bake_is_color; then
		printf "\033[0;34m%s:\033[0m %s\n" 'Info' "$1"
	else
		printf '%s: %s\n' 'Info' "$1"
	fi
}

# @description Dies if any of the supplied variables are empty. Deprecated in favor of 'bake.assert_not_empty'
# @arg $@ string Names of variables to check for emptiness
# @see bake.assert_not_empty
bake.assert_nonempty() {
	__bake_internal_warn "Function 'bake.assert_nonempty' is deprecated. Please use 'bake.assert_not_empty' instead"
	bake.assert_not_empty "$@"
}

# @description Dies if any of the supplied variables are empty
# @arg $@ string Names of variables to check for emptiness
bake.assert_not_empty() {
	local variable_name=
	for variable_name; do
		local -n ____variable="$variable_name"

		if [ -z "$____variable" ]; then
			bake.die "Failed because variable '$variable_name' is empty"
		fi
	done; unset -v variable_name
}

# @description Dies if a command cannot be found
# @arg $1 string Command name to test for existence
bake.assert_cmd() {
	local cmd=$1

	if [ -z "$cmd" ]; then
		bake.die "Argument must not be empty"
	fi

	if ! command -v "$cmd" &>/dev/null; then
		bake.die "Failed to find command '$cmd'. Please install it before continuing"
	fi
}

# @description Change the behavior of Bake. See [guide.md](./docs/guide.md) for details
# @arg $1 string Name of config property to change
# @arg $2 string New value of config property
bake.cfg() {
	local cfg="$1"
	local value="$2"

	case $cfg in
	stacktrace)
		case $value in
			yes|no) __bake_cfg_stacktrace=$value ;;
			*) __bake_internal_die2 "Config property '$cfg' accepts only either 'yes' or 'no'" ;;
		esac
		;;
	pedantic-task-cd)
		case $value in
			yes) trap '__bake_trap_debug' 'DEBUG' ;;
			no) trap - 'DEBUG' ;;
			*) __bake_internal_die2 "Config property '$cfg' accepts only either 'yes' or 'no'" ;;
		esac
		;;
	big-print)
		case $value in
			yes|no) ;;
			*) __bake_internal_die2 "Config property '$cfg' accepts only either 'yes' or 'no'" ;;
		esac
		;;
	*)
		__bake_internal_die2 "No config property matched '$cfg'"
		;;
	esac
}

# @description Prints stacktrace
# @internal
__bake_print_stacktrace() {
	if [ "$__bake_cfg_stacktrace" = 'yes' ]; then
		if __bake_is_color; then
			printf '\033[4m%s\033[0m\n' 'Stacktrace:'
		else
			printf '%s\n' 'Stacktrace:'
		fi

		local i=
		for ((i=0; i<${#FUNCNAME[@]}-1; ++i)); do
			local __bash_source="${BASH_SOURCE[$i]}"; __bash_source=${__bash_source##*/}
			printf '%s\n' "  in ${FUNCNAME[$i]} ($__bash_source:${BASH_LINENO[$i-1]})"
		done; unset -v i __bash_source
	fi
} >&2

# @description Function that is executed when the 'ERR' event is trapped
# @internal
__bake_trap_err() {
	local error_code=$?

	__bake_print_big "<- ERROR"
	__bake_internal_error "Your Bakefile did not exit successfully (exit code $error_code)"
	__bake_print_stacktrace

	exit $error_code
} >&2

__global_bake_trap_debug_current_function=
__bake_trap_debug() {
	local current_function="${FUNCNAME[1]}"

	if [[ $current_function != "$__global_bake_trap_debug_current_function" \
			&& $current_function == task.* ]]; then
		if ! cd "$BAKE_ROOT"; then
			__bake_internal_die "Failed to cd to \$BAKE_ROOT"
		fi
	fi

	__global_bake_trap_debug_current_function=$current_function
} >&2

# @description Test whether color should be outputed
# @exitcode 0 if should print color
# @exitcode 1 if should not print color
# @internal
__bake_is_color() {
	if [[ -v NO_COLOR || $TERM == dumb ]]; then
		return 1
	else
		return 0
	fi
}

# @description Calls `__bake_internal_error` and terminates with code 1
# @arg $1 string Text to print
# @internal
__bake_internal_die() {
	__bake_internal_error "$1. Exiting"
	exit 1
}

# @description Calls `__bake_internal_error` and terminates with code 1. Before
# doing so, it closes with "<- ERROR" big text
# @arg $1 string Text to print
# @internal
__bake_internal_die2() {
	__bake_print_big '<- ERROR'

	__bake_internal_error "$1. Exiting"
	exit 1
}

# @description Prints `$1` formatted as an internal Bake error to standard error
# @arg $1 Text to print
# @internal
__bake_internal_error() {
	if __bake_is_color; then
		printf "\033[0;31m%s:\033[0m %s\n" "Error (bake)" "$1"
	else
		printf '%s: %s\n' 'Error (bake)' "$1"
	fi
} >&2

# @description Prints `$1` formatted as an internal Bake warning to standard error
# @arg $1 Text to print
# @internal
__bake_internal_warn() {
	if __bake_is_color; then
		printf "\033[0;33m%s:\033[0m %s\n" "Warn (bake)" "$1"
	else
		printf '%s: %s\n' 'Warn (bake)' "$1"
	fi
} >&2

# @description Prints `$1` formatted as an error to standard error. This is not called because
# I do not wish to surface a public 'bake.error' function. All errors should halt execution
# @arg $1 string Text to print
# @internal
__bake_error() {
	if __bake_is_color; then
		printf "\033[0;31m%s:\033[0m %s\n" 'Error' "$1"
	else
		printf '%s: %s\n' 'Error' "$1"
	fi
} >&2

# @description Nicely prints all 'Bakefile.sh' tasks to standard output
# @internal
__bake_print_tasks() {
	printf '%s\n' 'Tasks:'
	local str=

	# shellcheck disable=SC1007,SC2034
	local regex="^(([[:space:]]*function[[:space:]]*)?task\.(.*?)\(\)).*"
	local line=
	while IFS= read -r line || [ -n "$line" ]; do
		if [[ "$line" =~ $regex ]]; then
			str+="  -> ${BASH_REMATCH[3]}"$'\n'
		fi
	done < "$BAKE_FILE"; unset -v line

	if [ -z "$str" ]; then
		if __bake_is_color; then
			str=$'  \033[3mNo tasks\033[0m\n'
		else
			str=$'  No tasks\n'
		fi
	fi

	printf '%s' "$str"
} >&2

# @description Prints text that takes up the whole terminal width
# @arg $1 string Text to print
# @internal
__bake_print_big() {
	local print_text="$1"

	if [ "$__bake_cfg_big_print" = 'no' ]; then
		return
	fi

	# shellcheck disable=SC1007
	local _stty_height= _stty_width=
	read -r _stty_height _stty_width < <(
		if stty size &>/dev/null; then
			stty size
		else
			if [ -n "$COLUMNS" ]; then
				printf '%s\n' "20 $COLUMNS"
			else
				printf '%s\n' '20 80'
			fi
		fi
	)

	local separator_text=
	# shellcheck disable=SC2183
	printf -v separator_text '%*s' $((_stty_width - ${#print_text} - 1))
	printf -v separator_text '%s' "${separator_text// /=}"
	if __bake_is_color; then
		printf '\033[1m%s %s\033[0m\n' "$print_text" "$separator_text"
	else
		printf '%s %s\n' "$print_text" "$separator_text"
	fi
} >&2

# @description Parses the arguments. This also includes setting the the 'BAKE_ROOT'
# and 'BAKE_FILE' variables
# @set REPLY Number of times to shift
# @internal
__bake_parse_args() {
	unset REPLY; REPLY=
	local -i total_shifts=0

	# FIXME: bug for when passing -v to child task argument
	local __bake_arg=
	for arg; do case $arg in
	-f)
		BAKE_FILE=$2
		if [ -z "$BAKE_FILE" ]; then
			__bake_internal_die "A value was not specified for for flag '-f"
		fi
		((total_shifts += 2))
		if ! shift 2; then
			__bake_internal_die 'Failed to shift'
		fi

		if [ ! -e "$BAKE_FILE" ]; then
			__bake_internal_die "Specified file '$BAKE_FILE' does not exist"
		fi
		if [ ! -f "$BAKE_FILE" ]; then
			__bake_internal_die "Specified file '$BAKE_FILE' is not actually a file"
		fi
		;;
	-v)
		local bake_version='1.8.2'
		printf '%s\n' "Version: $bake_version"
		;;
	-h)
		local flag_help='yes'
		if ! shift; then
			__bake_internal_die 'Failed to shift'
		fi
	esac done

	if [ -n "$BAKE_FILE" ]; then
		BAKE_ROOT=$(
			# shellcheck disable=SC1007
			CDPATH= cd -- "${BAKE_FILE%/*}"
			printf '%s\n' "$PWD"
		)
		BAKE_FILE="$BAKE_ROOT/${BAKE_FILE##*/}"
	else
		if ! BAKE_ROOT=$(
			while [ ! -f './Bakefile.sh' ] && [ "$PWD" != / ]; do
				if ! cd ..; then
					exit 1
				fi
			done

			if [ "$PWD" = / ]; then
				exit 1
			fi

			printf '%s' "$PWD"
		); then
			__bake_internal_die "Failed to find 'Bakefile.sh'"
		fi
		BAKE_FILE="$BAKE_ROOT/Bakefile.sh"
	fi

	if [ "$flag_help" = 'yes' ]; then
		cat <<-"EOF"
		Usage: bake [-h|-v] [-f <Bakefile>] [var=value ...] <task> [args ...]
		EOF
		__bake_print_tasks
		exit
	fi

	REPLY=$total_shifts
}

# @description Main function
# @internal
__bake_main() {
	__bake_cfg_stacktrace='no'
	__bake_cfg_big_print='yes'

	# Environment boilerplate
	set -ETeo pipefail
	shopt -s dotglob extglob globasciiranges globstar lastpipe shift_verbose
	export LANG='C' LC_CTYPE='C' LC_NUMERIC='C' LC_TIME='C' LC_COLLATE='C' \
		LC_MONETARY='C' LC_MESSAGES='C' LC_PAPER='C' LC_NAME='C' LC_ADDRESS='C' \
		LC_TELEPHONE='C' LC_MEASUREMENT='C' LC_IDENTIFICATION='C' LC_ALL='C'
	trap '__bake_trap_err' 'ERR'
	trap ':' 'INT' # Ensure Ctrl-C ends up printing <- ERROR ==== etc.
	bake.cfg pedantic-task-cd 'no'

	# Parse arguments
	# Set `BAKE_{ROOT,FILE}`
	BAKE_ROOT=; BAKE_FILE=
	__bake_parse_args "$@"
	if ! shift "$REPLY"; then
		__bake_internal_die 'Failed to shift'
	fi

	# Set variables à la Make
	# shellcheck disable=SC1007
	local __bake_key= __bake_value=
	local __bake_arg=
	for __bake_arg; do case $__bake_arg in
		*=*)
			IFS='=' read -r __bake_key __bake_value <<< "$__bake_arg"

			declare -g "$__bake_key"
			local -n __bake_variable="$__bake_key"
			__bake_variable="$__bake_value"

			if ! shift; then
				__bake_internal_die 'Failed to shift'
			fi
			;;
		*) break
	esac done; unset -v __bake_arg
	unset -v __bake_key __bake_value
	unset -vn __bake_variable

	local __bake_task="$1"
	if [ -z "$__bake_task" ]; then
		__bake_internal_error "No valid task supplied"
		__bake_print_tasks
		exit 1
	fi
	if ! shift; then
		__bake_internal_die 'Failed to shift'
	fi

	if ! cd "$BAKE_ROOT"; then
		__bake_internal_die "Failed to cd"
	fi

	# shellcheck disable=SC2097,SC1007,SC1090
	__bake_task= source "$BAKE_FILE"

	if declare -f task."$__bake_task" >/dev/null 2>&1; then
		local line=
		local shouldTestNextLine='no'
		while IFS= read -r line; do
			if [ "$shouldTestNextLine" = 'yes' ]; then
				if [[ $line == *'bake.cfg'*big-print*no* ]]; then
					__bake_cfg_big_print='no'
				fi
				shouldTestNextLine='no'
			fi

			if [[ $line == @(task."$__bake_task"|init)*'('*')'*'{' ]]; then
				shouldTestNextLine='yes'
			fi
		done < "$BAKE_FILE"; unset -v line shouldTestNextLine

		__bake_print_big "-> RUNNING TASK '$__bake_task'"
		if declare -f init >/dev/null 2>&1; then
			init "$__bake_task"
		fi
		task."$__bake_task" "$@"
		__bake_print_big "<- DONE"
	else
		__bake_internal_error "Task '$__bake_task' not found"
		__bake_print_tasks
		exit 1
	fi
}
