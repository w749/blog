#!/bin/bash
IFS=$'\n'
UPDATE_DIR="source/_posts"
UPDATE_MD=`find ${UPDATE_DIR} -name *.md`

#获得随机数返回值，shell函数里算出随机数后，更新该值
function random()
{
    min=$1
    max=$2-$1
    num=$(echo $RANDOM |cksum |cut -c 1-8)
    ((retnum=num%max+min))
    echo "$retnum"
}

for md in ${UPDATE_MD}
do
    old_date=`sed -n '/date: /p' ${md} | sed 's/date: //g' | head -1`
    old_date=`echo ${old_date:0:10}`
    hour=`random 10 22`
    min_date=`random 10 30`
    min_update=`random 31 59`
    second_date=`random 10 59`
    second_update=`random 10 59`
    new_date="${old_date} ${hour}:${min_date}:${second_date}"
    new_update="${old_date} ${hour}:${min_update}:${second_update}"

    sed -i "s/date: .*/date: ${new_date}/g" ${md}
    sed -i "/updated: /d" ${md}
    sed -i "/date: /a\updated: ${new_update}" ${md}
    echo "更新文件：${md}，创建时间：${new_date}，更新时间：${new_update}"
done

