if [[ -z "$RAILS_ENV" ]]; then
    echo "ERROR: You must set RAILS_ENV."
    exit
else
    echo "RAILS_ENV=$RAILS_ENV"
fi

if [[ -s "$HOME/.rvm/scripts/rvm" ]] ; then

  # First try to load from a user install
  source "$HOME/.rvm/scripts/rvm"

elif [[ -s "/usr/local/rvm/scripts/rvm" ]] ; then

  # Then try to load from a root install
  source "/usr/local/rvm/scripts/rvm"

else

  printf "ERROR: An RVM installation was not found.\n"

fi

function cmdline_for_pid () {
    pid="$1"
    if [ -n "$pid" ]; then
        cat "/proc/${pid}/cmdline" | tr '\0' ' ' | sed -r -e 's/\s+$//'
    else
        cat ""
    fi
}

function pid_killer () {
    pid="$1"
    if [ -z "$pid" ]; then
        echo "Empty pid passed to pid_killer."
    elif [ ! -d "/proc/${pid}" ]; then
        echo "Non-existent pid (${pid}) passed to pid_killer."
    else
        cmdline=$(cmdline_for_pid "$pid")
        kill -TERM "$pid"
        echo "Sent TERM signal to process ${pid} (${cmdline})"
        tries=3
        while [ -d "/proc/${pid}" -a "$tries" -gt 0 ]; do
            echo "Waiting for process ${pid} to disappear"
            sleep 2
            tries=$(($tries - 1))
            if [ "$tries" -eq 0 ]; then
                kill -KILL "$pid"
                echo "Sent KILL signal to process ${pid} (${cmdline})"
            fi
        done
    fi
}

function pidfile_killer () {
    if [ -n "$1" -a -f "$1" ]; then
        pid=$(cat "$1")
        pid_killer "$pid"
        rm -f "$1"
    else
        echo "No such pid file: $1"
    fi
}

PIDFILE=$HOME/data/pidfile
IMPORT_WORKER_PIDFILE=$HOME/data/import_worker_pid
IMPORT_WORKER_LOGFILE=$HOME/log/import_worker.log
UNICORN_CFG=$HOME/src/shared/config/unicorn.rb
PWD=`pwd`

cd $HOME/src/current;
pidfile_killer "$PIDFILE"
pidfile_killer "$IMPORT_WORKER_PIDFILE"

echo "Restarting unicorn"
bundle exec unicorn_rails -c $UNICORN_CFG -D &&

echo "Restarting delayed_job"
bundle exec script/delayed_job -n 2 restart;


echo "Restarting import:worker task"
bundle exec rake import:worker 2>&1 >> "$IMPORT_WORKER_LOGFILE" &
echo "$!" > $IMPORT_WORKER_PIDFILE;

echo "Done"

cd $PWD;
