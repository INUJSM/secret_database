#!/bin/bash

function edit_diary() {
    print_line
    echo " >> [3] 일기 수정 모드"
    
    show_list
    if [ $? -ne 0 ]; then return; fi

    echo ""
    echo -n " 수정할 날짜를 입력하세요: "
    read target_date
    
    filename="$DATA_DIR/${target_date}${DIARY_EXT}"

    if [ ! -f "$filename" ]; then
        echo " [!] 파일을 찾을 수 없습니다."
        return
    fi

    echo -n " [보안] 비밀번호 입력 (본인 확인): "
    read -s password
    echo ""

    openssl enc -d -aes-256-cbc -base64 -pbkdf2 -pass pass:"$password" -in "$filename" -out "$TEMP_FILE" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo " [오류] 비밀번호가 틀렸습니다. 수정 권한이 없습니다."
        rm -f "$TEMP_FILE" 2>/dev/null
        return
    fi

    if command -v nano &> /dev/null; then
        nano "$TEMP_FILE"
    else
        vi "$TEMP_FILE"
    fi

    openssl enc -aes-256-cbc -base64 -pbkdf2 -pass pass:"$password" -in "$TEMP_FILE" -out "$filename"
    rm "$TEMP_FILE"

    echo " [성공] 수정된 내용이 다시 암호화되어 저장되었습니다."
}