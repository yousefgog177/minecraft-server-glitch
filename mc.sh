#!/bin/bash

set -e
root=$PWD
mkdir -p mc
cd mc

download() {
    set -e
    echo By executing this script you agree to the JRE License, the PaperMC license,
    echo the Mojang Minecraft EULA,
    echo the NPM license, the MIT license,
    echo and the licenses of all packages used \in this project.
    echo Press Ctrl+C \if you \do not agree to any of these licenses.
    echo Press Enter to agree.
    read -s agree_text
    echo Thank you \for agreeing, the download will now begin.
    wget -O jre.tar.gz "https://javadl.oracle.com/webapps/download/AutoDL?BundleId=242050_3d5a2bb8f8d4428bbe94aed7ec7ae784"
    tar -zxf jre.tar.gz
    rm -rf jre.tar.gz
    mv ./jre* ./jre
    echo JRE downloaded
    wget -O server.jar "https://papermc.io/api/v1/paper/1.16.1/latest/download"
    echo Paper downloaded
    wget -O server.properties "https://files.mikeylab.com/xpire/server.properties"
    echo Server properties downloaded
    echo "eula=true" > eula.txt
    echo Agreed to Mojang EULA
    wget -O ngrok.zip https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
    unzip ngrok.zip
    rm -rf ngrok.zip
    echo "Download complete" 
}

require() {
    if [ ! $1 $2 ]; then
        echo $3
        echo "Running download..."
        download
    fi
}
require_file() { require -f $1 "File $1 required but not found"; }
require_dir()  { require -d $1 "Directory $1 required but not found"; }
require_env()  {
    var=`python3 -c "import os;print(os.getenv('$1',''))"`
    if [ -z "${var}" ]; then
        echo "Environment variable $1 not set. "
        echo "In your .env file, add a line with:"
        echo "$1="
        echo "and then right after the = add $2"
        exit
    fi
    eval "$1=$var"
}
require_executable() {
    require_file "$1"
    chmod +x "$1"
}

# server files
require_file "eula.txt"
require_file "server.properties"
require_file "server.jar"
# java
require_dir "jre"
require_executable "jre/bin/java"
# ngrok binary
require_executable "ngrok"

# environment variables
require_env "ngrok_token" "your ngrok authtoken from https://dashboard.ngrok.com"
require_env "ngrok_region" "your region, one of:
us - United States (Ohio)
eu - Europe (Frankfurt)
ap - Asia/Pacific (Singapore)
au - Australia (Sydney)
sa - South America (Sao Paulo)
jp - Japan (Tokyo)
in - India (Mumbai)" 

# start web server
#echo "Starting web server..."
echo "Minecraft server starting, please wait" > $root/ip.txt

# start tunnel
mkdir -p ./logs
touch ./logs/temp # avoid "no such file or directory"
rm ./logs/*
echo "Starting ngrok tunnel in region $ngrok_region"
./ngrok authtoken $ngrok_token
touch logs/ngrok.log
./ngrok tcp -region $ngrok_region --log=stdout 1025 > ./logs/ngrok.log &
# wait for started tunnel message, and print each line of file as it is written
tail -f ./logs/ngrok.log | sed '/started tunnel/ q'
orig_server_ip=`curl --silent http://127.0.0.1:4040/api/tunnels | jq '.tunnels[0].public_url'`
trimmed_server_ip=`echo $orig_server_ip | grep -o '[a-zA-Z0-9.]*\.ngrok.io[0-9:]*'`
server_ip="${trimmed_server_ip:-$orig_server_ip}"
echo "Server IP is: $server_ip"
echo "Server running on: $server_ip" > $root/ip.txt

touch logs/latest.log
# Experiment: Run http server after all ports are opened
#( tail -f ./logs/latest.log | sed '/RCON running on/ q' && python3 -m http.server 8080 ) &

# Start minecraft
PATH=$PWD/jre/bin:$PATH
echo "Running server..."
java -Xmx1G -Xms1G -jar server.jar nogui
echo "Exit code $?"