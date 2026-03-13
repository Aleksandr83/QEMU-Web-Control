#!/bin/bash

# get_file_sha256.sh - Compute combined SHA256 checksum for a directory or file list
# Version: 4.0
# Usage: --lang=ru  for Russian, default is English

LANG_CODE="en"
for arg in "$@"; do
    case $arg in --lang=*) LANG_CODE="${arg#*=}" ;; esac
done

declare -A MSG
if [[ "$LANG_CODE" == "ru" ]]; then
    MSG=(
        [help_usage]="Использование: $0 [ОПЦИИ]"
        [help_required]="Обязательные опции (должна быть указана хотя бы одна):"
        [help_dir]="  --dir=ПУТЬ          Корневая директория для рекурсивного обхода"
        [help_files]="  --files=СПИСОК      Список конкретных файлов через запятую"
        [help_optional]="Дополнительные опции:"
        [help_output]="  --output=ФАЙЛ       Имя выходного файла (обязательно)"
        [help_ignore]="  --ignore_folders=СПИСОК  Папки для игнорирования (через запятую)"
        [help_lang]="  --lang=КОД          Язык интерфейса: en (по умолчанию), ru"
        [help_helpflag]="  --help              Показать эту справку"
        [help_examples]="Примеры:"
        [help_desc]="Описание:"
        [help_desc1]="  Скрипт вычисляет ОБЩУЮ SHA256 сумму для файлов из --dir и/или --files."
        [help_desc2]="  --dir и --files можно комбинировать. Выходной файл содержит одно значение."
        [help_algo]="  Алгоритм работы:"
        [help_algo1]="  1. Собираются все файлы (рекурсивно) с учётом игнорируемых папок"
        [help_algo2]="  2. Для каждого файла вычисляется его SHA256"
        [help_algo3]="  3. Все хэши сортируются и конкатенируются"
        [help_algo4]="  4. Вычисляется финальный SHA256 от этой строки"
        [help_note]="  Это позволяет детектировать любые изменения в любых файлах директории."
        [err_unknown]="Неизвестный параметр"
        [err_no_input]="Ошибка: Необходимо указать --dir или --files"
        [err_no_output]="Ошибка: Необходимо указать --output"
        [err_no_dir]="Ошибка: Директория не существует"
        [err_no_sha256]="Ошибка: Команда sha256sum не найдена"
        [err_install_sha256]="Установите: sudo apt install coreutils"
        [err_no_files]="ОШИБКА: Не найдено ни одного файла для обработки!"
        [header]="ВЫЧИСЛЕНИЕ ОБЩЕЙ SHA256 СУММЫ"
        [mode_files]="Источник: конкретные файлы/директории (--files)"
        [mode_dir]="Источник: рекурсивный обход директории (--dir)"
        [label_dir]="Директория"
        [label_ignore]="Игнорируемые папки"
        [label_collecting]="  Сбор файлов из"
        [warn_not_found]="  Предупреждение: не найден"
        [label_found]="Найдено файлов"
        [label_hashing]="Вычисление хэшей отдельных файлов:"
        [label_progress]="  Прогресс"
        [label_computing]="Вычисление общей SHA256 суммы..."
        [label_done]="ГОТОВО!"
        [label_processed]="Обработано файлов"
        [label_time]="Время выполнения"
        [label_total_hash]="Общая SHA256 сумма директории:"
        [label_saved]="Результат сохранён в"
        [label_content]="Содержимое выходного файла (одно значение):"
    )
else
    MSG=(
        [help_usage]="Usage: $0 [OPTIONS]"
        [help_required]="Required options (at least one must be specified):"
        [help_dir]="  --dir=PATH          Root directory for recursive traversal"
        [help_files]="  --files=LIST        Comma-separated list of specific files"
        [help_optional]="Additional options:"
        [help_output]="  --output=FILE       Output file name (required)"
        [help_ignore]="  --ignore_folders=LIST  Folders to ignore (comma-separated)"
        [help_lang]="  --lang=CODE         Interface language: en (default), ru"
        [help_helpflag]="  --help              Show this help"
        [help_examples]="Examples:"
        [help_desc]="Description:"
        [help_desc1]="  Computes a COMBINED SHA256 checksum for files from --dir and/or --files."
        [help_desc2]="  --dir and --files can be combined. The output file contains one value."
        [help_algo]="  Algorithm:"
        [help_algo1]="  1. All files are collected recursively, respecting ignored folders"
        [help_algo2]="  2. SHA256 is computed for each file"
        [help_algo3]="  3. All hashes are sorted and concatenated"
        [help_algo4]="  4. Final SHA256 is computed from that string"
        [help_note]="  This detects any change in any file within the directory."
        [err_unknown]="Unknown parameter"
        [err_no_input]="Error: --dir or --files must be specified"
        [err_no_output]="Error: --output must be specified"
        [err_no_dir]="Error: directory does not exist"
        [err_no_sha256]="Error: sha256sum command not found"
        [err_install_sha256]="Install with: sudo apt install coreutils"
        [err_no_files]="ERROR: No files found to process!"
        [header]="COMPUTING COMBINED SHA256 CHECKSUM"
        [mode_files]="Source: specific files/directories (--files)"
        [mode_dir]="Source: recursive directory traversal (--dir)"
        [label_dir]="Directory"
        [label_ignore]="Ignored folders"
        [label_collecting]="  Collecting files from"
        [warn_not_found]="  Warning: not found"
        [label_found]="Files found"
        [label_hashing]="Computing individual file hashes:"
        [label_progress]="  Progress"
        [label_computing]="Computing combined SHA256 checksum..."
        [label_done]="DONE!"
        [label_processed]="Files processed"
        [label_time]="Elapsed time"
        [label_total_hash]="Combined SHA256 checksum:"
        [label_saved]="Result saved to"
        [label_content]="Output file contents (single value):"
    )
fi

show_help() {
    cat << EOF
${MSG[help_usage]}

${MSG[help_required]}
${MSG[help_dir]}
${MSG[help_files]}

${MSG[help_optional]}
${MSG[help_output]}
${MSG[help_ignore]}
${MSG[help_lang]}
${MSG[help_helpflag]}

${MSG[help_examples]}
  $0 --dir=/home/user/docs --output=result.txt
  $0 --files=file1.txt,file2.jpg --output=result.txt
  $0 --dir=/home/user --ignore_folders=.git,temp --output=result.txt
  $0 --dir=/home/user --output=result.txt --lang=ru

${MSG[help_desc]}
${MSG[help_desc1]}
${MSG[help_desc2]}

${MSG[help_algo]}
${MSG[help_algo1]}
${MSG[help_algo2]}
${MSG[help_algo3]}
${MSG[help_algo4]}

${MSG[help_note]}
EOF
}

is_ignored() {
    local path="$1"
    shift
    local ignore_list=("$@")
    for ignore in "${ignore_list[@]}"; do
        if [[ -n "$ignore" ]]; then
            if [[ "$path" == *"/$ignore"* ]] || [[ "$path" == "$ignore"* ]]; then
                return 0
            fi
        fi
    done
    return 1
}

collect_files() {
    local dir="$1"
    shift
    local ignore_folders=("$@")
    local files_list=()

    if is_ignored "$dir" "${ignore_folders[@]}"; then
        return
    fi

    while IFS= read -r -d '' item; do
        if [[ -f "$item" ]]; then
            files_list+=("$item")
        elif [[ -d "$item" ]]; then
            while IFS= read -r -d '' subfile; do
                files_list+=("$subfile")
            done < <(collect_files "$item" "${ignore_folders[@]}")
        fi
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | sort -z)

    printf '%s\0' "${files_list[@]}"
}

format_time() {
    local seconds=$1
    printf "%02d:%02d:%02d" $((seconds/3600)) $((seconds%3600/60)) $((seconds%60))
}

normalize_path() {
    local p="${1/#\~/$HOME}"
    realpath "$p" 2>/dev/null || readlink -f "$p" 2>/dev/null || (cd "$(dirname "$p")" 2>/dev/null && echo "$(pwd)/$(basename "$p")")
}

DIR=""
FILES=""
OUTPUT=""
IGNORE_FOLDERS=()
HELP=false

for arg in "$@"; do
    case $arg in
        --dir=*)
            DIR="${arg#*=}"
            ;;
        --files=*)
            FILES="${arg#*=}"
            ;;
        --output=*)
            OUTPUT="${arg#*=}"
            ;;
        --ignore_folders=*)
            IFS=',' read -ra TEMP_IGNORE <<< "${arg#*=}"
            for i in "${!TEMP_IGNORE[@]}"; do
                cleaned=$(echo "${TEMP_IGNORE[$i]}" | xargs)
                [[ -n "$cleaned" ]] && IGNORE_FOLDERS+=("$cleaned")
            done
            ;;
        --lang=*)
            ;;
        --help)
            HELP=true
            ;;
        *)
            echo "${MSG[err_unknown]}: $arg" >&2
            show_help
            exit 1
            ;;
    esac
done

if $HELP; then
    show_help
    exit 0
fi

if [[ -z "$DIR" && -z "$FILES" ]]; then
    echo "${MSG[err_no_input]}" >&2
    show_help
    exit 1
fi

if [[ -z "$OUTPUT" ]]; then
    echo "${MSG[err_no_output]}" >&2
    show_help
    exit 1
fi

if [[ -n "$DIR" ]]; then
    if [[ ! -d "${DIR/#\~/$HOME}" ]]; then
        echo "${MSG[err_no_dir]}: '$DIR'" >&2
        exit 1
    fi
    DIR=$(normalize_path "$DIR")
fi

if ! command -v sha256sum &> /dev/null; then
    echo "${MSG[err_no_sha256]}" >&2
    echo "${MSG[err_install_sha256]}" >&2
    exit 1
fi

START_TIME=$(date +%s)
TEMP_DIR=$(mktemp -d)
TEMP_HASHES="$TEMP_DIR/hashes.txt"

echo "==========================================" >&2
echo "${MSG[header]}" >&2
echo "==========================================" >&2

FILES_LIST=()

if [[ -n "$DIR" ]]; then
    echo "${MSG[mode_dir]}" >&2
    echo "${MSG[label_dir]}: $DIR" >&2
    if [[ ${#IGNORE_FOLDERS[@]} -gt 0 ]]; then
        echo "${MSG[label_ignore]}: ${IGNORE_FOLDERS[*]}" >&2
    fi
    echo "----------------------------------------" >&2
    while IFS= read -r -d '' file; do
        FILES_LIST+=("$file")
    done < <(collect_files "$DIR" "${IGNORE_FOLDERS[@]}")
fi

if [[ -n "$FILES" ]]; then
    echo "${MSG[mode_files]}" >&2
    IFS=',' read -ra FILE_ARRAY <<< "$FILES"
    for file in "${FILE_ARRAY[@]}"; do
        file=$(echo "$file" | xargs)
        [[ -z "$file" ]] && continue
        file=$(normalize_path "$file")
        if [[ -f "$file" ]]; then
            FILES_LIST+=("$file")
        elif [[ -d "$file" ]]; then
            echo "${MSG[label_collecting]}: $file" >&2
            while IFS= read -r -d '' subfile; do
                FILES_LIST+=("$subfile")
            done < <(collect_files "$file" "${IGNORE_FOLDERS[@]}")
        else
            echo "${MSG[warn_not_found]}: '$file'" >&2
        fi
    done
fi

IFS=$'\n' FILES_LIST=($(sort -u <<<"${FILES_LIST[*]}"))
unset IFS

TOTAL_FILES=${#FILES_LIST[@]}
echo "${MSG[label_found]}: $TOTAL_FILES" >&2
echo "----------------------------------------" >&2

if [[ $TOTAL_FILES -eq 0 ]]; then
    echo "${MSG[err_no_files]}" >&2
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "${MSG[label_hashing]}" >&2
CURRENT=0
for file in "${FILES_LIST[@]}"; do
    ((CURRENT++))
    PERCENT=$((CURRENT * 100 / TOTAL_FILES))
    echo -ne "${MSG[label_progress]}: [$CURRENT/$TOTAL_FILES] $PERCENT% - $(basename "$file")\r" >&2
    sha256sum "$file" | awk '{print $1}' >> "$TEMP_HASHES"
done
echo -e "\n----------------------------------------" >&2

sort -o "$TEMP_HASHES" "$TEMP_HASHES"

echo "${MSG[label_computing]}" >&2
FINAL_HASH=$(sha256sum "$TEMP_HASHES" | awk '{print $1}')

echo "$FINAL_HASH" > "$OUTPUT"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "==========================================" >&2
echo "${MSG[label_done]}" >&2
echo "----------------------------------------" >&2
echo "${MSG[label_processed]}: $TOTAL_FILES" >&2
echo "${MSG[label_time]}: $(format_time $DURATION)" >&2
echo "----------------------------------------" >&2
echo "${MSG[label_total_hash]}" >&2
echo "  $FINAL_HASH" >&2
echo "----------------------------------------" >&2
echo "${MSG[label_saved]}: $OUTPUT" >&2
echo "" >&2
echo "${MSG[label_content]}" >&2
cat "$OUTPUT" >&2
echo "==========================================" >&2

rm -rf "$TEMP_DIR"
chmod 644 "$OUTPUT" 2>/dev/null
