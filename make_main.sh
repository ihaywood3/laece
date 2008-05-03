#!/bin/sh

(
    cat main_start.html
    cd jst
    for i in `ls *.jst`; do
        echo "<textarea id=\"`basename $i .jst`\" style=\"display: none;\">"
        cat $i
        echo "</textarea>"
    done
    echo "</body></html>" 
) > main.html