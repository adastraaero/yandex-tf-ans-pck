#!/usr/bin/expect -f
# Указываем что скрипт должен выполняться через интерпритатор expect, -f указывает на выполнение скрипта из файла.
# expect должен быть предварительно установлен в системе - sudo apt install expect

set timeout 30
set host [lindex $argv 0]
set user [lindex $argv 1]
set password [lindex $argv 2]
set output [lindex $argv 3]

spawn ssh -oKexAlgorithms=+diffie-hellman-group-exchange-sha1,diffie-hellman-group1-sha1 \
    -oHostKeyAlgorithms=+ssh-rsa \
    -oCiphers=+aes256-cbc \
    -oStrictHostKeyChecking=no \
    "$user@$host"

# spawn запускает дочерний процесс, с которым expect может взаимодейстовать.
# Используем старые алгоритмы шифрования для серии Cisco SG300

#Ожидаем появление строки пароль
expect "password:"
# вводим пароль и используем \r, который равен нажатию кнопики enter.
send "$password\r"


# Ожидаем появления приглашения командной строки 
expect -re {#}
# Отключаем постраничную разбивку вывода
send "terminal datadump\r"
expect -re {#}
send "show running-config\r"


# Открываем файл $output на запись  для сохранения конфига.
set f [open $output "w"]
expect {
    -re {#} {
        puts $f $expect_out(buffer)
    }
}

#Ожидаеv, пока вывод команды show running-config завершится иснова будет #
# puts $f $expect_out(buffer) — записывает весь буфер полученного вывода в файл.


# Закрываем файл, завершив запись конфы
close $f

# Завершаем ssh сессию
send "exit\r"

expect eof
