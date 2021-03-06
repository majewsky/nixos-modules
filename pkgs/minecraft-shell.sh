set -euo pipefail

SERVER_ROOT="$HOME/servers"
CURRENT_SERVER="$(systemctl --user | awk '$4 == "running" && $1 ~ /minecraft@/ { print $1 }' | sed 's/^minecraft@//;s/\.service$//' || exit 1)"

usage() {
cat <<-'EOF'
syntax:
	minecraft-shell list            - List names of available servers.
	                                  The mark indicates the currently running server, if any.

	minecraft-shell start <NAME>    - Start given server.
	minecraft-shell stop            - Stop currently running server, if any.

	minecraft-shell status          - Show status of currently running server, if any.
	minecraft-shell logs [ARG...]   - Show logs for currently running server.#
	                                  Args are passed on to journalctl(1).

	minecraft-shell help            - Display this message.

EOF
}

# This program is intended to be used as a login shell, so it's usually invoked as
# `minecraft-shell -c "some command"` by `ssh minecraft some command`.
if [ $# -eq 2 -a "${1:-}" = "-c" ]; then
	set -- $2
fi

if [ $# -eq 0 ]; then
	echo -e "\e[1;31mWARNING:\e[0m Direct shell access is only intended for maintenance usage." >&2
	echo -e '         Run `ssh minecraft help` to see the builtin commands of minecraft-shell.' >&2
	exec bash -i
fi

CMD="$1"
shift

case "$CMD" in
	help)
		usage
		exit 0
		;;
	list)
		if [ $# -ne 0 ]; then
			usage
			exit 1
		fi
		cd "$SERVER_ROOT"
		ls --quoting-style=literal -1 */Server\ Files/ServerStart.sh | cut -d/ -f1 | while read SERVER_NAME; do
			if [ "$CURRENT_SERVER" = "$SERVER_NAME" ]; then
				echo "* $SERVER_NAME"
			else
				echo "  $SERVER_NAME"
			fi
		done
		;;
	stop)
		if [ $# -ne 0 ]; then
			usage
			exit 1
		fi
		if [ -z "$CURRENT_SERVER" ]; then
			echo "No server running."
			exit 0
		fi
		echo "Stopping $CURRENT_SERVER..."
		echo "WARNING: Stopping is currently disabled because it may corrupt the world." >&2
		echo "         Log onto the server and use the /stop command instead." >&2
		exit 1
		#systemctl --user stop "minecraft@$CURRENT_SERVER"
		;;
	start)
		if [ $# -ne 1 ]; then
			usage
			exit 1
		fi
		if [ ! -f "$SERVER_ROOT/$1/Server Files/ServerStart.sh" ]; then
			echo "No such server: $1"
			exit 1
		fi
		if [ -n "$CURRENT_SERVER" ]; then
			if [ "$CURRENT_SERVER" = "$1" ]; then
				echo "Already running."
				exit 0
			else
				echo "Server $CURRENT_SERVER currently running. Use \`stop\` command first."
				exit 1
			fi
		fi
		systemctl --user start "minecraft@$1"
		echo "Server $1 now starting up."
		;;
	status)
		if [ $# -ne 0 ]; then
			usage
			exit 1
		fi
		if [ -z "$CURRENT_SERVER" ]; then
			echo "No server running."
			exit 1
		fi
		systemctl --user status "minecraft@$CURRENT_SERVER"
		;;
	logs)
		if [ "$#" -gt 0 ]; then
			if [[ "$1" != -* ]]; then
				CURRENT_SERVER="$1"
				shift
			fi
		fi
		if [ -z "$CURRENT_SERVER" ]; then
			echo "No server running or specified."
			exit 1
		fi
		exec journalctl -q --user -u "minecraft@$CURRENT_SERVER" "$@"
		;;
	backup)
		echo "This is not needed anymore. We take a daily incremental backup via cronjob."
		;;
	*)
		exec "$CMD" "$@"
		;;
esac
