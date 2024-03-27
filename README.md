# DirBackup S3cmd

[![Docker Pulls](https://img.shields.io/docker/pulls/ssedov/dirbackup-s3cmd)](https://hub.docker.com/r/ssedov/dirbackup-s3cmd)

-----------
Create an archive from the /data (mounted volume) and send it to S3 (using s3cmd). 

## Important notes
Use [xueshanf/awscli](https://hub.docker.com/r/xueshanf/awscli:latest)

## Usage

### Build and push

Edit APP_NAME and TAG in Makefile and run:
```shell
make build
```

### Basic usage

Use the following command to start backup and copy to S3 backet:
```shell
docker run --rm -v /data/web:/data:ro \
  -e BACKUP_FORMAT='xz' \
  -e BACKUP_EXCLUDE='ansible,roles,collections,.terraform,.DS_Store,node_modules,*.log' \
  -e BACKUP_NAME=files \
  -e S3_BACKET=web-backup \
  -e S3_PATH=data \
  -e S3_NAME_PREFIX=data \
  -e S3_ACCESS_KEY='access_key' \
  -e S3_SECRET_KEY='secret' \
  ssedov/dirbackup-s3cmd:2.1
```

## Environment variables

The following environment variables allow you to control the configuration parameters:

- `BACKUP_DIR`: Specifies the directory within the mounted volume that will be archived. By default, it will use the root directory '/'.
- `BACKUP_NAME`: Sets the name of the backup archive. The default name is 'data'.
- `BACKUP_EXCLUDE`: A comma-separated list of items to be excluded from the backup with no spaces. The default is an empty string.
- `BACKUP_FORMAT`: Determines the archiving utility to be used. Options are either 'gzip' or 'xz'. The default format is 'gzip'.
- `S3_BUCKET`: The required name for the bucket in S3 storage.
- `S3_ACCESS_KEY`: The required S3 access key credential.
- `S3_SECRET_KEY`: The required S3 secret key credential.
- `S3_PATH`: Defines the path within the S3 bucket where the archive will be stored. It defaults to an empty string.
- `S3_NAME_PREFIX`: Establishes a prefix for the archive name. The default is an empty string.
- `S3_PROVIDER`: The S3 service is provided by either 'yandex' or 'selectel'. The default provider is 'yandex'.

### Added in branch (tag) dev
- `ROTATION`: Enables the rotation of archives. This is not set by default.
- `ROTATION_DRY_RUN`: Outputs a notification about the intentions, but does not delete files from the storage. This is not set by default.
- `BACKUP_SRC`: The data source for the backup process is provided by either 'cifs' for CIFS server sources or 'local' for local sources. The default provider is 'local'.
- `CIFS_HOST`: The required hostname of the CIFS server. Use BACKUP_SRC=cifs then.
- `CIFS_SHARE`: The required name of the CIFS share. Use BACKUP_SRC=cifs then.
- `CIFS_USER`: The required user credential for accessing the CIFS share. Use BACKUP_SRC=cifs then.
- `CIFS_PASSWORD`: The required password associated with the CIFS user account. Use BACKUP_SRC=cifs then.
- `CIFS_DOMAIN`: The domain of the CIFS user, if applicable. Optional, use BACKUP_SRC=cifs then.


## Rotation Policy Description
The rotation policy ensures that the archives are maintained as follows:
- Daily archives for the last 7 days, including the current day, are preserved when available.
- Weekly archives for the last 4 weeks, including the current week. The policy retains the latest available archive created during that week.
- Monthly archives for the last 4 months, including the current month. The policy retains the latest available archive created in that month.


# Russian

## Описание переменных
- `BACKUP_DIR`: Каталог внутри подключаемого каталога который будет архивирован, по умолчанию ‘/’.
- `BACKUP_NAME`: Имя архива, по умолчанию ‘data’.
- `BACKUP_EXCLUDE`: Список исключений из архива, через запятую, без пробелов, по умолчанию ‘’.
- `BACKUP_FORMAT`: Архиватор, может быть gzip или xz, по умолчанию ‘gzip’.
- `S3_BACKET`: Имя бакета в хранилище S3, требуется обязательно.
- `S3_ACCESS_KEY`: S3 access key, требуется обязательно.
- `S3_SECRET_KEY:` S3 secret key, требуется обязательно.
- `S3_PATH`: Путь к архиву в бакете S3, по умолчанию ‘’.
- `S3_NAME_PREFIX`: Префикс имени архива, по умолчанию ‘’.
- `S3_PROVIDER`: Провайдер S3, может быть 'yandex' или 'selectel', по умолчанию 'yandex'.

### Добавлено в ветке (теге) dev
- `ROTATION`: Включает ротацию архивов, по умолчанию не задано.
- `ROTATION_DRY_RUN`: Выводит уведомление о намерениях, но не удаляет файлы из хранилища, по умолчанию не задано.
- `BACKUP_SRC`: Источник данных для резервного копирования, может быть 'cifs' или 'local', по умолчанию 'local'
- `$CIFS_HOST`: Имя сервера CIFS, требуется обязательно, если BACKUP_SRC=cifs
- `$CIFS_SHARE`: Имя каталога CIFS, требуется обязательно, если BACKUP_SRC=cifs
- `$CIFS_USER`: Имя пользователя CIFS, требуется обязательно, если BACKUP_SRC=cifs
- `$CIFS_PASSWORD`: Пароль пользователя CIFS, требуется обязательно, если BACKUP_SRC=cifs
- `$CIFS_DOMAIN`: Домен пользователя CIFS, может быть установлено, если BACKUP_SRC=cifs, по умолчанию не задано.

## Описание ротации
Всегда остаются архивы:
- Ежедневные за 7 последних дней, включая текущий при их наличии.
- Еженедельные за 4 последние недели, включая текущую. Остается последний из наличия архив сделанный на той неделе.
- Ежемесячные за последние 4 месяца, включая текущий. Остается последний из наличия архив сделанный в том месяце.
