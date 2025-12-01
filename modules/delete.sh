#!/bin/bash

function delete_diary() {
    print_line
    echo " >> [4] 일기 삭제 모드"
    
    show_list
    if [ $? -ne 0 ]; then return; fi

    echo ""
    echo -n " 삭제할 날짜를 입력하세요: "
    read target_date
    
    filename="$DATA_DIR/${target_date}${DIARY_EXT}"

    if [ ! -f "$filename" ]; then
        echo " [!] 파일을 찾을 수 없습니다."
        return
    fi

    echo -n " [보안] 비밀번호 입력 (본인 확인): "
    read -s password
    echo ""

    openssl enc -d -aes-256-cbc -base64 -pbkdf2 -pass pass:"$password" -in "$filename" -out /dev/null 2>/dev/null

    if [ $? -ne 0 ]; then
        echo " [오류] 비밀번호가 일치하지 않아 삭제할 수 없습니다."
        return
    fi

    echo -n " 정말로 삭제하시겠습니까? (y/n): "
    read confirm
    if [ "$confirm" == "y" ]; then
        rm "$filename"
        echo " [성공] 로컬 파일이 영구 삭제되었습니다."
    else
        echo " 삭제가 취소되었습니다."
    fi
}