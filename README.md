# yandex-tf-ans-pck
# В этой репе пишу для себя простые примера кода для terraform/ansible/packer/kubernetes в основном на yandex cloud.

#[Структура репозитория]
## kuber_clusters - примеры развертывания кластеров k8s на yandex cloud от простых к сложным.
## packer - сборка образов packerом с заливкой в yandex cloud  и последуюищм использованием в terraform.
## simple_virtuals - развертывание простых виртуалок с сервисами и без на yandex cloud.


## packer/v.1
### Задача: собрать образ ubuntu с предустановленным git.

<details>
Получим данные для нашего YC:

```
yc config list
```

Создаём сервисный аккаунт, назначаем ему права

```
$ SVC_ACCT="<придумайте имя>"
$ FOLDER_ID="<замените на собственный>"
$ yc iam service-account create --name $SVC_ACCT --folder-id $FOLDER_ID
```
```
$ SVC_ACCT="<придумайте имя>"
$ FOLDER_ID="<замените на собственный>"
$ yc iam service-account create --name $SVC_ACCT --folder-id $FOLDER_ID
```

Создаём IAM key для данного аккаунта и экспортируев в файл (является секретом не постим наружу!)

```
$ yc iam key create --service-account-id $ACCT_ID --output <вставьте свой путь>/key.json
```


**Создание файла-шаблона Packer**
Создаем builders и provisioners

```
{
    "builders": [
        {
            "type": "yandex",
            "service_account_key_file": "{{user `key`}}",
            "folder_id": "b1gl9g5f46b3fv1g4ac1",
            "source_image_family": "ubuntu-2204-lts",
            "image_name": "git-base-{{timestamp}}",
            "image_family": "git-base",
            "ssh_username": "ubuntu",
            "platform_id": "standard-v1",
	    "use_ipv4_nat": "true"
        }
    ],
    "provisioners": [
        {
            "type": "shell",
            "script": "scripts/gitinst.sh",
            "execute_command": "sudo {{.Path}}"
        }
    ]
}
```

Разбор файл-шаблона:
* Builders - секция, отвечающая за то, на какой платформе и с какими параметрами мы будем делать ВМ, которую впоследствии сохраним как образ.
* type - тип билдера - то, на какой платформе мы создаём образ.
* folder_id - идентификатор каталога, в котором будет создан образ.
* source_image_family - семейство образов, которое мы берём за основу. Packer самостоятельно выберет самый свежий образ.
* image_name - имя результирующего образа. В имени использована конструкция timestamp, которая гарантирует уникальность имени.
* image_family - имя семейства, к которому мы отнесём результирующий образ.
* ssh_username - имя пользователя, который будет использовандля подключения к ВМ и выполнения provisioning'а.
* platform_id - размер ВМ  смотреть тут - https://cloud.yandex.ru/docs/compute/concepts/vm-platforms
* execute_command позволяет указать, каким способом будет запускаться скрипт. Т.к. команды по установке требуют sudo,то мы указываем, что запускать скрипт следует с sudo.
  т.е. из самих скриптов sudo можно убрать.







Скопируем скрипты в указанные директории из `ubuntu16.json`.
Скрипт выполняет обновление ОС и установку сведего git.

```
apt update
apt upgrade -y
apt install -y ca-certificates curl openssh-server
apt install curl debian-archive-keyring lsb-release ca-certificates apt-transport-https software-properties-common -y
gpg_key_url="https://packages.gitlab.com/gitlab/gitlab-ce/gpgkey"
curl -fsSL $gpg_key_url| sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/gitlab.gpg
tee /etc/apt/sources.list.d/gitlab_gitlab-ce.list<<EOF
deb https://packages.gitlab.com/gitlab/gitlab-ce/ubuntu/ focal main
deb-src https://packages.gitlab.com/gitlab/gitlab-ce/ubuntu/ focal main
EOF
apt update
apt install gitlab-ce
gitlab-ctl reconfigure
```


Выполним проверку на синтаксис:

```
packer validate ./ubuntu16.json
```
**Параметризирование шаблона**

Создаем `variables.json`, `.gitignore` файлы и для коммита в репозиторий `variables.json.examples`. В gitignore включаем variables.json.

```
$ cat variables.json.examples

{
  "key": "key.json",
  "folder_id": "folder-id_from_config",
  "image": "ubuntu-1604-lts"
}
```

Запускаем процесс сборки:
```
packer build ./ubuntu16.json
```




</details>

