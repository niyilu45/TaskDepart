#!/bin/bash
# 1) Delete Useless Lines
# 2) Depart to blocks with TaskBegin and TaskEnd
# 3) In every block, find the [str]
# 4) If [str] exist, change str to array in 5), else depart blocks to many files in 6).
# 5) Copy this block by size of array, and assgin value of array. 
#     Do not deal with the second [str] in this block, go to 2)
# 6) Depart blocks to files.

function DelNoneUseLines(){
    tmpFile=$1
    commentStartFlag=$2
    commentEndFlag=$3
    # delete lines begin with % \s* means 0 to n blank
    sed -i '/^\s*\%/d' $tmpFile
    # delete lines in CommentBegin and CommentEnd
    sed -i "/${commentStartFlag}/,/${commentEndFlag}/d" $tmpFile
}
function GetDataSplitColon(){
    str=$1
    idx=$2
    OLDIFS=$IFS
    IFS=':'
    array=($str)
    IFS=$OLDIFS
    size=0
    first=${array[0]}
    intvl=${array[1]}
    configNum=${#array[*]}
    data=`echo $first $intvl $idx | awk '{printf "%0.1f\n", $1+($2*$3)}'`
    echo $data
}
function CalcNumSplitColon(){
    str=$1
    OLDIFS=$IFS
    IFS=':'
    array=($str)
    IFS=$OLDIFS
    size=0
    first=${array[0]}
    intvl=${array[1]}
    last=${array[2]}
    configNum=${#array[*]}
    dataNum=0
    whileFlag=1
    isIntvlPositive=`echo $intvl | awk '{printf($1>=0)?"1":"0"}'`
    if [ $configNum -ne 3 ]; then
        dataNum=0
    elif [ $isIntvlPositive -eq 1 ]; then
        until [ $whileFlag -ne 1 ] ; do
            let dataNum++
            first=`echo ${first} ${intvl} | awk '{printf "%0.1f\n", $1+$2}'`
            whileFlag=`echo $first $last | awk '{printf($1<=$2)?"1":"0"}'`
        done
    else
        until [ $whileFlag -ne 1 ] ; do
            let dataNum++
            first=`echo ${first} ${intvl} | awk '{printf "%0.1f\n", $1+$2}'`
            whileFlag=`echo $first $last | awk '{printf($1>=$2)?"1":"0"}'`
        done
    fi
    echo $dataNum
}
function GetDataSplitComma(){
    str=$1
    OLDIFS=$IFS
    IFS=','
    array=($str)
    IFS=$OLDIFS
    echo ${array[$2]}
}
function CalcNumSplitComma(){
    str=$1
    OLDIFS=$IFS
    IFS=','
    array=($str)
    IFS=$OLDIFS
    echo ${#array[*]}
}
function GetStrInBrackets(){
    str=${str#*[}
    str=${str%]*}
    echo $str
}
function IsExistColon(){
    str=$1
    colon=':'
    if [[ $str == *$colon* ]]
    then
        echo 1
    else
        echo 0
    fi
}

###############################
# Main
tmpFile="simParameterTmp.txt"
taskStartFlag=TaskBegin
taskEndFlag=TaskEnd
commentStartFlag=CommentBegin
commentEndFlag=CommentEnd
\cp -f simParameter.txt $tmpFile

DelNoneUseLines $tmpFile $commentStartFlag $commentEndFlag

mayExistBrackInTask=1
while [ $mayExistBrackInTask -eq 1 ] ; do
    tbLines=`cat -n $tmpFile | grep $taskStartFlag | awk '{print $1}'`
    tbLines=($tbLines)
    teLines=`cat -n $tmpFile | grep $taskEndFlag | awk '{print $1}'`
    teLines=($teLines)
    tbNum=${#tbLines[*]}
    teNum=${#teLines[*]}
    if [ $tbNum -ne $teNum ]; then
        echo "Numbers of TaskBegin and TaskEnd are not same!"
        exit
    fi
    i=0
    mayExistBrackInTask=0
    while [ $i -lt $tbNum ] ; do
        # find the bracket in line 1 to line teLines.
        bkLines=`cat -n $tmpFile | head -n ${teLines[$i]}| grep '\[' | awk '{print $1}'`
        bkLines=($bkLines) # depart by blank
        bkNum=${#bkLines[*]}
        if [ $bkNum -ne 0 ]; then
            # Copy the task and replace content in brackets.
            bkSolveLine=${bkLines[0]} # Only solve one line, others waits for subsequent loop.
            # Parse data in bracket
            str=`sed -n "$bkSolveLine p" $tmpFile`
            strInBrack=`GetStrInBrackets "$str"`
            # Get the num array in brackets
            isExistColon=`IsExistColon "$strInBrack"`
            if [ $isExistColon -eq 1 ]; then
                dataNumInBrack=`CalcNumSplitColon $strInBrack`
                for ((k=0; k<dataNumInBrack; k++)) do
                    arr[$k]=`GetDataSplitColon "$strInBrack" $k`
                done
            else
                dataNumInBrack=`CalcNumSplitComma "$strInBrack" `
                for ((k=0; k<dataNumInBrack; k++)) do
                    arr[$k]=`GetDataSplitComma "$strInBrack" $k`
                done
            fi
            # Copy the Task
            for ((j=0; j<dataNumInBrack-1; j++)) do
                sed -rni "p;${tbLines[$i]},${teLines[$i]}H;${teLines[$i]}{g;p}" $tmpFile
            done
            # Replace the data in bracket lins of copied Tasks.
            if [ $dataNumInBrack -eq 0 ]; then
                echo "error dataNumInBracket = 0"
                exit
            fi
            for ((j=0; j<dataNumInBrack; j++)) do
                let tmpLine=teLines[i]-tbLines[i]+1+1
                let tmpLine=tmpLine*j+bkSolveLine
                sed -i "${tmpLine}s/\[.*\]/${arr[$j]}/g" $tmpFile
            done

            mayExistBrackInTask=1
            let i=0 # refind from the begin of files.
            break
        fi
        let i++
    done
done
echo "----End File----"
cat $tmpFile


