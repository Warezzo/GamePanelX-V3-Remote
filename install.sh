#!/bin/bash
#
# GamePanelX
# Remote Scripts v3.0.14
#
# Installation Script
#
# Licensed under the GPL (GNU General Public License V3)
#
echo -e "\e[00;34m##################################################################"
echo "##                                                              ##"
echo "##                         GamePanelX                           ##"
echo "##                                                              ##"
echo "##       Welcome to the Remote Server installer (v3.0.14)       ##"
echo "##                                                              ##"
echo -e "##################################################################\e[00m"
echo
remote_version="3.0.14"

if [ "$UID" -ne "0" ]
then
    echo "ERROR: You must be the root user to run this script.  Exiting."
    exit
fi

# Check for GNU Screen
if [ "$(which screen 2>&1 | grep 'no screen in')" ]
then
        # CentOS / RedHat
        if [ -f /etc/redhat-release ]
        then
                echo
                read -p "(RedHat) Missing requirements!  Is it OK to install packages via Yum (yum install screen)? (y/n): " gpx_ok_yum

                if [[ "$gpx_ok_yum" == "y" || "$gpx_ok_yum" == "yes" || "$gpx_ok_yum" == "Y" ]]
                then
                        yum -y install screen
                fi
        # Debian / Ubuntu
        elif [ -f /etc/debian_version ]
        then 
                echo
                read -p "(Debian) Missing requirements!  Is it OK to install packages via APT (apt-get install screen)? (y/n): " gpx_ok_apt

                if [[ "$gpx_ok_apt" == "y" || "$gpx_ok_apt" == "yes" || "$gpx_ok_apt" == "Y" ]]
                then
                        apt-get --yes install screen
                fi
        # Gentoo
        elif [ -f /etc/gentoo-release ]
        then
                echo
                read -p "(Gentoo) Missing requirements!  Is it OK to install packages via Portage (emerge screen)? (y/n): " gpx_ok_gentoo

                if [[ "$gpx_ok_gentoo" == "y" || "$gpx_ok_gentoo" == "yes" || "$gpx_ok_gentoo" == "Y" ]]
                then
                        emerge screen
                fi
        fi
fi

##############################################################

# User input
read -p "Create this Linux user for game/voice servers: " gpx_user
echo

# Check required
if [ "$gpx_user" == "" ]
then
    # echo "You must specify a username!  Exiting."
    echo -e "\e[00;31mYou must specify a username!  Exiting.\e[00m"
    exit
fi

# Check if user already exists
if [ "$(grep "^$gpx_user:" /etc/passwd)" ]
then
    echo "ERROR: That user already exists!.  Please choose a different username and try again.  Exiting."
    exit
fi

# Create the main /usr/local/gpx
if [ -d /usr/local/gpx ]
then
    echo "GPX directory (/usr/local/gpx) already exists!  Please uninstall first if you wish to start over.  Exiting."
    exit
else
    mkdir /usr/local/gpx
fi

# Create the gpx user
useradd -m -c "GamePanelX" -s /bin/bash $gpx_user
gpx_user_home="/usr/local/gpx"

# Log this username
echo $gpx_user > $gpx_user_home/.gpx_lastuser

# Make sure homedir exists
if [ ! -d "$gpx_user_home" ]
then
        echo "ERROR: Failed to find the users homedir!  Exiting."
        exit
fi

# Untar the Remote files
if [ -f "./gpx-remote-latest.tar.gz" ]
then
        tar -zxf ./gpx-remote-latest.tar.gz -C $gpx_user_home/
else
        echo "ERROR: Latest remote server files (./gpx-remote-latest.tar.gz) not found!  Try re-downloading the remote files and try again.  Exiting."
        exit
fi

# Change ownership of all the new files
chown $gpx_user: $gpx_user_home -R
chown root:$gpx_user $gpx_user_home/users -R
chown root: $gpx_user_home/ftpd -R
chmod 0660 $gpx_user_home/users -R
chmod 0750 $gpx_user_home/{logs,templates} -R
chmod 0660 $gpx_user_home/logs/*
chmod 0700 $gpx_user_home/{addons,queue,tmp,etc,uploads,users} -R
chmod 0760 $gpx_user_home/queue $gpx_user_home/tmp
chmod 0774 $gpx_user_home/users
chmod 0555 $gpx_user_home/bin
chmod 0754 $gpx_user_home/bin/*

# Setup config
touch $gpx_user_home/etc/config.cfg
echo > $gpx_user_home/etc/config.cfg
> $gpx_user_home/etc/config.cfg
echo "username: $gpx_user" >> $gpx_user_home/etc/config.cfg
echo "version: $remote_version" >> $gpx_user_home/etc/config.cfg

# Set system password
echo
echo "-- Enter a password for GamePanelX user \"$gpx_user\" "
passwd $gpx_user

#############################################################################################################

# Only allow gpx* users to login from the master
if [ "$gpx_master_ip" ]
then
    read -p "Modify SSH config to only allow GPX SSH logins from the Master server network? (Highly Recommended) (y/n): " gpx_ssh_answer
    
    if [[ "$gpx_ssh_answer" == "y" || "$gpx_ssh_answer" == "yes" || "$gpx_ssh_answer" == "Y" ]]
    then
        read -p "Primary Master Server IP: " gpx_master_ip
        
        # Split up IP for wildcards
        ip_net="$(echo $gpx_master_ip | awk -F'.' '{print $1"."$2"."$3}')"
        
        # Comment any current AllowUsers lines
        sed -i 's/^AllowUsers/\# Old\: AllowUsers/g' /etc/ssh/sshd_config
        
        # Add our new line
        echo >> /etc/ssh/sshd_config
        echo '# Automatically added by GamePanelX' >> /etc/ssh/sshd_config
        echo "AllowUsers root $gpx_user gpx*@$ip_net*" >> /etc/ssh/sshd_config
        
        # Restart SSHD
        if [ -f /sbin/service ]; then
            /sbin/service sshd restart
        elif [ -f /etc/init.d/sshd ]; then
            /etc/init.d/sshd restart
        elif [ -f /etc/init.d/ssh ]; then
            /etc/init.d/ssh restart
        elif [ -f /etc/rc.d/sshd ]; then
            /etc/rc.d/sshd restart
        else
            echo "Failed to find the SSH server location!  Please manually restart the SSH server."
        fi
        
        echo
        echo "Modified and restarted the SSH server.  Make sure to edit /etc/ssh/sshd_config if you need any more users allowed."
    else
        echo "NOT modifying SSH config."
    fi
fi

# Kill old manager processes
if [ "$(ps -ef | grep GPXManager | grep -v grep)" ]; then
	killall GPXManager
fi

# Start the manager daemon
/usr/local/gpx/bin/GPXManager

#############################################################################################################

# FTP Server Installation
echo;echo
read -p "Install GamePanelX FTP server? (y/n): " gpx_ftp_ans

if [[ "$gpx_ftp_ans" == "y" || "$gpx_ftp_ans" == "yes" || "$gpx_ftp_ans" == "Y" ]]
then
    if [ ! -f ./ftp.sh ]
    then
        echo "No FTP script (./ftp.sh) found!  Exiting."
        exit
    fi

    chmod u+x ftp.sh
    ./ftp.sh -u $gpx_user
fi

echo
echo
echo "##################################################################"
echo
echo -e "\e[00;32mCompleted GamePanelX Remote Server Installation! \e[00m"
echo
exit