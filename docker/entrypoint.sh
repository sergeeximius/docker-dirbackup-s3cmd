#!/bin/bash

if [[ "$@" == "bash" ]]; then
    exec $@
fi

if [[ ! -z "$BACKUP_SRC" ]]; then
    if [[ $BACKUP_SRC = cifs ]]; then
        test -z "$CIFS_HOST" && echo "CIFS_HOST is not defined" && exit 1
        test -z "$CIFS_SHARE" && echo "CIFS_SHARE is not defined" && exit 1
        test -z "$CIFS_USER" && echo "CIFS_USER is not defined" && exit 1
        test -z "$CIFS_PASSWORD" && echo "CIFS_PASSWORD is not defined" && exit 1
        echo "username=$CIFS_USER" >>~/.smb-credentials
        echo "password=$CIFS_PASSWORD" >>~/.smb-credentials
        test -z "$CIFS_DOMAIN" || echo "domain=$CIFS_DOMAIN" >>~/.smb-credentials
        mkdir -p /data
        echo "Mount CIFS share //${CIFS_HOST}/${CIFS_SHARE}"
        mount.cifs -o credentials=~/.smb-credentials,iocharset=utf8 //${CIFS_HOST}/${CIFS_SHARE} /data
    else
        echo "BACKUP_SRC can be set to 'local' or 'cifs' to determine the backup source type"
        exit 1
    fi
else
    backup_src='local'
fi
test -z "$BACKUP_DIR" && backup_dir='' || backup_dir=/${BACKUP_DIR}
test -z "$BACKUP_NAME" && backup_name='data' || backup_name=${BACKUP_NAME}
if [[ ! -z "$BACKUP_EXCLUDE" ]]; then
    if [[ $BACKUP_EXCLUDE =~ ^[a-zA-Z0-9,_.\*-]+$ ]]; then
        IFS=',' read -r -a dirs <<<"$BACKUP_EXCLUDE"
        exclude_params=()
        for dir in "${dirs[@]}"; do
            exclude_params+=("--exclude=$dir")
        done
        exclude_params+=("--exclude=*.DS_Store")
        echo "Use tar options: "${exclude_params[@]}""
    else
        echo "BACKUP_EXCLUDE contains invalid characters, example 'ansible,.terraform,*.sql' without spaces"
        exit 1
    fi
else
    exclude_params=("--exclude=*.DS_Store")
fi
test -z "$S3_BACKET" && echo "S3_BACKET is not defined" && exit 1
test -z "$S3_ACCESS_KEY" && echo "S3_ACCESS_KEY is not defined" && exit 1
test -z "$S3_SECRET_KEY" && echo "S3_SECRET_KEY is not defined" && exit 1
test -z "$S3_PATH" && s3_path='' || s3_path=/${S3_PATH}
test -z "$S3_NAME_PREFIX" && s3_name_prefix='' || s3_name_prefix=${S3_NAME_PREFIX}_
test -z "$S3_PROVIDER" && s3_provider='yandex' || s3_provider=${S3_PROVIDER}

postfix=$(date +%Y-%m-%d).tar

mv /root/.s3cfg_$([ "$s3_provider" = "selectel" ] && echo "selectel" || echo "yandex") ~/.s3cfg
echo "access_key = $S3_ACCESS_KEY" >>~/.s3cfg
echo "secret_key = $S3_SECRET_KEY" >>~/.s3cfg

backup_bin=$([ "$BACKUP_FORMAT" = "xz" ] && echo "xz" || echo "gzip")
backup_ext=$([ "$BACKUP_FORMAT" = "xz" ] && echo ".xz" || echo ".gz")

# Функция для проверки, содержится ли дата в массиве
date_in_array() {
    local date_to_check=$1
    shift
    local dates_array=("$@")
    for date in "${dates_array[@]}"; do
        if [[ "$date" == "$date_to_check" ]]; then
            return 0 # Дата найдена
        fi
    done
    return 1 # Дата не найдена
}

# Функция для вывода файлов которые должны остаться после ротации
# Последние 6 файлов и 1 последний файл за каждую неделю
function get_files_to_pass() {
    local all_files=("$@")
    local -a to_pass=()

    local -a last_weekly=()
    local -a last_monthly=()
    local -a last_custom=()
    declare -A latest_file_per_week
    declare -A latest_file_per_month

    for ((i = 1; i <= 6; i++)); do
        local last_day=$(date -d "today - $((i - 1)) days" +%Y-%m-%d)
        last_weekly+=("$last_day")
    done
    for ((i = 7; i <= 32; i++)); do
        local last_day=$(date -d "today - $((i - 1)) days" +%Y-%m-%d)
        last_monthly+=("$last_day")
    done
    for ((i = 1; i <= 125; i++)); do
        local last_day=$(date -d "today - $((i - 1)) days" +%Y-%m-%d)
        last_custom+=("$last_day")
    done

    for file in "${all_files[@]}"; do
        file_date_str=$(basename "$file" | egrep -o "\d{4}-\d{2}-\d{2}")

        if date_in_array "$file_date_str" "${last_weekly[@]}"; then
            to_pass+=("${file}_pass_days")
            continue
        fi
        week_of_year=$(date -d "$file_date_str" +%Y-%W)
        latest_file_date_str=$(basename "${latest_file_per_week[$week_of_year]}" | egrep -o "\d{4}-\d{2}-\d{2}")
        if [ -z "${latest_file_per_week[$week_of_year]}" ] || [ "$(date -d "$latest_file_date_str" +%s)" -le "$(date -d "$file_date_str" +%s)" ]; then
            if date_in_array "$file_date_str" "${last_monthly[@]}"; then
                latest_file_per_week[$week_of_year]=$file
            fi
        fi
        month_of_year=$(date -d "$file_date_str" +%Y-%m)
        latest_file_date_str=$(basename "${latest_file_per_month[$month_of_year]}" | egrep -o "\d{4}-\d{2}-\d{2}")
        if [ -z "${latest_file_per_month[$month_of_year]}" ] || [ "$(date -d "$latest_file_date_str" +%s)" -le "$(date -d "$file_date_str" +%s)" ]; then
            if date_in_array "$file_date_str" "${last_custom[@]}"; then
                latest_file_per_month[$month_of_year]=$file
            fi
        fi
    done

    for week in "${!latest_file_per_week[@]}"; do
        to_pass+=("${latest_file_per_week[$week]}_pass_weekly")
    done
    for month in "${!latest_file_per_month[@]}"; do
        to_pass+=("${latest_file_per_month[$month]}_pass_monthly")
    done

    echo "${to_pass[@]}"
}

tar "${exclude_params[@]}" -cf /${backup_name}_${postfix} data${backup_dir}

$backup_bin /${backup_name}_${postfix}
s3cmd --storage-class COLD put /${backup_name}_${postfix}${backup_ext} s3://${S3_BACKET}${s3_path}/${s3_name_prefix}${backup_name}_${postfix}${backup_ext}

if [ $? -ne 0 ]; then
    echo "Command s3cmd return code $?. Exit"
    exit 1
fi

if [[ ! -z "$ROTATION" ]]; then
    # Получение списка файлов в bucket и сортировка (новейшие файлы вверху).
    all_files=($(s3cmd ls s3://${S3_BACKET}${s3_path}/ | awk '{print $4}' | grep -- "${s3_name_prefix}${backup_name}" | sort -r))
    # Определение файлов для пропуска.
    echo $(get_files_to_pass "${all_files[@]}") >/tmp/files_to_pass.txt

    # Вывод информации или ротация
    for file in "${all_files[@]}"; do
        if [[ ! -z "$ROTATION_DRY_RUN" ]]; then
            if grep -q "$file" /tmp/files_to_pass.txt; then
                echo "Will be passed: $file"
            else
                echo "Will be deleted: $file"
            fi
        else
            if grep -q "$file" /tmp/files_to_pass.txt; then
                echo "Passing: $file"
            else
                echo "Deleting: $file"
                #s3cmd del "$file"
            fi
        fi
    done

    echo "Rotation debug:"
    tr ' ' '\n' < /tmp/files_to_pass.txt | sort -r
fi

exec "$@"
