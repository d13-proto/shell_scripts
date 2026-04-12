#! /usr/bin/env bash

# 导出MySQL数据库结构
mysqldump_structure() {
    mysqldump --no-create-db --no-data --events --routines --compact "$@" \
    | sed -E 's/^\/\*![0-9]+.*\*\/;?\s*//g' \
    | sed -E 's/ AUTO_INCREMENT=[0-9]+//g' \
    | tr --squeeze-repeats '\n' \
    | sed -E '/^CREATE TABLE/i\\'
}