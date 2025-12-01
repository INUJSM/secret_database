#!/bin/bash

function read_diary() {
    print_line
    echo " >> [2] 일기 조회 모드"
    
    show_list
    if [ $? -ne 0 ]; then return; fi

    echo ""
    echo -n " 조회할 날짜를 입력하세요: "
    read target_date
    
    filename="$DATA_DIR/${target_date}${DIARY_EXT}"

    if [ ! -f "$filename" ]; then
        echo " [!] 파일을 찾을 수 없습니다."
        return
    fi

    echo -n " [보안] 비밀번호 입력: "
    read -s password
    echo ""
    echo " ---------------- 내용 확인 ----------------"

    openssl enc -d -aes-256-cbc -base64 -pbkdf2 -pass pass:"$password" -in "$filename" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        echo " [접근 거부] 비밀번호가 일치하지 않거나 파일이 손상되었습니다."
    fi
    echo ""
}