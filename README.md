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


Устанавливаем Apache и Midnight commander в Ubuntu - installApache_MC_Ubuntu.yaml

```
---
- name: test playbook
  hosts: testsrv1
  become: yes
  tasks:
    - name: install apache and midnight commander
      ansible.builtin.apt:
        pkg:
          - mc
          - apache2
        state: latest
        update_cache: yes
        cache_valid_time: 3600

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

<details>

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
</details>

### Ansible Tags

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

#### PrintOSFamily_Update_tags_all.yaml 
Пример обновления Ubuntu и Centos и использованием AnsibleFacts для определения какой модуль обновления вызывать,
с и спользованием тегов, чтобы можно было вызывать таски отдельно по тегам.

```
---
- name: Anbsible playbook
#лучше явно указывать теги never и always
# always - задачи с этим тэгом будут выполнятся всегда, в независимости от того какой тэг вы указали при запуске.
#never - задачи с этим тэгом не будут выполняться только если вы не укажете конкретно --tags never
# есть теги tagged и untagged, которые позволяют запускать все тегированные.не тегированные таски.
# no_log - указывает, что не нужно выводить чувствительные данные.
  hosts: testsrv1
  become: true
  tasks:
    - name: Set fact
      ansible.builtin.set_fact:
          passwd: 'kek15'
      no_log: true

    - name: shell
      ansible.builtin.shell:
      # | показывает, что нужно выполнять команды после |
        cmd: |
          uptime
          echo "test2525"

    - name: Print os family
      ansible.builtin.debug:
        var: ansible_facts['os_family']
    
    - name: Update ubuntu
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600
        upgrade: full
      tags:
        - ubnt
        - never
      when: ansible_facts['os_family'] == "Debian"
    

    - name: Update CentOS
      ansible.builtin.yum:
        update_cache: true
        name: '*'
        state: latest
      tags:
        - cnt
        - never
      when: ansible_facts['os_family'] == "RedHat"

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

PrintVariableData.yaml + PrintVariable_loopControl.yaml 
Использование loop совместно с ansbile facts и зарегистрированными переменными.
Выводим на экран все ip адреса localhost

```
---
- name: test playbook
  connection: local
  hosts: 127.0.0.1
  tasks:
    - name: setup
      ansible.builtin.setup:
      register: setup_reg

    - name: print var
      ansible.builtin.debug:
        # Проходим по всем элементам списка и выводим нужное
        msg: "{{ item }}"
        # var: setup_reg
      loop: "{{ setup_reg.ansible_facts.ansible_all_ipv4_addresses }}"
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

## Bscripts - this section is devoted for bash scripting

<details>

**Positional argument variables**
| Variable   | Value                                                                                                  |
|------------|--------------------------------------------------------------------------------------------------------|
| $n or ${n} | N-th (positional) argument passed in a commad line                                                     |
| $*         | All arguments in command line in a form of a single string variable, broken down by a delimiter ($IFS) |
| "$*"       | All arguments in commnd line in a form of a single string variable                                     |
| $@         | All arguments in command line in a form of an array                                                    |
| "$@"       | All arguments in command line in a form of quotted strings                                             |
| $#         | Number of arguments passed in a command line  


1. [script1.sh]     
2. [script2.sh]  
3. [case_example1.sh]
4. [case_example2.sh]
5. [conditionaloperator.sh]
6. [until_middle.sh]
7. [until_simple.sh]
8. [while_simple.sh]
9. [while_simple2.sh]
10. [while_middle.sh]
11. [simple_random_game.sh]
12. [check_site_responseOK.sh]

[script1.sh]:https://github.com/adastraaero/yandex-tf-ans-pck/blob/main/Bscripts/example1.sh
[script2.sh]:https://github.com/adastraaero/yandex-tf-ans-pck/blob/main/Bscripts/example2.sh
[case_example1.sh]:https://github.com/adastraaero/yandex-tf-ans-pck/blob/main/Bscripts/case_example1.sh
[case_example2.sh]:https://github.com/adastraaero/yandex-tf-ans-pck/blob/main/Bscripts/case_example2.sh
[conditionaloperator.sh]:https://github.com/adastraaero/yandex-tf-ans-pck/blob/main/Bscripts/conditionaloperator.sh
[until_middle.sh]:https://github.com/adastraaero/yandex-tf-ans-pck/blob/main/Bscripts/until_middle.sh
[until_simple.sh]:https://github.com/adastraaero/yandex-tf-ans-pck/blob/main/Bscripts/until_simple.sh
[while_simple.sh]:https://github.com/adastraaero/yandex-tf-ans-pck/blob/main/Bscripts/while_simple.sh
[while_simple2.sh]:https://github.com/adastraaero/yandex-tf-ans-pck/blob/main/Bscripts/while_simple2.sh
[while_middle.sh]:https://github.com/adastraaero/yandex-tf-ans-pck/blob/main/Bscripts/while_middle.sh
[simple_random_game.sh]:https://github.com/adastraaero/yandex-tf-ans-pck/blob/main/Bscripts/simple_random_game.sh
[check_site_responseOK.sh]:https://github.com/adastraaero/yandex-tf-ans-pck/blob/main/Bscripts/check_site_responseOK.sh



script1.sh and script2.sh are explaining intergrated Bash variables and comparison operators.  
case_example1.sh and case_example2.sh are explaining intergrated Bash variables and comparison operators.  
conditionaloperator.sh - is an example of conditional operators.

until_middle.sh and until_simple.sh are examples of until operator.

while_simple.sh, while_simple2.sh,while_middle.sh are example of while loop.

simple_random_game.sh - simple random generator game.

check_site_responseOK.sh - check code 200 from site throught curl request.








### Pipeline examples:

Receive number of strokes in each log file for understanding, which file is bigger.
```
wc -l /var/log/*.log | sort -n
```

recevie  list of log files in directory in alphabetical order.
```
ls /var/log | grep ".log$" | sort
```

</details>

## Ansible_Pbooks_Roles - плейбуки и роли для ansbile от простого к сложному с использованием Vagrant или terraform

<details>

### Ubuntu_22_Mysql - Пример развертывания mysql Ubuntu 22_04
#### Полезные данные
Операторы SQL
* DDL(Data Definition Language) - операторы определения данных.
  * CREATE - создание объекта в базе данных
  * ALTER - изменение объекта
  * DROP - удаление объекта
* DML(Data Manipulation Language) - операторы манипуляции с данными.
  * SELECT - выборка данных в соответствии с условием
  * INSERT - Добавление новых данных
  * UPDATE - изменение существующих данных
  * DELETE - удаление данных
* DCL(Data Control Language) - оператор определения доступа к данным.
  * GRANT - предоставление доступа к объекту
  * REVOKE - отзыв ранее выданного разрешения
  * DENY - запрет, который является приоритетным над разрешением.
* TCL(Transcation Control Language) - язык управления транзакциями.
  * BEGIN TRANSACTION - обозначение начала транзакции
  * COMMIT TRANSACTION - изменение команд внутри транзакции
  * ROLLBACK TRANSACTION - откат транзакции
  * SAVE TRANSACTION - указание промежуточной точки сохранения внутри транзакции

Вывести все доступные подсистемы хранения
```
mysql> show engines;
#Использование движка MyISAM
mysql> create table test2 (id integer) engine=MiISAM;

#Использование движка MEMORY
mysql> create table test3 (id integer) engine=MEMORY;

#Проверка - вывод информации по таблице с указанием движка
mysql> show table status like 'test2' \G

```
можно выбирать разные подсистемы хранения для таблиц в зависимости от требований надежности и производительности.


Настройка входа без пароля c проверкой создания файла:
```
mysql_config_editor set --user=root --password
ls -lA ~/.mylogin.cnf
cat ~/.mylogin.cnf
mysql_config_editor print --all
```
```
#Выдача полных прав на базу
mysql> grant all privileges on test.* to 'test'@'localhost';

#Перезагрузить кэш привелегий
mysql> flush privileges;

#Отбор прав на базу
mysql> revoke all privileges on test.* from 'test'@'localhost';

```
#### Посмотреть сколько времени занимают различные запросы

```
#Включаем профайлинг
mysql> set profiling =1;

#Выполняем различные запросы

#Смотрим результат
mysql> show profiles;

```

#### Тюниг mysql
```
# Скачивание mysqltuner
$ wget https://raw.github.com/major/MySQLTuner-perl/master/mysqltuner.pl
# Запуск mysqltuner и вывод результата
$ perl mysqltuner.pl
```

#### Просмотр системных переменных

```
# Просмотр параметра 'max_connections' (вариант 1)
mysql> SHOW GLOBAL VARIABLES LIKE 'max_connections'

# Просмотр параметра 'max_connections' (вариант 2)
mysql> select @@global.max_connections;

# Изменение параметра 'max_connections' (вариант 1)
mysql> SET GLOBAL max_connections=100\g

# Изменение параметра 'max_connections' (вариант 2)
mysql> SET @@global.max_connections=100\g

```
#### Изменение системных переменных
```
$ vim /etc/my.cnf.d/mysql-server.cnf
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
log-error=/var/log/mysql/mysqld.log
pid-file=/run/mysqld/mysqld.pid
$ systemctl restart mysqld
```

#### Cоздание бэкапа
```
# Создание бэкапа
$ mysqldump -u root -p DATABASE > backup.sql
# Восстановление бэкапа
$ mysql -u root -p NEW_DATABASE < backup.sql
```





</details>


## UBT_MYSQL_NGIXPHP_Roles
Пример развертывания LEMP стека (Linux, Nginx, MySQL, PHP) на Ubuntu 22.04  
Без настройки firewall и selinux.  
master - роль включает в себя Nginx, PHP  
slave - включает в себя MySQL  
проверка - http://192.168.11.150/info.php  - должный увидеть данные по php  
         http://192.168.11.150 - - должный увидеть кастомный nginx.html  
проверка работы MYSQL - c master - mysql -u wordpress -p -h 192.168.11.151 - должно произойти подключение.           
<details>



</details>