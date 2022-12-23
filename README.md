# yandex-tf-ans-pck
В этой репе пишу для себя простые примера кода для terraform/ansible/packer/kubernetes в основном на yandex cloud.

Структура репозитория:
* kuber_clusters - примеры развертывания кластеров k8s на yandex cloud от простых к сложным.
* packer - сборка образов packerом с заливкой в yandex cloud  и последуюищм использованием в terraform.
* simple_virtuals - развертывание простых виртуалок с сервисами и без на yandex cloud.

## kuber_clusters/v.1
### Задача: Развертывание простого кластера k8s на yandex cloud

<details>

```
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.60.0"
    }
  }
}

provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

resource "yandex_kubernetes_cluster" "k8s-cluster" {
  name       = "k8s-cluster"
  network_id = var.network_id

  master {
    version = "1.21"
    zonal {
      zone      = var.zone
      subnet_id = var.subnet_id
    }
    public_ip = true
  }

  service_account_id      = var.service_account_id
  node_service_account_id = var.service_account_id

  release_channel         = "RAPID"
  network_policy_provider = "CALICO"
}

resource "yandex_kubernetes_node_group" "k8s-node" {
  cluster_id = yandex_kubernetes_cluster.k8s-cluster.id
  version    = "1.21"
  name       = "k8s-node"

  instance_template {

    resources {
      cores  = var.cores
      memory = var.memory
    }

    network_interface {
      subnet_ids = ["e9bc19cu3vl8fknf5mn6"]
      nat        = true
    }


    boot_disk {
      type = "network-ssd"
      size = var.size
    }

    metadata = {
      ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    }
  }

  scale_policy {
    #Ключ fixed_scale определяет группу ВМ фиксированного размера. Размер группы определяется в ключе size
    fixed_scale {
      size = 2
    }
  }
}
```

</details>

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

## simple_virtuals/yandex_git_tf
### Задача: Развернуть на yandex cloud ВМ с предустановленным git используя,ранее собранный packerом образ (packer/v.1).

<details>
Если использовать значение memory меньше 4, то гит не заводится.

```
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}



provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

resource "yandex_compute_instance" "git-srv" {
  name  = "git-srv-${count.index}"
  count = var.instance_count

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      # Указать id образа
      image_id = var.image_id
    }
  }

  network_interface {
    # Указан id подсети default-ru-central1-a
    subnet_id = var.subnet_id
    nat       = true
  }
  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }
}
```
</details>

## simple_virtuals/v.1/
### Задача: развертывание в yandex cloud ВМ с ubuntu 22.04 и внешним ip адресом.

<details>
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}


provider "yandex" {
  token = "********************************************" # *OAuth-токен яндекса*
  # не обязательный параметр (берется облако по умолчанию),
  # хотя в документации написано иначе
  cloud_id  = "**********************"
  folder_id = "**************"
  zone      = "******"
}

data "yandex_compute_image" "last_ubuntu" {
  family = "ubuntu-2204-lts" # ОС (Ubuntu, 22.04 LTS)
}

data "yandex_vpc_subnet" "default_a" {
  name = "default-ru-central1-a" # одна из дефолтных подсетей
}




# ресурс "yandex_compute_instance" т.е. сервер
# Terraform будет знаеть его по имени "yandex_compute_instance.default"
resource "yandex_compute_instance" "default" {
  name        = "test-instance"
  platform_id = "standard-v1" # тип процессора (Intel Broadwell)

  resources {
    core_fraction = 5 # Гарантированная доля vCPU
    cores         = 2 # vCPU
    memory        = 1 # RAM
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.last_ubuntu.id
    }
  }

  network_interface {
    subnet_id = data.yandex_vpc_subnet.default_a.subnet_id
    nat       = true # автоматически установить динамический ip
  }
}
</details>


## Базовые плейбуки Ansible ansible/simpletasks/


<details>

Несколько задач в одном плейбуке - multipletasks.yaml


```
---
- name: Running 2 tasks   <----- Name of the play
  hosts: localhost        <----- Run it on local host

  tasks:                  <----- Run the following task
    - name: Test connectivity <----- Name of the tast
      ping:                   <----- Run the ping module 

    - name: Print Hello World <----- Name of the second task
      debug: msg="Hello World" <----- Run the debug module 

```

Копируем файлы на удаленный хост - copy_file.yaml

```
---
- name: Copy file from local to remote <----- Description of the playbook
  hosts: testsrv1

  tasks:                               <----- Run the following tast
    - name: Copying file               <----- Description of the task
      become: true                     <----- Transfer as a current user
      copy:                            <----- Run the copy module
       src: /home/mity/Documents/yandex_train/ansible/simpletasks/copy_test_file <----- source of the file
       dest: /tmp                                                                <----- Destination of the file
       owner: mity                                                               <----- Change ownership
       group: mity
       mode: 0644                                                                <----- Change file permissions 
```


Меняем разрешения на файл - changefilepermission.yaml

```
---
- name: Change file permissions
  hosts: testsrv1
  

  tasks:
    - name: Change file permissions
      file:
       path: /tmp/copy_test_file                                                 <----- File location
       mode: 0777                                                                <----- Permissions

```



</details>



## Продвинутые плейбуки и роли Ansible ansible/AdvancedAutomationFeatures/


<details>

### Общие сведения об Ansible Roles

Roles simplifies long playbooks by grouping tasks into smaller playbooks

The role are the way of breking a playbook inot multiple playbook files. This simplifies writing complex playbooks and it makes them easier to reuse

Writing ansible code to manage the same service for multiple environments  create more complexity and it becomes difficult to manage everything in one ansible palybook.
Also sharing code among other teams become difficult. That is where Ansible Role helps solve these problems.

Roles are like templates that are most of time static and can be called by the playbooks

Roles allow the entire configuration to be grouped in:
- **Tasks**
- **Modules**
- **Variables**
- **Handles**


Создаём директории basicinstall и fullinstall, первая роль описывает простую установку apache2,
вторая описывает установку apache2 и открытие порта на ufw.
В каждой из поддиректорий создаем папку tasks и в ней файл main.yaml, в котором описываем задачу что нужно сделать.

### basicinstall/tasks/main.yaml

```
---
- name: install apache latest
  become: true
  apt: name=apache2 update_cache=yes state=latest

```

### fullinstall/tasks/main.yaml

```
---
- name: install apache latest
  become: true
  apt: name=apache2 update_cache=yes state=latest

- name: open port
  become: true
  community.general.ufw:
    rule: allow
    port: 80
    proto: tcp
```

файл byrole.yaml, который находится в корне директории, описывает к каким группам хостов какую из ролей применять.

### ansible/AdvancedAutomationFeatures/byrole.yaml

```
---
- name: Full install
  hosts: localhost
  roles:
    - fullinstall


- name: Basic install
  hosts: testsrv1
  roles:
  - basicinstall
```

### Ansible Roles from Ansible Galaxy

Roles allow the entire configuration to be grouped in:
- **Tasks**
- **Modules**
- **Variables**
- **Handles**

Можно скачивать и устанавливать роли с https://galaxy.ansible.com/

```
ansible-galaxy install singleplatform-eng.users
```

роли скачиваются в /home/username/.ansible/roles

</details>

## Ansible Tags

<details>
Tags are the reference or aliases to a task
Insted of running an entire Ansible playbook, use tags to target a specific tasks you need to run

запускаем с тегами, чтобы выполнять отдельные таски в плейбуке.
-t i-apache2

запускаем с исключением тега, чтобы пропускать отдельные таски в плейбуке.
--skip-tags -i-apache

```
---
- name: Installing and Running apache
  hosts: testsrv1
  become: yes

  tasks:
    - name: install apache latest
      apt: name=apache2 update_cache=yes state=latest
      tags: i-apache2


    - name: open port
      community.general.ufw:
        rule: allow
        port: 80
        proto: tcp
      tags: o-port
      
```

</details>



















