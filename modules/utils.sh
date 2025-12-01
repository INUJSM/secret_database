#!/bin/bash

# [핵심] 스크립트 위치 및 데이터 경로 설정
# 메인에서 BASE_DIR을 넘겨받지만, 안전을 위해 체크
if [ -z "$BASE_DIR" ]; then
    BASE_DIR=$(dirname "$(dirname "$(realpath "$0")")")
fi

DATA_DIR="$BASE_DIR/data"
DIARY_EXT=".enc"
TEMP_FILE="$BASE_DIR/.temp_edit"

# 데이터 폴더가 없으면 생성
if [ ! -d "$DATA_DIR" ]; then
    mkdir -p "$DATA_DIR"
fi

# [자동 이사] 혹시 바깥(루트)에 있는 일기 파일이 있다면 data 폴더로 이동
mv "$BASE_DIR"/*.enc "$DATA_DIR" 2>/dev/null

# --------------------------------------------------------
# 유틸리티 함수
# --------------------------------------------------------

function print_line() {
    echo "------------------------------------------------------"
}

function show_list() {
    echo " [ 저장된 일기 목록 ]"
    
    # 데이터 폴더 확인 및 파일 개수 세기
    if [ ! -d "$DATA_DIR" ]; then
        echo " (저장된 일기가 없습니다)"
        return 1
    fi

    count=$(ls "$DATA_DIR"/*${DIARY_EXT} 2>/dev/null | wc -l)
    
    if [ "$count" -eq 0 ]; then
        echo " (저장된 일기가 없습니다)"
        return 1
    fi

    # 경로(data/)를 빼고 파일명만 예쁘게 출력
    ls "$DATA_DIR"/*${DIARY_EXT} | xargs -n 1 basename
    return 0
}