import os

from fabric.api import run, local, put, env
from fabric.context_managers import cd
from fabric.contrib.files import sed 

"""
  Fabric file to upload public/private keys to remote servers
  and set up non-root users. Also prevents SSH-ing in with the 
  root user. Fill in the following blank fields then run this
  Fabric script with "fab bootstrap".
"""

# run the bootstrap process as root before it is locked down
env.user = 'root'

# ssh key file path
env.key_filename = '~/.ssh/id_rsa'

# all IP address or hostnames of the servers you want to put
# your SSH keys and authorized_host files on, ex: 192.168.1.1
env.hosts = [os.environ.get('DEPLOYING_HOST', '')]

# your fulln name for the new non-root user
env.new_user_full_name = os.environ.get(
    'NEW_USER_FULL_NAME', 'Htet Naing Aung'
)

# username for the new non-root user
env.new_user = os.environ.get('NEW_USERNAME', 'deployer')
env.passwd = os.environ.get('DEPLOYER_PASSWD', '')
env.domain = os.environ.get('DEPLOYING_DOMAIN')

# group name for the new non-root user
env.new_user_grp = os.environ.get('NEW_USER_GROUP', 'deployers')

# local filesystem directory where your jenkinskey.pub and 
# authorized_keys files are going to be created (they will be scp'd
# to target hosts) don't include a trailing slash
# note: the tilde resolves to your home directory
SSH_KEY_NAME = 'deployer_key'
env.ssh_key_dir = f'./ssh_keys/{env.domain}'
SSH_KEY_FILE = f'{env.ssh_key_dir}/{SSH_KEY_NAME}'

def bootstrap():
    if not env.hosts[0]:
      print('---- ERROR ----')
      print('The environment variable DEPLOYING_HOST is not included!')
      exit(1)
    sed('/etc/ssh/sshd_config', '^UsePAM yes', 'UsePAM no')
    sed('/etc/ssh/sshd_config', '^PermitRootLogin yes', 'PermitRootLogin no')
    sed('/etc/ssh/sshd_config', '^#PasswordAuthentication yes',
        'PasswordAuthentication no')
    _create_privileged_group()
    _create_privileged_user()
    _create_ssh_keys()
    _upload_keys()
    _customize_vimrc()
    run('wget -O /etc/ssl/certs/cloudflare.crt https://support.cloudflare.com/hc/en-us/article_attachments/201243967/origin-pull-ca.pem')
    run('apt install python -y')  # ansible uses python 2
    run('service ssh reload')


def _create_privileged_group():
    run(f'/usr/sbin/groupadd {env.new_user_grp}')
    run('mv /etc/sudoers /etc/sudoers-backup')
    run(f'(cat /etc/sudoers-backup ; echo "%{env.new_user_grp} ALL=(ALL) ALL")'
        ' > /etc/sudoers')
    run('chmod 0440 /etc/sudoers')


def _create_privileged_user():
    run(f'/usr/sbin/useradd -c "{env.new_user_full_name}" -m -g {env.new_user_grp}' 
        f' -p $(openssl passwd -1 {env.passwd}) {env.new_user}')
    run(f'/usr/sbin/usermod -a -G {env.new_user_grp} {env.new_user}')
    run(f'/usr/sbin/usermod --shell /bin/bash {env.new_user}')
    run(f'mkdir /home/{env.new_user}/.ssh')
    run(f'chown -R {env.new_user} /home/{env.new_user}/.ssh')
    run(f'chgrp -R {env.new_user_grp} /home/{env.new_user}/.ssh')


def _create_ssh_keys():
    local(f'mkdir -p {env.ssh_key_dir}')
    local(f'rm -rf {env.ssh_key_dir}/*')
    local(f'ssh-keygen -t rsa -b 2048 -f {SSH_KEY_FILE} -q -P ""')
    local(f'chmod 600 {SSH_KEY_FILE}')
    local(f"cp {SSH_KEY_FILE}.pub {env.ssh_key_dir}/authorized_keys")


def _upload_keys():
    put(f'{env.ssh_key_dir}/authorized_keys', f'/home/{env.new_user}/.ssh')

def _customize_vimrc():
    run(f'wget -O /home/{env.new_user}/.vimrc'
          ' https://gist.githubusercontent.com/justinaung/66dfc69518cda72842bee635a3959dfa/raw/ac3c4c44f49b20039433f7a4d34febfdd8199dc9/vimrc')
