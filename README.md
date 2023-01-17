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

пример настройки ansible.cfg для удобства работы


```
[defaults]
inventory = hosts
remote_user = vagrant
host_key_checking = False
retry_files_enabled = False
#Default connection plugin to use, the ‘smart’ option will toggle between ‘ssh’ and ‘paramiko’ depending on controller OS and ssh versions
transport = smart
roles_path = roles

[privilege escaltaion]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

```







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


### Roles by Application

Создаём структуру, как указано ниже, в данном примере показано просто разделение задач по ролям и  
один общий плейбук **RolesbyApp.yml** который запускает установку ролей.

```
tree
.
├── ansible.cfg
├── hosts
├── roles
│   ├── apache
│   │   └── tasks
│   │       └── main.yml
│   ├── named
│   │   └── tasks
│   │       └── main.yml
│   └── ntpd
│       └── tasks
│           └── main.yml
└── RolesbyApp.yml
```

```
cat roles/apache/tasks/main.yml 
---
- name: Install Apache
  become: true
  yum:
    name: httpd
    state: present

```

```
cat RolesbyApp.yml 
---
- name: install packages
  hosts: testsrv
  roles:
    - apache
    - ntpd
    - named
```











## Ansible Tags

<details>
Tags are the reference or aliases to a task
Insted of running an entire Ansible playbook, use tags to target a specific tasks you need to run

запускаем с тегами, чтобы выполнять отдельные таски в плейбуке.
-t i-apache2

запускаем с исключением тега, чтобы пропускать отдельные таски в плейбуке.
--skip-tags o-port

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


### Ansible Handlers

<details>

- **Handlers are executed at the end of the play once all tasks are finished. In Ansible, handlers are typically used to start, reload, restart and stop services.**
- **Sometimes you want to run a task only when a change is made on a machine.For example, you want to restart a service if a task updates the configuration of that service, but not if the configuration - unchanged**
- **Remember the case when we had to reload the firewlld because we wanted to enable http service? - it's a perfect example of using handlers**
- **So basically handlers are tasks that only run when notified**
- **Each handler should have a globally unique name**

При выполнении задач в плейбуках периодически возникает необходимость перезапускать какой-либо сервис. Например, при обновлении конфигурационного файла.
Простое решение - написать две обычные задачи. Одна из них будет обновлять конфиг, а вторая делать рестарт. И это будет работать, но есть одна проблема:
рестарт произойдет в любом случае, даже если конфиг не изменится

Чтобы этого избежать, в Ansible существует механизм, который называется handlers.

1. На верхнем уровне, где определены хосты и список задач, добавляем еще один ключ с именем handlers и внутри него описываем набор задач. Причем в данном случае обязательно, чтобы задачи содержали имя.
2. Связываем таски, которые могут порождать изменения, с задачами из секции handlers. Для этого с помощью ключа notify обращаемся к хендлерам по их именам:

```
---
- name: Installing and Running apache
  hosts: testsrv1
  become: yes

  tasks:
    - name: install apache latest
      apt: name=apache2 update_cache=yes state=latest
      notify:
        - restart apache2

    - name: open port
      community.general.ufw:
        rule: allow
        port: 80
        proto: tcp


  handlers:
    - name: restart apache2
      service: name=apache2 state=restarted
```


</details>

### Conditions /ansible/Conditions

<details>

- **Condition execution allow Ansible to take actions on its own based on certain conditions**
- **Under condititons certain values must be met before executing a tasks**
- **We can user the WHEN statement to make Ansible automations more smart**

Условия определяются на основе данных, полученных из  Gathering Facts.

Посмотреть какие данные собираются можно командой:

```
ansible myhost -m setup
```

```
---
- name: Install Apache WebServer
  hosts: apachesrvs
  become: true

  tasks:
  - name: Instiall Apache on Ubuntu Server
    apt:
      name: apache2
      state: latest
    when: ansible_os_family == "Debian"


  - name: Install Apache on Centos Server
    yum:
      name: httpd
      state: present
    when: ansible_os_family == "RedHat"
```


</details>

### Loops /ansible/Loop

<details>

- **A loop is  a powerfull programming tool that enables you to execute  set of commands repeatedly**
- **We can automate task but what if that task itself repetitive**
	- **Creating multiple users at once**
	- **Installing many packages on hundreds of servers**
- **Loops can work hand in hand with conditions as we loop certain task until that conditions**
- **When creating loops, Ansbile provides these two directives: loop and with_* keyword**

Example:
To create multiple users in Linux command line we use "for loop"

```
for u in jerry kramer eliane; do useradd $u; done
```

loop example
```
---
- name: Create users thru loop
  hosts: testsrv1
  become: true

  tasks:
  - name: Create users
    user:
      name: "{{ item }}"
    loop:
      - jerry
      - kramer
      - eliane
```

with_item example
```
---
- name: Create user thru loop v.2
  hosts: centossrv
  become: true
  vars:
    users: [jerry,kramer,eliane]

  tasks:
  - name: Create users
    user:
      name: "{{item}}"
    with_items: "{{users}}"
```

</details>


### Security ansible/SecurityandVault

<details>
Ansible-Vault используется для зашифровки плейбуков и строк.

Oftentimes you have to share Ansible code withgroups over the network and.

anything you share over network has a risk to end up wrong hands.

It is best practise to use Ansible vault feature which will password protect your code.

Создаем зашифрованный плейбук
```
ansible-vault create httpvbyvault.yaml
```

запускаем зашифрованный плейбук

```
ansible-playbook httpvbyvault.yaml --ask-vault-pass -i hosts.ini
```

редактируем зашифрованный плейбук
```
ansible-vault edit httpvbyvault.yaml 
```

просматриваем зашифрованный плейбук

```
ansible-vault view httpvbyvault.yaml
```

```
---
- name: Install httpd package
  hosts: centossrv
  become: true

  tasks:
    - name: Install package
      yum:
        name: httpd
        state: present
```

### Encrypting Strings within a Playbook

Можно зашифровать строку и поместить её внутрь плейбука
Strings/word can be encrypted within a playbook

ansible-vault encrypt_string httpd

Запускается файл с зашифрованной строкой так же:

ansible-playbook httpvbyvault.yaml --ask-vault-pass -i hosts.ini


```
---
- name: Test encrypted output
  hosts: centossrv
  vars:
   secret: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          63346238323034666537633233303335666336366636306165366638313434643631643530646661
          3166663935333831656264366665353965313138353865320a363761366462623233346632646539
          34323139346131663364393530393434366265646563323864313239646634343132383165323166
          3139663762316438620a303761363163313663616262396264383066323431383939633565326337
          3936

  tasks:
          - name: Print encrypted string
            debug:
                    var: secret
                             
```

</details>



### Additional commands

<details>

```
ansible-config
```
- **Shows or modifies Ansible configuration**

```
ansible-connection 
```
- **Connection for remote clients**

```
ansible-console 
```

- **Allows for running ad-hoc task against a chosent inventory from a nice shell with built-in tab completion**
- **It supports several commands and you can modify its configuration at runtime**
- **You can run name of the listed command followed by help**
- **Certain commands are misleading  e.g. = cd which changes the host instead of changing th directory**

```
ansible-doc
```

- **you can access manuals on plug-ins and modules through this command**
- **adnsible-doc -l -List all modules**



```
ansible-inventory
ansible-inventory -i hosts  --graph
ansible-inventory --list
```

- **Using the ansible-inventory command provides you with details of your host inventory files**

```
ansible-pull
```

- **A mode called 'ansbile-pull' can also invert the system and have systems 'phone home' via**
- **scheduled git checkouts to pull configuration directives from a central repository**


</details>