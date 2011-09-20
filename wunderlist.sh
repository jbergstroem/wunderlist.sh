#!/bin/sh
#
# wunderlist.sh
#  - nagware at its finest
#
# See http://github.com/jbergstroem/wunderlist.sh for additional info
#
#
#
# Changelog
#
# - Support the Wunderlist linux flavor
#
# * Released 0.1 (2011-09-16)
#
# - Added list, help, done and new commands
#

VERSION="0.1"

SQLITE=`which sqlite3`

# Modify path depending on what os we run
# defaults to os x (Darwin)
FLAVOR="Library"
[[ `uname` == "Linux" ]] && FLAVOR=".titanium"

DB=`ls ~/${FLAVOR}/Wunderlist/wunderlist.db`

CMD=$1
shift
ARGS=$@

COLOR='\033[01;33m'           # bold yellow
COLOR_IMPORTANT='\033[01;31m' # bold red
COLOR_RESET='\033[00;00m'     # normal white

LIST_SQL="select name,
case
  when date(date, 'unixepoch') = date('now') then 'Today'
  when date(date, 'unixepoch') > date('now') then date(date, 'unixepoch')
  when date(date, 'unixepoch') < date('now') and date != 0 then 'Overdue'
  else  ''
end as date,
important,
id
from tasks where done = 0 and deleted = 0 and list_id = 1
order by position, date desc;"


function list {
  local IFS=$'\n'

  ROWS=`${SQLITE} ${DB} "${LIST_SQL}"`
  if [ -n "$ROWS" ]; then
    echo "=== 2DO ===================="

    for RESULT in $ROWS; do
      # This shows how much I really suck at shell scripting.
      # Note to what lengths I avoid awk
      local M=`echo $RESULT | cut -f 1 -d "|"` # message
      local D=`echo $RESULT | cut -f 2 -d "|"` # date
      local I=`echo $RESULT | cut -f 3 -d "|"` # importance

      if [ -z "$D" ]; then
        D=""
      elif [ $D = "Overdue" ]; then
        D="${COLOR_IMPORTANT}(${D})${COLOR_RESET}"
      else
        D="($D)"
      fi

      if [ $I -eq 1 ]; then
        I="${COLOR_IMPORTANT}*${COLOR_RESET}"
      else
        I="${COLOR}*${COLOR_RESET}"
      fi

      echo " $I $M $D"
    done
  fi
  exit 0
}

function itsdone {
  local IFS=$'\n'
  local NUM=0
  local IDS=""

  ROWS=`${SQLITE} ${DB} "${LIST_SQL}"`
  if [ -n "$ROWS" ]; then
    echo "=== 2DO(NE) ================"
    for RESULT in $ROWS; do
      let "NUM += 1"
      local M=`echo $RESULT | cut -f 1 -d "|"` # message
      local I=`echo $RESULT | cut -f 4 -d "|"` # id
      IDS="$IDS$I|"

      echo " $NUM) $M"
    done
    echo "\nI'm done with: \c"
    read done

    if [[ $done = *[^0-9]* || $done > $NUM || $done < 1 ]]; then
      echo "Not a valid number"
      exit 1
    fi

    local ID_REMOVE=`echo "$IDS" | cut -f $done -d "|"`

    local UPDATE_SQL="update tasks set done_date = strftime('%s', 'now'),
                      done = 1 where id = $ID_REMOVE"

    local RET=`${SQLITE} ${DB} "${UPDATE_SQL}"`
    exit $RET

  fi
}

function new {
  echo $ARGS
  if [[ -z "$1" ]]; then
    echo "Your todo should actually contain something"
    exit 1
  fi

  local INSERT_SQL="insert into tasks(list_id, name)
    values(1, '$ARGS');
  "
  `${SQLITE} ${DB} "${INSERT_SQL}"` || {
    echo "Something went wrong"
    exit 1
  }
  echo "Created new todo: $ARGS"
  exit 0
}

function help {
  echo "\
 wunderlist $VERSION
  - nagware at its finest

 usage:
  wunderlist.sh [option] [arguments]

 options:
  help       : this screen
  list       : shows current todo's in 'new'
  new <todo> : inserts a new todo
  done       : check a todo as done from list
"
  exit 0
}

case "$CMD" in
  done)
    itsdone;
  ;;
  list)
    list;
  ;;
  new)
    new;
  ;;
  *)
    help;
  ;;
esac


