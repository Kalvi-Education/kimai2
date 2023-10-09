#!/bin/bash -x

function waitForDB() {
  # Parse sql connection data
  if [ ! -z "$DATABASE_URL" ]; then
    DB_TYPE=$(awk -F '[/:@]' '{print $1}' <<< "$DATABASE_URL")
    DB_USER=$(awk -F '[/:@]' '{print $4}' <<< "$DATABASE_URL")
    DB_PASS=$(awk -F '[/:@]' '{print $5}' <<< "$DATABASE_URL")
    DB_UNIX='/'$(awk -F '[/:@]' '{print $7}' <<< "$DATABASE_URL")'/'$(awk -F '[/:@]' '{print $8}' <<< "$DATABASE_URL")':'$(awk -F '[/:@]' '{print $9}' <<< "$DATABASE_URL")':'$(awk -F '[/:@]' '{print $10}' <<< "$DATABASE_URL")
    DB_BASE=$(awk -F '[/:@]' '{print $11}' <<< "$DATABASE_URL")

    export DATABASE_URL="mysql:unix_socket=${DB_UNIX};dbname=${DB_BASE}"
    export DATABASE_SOCKET="${DB_UNIX}"
    export DATABASE_USER="${DB_USER}"
    export DATABASE_PASSWORD="${DB_PASS}"
    export DATABASE_DB_NAME="${DB_BASE}"

    echo "DATABASE_URL=${DATABASE_URL} DB_TYPE=${DB_TYPE} DB_USER=${DB_USER} DB_PASS=${DB_PASS} DB_UNIX=${DB_UNIX} DB_BASE=${DB_BASE}"
  else
    DB_TYPE=${DB_TYPE:mysql}
    if [ "$DB_TYPE" == "mysql" ]; then
      export DATABASE_URL="${DB_TYPE}://${DB_USER:=kimai}:${DB_PASS:=kimai}@${DB_HOST:=sqldb}:${DB_PORT:=3306}/${DB_BASE:=kimai}"
    else
      echo "Unknown database type, cannot proceed. Only 'mysql' is supported, received: [$DB_TYPE]"
      exit 1
    fi
  fi

  re='^[0-9]+$'
  if ! [[ $DB_PORT =~ $re ]] ; then
     DB_PORT=3306
  fi

  echo "Wait for MySQL DB connection ..."
  until php /dbtest.php $DB_UNIX $DB_BASE $DB_USER $DB_PASS; do
    echo Checking DB: $?
    sleep 3
  done
  echo "Connection established"
}

function handleStartup() {
  # These are idempotent, run them anyway
  /opt/kimai/bin/console -n kimai:install
  /opt/kimai/bin/console -n kimai:update
  if [ ! -z "$ADMINPASS" ] && [ ! -a "$ADMINMAIL" ]; then
    /opt/kimai/bin/console kimai:user:create superadmin "$ADMINMAIL" ROLE_SUPER_ADMIN "$ADMINPASS"
  fi
  echo "$KIMAI" > /opt/kimai/var/installed
  echo "Kimai2 ready"
}

function runServer() {
  # Just while I'm fixing things
  /opt/kimai/bin/console kimai:reload --env="$APP_ENV"
  chown -R $USER_ID:$GROUP_ID /opt/kimai/var
  if [ -e /use_apache ]; then
    exec /usr/sbin/apache2 -D FOREGROUND
  elif [ -e /use_fpm ]; then
    exec php-fpm
  else
    echo "Error, unknown server type"
  fi
}

waitForDB
handleStartup
runServer
