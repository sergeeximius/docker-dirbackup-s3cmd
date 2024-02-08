#!/bin/bash

if [[ "$@" == "bash" ]]; then
    exec $@
fi

test -z "$BACKUP_DIR" && BACKUP_DIR='' || BACKUP_DIR=/${BACKUP_DIR}
test -z "$BACKUP_NAME" && BACKUP_NAME='data' || BACKUP_NAME=${BACKUP_NAME}
if [[ ! -z "$BACKUP_EXCLUDE" ]]; then
  if [[ $BACKUP_EXCLUDE =~ ^[a-zA-Z0-9,_.\*-]+$ ]]; then
    IFS=',' read -r -a dirs <<< "$BACKUP_EXCLUDE"
    EXCLUDE_PARAMS=()
    for dir in "${dirs[@]}"; do
      EXCLUDE_PARAMS+=("--exclude=$dir")
    done
    echo "Use tar options: "${EXCLUDE_PARAMS[@]}""
  else
    echo "BACKUP_EXCLUDE contains invalid characters, example 'ansible,.terraform,*.sql' without spaces"
    exit 1
  fi
else
  EXCLUDE_PARAMS=''
fi
test -z "$S3_BACKET" && echo "S3_BACKET is not defined" && exit 1
test -z "$S3_ACCESS_KEY" && echo "S3_ACCESS_KEY is not defined" && exit 1
test -z "$S3_SECRET_KEY" && echo "S3_SECRET_KEY is not defined" && exit 1
test -z "$S3_PATH" && S3_PATH=''
test -z "$S3_NAME_PREFIX" && S3_NAME_PREFIX='' || S3_NAME_PREFIX=${S3_NAME_PREFIX}_
test -z "$S3_PROVIDER" && S3_PROVIDER='yandex'

POSTFIX=$(date +%Y-%m-%d).tar

if [ "$S3_PROVIDER" = "selectel" ]; then
  mv /root/.s3cfg_selectel ~/.s3cfg
else
  mv /root/.s3cfg_yandex ~/.s3cfg
fi

echo "access_key = $S3_ACCESS_KEY" >> ~/.s3cfg
echo "secret_key = $S3_SECRET_KEY" >> ~/.s3cfg

tar "${EXCLUDE_PARAMS[@]}" -cf /${BACKUP_NAME}_${POSTFIX} data${BACKUP_DIR}

if [ "$BACKUP_FORMAT" = "xz" ]; then
  BACKUP_BIN="xz"
  BACKUP_EXT=".xz"
else
  BACKUP_BIN="gzip"
  BACKUP_EXT=".gz"
fi

$BACKUP_BIN /${BACKUP_NAME}_${POSTFIX}
s3cmd --storage-class COLD put /${BACKUP_NAME}_${POSTFIX}${BACKUP_EXT} s3://${S3_BACKET}/${S3_PATH}/${S3_NAME_PREFIX}${BACKUP_NAME}_${POSTFIX}${BACKUP_EXT}

if [ $? -ne 0 ]; then
  exit 1
fi

exec "$@"
