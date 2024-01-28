#!/bin/bash

#Script allows you to greet someone
#Usage: ./hello [name]
# $@ и $* - ссылаются на все переданные аргументы для скрипта
# $# - counter
# $0 - показывает имя запускаемого скрипта



echo "Hello $1, how are you today"
echo "\$* gives $*"
echo "\$# gives $#"
echo "\$@ gives $@"
echo "\$0 gives $0"


# trying to show every signle argument on a separated line
echo showing the interpretation of \$*
for i in "$*"
do
	echo $i
done


echo showing the interpretation of \$@
for i in "$@"
do
	echo $i
done
exit 0
