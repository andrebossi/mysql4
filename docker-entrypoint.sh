#!/bin/sh

set -xv
set -eo pipefail

if [ "${1:0:1}" = '-' ]; then
  set -- mysqld_safe "$@"
fi

HOSTNAME=$(hostname)

file_env() {
  var=$1
  file_var="${var}_FILE"
  var_value=$(printenv $var || true)
  file_var_value=$(printenv $file_var || true)
  default_value=$2

  if [ -n "$var_value" -a -n "$file_var_value" ]; then
    echo >&2 "error: both $var and $file_var are set (but are exclusive)"
    exit 1
  fi

  if [ -z "${var_value}" ]; then
    if [ -z "${file_var_value}" ]; then
      export "${var}"="${default_value}"
    else
      export "${var}"="${file_var_value}"
    fi
  fi

  unset "$file_var"
}

_get_config() {
  conf="$1"
  mysqld_safe --help > /dev/null
  cat /etc/my.cnf | grep -i 'datadir=' | cut -d '=' -f 2
}

DATA_DIR="$(_get_config 'datadir')"

if [ ! -d "${DATA_DIR}tmp" ]; then
	mkdir "${DATA_DIR}tmp"
	chown mysql:mysql  "${DATA_DIR}/tmp"
fi
if [ ! -d "${DATA_DIR}mysql" ]; then
  file_env 'MYSQL_ROOT_PASSWORD'
  if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
    echo >&2 'error: database is uninitialized and password option is not specified '
    echo >&2 '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
    exit 1
  fi

  echo $"$DATA_DIR"
  mkdir -p "$DATA_DIR"
  chown mysql: "$DATA_DIR"

  echo 'Initializing database'
  mysql_install_db --user=mysql --datadir="$DATA_DIR" --rpm
  chown -R mysql: "$DATA_DIR"
  echo 'Database initialized'
  
  tfile=`mktemp`
  if [ ! -f "$tfile" ]; then
      return 1
  fi

  cat << EOF > $tfile
USE mysql;
FLUSH PRIVILEGES;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY "$MYSQL_ROOT_PASSWORD" WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
UPDATE user SET password=PASSWORD("") WHERE user='root' AND host='localhost';
EOF

  if [ "$MYSQL_DATABASE" != "" ]; then
    echo "[i] Creating database: $MYSQL_DATABASE"
    echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> $tfile

    if [ "$MYSQL_USER" != "" ]; then
      echo "[i] Creating user: $MYSQL_USER with password $MYSQL_PASSWORD"
      echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* to '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" >> $tfile
    fi
  fi

  mysqld_safe --user=root --bootstrap --datadir="$DATA_DIR" < $tfile
fi

chown -R mysql: "$DATA_DIR"
exec "$@"