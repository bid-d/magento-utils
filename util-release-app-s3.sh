#!/bin/bash

# example
# -b s3 bucket name to store export file
# sh util-release-app-s3.sh -m 'none' -s 'git'  -b 'bucket_name'

# -m 'none' don't copy enitre media folder, only the media items required for porto
#    'full' copy all image from media file

# -s 'git' copy all source code with git files
#    'none' don't copy any git files.

# -b 'bucket_name' it is required to create s3 bucket name with 'omnyfy-marketplace-$bucket_name'

while getopts m:s:d:b:a: flag
do
    case "${flag}" in
        m) media=${OPTARG};;
        s) source=${OPTARG};;
        d) database=${OPTARG};;
        b) bucket=${OPTARG};;
    esac
done

echo "media: $media";
echo "source: $source";
echo "database: $database";
echo "s3bucket: $bucket";

if [ -z "$bucket" ];
  then
    echo "s3 bucket argument supplied"
    return 1 2>/dev/null
    exit 1
fi

# project folder
project_folder=${PWD##*/}
s3_generated_path=src
temp_folder=/home/omnyfy/build/projects/${project_folder}
archive_folder=/home/omnyfy/build/archive

projectname="marketplace"
today=$(date +"%Y-%m-%d-%H-%M-%S")
envpath=${envpath:-/var/www/${projectname}/app/etc/env.php}

# database connection
mysql_host=$(grep [\']db[\'] -A 20 ${envpath} | grep host | head -n1 | sed "s/.*[=][>][ ]*[']//" | sed "s/['][,]//");
mysql_username=$(grep [\']db[\'] -A 20 ${envpath} | grep username | head -n1 | sed "s/.*[=][>][ ]*[']//" | sed "s/['][,]//");
mysql_password=$(grep [\']db[\'] -A 20 ${envpath} | grep password | head -n1 | sed "s/.*[=][>][ ]*[']//" | sed "s/[']$//" | sed "s/['][,]//");
database_name=$(grep [\']db[\'] -A 20 ${envpath} | grep dbname | head -n1 | sed "s/.*[=][>][ ]*[']//" | sed "s/['][,]//");
aws_s3_bucketname=omnyfy-marketplace-$bucket

# clear up temp files
rm -rf /home/omnyfy/build/projects/${project_folder}/*
rm ${archive_folder}/${project_folder}_marketplace.zip

# creating folder strcuture
mkdir -p ${archive_folder}
mkdir -p ${temp_folder}
mkdir -p ${temp_folder}/app
mkdir -p ${temp_folder}/app/etc
mkdir -p ${temp_folder}/app/design/frontend
mkdir -p ${temp_folder}/app/design/adminhtml
mkdir -p ${temp_folder}/pub/media
mkdir -p ${temp_folder}/dbdump
mkdir -p ${temp_folder}/log
mkdir -p ${temp_folder}/patches

cp -rf marketplace_version.json ${temp_folder}/
cp -rf composer.json ${temp_folder}/
cp -rf composer.lock ${temp_folder}/
cp -rf app/code ${temp_folder}/app
cp -rf app/etc/config.php ${temp_folder}/app/etc/
cp -rf app/design/frontend/* ${temp_folder}/app/design/frontend
cp -rf app/design/adminhtml/* ${temp_folder}/app/design/adminhtml
cp -rf patches/* ${temp_folder}/patches

cp -rf var/log/exception.log  ${temp_folder}/log
cp -rf var/log/debug.log  ${temp_folder}/log
cp -rf var/log/system.log ${temp_folder}/log

if [ $media = "full" ];
  then
    echo "media is set to full"
    cp -rf pub/media/* ${temp_folder}/pub/media
  else
    cp -rf pub/media/js ${temp_folder}/pub/media
    cp -rf pub/media/logo ${temp_folder}/pub/media
    cp -rf pub/media/porto ${temp_folder}/pub/media
    cp -rf pub/media/wysiwyg ${temp_folder}/pub/media
fi

if [ $source = "git" ];
  then
    echo "source is git, .git file will be keeped"
  else
    (cd ${temp_folder} &&  find . -name ".git*" -exec rm -R -f {} \;)
fi

mysqldump  --column-statistics=0 --set-gtid-purged=OFF -h $mysql_host -u $mysql_username "-p$mysql_password" $database_name > ${temp_folder}/dbdump/marketplace_app_db_$(date +%Y%m%d_%H%M%S).sql

(cd $temp_folder && zip -r ${archive_folder}/${project_folder}_marketplace.zip *)

sudo du -sh -m ${temp_folder}

