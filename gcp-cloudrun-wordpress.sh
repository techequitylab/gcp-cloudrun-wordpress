#!/bin/bash
# 
# Copyright 2019 Shiyghan Navti. Email shiyghan@gmail.com
#
#################################################################################
##############      Configure a Wordpress on Google Cloud Run     ###############
#################################################################################

# User prompt function
function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=$(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=$(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-cloudrun-wordpress > /dev/null 2>&1
export SCRIPTNAME=gcp-cloudrun-wordpress.sh
export PROJDIR=`pwd`/gcp-cloudrun-wordpress
export LOCALIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
export AUTHORIZED_NETWORK=${LOCALIP}/32
export APPLICATION_NAME=wordpress # set the application name (mysportsbookapp.com)

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT # set app project
export SECRETS_PROJECT=$GCP_PROJECT # set secrets project
export GCP_REGION=us-central1 # set the GCP region
export DB_PORT=5432 # set the database port
export DB_TYPE=mysql # set the database type
export DB_VERSION=MYSQL_8_0 # MYSQL_8_0
export DB_CPU=1 # set the vCPU count
export DB_MEMORY=3840MB # set the memory (7680MB)
export DB_INSTANCE=${GCP_PROJECT}-mysql # set instance name
export APPLICATION_NAME=${APPLICATION_NAME} # set the application name (mysportsbookapp.com)
export APPLICATION_IMAGE_URL=gcr.io/\$GCP_PROJECT/${APPLICATION_NAME} # set the application image URL
export APPLICATION_MIN_INSTANCES=1 # set the min number of instances
export APPLICATION_MAX_INSTANCES=1 # set the maximum number of instances
export APPLICATION_GITHUB_REPOSITORY= # to set repo
export APPLICATION_MIRRORED_REPOSITORY= # Set the application repo
export APPLICATION_CUSTOM_DOMAIN= # set custom domain
export APPLICATION_ENVIRONMENT=dev # set environment
export APPLICATION_CONTENT_UPLOAD=nfu_convention_wp_content.zip # wp_content zip file name
export SUBNET_PRIMARY="10.0.0.0/24" # 172.16.4.0/22
export SUBNET_CLOUDSQL="10.0.90.0" # 172.16.90.0
EOF
source $PROJDIR/.env
fi

export ATTESTOR_NAME="binauth-attestor"
export NOTE_ID=binauthz-attestor-note
export DESCRIPTION="Binary Authentication Attestor Note"
export KMS_KEY_NAME="binauth-key"
export KMS_KEYRING_NAME="binauth-keyring"
export KMS_KEY_VERSION=1

# Display menu options
while :
do
clear
cat<<EOF
====================================================
Configure Cloud Run $APPLICATION_NAME CI/CD Pipeline
----------------------------------------------------
Please enter number to select your choice:
 (1) Enable APIs
 (2) Configure network (VPC Network)
 (3) Configure database instance (Cloud SQL)
 (4) Initialise database (Cloud SQL)
 (5) Configure security (Binary Authorisation)
 (6) Create application artifacts (Application Source Code)
 (7) Create CI/CD artifacts (Cloud Source Repositories)
 (8) Configure CI/CD pipeline (Cloud Build and Cloud Deploy)
 (9) Configure IAM policies (Cloud IAM)
(10) Configure Media Cloud (Cloud Storage)
(11) Configure Global Load Balancer (Network Services)
(12) Configure Custom Domain for application (Cloud Source Repositories)
(13) Backup database (Cloud SQL)
(14) Restore database (Cloud SQL)
(15) Backup database (MySQL)
(16) Restore database (MySQL)
(17) Drop database (Cloud SQL)
 (G) Launch step by step guide
 (Q) Quit
----------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete $GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create $GCP_PROJECT 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export SECRETS_PROJECT=$SECRETS_PROJECT
export GCP_REGION=$GCP_REGION
export DB_PORT=$DB_PORT
export DB_TYPE=$DB_TYPE
export DB_VERSION=$DB_VERSION
export DB_CPU=$DB_CPU
export DB_MEMORY=$DB_MEMORY
export DB_INSTANCE=$DB_INSTANCE
export APPLICATION_NAME=$APPLICATION_NAME
export APPLICATION_IMAGE_URL=$APPLICATION_IMAGE_URL
export APPLICATION_MIN_INSTANCES=$APPLICATION_MIN_INSTANCES
export APPLICATION_MAX_INSTANCES=$APPLICATION_MAX_INSTANCES
export APPLICATION_GITHUB_REPOSITORY=$APPLICATION_GITHUB_REPOSITORY
export APPLICATION_MIRRORED_REPOSITORY=$APPLICATION_MIRRORED_REPOSITORY
export APPLICATION_CUSTOM_DOMAIN=$APPLICATION_CUSTOM_DOMAIN
export APPLICATION_ENVIRONMENT=$APPLICATION_ENVIRONMENT
export APPLICATION_CONTENT_UPLOAD=$APPLICATION_CONTENT_UPLOAD
export SUBNET_PRIMARY=$SUBNET_PRIMARY
export SUBNET_CLOUDSQL=$SUBNET_CLOUDSQL
EOF
        export PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT --format="value(projectNumber)") > /dev/null 2>&1
        if [[ -z $APPLICATION_GITHUB_REPOSITORY ]]; then
            export GITHUB_REPOSITORY=unset
        else 
            export GITHUB_REPOSITORY=$APPLICATION_GITHUB_REPOSITORY
        fi
        if [[ -z $APPLICATION_MIRRORED_REPOSITORY ]]; then
            export APPLICATION_REPOSITORY=unset
        else 
            export APPLICATION_REPOSITORY=$APPLICATION_MIRRORED_REPOSITORY
        fi
        if [[ -z $APPLICATION_CUSTOM_DOMAIN ]]; then
            export APPLICATION_DOMAIN=unset
        else 
            export APPLICATION_DOMAIN=$APPLICATION_CUSTOM_DOMAIN
        fi
        gsutil cp $PROJDIR/.env gs://$GCP_PROJECT/$PROJDIR.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud secrets project is $SECRETS_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Google Cloud SQL port is $DB_PORT ***" | pv -qL 100
        echo "*** Google Cloud SQL database type is $DB_TYPE ***" | pv -qL 100
        echo "*** Google Cloud SQL database version is $DB_VERSION ***" | pv -qL 100
        echo "*** Google Cloud SQL database vCPU is $DB_CPU ***" | pv -qL 100
        echo "*** Google Cloud SQL database memory is $DB_MEMORY ***" | pv -qL 100
        echo "*** Google Cloud SQL database instance is $DB_INSTANCE ***" | pv -qL 100
        echo "*** Application name is $APPLICATION_NAME ***" | pv -qL 100
        echo "*** Application image URL is $APPLICATION_IMAGE_URL ***" | pv -qL 100
        echo "*** Application minimum instances is $APPLICATION_MIN_INSTANCES ***" | pv -qL 100
        echo "*** Application maximum instances is $APPLICATION_MAX_INSTANCES ***" | pv -qL 100
        echo "*** Application github repository is $GITHUB_REPOSITORY ***" | pv -qL 100
        echo "*** Application mirror repository is $APPLICATION_REPOSITORY ***" | pv -qL 100
        echo "*** Application custom domain is $APPLICATION_DOMAIN ***" | pv -qL 100
        echo "*** Application environment is $APPLICATION_ENVIRONMENT ***" | pv -qL 100
        echo "*** Application upload zip file is $APPLICATION_CONTENT_UPLOAD ***" | pv -qL 100
        echo "*** VPC primary subnet is $SUBNET_PRIMARY ***" | pv -qL 100
        echo "*** VPC connector IP range $SUBNET_CLOUDSQL ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete $GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create $GCP_PROJECT 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export SECRETS_PROJECT=$SECRETS_PROJECT
export GCP_REGION=$GCP_REGION
export DB_PORT=$DB_PORT
export DB_TYPE=$DB_TYPE
export DB_VERSION=$DB_VERSION
export DB_CPU=$DB_CPU
export DB_MEMORY=$DB_MEMORY
export DB_INSTANCE=$DB_INSTANCE
export APPLICATION_NAME=$APPLICATION_NAME
export APPLICATION_IMAGE_URL=$APPLICATION_IMAGE_URL
export APPLICATION_MIN_INSTANCES=$APPLICATION_MIN_INSTANCES
export APPLICATION_MAX_INSTANCES=$APPLICATION_MAX_INSTANCES
export APPLICATION_GITHUB_REPOSITORY=$APPLICATION_GITHUB_REPOSITORY
export APPLICATION_MIRRORED_REPOSITORY=$APPLICATION_MIRRORED_REPOSITORY
export APPLICATION_CUSTOM_DOMAIN=$APPLICATION_CUSTOM_DOMAIN
export APPLICATION_ENVIRONMENT=$APPLICATION_ENVIRONMENT
export APPLICATION_CONTENT_UPLOAD=$APPLICATION_CONTENT_UPLOAD
export SUBNET_PRIMARY=$SUBNET_PRIMARY
export SUBNET_CLOUDSQL=$SUBNET_CLOUDSQL
EOF
                export PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT --format="value(projectNumber)") > /dev/null 2>&1
                if [[ -z $APPLICATION_GITHUB_REPOSITORY ]]; then
                    export GITHUB_REPOSITORY=unset
                else 
                    export GITHUB_REPOSITORY=$APPLICATION_GITHUB_REPOSITORY
                fi
                if [[ -z $APPLICATION_MIRRORED_REPOSITORY ]]; then
                    export APPLICATION_REPOSITORY=unset
                else 
                    export APPLICATION_REPOSITORY=$APPLICATION_MIRRORED_REPOSITORY
                fi
                if [[ -z $APPLICATION_CUSTOM_DOMAIN ]]; then
                    export APPLICATION_DOMAIN=unset
                else 
                    export APPLICATION_DOMAIN=$APPLICATION_CUSTOM_DOMAIN
                fi
                gsutil cp $PROJDIR/.env gs://$GCP_PROJECT/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud platform project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud secrets project is $SECRETS_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Google Cloud SQL port is $DB_PORT ***" | pv -qL 100
                echo "*** Google Cloud SQL database type is $DB_TYPE ***" | pv -qL 100
                echo "*** Google Cloud SQL database version is $DB_VERSION ***" | pv -qL 100
                echo "*** Google Cloud SQL database vCPU is $DB_CPU ***" | pv -qL 100
                echo "*** Google Cloud SQL database memory is $DB_MEMORY ***" | pv -qL 100
                echo "*** Google Cloud SQL database instance is $DB_INSTANCE ***" | pv -qL 100
                echo "*** Application name is $APPLICATION_NAME ***" | pv -qL 100
                echo "*** Application image URL is $APPLICATION_IMAGE_URL ***" | pv -qL 100
                echo "*** Application minimum instances is $APPLICATION_MIN_INSTANCES ***" | pv -qL 100
                echo "*** Application maximum instances is $APPLICATION_MAX_INSTANCES ***" | pv -qL 100
                echo "*** Application github repository is $GITHUB_REPOSITORY ***" | pv -qL 100
                echo "*** Application mirror repository is $APPLICATION_REPOSITORY ***" | pv -qL 100
                echo "*** Application custom domain is $APPLICATION_DOMAIN ***" | pv -qL 100
                echo "*** Application environment is $APPLICATION_ENVIRONMENT ***" | pv -qL 100
                echo "*** Application upload zip file is $APPLICATION_CONTENT_UPLOAD ***" | pv -qL 100
                echo "*** VPC primary subnet is $SUBNET_PRIMARY ***" | pv -qL 100
                echo "*** VPC connector IP range $SUBNET_CLOUDSQL ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT services enable servicemanagement.googleapis.com servicecontrol.googleapis.com cloudresourcemanager.googleapis.com compute.googleapis.com containerregistry.googleapis.com cloudbuild.googleapis.com clouddeploy.googleapis.com artifactregistry.googleapis.com run.googleapis.com secretmanager.googleapis.com servicenetworking.googleapis.com vpcaccess.googleapis.com containeranalysis.googleapis.com binaryauthorization.googleapis.com cloudkms.googleapis.com # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    echo
    echo "$ gcloud --project $GCP_PROJECT services enable servicemanagement.googleapis.com servicecontrol.googleapis.com cloudresourcemanager.googleapis.com compute.googleapis.com containerregistry.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com run.googleapis.com secretmanager.googleapis.com servicenetworking.googleapis.com vpcaccess.googleapis.com containeranalysis.googleapis.com binaryauthorization.googleapis.com cloudkms.googleapis.com # to enable APIs" | pv -qL 100
    gcloud --project $GCP_PROJECT services enable servicemanagement.googleapis.com servicecontrol.googleapis.com cloudresourcemanager.googleapis.com compute.googleapis.com containerregistry.googleapis.com cloudbuild.googleapis.com clouddeploy.googleapis.com artifactregistry.googleapis.com run.googleapis.com secretmanager.googleapis.com servicenetworking.googleapis.com vpcaccess.googleapis.com containeranalysis.googleapis.com binaryauthorization.googleapis.com cloudkms.googleapis.com
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"
    echo
    echo "$ gcloud compute networks create serverless-vpc --subnet-mode=custom --project \$GCP_PROJECT # to create network" | pv -qL 100
    echo
    echo "$ gcloud compute networks subnets create cloudsql-subnet --network=serverless-vpc --range=\$SUBNET_PRIMARY --region=\$GCP_REGION --enable-private-ip-google-access --project \$GCP_PROJECT # to create subnet" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"
    echo
    echo "$ gcloud compute networks create serverless-vpc --subnet-mode=custom --project $GCP_PROJECT # to create network" | pv -qL 100
    gcloud compute networks create serverless-vpc --subnet-mode=custom --project $GCP_PROJECT
    echo
    echo "$ gcloud compute networks subnets create cloudsql-subnet --network=serverless-vpc --range=$SUBNET_PRIMARY --region=$GCP_REGION --enable-private-ip-google-access --project $GCP_PROJECT # to create subnet" | pv -qL 100
    gcloud compute networks subnets create cloudsql-subnet --network=serverless-vpc --range=$SUBNET_PRIMARY --region=$GCP_REGION --enable-private-ip-google-access --project $GCP_PROJECT 
 elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"
    echo
    echo "$ gcloud compute networks delete serverless-vpc # to delete custom network" | pv -qL 100
    gcloud compute networks delete serverless-vpc --quiet 2>/dev/null
else
    export STEP="${STEP},2i"
    echo
    echo "*** Not implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"   
    echo
    echo "$ printf \"\${GCP_PROJECT}-mysql\" | gcloud --project \$SECRETS_PROJECT secrets create \${GCP_PROJECT}-cloudsql-instance-name --data-file=- # to set DB instance" | pv -qL 100
    echo
    echo "$ printf \"\$GCP_PROJECT:\$GCP_REGION:\${GCP_PROJECT}-mysql\" | gcloud --project \$SECRETS_PROJECT secrets create \${GCP_PROJECT}-cloudsql-instance-connection --data-file=- # to set DB instance" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT compute addresses create cloudsql-iprange --global --network=projects/\$GCP_PROJECT/global/networks/serverless-vpc --purpose=VPC_PEERING --addresses=\$SUBNET_CLOUDSQL --prefix-length=24 --description=\"Peering IP Range for CloudSQL\" # to create peering IP range" | pv -qL 100
    echo
    echo
    echo "$ gcloud --project \$GCP_PROJECT services vpc-peerings connect --service=servicenetworking.googleapis.com --ranges=cloudsql-iprange --network=serverless-vpc # to create a private connection" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT compute networks vpc-access connectors create serverless-vpc-connector --network serverless-vpc --region \$GCP_REGION --range 10.8.0.0/28 # to configure VPC connector" | pv -qL 100
    echo
    echo "$ gcloud compute routers create cloudsql-vpc-router --network serverless-vpc --region \$GCP_REGION # to create cloud Router to program a NAT gateway" | pv -qL 100
    echo
    echo "$ gcloud compute addresses create cloudsql-vpc-nat-ip --region \$GCP_REGION # to reserve a static IP address" | pv -qL 100
    echo
    echo "$ gcloud compute routers nats create cloudsql-vpc-nat --router cloudsql-vpc-router --region \$GCP_REGION --nat-custom-subnet-ip-ranges cloudsql-subnet --nat-external-ip-pool cloudsql-vpc-nat-ip # to create Cloud NAT gateway configuration" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT beta sql instances create \$DB_INSTANCE --database-version=\$DB_VERSION --backup-start-time=00:00 --cpu=\$DB_CPU --memory=\$DB_MEMORY --zone=\${GCP_REGION}-b --secondary-zone=\${GCP_REGION}-c --maintenance-window-day=MON --maintenance-window-hour=4 --storage-type=SSD --network=projects/\$GCP_PROJECT/global/networks/serverless-vpc --availability-type=regional --storage-auto-increase --backup-start-time=4:00 --retained-backups-count=7 --enable-bin-log --retained-transaction-log-days=7 --maintenance-release-channel=production --storage-size 10GB # to create database instance (--no-assign-ip)" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"
    echo
    echo "$ gcloud --project $GCP_PROJECT compute addresses create cloudsql-iprange --global --network=projects/$GCP_PROJECT/global/networks/serverless-vpc --purpose=VPC_PEERING --addresses=$SUBNET_CLOUDSQL --prefix-length=24 --description=\"Peering IP Range for CloudSQL\" # to create peering IP range" | pv -qL 100
    gcloud --project $GCP_PROJECT compute addresses create cloudsql-iprange --global --network=projects/$GCP_PROJECT/global/networks/serverless-vpc --purpose=VPC_PEERING --addresses=$SUBNET_CLOUDSQL --prefix-length=24 --description="Peering IP Range for CloudSQL" 2>/dev/null
    echo
    sleep 15
    echo "$ gcloud --project $GCP_PROJECT services vpc-peerings connect --service=servicenetworking.googleapis.com --ranges=cloudsql-iprange --network=serverless-vpc # to create a private connection" | pv -qL 100
    gcloud --project $GCP_PROJECT services vpc-peerings connect --service=servicenetworking.googleapis.com --ranges=cloudsql-iprange --network=serverless-vpc
    echo
    echo "$ gcloud --project $GCP_PROJECT compute networks vpc-access connectors create serverless-vpc-connector --network serverless-vpc --region $GCP_REGION --range 10.8.0.0/28 # to configure VPC connector" | pv -qL 100
    gcloud --project $GCP_PROJECT compute networks vpc-access connectors create serverless-vpc-connector --network serverless-vpc --region $GCP_REGION --range 10.8.0.0/28
    echo
    echo "$ gcloud compute routers create cloudsql-vpc-router --network serverless-vpc --region $GCP_REGION # to create cloud Router to program a NAT gateway" | pv -qL 100
    gcloud compute routers create cloudsql-vpc-router --network serverless-vpc --region $GCP_REGION
    echo
    echo "$ gcloud compute addresses create cloudsql-vpc-nat-ip --region $GCP_REGION # to reserve a static IP address" | pv -qL 100
    gcloud compute addresses create cloudsql-vpc-nat-ip --region $GCP_REGION 
    echo
    echo "$ gcloud compute routers nats create cloudsql-vpc-nat --router cloudsql-vpc-router --region $GCP_REGION --nat-custom-subnet-ip-ranges cloudsql-subnet --nat-external-ip-pool cloudsql-vpc-nat-ip # to create Cloud NAT gateway configuration" | pv -qL 100
    gcloud compute routers nats create cloudsql-vpc-nat --router cloudsql-vpc-router --region $GCP_REGION --nat-custom-subnet-ip-ranges cloudsql-subnet --nat-external-ip-pool cloudsql-vpc-nat-ip
    echo
    echo "$ gcloud --project $GCP_PROJECT beta sql instances create $DB_INSTANCE --database-version=$DB_VERSION --backup-start-time=00:00 --cpu=$DB_CPU --memory=$DB_MEMORY --zone=${GCP_REGION}-b --secondary-zone=${GCP_REGION}-c --maintenance-window-day=MON --maintenance-window-hour=4 --storage-type=SSD --network=projects/$GCP_PROJECT/global/networks/serverless-vpc --availability-type=regional --storage-auto-increase --backup-start-time=4:00 --retained-backups-count=7 --enable-bin-log --retained-transaction-log-days=7 --maintenance-release-channel=production --storage-size 10GB # to create database instance (--no-assign-ip)" | pv -qL 100
    gcloud --project $GCP_PROJECT beta sql instances create  $DB_INSTANCE --database-version=$DB_VERSION --backup-start-time=00:00 --cpu=$DB_CPU --memory=$DB_MEMORY --zone=${GCP_REGION}-b --secondary-zone=${GCP_REGION}-c --maintenance-window-day=MON --maintenance-window-hour=4 --storage-type=SSD --network=projects/$GCP_PROJECT/global/networks/serverless-vpc --availability-type=regional --storage-auto-increase --backup-start-time=4:00 --retained-backups-count=7 --enable-bin-log --retained-transaction-log-days=7 --maintenance-release-channel=production --storage-size 10GB
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"
    echo
    echo "*** Not implemented ***"
else
    export STEP="${STEP},3i"
    echo
    echo "*** Not implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"
    echo
    echo "$ printf \"\$(date +%s | sha256sum | base64 | head -c 12 ; echo)\") | gcloud --project \$SECRETS_PROJECT secrets create \${GCP_PROJECT}-\${DB_INSTANCE}-\${DATABASE_NAME}-password --data-file=- # to create password" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql -q instances patch \$DB_INSTANCE --assign-ip --authorized-networks=\$AUTHORIZED_NETWORK # to authorize access from the local client IP" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql databases delete \$DB_NAME --instance=\$DB_INSTANCE --quiet # to delete database" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql databases create \$DB_NAME --instance=\$DB_INSTANCE --charset=utf8 # to create database" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql users create \$DB_USER --instance=\$DB_INSTANCE --password=\$DB_PASSWORD --host=% # to create database user" | pv -qL 100
    echo
    echo "$ mysql -h\$DB_HOST -P3306 -u\$DB_USER -e \"SHOW DATABASES;\" # to display databases" | pv -qL 100
    echo
    echo "$ mysql -h\$DB_HOST -P3306 -u\$DB_USER -e \"DROP DATABASE \$DB_NAME;\" # to drop databases" | pv -qL 100
    echo
    echo "$ mysql -h\$DB_HOST -P3306 -u\$DB_USER -e \"CREATE DATABASE \$DB_NAME;\" # to create databases" | pv -qL 100
    echo
    echo "$ mysql -h\$DB_HOST -P3306 -u\$DB_USER -e \"SHOW DATABASES;\" # to display databases" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql databases delete \$DB_NAME --instance=\$DB_INSTANCE --quiet # to delete database" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql databases create \$DB_NAME --instance=\$DB_INSTANCE --charset=utf8 # to create database" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql users create \$DB_USER --instance=\$DB_INSTANCE --password=\$DB_PASSWORD --host=% # to create database user" | pv -qL 100
    echo
    echo "$ mysql -h\$DB_HOST -P3306 -u\$DB_USER -e \"SHOW DATABASES;\" # to display databases" | pv -qL 100
    echo
    echo "$ mysql -h\$DB_HOST -P3306 -u\$DB_USER -e \"DROP DATABASE \$DB_NAME;\" # to drop databases" | pv -qL 100
    echo
    echo "$ mysql -h\$DB_HOST -P3306 -u\$DB_USER -e \"CREATE DATABASE \$DB_NAME;\" # to create databases" | pv -qL 100
    echo
    echo "$ mysql -h\$DB_HOST -P3306 -u\$DB_USER -e \"SHOW DATABASES;\" # to display databases" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql databases delete \$DB_NAME --instance=\$DB_INSTANCE --quiet # to delete database" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql databases create \$DB_NAME --instance=\$DB_INSTANCE --charset=utf8 # to create database" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql users create \$DB_USER --instance=\$DB_INSTANCE --password=\$DB_PASSWORD --host=% # to create database user" | pv -qL 100
    echo
    echo "$ mysql -h\$DB_HOST -P3306 -u\$DB_USER -e \"SHOW DATABASES;\" # to display databases" | pv -qL 100
    echo
    echo "$ mysql -h\$DB_HOST -P3306 -u\$DB_USER -e \"DROP DATABASE \$DB_NAME;\" # to drop databases" | pv -qL 100
    echo
    echo "$ mysql -h\$DB_HOST -P3306 -u\$DB_USER -e \"CREATE DATABASE \$DB_NAME;\" # to create databases" | pv -qL 100
    echo
    echo "$ mysql -h\$DB_HOST -P3306 -u\$DB_USER -e \"SHOW DATABASES;\" # to display databases" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql -q instances patch \$DB_INSTANCE --no-assign-ip --clear-authorized-networks # to disable access from the local IP" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"
    export LOCALIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
    export AUTHORIZED_NETWORK=${LOCALIP}/32
    echo
    echo "$ gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --assign-ip --authorized-networks=$AUTHORIZED_NETWORK # to authorize access from the local client IP" | pv -qL 100
    gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --assign-ip --authorized-networks=$AUTHORIZED_NETWORK
    export DATABASE_NAME=${APPLICATION_NAME}_dev
    export DB_NAME=${DATABASE_NAME}
    export DB_USER=$DB_NAME
    export DB_HOST=$(gcloud --project $GCP_PROJECT sql instances describe $DB_INSTANCE --format 'value(ipAddresses[0].ipAddress)')
    unset DB_PASSWORD
    export DB_PASSWORD=$(gcloud --project $SECRETS_PROJECT secrets versions access latest --secret=${GCP_PROJECT}-${DB_INSTANCE}-${DATABASE_NAME}-password > /dev/null 2>&1)
    if [ -z "$DB_PASSWORD" ]
    then
        echo
        echo "$ printf \"\$(date +%s | sha256sum | base64 | head -c 12 ; echo)\") | gcloud --project $SECRETS_PROJECT secrets create ${GCP_PROJECT}-${DB_INSTANCE}-${DATABASE_NAME}-password --data-file=- # to create password" | pv -qL 100
        printf "$(date +%s | sha256sum | base64 | head -c 12 ; echo)" | gcloud --project $SECRETS_PROJECT secrets create ${GCP_PROJECT}-${DB_INSTANCE}-${DATABASE_NAME}-password --data-file=- 2>/dev/null
        sleep 5
    fi 
    export DB_PASSWORD=$(gcloud --project $SECRETS_PROJECT secrets versions access latest --secret=${GCP_PROJECT}-${DB_INSTANCE}-${DATABASE_NAME}-password 2>/dev/null)
    export MYSQL_PWD=$DB_PASSWORD
    echo
    echo "$ gcloud --project $GCP_PROJECT sql databases delete $DB_NAME --instance=$DB_INSTANCE --quiet # to delete database" | pv -qL 100
    gcloud --project $GCP_PROJECT sql databases delete $DB_NAME --instance=$DB_INSTANCE --quiet 2>/dev/null
    echo
    echo "$ gcloud --project $GCP_PROJECT sql databases create $DB_NAME --instance=$DB_INSTANCE --charset=utf8 # to create database" | pv -qL 100
    gcloud --project $GCP_PROJECT sql databases create $DB_NAME --instance=$DB_INSTANCE --charset=utf8 2>/dev/null
    echo
    echo "$ gcloud --project $GCP_PROJECT sql users create $DB_USER --instance=$DB_INSTANCE --password=\$DB_PASSWORD --host=% # to create database user" | pv -qL 100
    gcloud --project $GCP_PROJECT sql users create $DB_USER --instance=$DB_INSTANCE --password=$DB_PASSWORD --host=% 
    echo
    echo "$ mysql -h$DB_HOST -P3306 -u$DB_USER -e \"SHOW DATABASES;\" # to display databases" | pv -qL 100
    mysql -h$DB_HOST -P3306 -u$DB_USER -e "SHOW DATABASES;"
    echo
    echo "$ mysql -h$DB_HOST -P3306 -u$DB_USER -e \"DROP DATABASE $DB_NAME;\" # to drop databases" | pv -qL 100
    mysql -h$DB_HOST -P3306 -u$DB_USER -e "DROP DATABASE $DB_NAME;"
    echo
    sleep 5
    echo "$ mysql -h$DB_HOST -P3306 -u$DB_USER -e \"CREATE DATABASE $DB_NAME;\" # to create databases" | pv -qL 100
    mysql -h$DB_HOST -P3306 -u$DB_USER -e "CREATE DATABASE $DB_NAME;"
    echo
    echo "$ mysql -h$DB_HOST -P3306 -u$DB_USER -e \"SHOW DATABASES;\" # to display databases" | pv -qL 100
    mysql -h$DB_HOST -P3306 -u$DB_USER -e "SHOW DATABASES;"
    export DATABASE_NAME=${APPLICATION_NAME}_qa
    export DB_NAME=${DATABASE_NAME}
    export DB_USER=$DB_NAME
    export DB_HOST=$(gcloud --project $GCP_PROJECT sql instances describe $DB_INSTANCE --format 'value(ipAddresses[0].ipAddress)')
    unset DB_PASSWORD
    export DB_PASSWORD=$(gcloud --project $SECRETS_PROJECT secrets versions access latest --secret=${GCP_PROJECT}-${DB_INSTANCE}-${DATABASE_NAME}-password > /dev/null 2>&1)
    if [ -z "$DB_PASSWORD" ]
    then
        echo
        echo "$ printf \"\$(date +%s | sha256sum | base64 | head -c 12 ; echo)\") | gcloud --project $SECRETS_PROJECT secrets create ${GCP_PROJECT}-${DB_INSTANCE}-${DATABASE_NAME}-password --data-file=- # to create password" | pv -qL 100
        printf "$(date +%s | sha256sum | base64 | head -c 12 ; echo)" | gcloud --project $SECRETS_PROJECT secrets create ${GCP_PROJECT}-${DB_INSTANCE}-${DATABASE_NAME}-password --data-file=- 2>/dev/null
        sleep 5
    fi 
    export DB_PASSWORD=$(gcloud --project $SECRETS_PROJECT secrets versions access latest --secret=${GCP_PROJECT}-${DB_INSTANCE}-${DATABASE_NAME}-password 2>/dev/null)
    export MYSQL_PWD=$DB_PASSWORD
    echo
    echo "$ gcloud --project $GCP_PROJECT sql databases delete $DB_NAME --instance=$DB_INSTANCE --quiet # to delete database" | pv -qL 100
    gcloud --project $GCP_PROJECT sql databases delete $DB_NAME --instance=$DB_INSTANCE --quiet 2>/dev/null
    echo
    echo "$ gcloud --project $GCP_PROJECT sql databases create $DB_NAME --instance=$DB_INSTANCE --charset=utf8 # to create database" | pv -qL 100
    gcloud --project $GCP_PROJECT sql databases create $DB_NAME --instance=$DB_INSTANCE --charset=utf8 2>/dev/null
    echo
    echo "$ gcloud --project $GCP_PROJECT sql users create $DB_USER --instance=$DB_INSTANCE --password=\$DB_PASSWORD --host=% # to create database user" | pv -qL 100
    gcloud --project $GCP_PROJECT sql users create $DB_USER --instance=$DB_INSTANCE --password=$DB_PASSWORD --host=% 
    echo
    echo "$ mysql -h$DB_HOST -P3306 -u$DB_USER -e \"SHOW DATABASES;\" # to display databases" | pv -qL 100
    mysql -h$DB_HOST -P3306 -u$DB_USER -e "SHOW DATABASES;"
    echo
    echo "$ mysql -h$DB_HOST -P3306 -u$DB_USER -e \"DROP DATABASE $DB_NAME;\" # to drop databases" | pv -qL 100
    mysql -h$DB_HOST -P3306 -u$DB_USER -e "DROP DATABASE $DB_NAME;"
    echo
    sleep 5
    echo "$ mysql -h$DB_HOST -P3306 -u$DB_USER -e \"CREATE DATABASE $DB_NAME;\" # to create databases" | pv -qL 100
    mysql -h$DB_HOST -P3306 -u$DB_USER -e "CREATE DATABASE $DB_NAME;"
    echo
    echo "$ mysql -h$DB_HOST -P3306 -u$DB_USER -e \"SHOW DATABASES;\" # to display databases" | pv -qL 100
    mysql -h$DB_HOST -P3306 -u$DB_USER -e "SHOW DATABASES;"
    export DATABASE_NAME=${APPLICATION_NAME}_prod
    export DB_NAME=${DATABASE_NAME}
    export DB_USER=$DB_NAME
    export DB_HOST=$(gcloud --project $GCP_PROJECT sql instances describe $DB_INSTANCE --format 'value(ipAddresses[0].ipAddress)')
    unset DB_PASSWORD
    export DB_PASSWORD=$(gcloud --project $SECRETS_PROJECT secrets versions access latest --secret=${GCP_PROJECT}-${DB_INSTANCE}-${DATABASE_NAME}-password > /dev/null 2>&1)
    if [ -z "$DB_PASSWORD" ]
    then
        echo
        echo "$ printf \"\$(date +%s | sha256sum | base64 | head -c 12 ; echo)\") | gcloud --project $SECRETS_PROJECT secrets create ${GCP_PROJECT}-${DB_INSTANCE}-${DATABASE_NAME}-password --data-file=- # to create password" | pv -qL 100
        printf "$(date +%s | sha256sum | base64 | head -c 12 ; echo)" | gcloud --project $SECRETS_PROJECT secrets create ${GCP_PROJECT}-${DB_INSTANCE}-${DATABASE_NAME}-password --data-file=- 2>/dev/null
        sleep 5
    fi 
    export DB_PASSWORD=$(gcloud --project $SECRETS_PROJECT secrets versions access latest --secret=${GCP_PROJECT}-${DB_INSTANCE}-${DATABASE_NAME}-password 2>/dev/null)
    export MYSQL_PWD=$DB_PASSWORD
    echo
    echo "$ gcloud --project $GCP_PROJECT sql databases delete $DB_NAME --instance=$DB_INSTANCE --quiet # to delete database" | pv -qL 100
    gcloud --project $GCP_PROJECT sql databases delete $DB_NAME --instance=$DB_INSTANCE --quiet 2>/dev/null
    echo
    echo "$ gcloud --project $GCP_PROJECT sql databases create $DB_NAME --instance=$DB_INSTANCE --charset=utf8 # to create database" | pv -qL 100
    gcloud --project $GCP_PROJECT sql databases create $DB_NAME --instance=$DB_INSTANCE --charset=utf8 2>/dev/null
    echo
    echo "$ gcloud --project $GCP_PROJECT sql users create $DB_USER --instance=$DB_INSTANCE --password=\$DB_PASSWORD --host=% # to create database user" | pv -qL 100
    gcloud --project $GCP_PROJECT sql users create $DB_USER --instance=$DB_INSTANCE --password=$DB_PASSWORD --host=% 
    echo
    echo "$ mysql -h$DB_HOST -P3306 -u$DB_USER -e \"SHOW DATABASES;\" # to display databases" | pv -qL 100
    mysql -h$DB_HOST -P3306 -u$DB_USER -e "SHOW DATABASES;"
    echo
    echo "$ mysql -h$DB_HOST -P3306 -u$DB_USER -e \"DROP DATABASE $DB_NAME;\" # to drop databases" | pv -qL 100
    mysql -h$DB_HOST -P3306 -u$DB_USER -e "DROP DATABASE $DB_NAME;"
    echo
    sleep 5
    echo "$ mysql -h$DB_HOST -P3306 -u$DB_USER -e \"CREATE DATABASE $DB_NAME;\" # to create databases" | pv -qL 100
    mysql -h$DB_HOST -P3306 -u$DB_USER -e "CREATE DATABASE $DB_NAME;"
    echo
    echo "$ mysql -h$DB_HOST -P3306 -u$DB_USER -e \"SHOW DATABASES;\" # to display databases" | pv -qL 100
    mysql -h$DB_HOST -P3306 -u$DB_USER -e "SHOW DATABASES;"
    echo
    echo "$ gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --no-assign-ip --clear-authorized-networks # to disable access from the local IP" | pv -qL 100
    gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --no-assign-ip --clear-authorized-networks
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"
    echo
    echo "*** Not implemented ***"
else
    export STEP="${STEP},4i"
    echo
    echo "*** Not implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"-5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"   
    echo
    echo "$ gcloud compute addresses create nfs-server-ip --region \$GCP_REGION --subnet cloudsql-subnet # to configure static IP" | pv -qL 100
    echo
    echo "$ gcloud compute instance-templates create nfs-server-template --boot-disk-size=30GB --image-family=ubuntu-1804-lts --image-project=ubuntu-os-cloud --machine-type=f1-micro --region \$GCP_REGION --network serverless-vpc --subnet cloudsql-subnet --tags nfs --create-disk device-name=data-disk,mode=rw,size=10GB,type=pd-ssd --no-address # to create VM template" | pv -qL 100
    echo
    echo "$ gcloud beta compute instance-groups managed create nfs-server-group --template nfs-server-template --zone \${GCP_REGION}-b --size 1 --stateful-disk device-name=data-disk,auto-delete=never --base-instance-name nfs-server --stateful-internal-ip interface-name=nic0,auto-delete=on-permanent-instance-deletion --no-force-update-on-repair # to create VM MIG" | pv -qL 100
    echo
    echo "$ gcloud compute instance-groups managed create-instance nfs-server-group --instance nfs-server --zone \${GCP_REGION}-b # to create VM instance" | pv -qL 100
    echo
    echo "$ gcloud compute firewall-rules create allow-ingress-from-iap --network serverless-vpc --direction=INGRESS --action=allow --rules=tcp:PORT --source-ranges=35.235.240.0/20 # to allow iap"
    echo
    echo "$ export EMAIL=\$(gcloud config get-value core/account) # to set email" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=user:\$EMAIL --role=roles/iap.tunnelResourceAccessor # to grant role" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=user:\$EMAIL --role=roles/compute.instanceAdmin.v1  # to grant role" | pv -qL 100
    echo
    echo "$ gcloud compute --project \$GCP_PROJECT --quiet ssh nfs-server --zone \${GCP_REGION}-b --tunnel-through-iap --command=\"sudo apt install -y nfs-kernel-server\" # to install nfs server" | pv -qL 100
    echo
    echo "$ gcloud compute --project \$GCP_PROJECT --quiet ssh nfs-server --zone \${GCP_REGION}-b --tunnel-through-iap --command=\"sudo mkdir /share && sudo chown nobody:nogroup /share && sudo chmod 777 /share\" # to create shared directory" | pv -qL 100
    echo
    echo "$ gcloud compute --project \$GCP_PROJECT --quiet ssh nfs-server --zone \${GCP_REGION}-b --tunnel-through-iap --command=\"sudo chmod 755 /etc/exports\" # to change permission" | pv -qL 100
    echo
    echo "$ gcloud compute --project \$GCP_PROJECT --quiet ssh nfs-server --zone \${GCP_REGION}-b --tunnel-through-iap --command=\"sudo grep -qxF '/share *(rw,sync,no_subtree_check)' /etc/exports || echo '/share *(rw,sync,no_subtree_check)' | sudo tee -a /etc/exports > /dev/null\" # to add share to nfs exports" | pv -qL 100
    echo
    echo "$ gcloud compute --project \$GCP_PROJECT --quiet ssh nfs-server --zone \${GCP_REGION}-b --tunnel-through-iap --command=\"sudo systemctl restart nfs-kernel-server\" # to restart nfs-kernel-server" | pv -qL 100
    echo
    echo "$ gcloud compute --project \$GCP_PROJECT --quiet ssh nfs-server --zone \${GCP_REGION}-b --tunnel-through-iap --command=\"sudo exportfs\" # to confirm directory is being shared" | pv -qL 100
    echo
    echo "$ gcloud compute firewall-rules create nfs --network serverless-vpc --allow=tcp:111,udp:111,tcp:2049,udp:2049 --target-tags=nfs # to configure firewall rule" | pv -qL 100
    echo
    echo "$ printf \"\$(gcloud --project \$GCP_PROJECT compute instances describe nfs-server --zone \${GCP_REGION}-b --format='get(networkInterfaces[0].accessConfigs[0].natIP)')\" | gcloud --project \$SECRETS_PROJECT secrets create \${GCP_PROJECT}-\${APPLICATION_NAME}-nfs-server-ip --data-file=- # to get Public IP get(networkInterfaces[0].accessConfigs[0].natIP), Private IP get(networkInterfaces[0].networkIP)" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"
    echo
    echo "$ gcloud compute addresses create nfs-server-ip --region $GCP_REGION --subnet cloudsql-subnet # to configure static IP" | pv -qL 100
    gcloud compute addresses create nfs-server-ip --region $GCP_REGION --subnet cloudsql-subnet 
    echo
    echo "$ gcloud compute instance-templates create nfs-server-template --boot-disk-size=30GB --image-family=ubuntu-1804-lts --image-project=ubuntu-os-cloud --machine-type=f1-micro --region $GCP_REGION --network serverless-vpc --subnet cloudsql-subnet --tags nfs --create-disk device-name=data-disk,mode=rw,size=10GB,type=pd-ssd --no-address # to create VM template" | pv -qL 100
    gcloud compute instance-templates create nfs-server-template --boot-disk-size=30GB --image-family=ubuntu-1804-lts --image-project=ubuntu-os-cloud --machine-type=f1-micro --region $GCP_REGION --network serverless-vpc --subnet cloudsql-subnet --tags nfs --create-disk device-name=data-disk,mode=rw,size=10GB,type=pd-ssd --no-address
    echo
    echo "$ gcloud beta compute instance-groups managed create nfs-server-group --template nfs-server-template --zone ${GCP_REGION}-b --size 1 --stateful-disk device-name=data-disk,auto-delete=never --base-instance-name nfs-server --stateful-internal-ip interface-name=nic0,auto-delete=on-permanent-instance-deletion --no-force-update-on-repair # to create VM MIG" | pv -qL 100
    gcloud beta compute instance-groups managed create nfs-server-group --template nfs-server-template --zone ${GCP_REGION}-b --size 1 --stateful-disk device-name=data-disk,auto-delete=never --base-instance-name nfs-server --stateful-internal-ip interface-name=nic0,auto-delete=on-permanent-instance-deletion --no-force-update-on-repair
    echo
    echo "$ gcloud compute instance-groups managed create-instance nfs-server-group --instance nfs-server --zone ${GCP_REGION}-b # to create VM instance" | pv -qL 100
    gcloud compute instance-groups managed create-instance nfs-server-group --instance nfs-server --zone ${GCP_REGION}-b
    echo
    echo "$ gcloud compute firewall-rules create allow-ingress-from-iap --network serverless-vpc --direction=INGRESS --action=allow --rules=tcp:PORT --source-ranges=35.235.240.0/20 # to allow iap"
    gcloud compute firewall-rules create allow-ingress-from-iap --network serverless-vpc --direction=INGRESS --action=allow --rules=tcp:22 --source-ranges=35.235.240.0/20
    echo
    echo "$ export EMAIL=\$(gcloud config get-value core/account) # to set email" | pv -qL 100
    export EMAIL=$(gcloud config get-value core/account)
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:$EMAIL --role=roles/iap.tunnelResourceAccessor # to grant role" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:$EMAIL --role=roles/iap.tunnelResourceAccessor
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:$EMAIL --role=roles/compute.instanceAdmin.v1  # to grant role" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:$EMAIL --role=roles/compute.instanceAdmin.v1
    echo
    sleep 15
    echo "$ gcloud compute --project $GCP_PROJECT --quiet ssh nfs-server --zone ${GCP_REGION}-b --tunnel-through-iap --command=\"sudo apt install -y nfs-kernel-server\" # to install nfs server" | pv -qL 100
    gcloud compute --project $GCP_PROJECT --quiet ssh nfs-server --zone ${GCP_REGION}-b --tunnel-through-iap --command="sudo apt install -y nfs-kernel-server"
    echo
    echo "$ gcloud compute --project $GCP_PROJECT --quiet ssh nfs-server --zone ${GCP_REGION}-b --tunnel-through-iap --command=\"sudo mkdir /share && sudo chown nobody:nogroup /share && sudo chmod 777 /share\" # to create shared directory" | pv -qL 100
    gcloud compute --project $GCP_PROJECT --quiet ssh nfs-server --zone ${GCP_REGION}-b --tunnel-through-iap --command="sudo mkdir /share && sudo chown nobody:nogroup /share && sudo chmod 777 /share"
    echo
    echo "$ gcloud compute --project $GCP_PROJECT --quiet ssh nfs-server --zone ${GCP_REGION}-b --tunnel-through-iap --command=\"sudo chmod 755 /etc/exports\" # to change permission" | pv -qL 100
    gcloud compute --project $GCP_PROJECT --quiet ssh nfs-server --zone ${GCP_REGION}-b --tunnel-through-iap --command="sudo chmod 755 /etc/exports"
    echo
    echo "$ gcloud compute --project $GCP_PROJECT --quiet ssh nfs-server --zone ${GCP_REGION}-b --tunnel-through-iap --command=\"sudo grep -qxF '/share *(rw,sync,no_subtree_check)' /etc/exports || echo '/share *(rw,sync,no_subtree_check)' | sudo tee -a /etc/exports > /dev/null\" # to add share to nfs exports" | pv -qL 100
    gcloud compute --project $GCP_PROJECT --quiet ssh nfs-server --zone ${GCP_REGION}-b --tunnel-through-iap --command="sudo grep -qxF '/share *(rw,sync,no_subtree_check)' /etc/exports || echo '/share *(rw,sync,no_subtree_check)' | sudo tee -a /etc/exports > /dev/null"
    echo
    echo "$ gcloud compute --project $GCP_PROJECT --quiet ssh nfs-server --zone ${GCP_REGION}-b --tunnel-through-iap --command=\"sudo systemctl restart nfs-kernel-server\" # to restart nfs-kernel-server" | pv -qL 100
    gcloud compute --project $GCP_PROJECT --quiet ssh nfs-server --zone ${GCP_REGION}-b --tunnel-through-iap --command="sudo systemctl restart nfs-kernel-server"
    echo
    echo "$ gcloud compute --project $GCP_PROJECT --quiet ssh nfs-server --zone ${GCP_REGION}-b --tunnel-through-iap --command=\"sudo exportfs\" # to confirm directory is being shared" | pv -qL 100
    gcloud compute --project $GCP_PROJECT --quiet ssh nfs-server --zone ${GCP_REGION}-b --tunnel-through-iap --command="sudo exportfs"
    echo
    echo "$ gcloud compute firewall-rules create nfs --network serverless-vpc --allow=tcp:111,udp:111,tcp:2049,udp:2049 --target-tags=nfs # to configure firewall rule" | pv -qL 100
    gcloud compute firewall-rules create nfs --network serverless-vpc --allow=tcp:111,udp:111,tcp:2049,udp:2049 --target-tags=nfs
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"
    echo
    echo "*** Not implemented ***"
else
    export STEP="${STEP},5i"
    echo
    echo "*** Not implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member serviceAccount:\${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com --role roles/binaryauthorization.attestorsViewer # to add binary authorization attestor viewer role" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member serviceAccount:\${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com --role roles/cloudkms.signerVerifier # to add cloud KMS cryptoKey signer/verifier role" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member serviceAccount:\${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com --role roles/containeranalysis.notes.attacher # to add Container Analysis notes attacher role" | pv -qL 100
    echo
    echo "$ gcloud container binauthz policy export --project \$GCP_PROJECT # to view the default policy" | pv -qL 100
    echo
    echo "$ gcloud iam service-accounts create gcp-binauth-sa # to create service account" | pv -qL 100
    echo
    echo "$ cat > \$PROJDIR/note_payload.json << EOM
{
  \"name\": \"projects/\${GCP_PROJECT}/notes/\${NOTE_ID}\",
  \"attestation\": {
    \"hint\": {
      \"human_readable_name\": \"\${DESCRIPTION}\"
    }
  }
}
EOM" | pv -qL 100
    echo
    echo "$ curl -X POST -H \"Content-Type: application/json\" -H \"Authorization: Bearer \$(gcloud auth print-access-token)\" -H \"x-goog-user-project: \$GCP_PROJECT\" --data-binary @\$PROJDIR/note_payload.json \"https://containeranalysis.googleapis.com/v1/projects/\${GCP_PROJECT}/notes/?noteId=\${NOTE_ID}\" # to create note in container analysis" | pv -qL 100
    echo
    echo "$ curl -H \"Authorization: Bearer \$(gcloud auth print-access-token)\" -H \"x-goog-user-project: \${GCP_PROJECT}\" \"https://containeranalysis.googleapis.com/v1/projects/\${GCP_PROJECT}/notes/\" # to verify note" | pv -qL 100
    echo
    echo "$ cat > \$PROJDIR/iam_request.json << EOM # to generate JSON file with info to set IAM role on note
{
  \"resource\": \"projects/${GCP_PROJECT}/notes/${NOTE_ID}\",
  \"policy\": {
    \"bindings\": [
      {
        \"role\": \"roles/containeranalysis.notes.occurrences.viewer\",
        \"members\": [
          \"serviceAccount:\${BINAUTH_SERVICE_ACCOUNT}\"
        ]
      }
    ]
  }
}
EOM" | pv -qL 100
    echo
    echo "$ curl -X POST -H \"Content-Type: application/json\" -H \"Authorization: Bearer \$(gcloud auth print-access-token)\" -H \"x-goog-user-project: \$GCP_PROJECT\" --data-binary @\$PROJDIR/iam_request.json \"https://containeranalysis.googleapis.com/v1/projects/\$GCP_PROJECT/notes/\$NOTE_ID:setIamPolicy\" # to add service account and requested access roles to IAM policy for note" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT container binauthz attestors create \$ATTESTOR_NAME --attestation-authority-note=$NOTE_ID --attestation-authority-note-project=\$GCP_PROJECT # to create attestor resource" | pv -qL 100
    echo
    echo "$ gcloud container binauthz attestors add-iam-policy-binding \"projects/\$GCP_PROJECT/attestors/\$ATTESTOR_NAME\" --member=\"serviceAccount:\$BINAUTH_SERVICE_ACCOUNT\" --role=roles/binaryauthorization.attestorsVerifier # to add IAM role binding for deployer project to attestor" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT kms keyrings create \$KMS_KEYRING_NAME --location \$GCP_REGION # to create Cloud KMS key ring" | pv -qL 100
    echo
    echo "$ gcloud kms keys create \$KMS_KEY_NAME --keyring \$KMS_KEYRING_NAME --location \$GCP_REGION --purpose \"asymmetric-signing\" --protection-level software --default-algorithm ec-sign-p256-sha256 # to generate asymmetric key" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT container binauthz attestors public-keys add --attestor \$ATTESTOR_NAME --keyversion-project \$GCP_PROJECT --keyversion-location \$GCP_REGION --keyversion-keyring \$KMS_KEYRING_NAME --keyversion-key \$KMS_KEY_NAME --keyversion \$KMS_KEY_VERSION # to add key to attestor" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT container binauthz attestors list # to verify key creation" | pv -qL 100
    echo
    echo "$ cat > \$PROJDIR/policy.yaml << EOF
globalPolicyEvaluationMode: ENABLE
defaultAdmissionRule:
    evaluationMode: REQUIRE_ATTESTATION
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
    requireAttestationsBy:
    - projects/\${GCP_PROJECT}/attestors/\$ATTESTOR_NAME
name: projects/\${GCP_PROJECT}/policy # to create a policy file that allows Google-maintained system images, sets the evaluationMode to REQUIRE_ATTESTATION, and adds a node named requireAttestationsBy that references the attestor
EOF" | pv -qL 100
    echo
    echo "$ gcloud container binauthz policy import \$PROJDIR/policy.yaml --project \$GCP_PROJECT # to import the policy YAML" | pv -qL 100
    echo
    echo "$ git clone https://github.com/GoogleCloudPlatform/cloud-builders-community.git /tmp/cloud-builders-community # to clone repo" | pv -qL 100
    echo
    echo "$ cp -rf /tmp/cloud-builders-community/binauthz-attestation \$PROJDIR # to copy configuration files" | pv -qL 100
    echo
    echo "$ cd \$PROJDIR/binauthz-attestation # to change directory"
    echo
    echo "$ gcloud builds submit . --config cloudbuild.yaml # to build image"
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    export PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT --format="value(projectNumber)") > /dev/null 2>&1 
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com --role roles/binaryauthorization.attestorsViewer # to add binary authorization attestor viewer role" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com --role roles/binaryauthorization.attestorsViewer
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com --role roles/cloudkms.signerVerifier # to add cloud KMS cryptoKey signer/verifier role" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com --role roles/cloudkms.signerVerifier
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com --role roles/containeranalysis.notes.attacher # to add Container Analysis notes attacher role" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com --role roles/containeranalysis.notes.attacher
    echo
    echo "$ gcloud container binauthz policy export --project $GCP_PROJECT # to view the default policy" | pv -qL 100
    gcloud container binauthz policy export
    echo
    echo "$ gcloud iam service-accounts create gcp-binauth-sa # to create service account" | pv -qL 100
    gcloud iam service-accounts create gcp-binauth-sa 2>/dev/null
    export BINAUTH_SERVICE_ACCOUNT="gcp-binauth-sa@$GCP_PROJECT.iam.gserviceaccount.com"
    echo
    echo "$ cat > $PROJDIR/note_payload.json << EOM
{
  \"name\": \"projects/${GCP_PROJECT}/notes/${NOTE_ID}\",
  \"attestation\": {
    \"hint\": {
      \"human_readable_name\": \"${DESCRIPTION}\"
    }
  }
}
EOM" | pv -qL 100
cat > $PROJDIR/note_payload.json << EOM
{
  "name": "projects/${GCP_PROJECT}/notes/${NOTE_ID}",
  "attestation": {
    "hint": {
      "human_readable_name": "${DESCRIPTION}"
    }
  }
}
EOM
    echo
    echo "$ curl -X POST -H \"Content-Type: application/json\" -H \"Authorization: Bearer \$(gcloud auth print-access-token)\" -H \"x-goog-user-project: $GCP_PROJECT\" --data-binary @$PROJDIR/note_payload.json \"https://containeranalysis.googleapis.com/v1/projects/${GCP_PROJECT}/notes/?noteId=${NOTE_ID}\" # to create note in container analysis" | pv -qL 100
    curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "x-goog-user-project: $GCP_PROJECT" --data-binary @$PROJDIR/note_payload.json "https://containeranalysis.googleapis.com/v1/projects/${GCP_PROJECT}/notes/?noteId=${NOTE_ID}"
    echo
    echo "$ curl -H \"Authorization: Bearer \$(gcloud auth print-access-token)\" -H \"x-goog-user-project: \${GCP_PROJECT}\" \"https://containeranalysis.googleapis.com/v1/projects/${GCP_PROJECT}/notes/\" # to verify note" | pv -qL 100
    curl -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "x-goog-user-project: ${GCP_PROJECT}" "https://containeranalysis.googleapis.com/v1/projects/${GCP_PROJECT}/notes/"
    echo
    echo "$ cat > $PROJDIR/iam_request.json << EOM # to generate JSON file with info to set IAM role on note
{
  \"resource\": \"projects/${GCP_PROJECT}/notes/${NOTE_ID}\",
  \"policy\": {
    \"bindings\": [
      {
        \"role\": \"roles/containeranalysis.notes.occurrences.viewer\",
        \"members\": [
          \"serviceAccount:${BINAUTH_SERVICE_ACCOUNT}\"
        ]
      }
    ]
  }
}
EOM" | pv -qL 100
cat > $PROJDIR/iam_request.json << EOM # to generate JSON file with info to set IAM role on note
{
  "resource": "projects/${GCP_PROJECT}/notes/${NOTE_ID}",
  "policy": {
    "bindings": [
      {
        "role": "roles/containeranalysis.notes.occurrences.viewer",
        "members": [
          "serviceAccount:${BINAUTH_SERVICE_ACCOUNT}"
        ]
      }
    ]
  }
}
EOM
    echo
    echo "$ curl -X POST -H \"Content-Type: application/json\" -H \"Authorization: Bearer \$(gcloud auth print-access-token)\" -H \"x-goog-user-project: $GCP_PROJECT\" --data-binary @$PROJDIR/iam_request.json \"https://containeranalysis.googleapis.com/v1/projects/$GCP_PROJECT/notes/$NOTE_ID:setIamPolicy\" # to add service account and requested access roles to IAM policy for note" | pv -qL 100
    curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "x-goog-user-project: $GCP_PROJECT" --data-binary @$PROJDIR/iam_request.json "https://containeranalysis.googleapis.com/v1/projects/$GCP_PROJECT/notes/$NOTE_ID:setIamPolicy"
    echo
    echo "$ gcloud --project $GCP_PROJECT container binauthz attestors create $ATTESTOR_NAME --attestation-authority-note=$NOTE_ID --attestation-authority-note-project=$GCP_PROJECT # to create attestor resource" | pv -qL 100
    gcloud --project $GCP_PROJECT container binauthz attestors create $ATTESTOR_NAME --attestation-authority-note=$NOTE_ID --attestation-authority-note-project=$GCP_PROJECT 2>/dev/null
    echo
    echo "$ gcloud container binauthz attestors add-iam-policy-binding \"projects/$GCP_PROJECT/attestors/$ATTESTOR_NAME\" --member=\"serviceAccount:$BINAUTH_SERVICE_ACCOUNT\" --role=roles/binaryauthorization.attestorsVerifier # to add IAM role binding for deployer project to attestor" | pv -qL 100
    gcloud container binauthz attestors add-iam-policy-binding "projects/$GCP_PROJECT/attestors/$ATTESTOR_NAME" --member="serviceAccount:$BINAUTH_SERVICE_ACCOUNT" --role=roles/binaryauthorization.attestorsVerifier
    echo
    echo "$ gcloud --project $GCP_PROJECT kms keyrings create $KMS_KEYRING_NAME --location $GCP_REGION # to create Cloud KMS key ring" | pv -qL 100
    gcloud --project $GCP_PROJECT kms keyrings create $KMS_KEYRING_NAME --location $GCP_REGION
    echo
    echo "$ gcloud kms keys create $KMS_KEY_NAME --keyring $KMS_KEYRING_NAME --location $GCP_REGION --purpose \"asymmetric-signing\" --protection-level software --default-algorithm ec-sign-p256-sha256 # to generate asymmetric key" | pv -qL 100
    gcloud kms keys create $KMS_KEY_NAME --keyring $KMS_KEYRING_NAME --location $GCP_REGION --purpose "asymmetric-signing" --protection-level software --default-algorithm ec-sign-p256-sha256
    # gcloud kms keys versions get-public-key $KMS_KEY_VERSION --key $KMS_KEY_NAME --keyring $KMS_KEYRING_NAME --location $GCP_REGION --output-file $PROJDIR/${KMS_KEY_NAME}-pubkey.pub # to download the public key for an existing asymmetric key
    echo
    echo "$ gcloud --project $GCP_PROJECT container binauthz attestors public-keys add --attestor $ATTESTOR_NAME --keyversion-project $GCP_PROJECT --keyversion-location $GCP_REGION --keyversion-keyring $KMS_KEYRING_NAME --keyversion-key $KMS_KEY_NAME --keyversion $KMS_KEY_VERSION # to add key to attestor" | pv -qL 100
    gcloud --project $GCP_PROJECT container binauthz attestors public-keys add --attestor $ATTESTOR_NAME --keyversion-project $GCP_PROJECT --keyversion-location $GCP_REGION --keyversion-keyring $KMS_KEYRING_NAME --keyversion-key $KMS_KEY_NAME --keyversion $KMS_KEY_VERSION
    sleep 5
    echo
    echo "$ gcloud --project $GCP_PROJECT container binauthz attestors list # to verify key creation" | pv -qL 100
    gcloud --project $GCP_PROJECT container binauthz attestors list
    echo
    echo "$ cat > $PROJDIR/policy.yaml << EOF
globalPolicyEvaluationMode: ENABLE
defaultAdmissionRule:
    evaluationMode: REQUIRE_ATTESTATION
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
    requireAttestationsBy:
    - projects/${GCP_PROJECT}/attestors/$ATTESTOR_NAME
name: projects/${GCP_PROJECT}/policy # to create a policy file that allows Google-maintained system images, sets the evaluationMode to REQUIRE_ATTESTATION, and adds a node named requireAttestationsBy that references the attestor
EOF" | pv -qL 100
cat > $PROJDIR/policy.yaml << EOF
globalPolicyEvaluationMode: ENABLE
defaultAdmissionRule:
  evaluationMode: REQUIRE_ATTESTATION
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  requireAttestationsBy:
    - projects/${GCP_PROJECT}/attestors/$ATTESTOR_NAME
name: projects/${GCP_PROJECT}/policy # to create a policy file that allows Google-maintained system images, sets the evaluationMode to REQUIRE_ATTESTATION, and adds a node named requireAttestationsBy that references the attestor
EOF
    echo
    echo "$ gcloud container binauthz policy import $PROJDIR/policy.yaml --project $GCP_PROJECT # to import the policy YAML" | pv -qL 100
    gcloud container binauthz policy import $PROJDIR/policy.yaml --project $GCP_PROJECT
    echo
    rm -rf /tmp/cloud-builders-community
    echo "$ git clone https://github.com/GoogleCloudPlatform/cloud-builders-community.git /tmp/cloud-builders-community # to clone repo" | pv -qL 100
    git clone https://github.com/GoogleCloudPlatform/cloud-builders-community.git /tmp/cloud-builders-community
    echo
    echo "$ cp -rf /tmp/cloud-builders-community/binauthz-attestation $PROJDIR # to copy configuration files" | pv -qL 100
    cp -rf /tmp/cloud-builders-community/binauthz-attestation $PROJDIR
    echo
    echo "$ cd $PROJDIR/binauthz-attestation # to change directory"
    cd $PROJDIR/binauthz-attestation
    echo
    echo "$ gcloud builds submit . --config cloudbuild.yaml # to build image"
    gcloud builds submit . --config cloudbuild.yaml
    stty echo # to ensure input characters are echoed on terminal
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"        
    echo
    echo "*** Nothing to delete ***"
else
    export STEP="${STEP},5i"
    echo
    echo "*** Not Implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"6")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},6i"   
    echo
    echo "$ cd \$PROJDIR # to change directory" | pv -qL 100
    echo
    echo "$ mkdir -p \$PROJDIR/src # to create directory" | pv -qL 100
    echo
    echo "$ mkdir -p \$PROJDIR/src/plugins # to create directory" | pv -qL 100
    echo
    echo "$ wget -q https://downloads.wordpress.org/plugin/file-manager-advanced.zip -O file-manager-advanced.zip # to download plugin" | pv -qL 100
    echo 
    echo "$ wget -q https://downloads.wordpress.org/plugin/ilab-media-tools.4.5.19.zip # to download plugin" | pv -qL 100
    echo
    echo "$ wget -q https://downloads.wordpress.org/plugin/updraftplus.1.22.24.zip -O updraftplus.1.22.24.zip # to download plugin" | pv -qL 100
    echo
    echo "$ wget -q https://downloads.wordpress.org/plugin/wp-maximum-upload-file-size.1.0.9.zip # to download plugin" | pv -qL 100
    echo
    echo "$ wget -q https://downloads.wordpress.org/plugin/all-in-one-wp-migration.7.72.zip # to download plugin" | pv -qL 100
    echo
    echo "$ wget -q https://downloads.wordpress.org/plugin/amazon-s3-and-cloudfront.3.2.0.zip # to download plugin" | pv -qL 100
    echo
    echo "$ unzip -q -o file-manager-advanced.zip -d \$PROJDIR/src/plugins # unzip plugin" | pv -qL 100
    echo
    echo "$ unzip -q -o ilab-media-tools.4.5.19.zip -d \$PROJDIR/src/plugins # unzip plugin" | pv -qL 100
    echo
    echo "$ unzip -q -o updraftplus.1.22.24.zip -d \$PROJDIR/src/plugins # unzip plugin" | pv -qL 100
    echo
    echo "$ unzip -q -o wp-maximum-upload-file-size.1.0.9.zip -d \$PROJDIR/src/plugins # unzip plugin" | pv -qL 100
    echo
    echo "$ unzip -q -o all-in-one-wp-migration.7.72.zip -d \$PROJDIR/src/plugins # unzip plugin" | pv -qL 100
    echo
    echo "$ mkdir -p \$PROJDIR/src/themes # to create directory" | pv -qL 100
    echo
    echo "$ mkdir -p \$PROJDIR/src/apache # to create directory" | pv -qL 100
    echo
    echo "$ rm -rf *.zip # to delete downloaded files" | pv -qL 100
    rm -rf  *.zip
    echo
    echo "$ cat <<EOF > \$PROJDIR/src/apache/ports.conf
Listen 8080
<IfModule ssl_module>
        Listen 443
</IfModule>
<IfModule mod_gnutls.c>
        Listen 443
</IfModule>
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF > \$PROJDIR/src/apache/000-default.conf
<VirtualHost *:8080>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html
        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF" | pv -qL 100
    echo
    echo "$ mkdir -p \$PROJDIR/src/wordpress # to create directory"
    echo
    echo "$ cat <<EOF > $PROJDIR/src/wordpress/cloud-run-entrypoint.sh
#!/usr/bin/env bash
# Start the sql proxy
cloud_sql_proxy -instances=\$DB_INSTANCE=tcp:3306 &
# Execute ENTRYPOINT and CMD as expected
exec \"\$@\"
EOF" | pv -qL 100
    echo
    echo "$ chmod +x \$PROJDIR/src/wordpress/cloud-run-entrypoint.sh # to make executable"
    echo
    echo "$ cat <<EOF > \$PROJDIR/src/wordpress/wp-config.php
<?php
if (
    isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) &&
    strpos(\$_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false
) {
    define('FORCE_SSL_ADMIN', true);
    \$_SERVER['HTTPS'] = 'on';
}
define( 'AS3CF_SETTINGS', serialize( array(
    'provider' => 'gcp',
    'use-server-roles' => true,
) ) );
define('DB_NAME', getenv('DB_NAME'));
define('DB_USER', getenv('DB_USER'));
define('DB_PASSWORD', getenv('DB_PASSWORD'));
define('DB_HOST', getenv('DB_HOST'));
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', 'utf8mb4_0900_ai_ci');
#define('WP_HOME', 'http://example.com' );
#define('WP_SITEURL', 'http://example.com' );
define('AUTH_KEY', 'put your unique phrase here');
define('SECURE_AUTH_KEY', 'put your unique phrase here');
define('LOGGED_IN_KEY', 'put your unique phrase here');
define('NONCE_KEY', 'put your unique phrase here');
define('AUTH_SALT', 'put your unique phrase here');
define('SECURE_AUTH_SALT', 'put your unique phrase here');
define('LOGGED_IN_SALT', 'put your unique phrase here');
define('NONCE_SALT', 'put your unique phrase here');
define( 'WP_DEBUG', false );
\$table_prefix = 'wp_';
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', dirname( __FILE__ ) . '/' );
}
require_once( ABSPATH . 'wp-settings.php' );
EOF" | pv -qL 100
    echo
    echo "$ curl https://api.wordpress.org/secret-key/1.1/salt/ > \$PROJDIR/src/wordpress/wp-config-salt.php" | pv -qL 100
    echo
    echo "$ key=\$(grep \"define('AUTH_KEY',\" \$PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('AUTH_KEY',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    echo
    echo "$ sed -i \"s/define('AUTH_KEY', '.*');/\$key);/\" \$PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    echo
    echo "$ key=\$(grep \"define('SECURE_AUTH_KEY',\" \$PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('SECURE_AUTH_KEY',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    echo
    echo "$ sed -i \"s/define('SECURE_AUTH_KEY', '.*');/define('SECURE_AUTH_KEY', '\$key');/\" \$PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    echo
    echo "$ key=\$(grep \"define('LOGGED_IN_KEY',\" \$PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('LOGGED_IN_KEY',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    echo
    echo "$ sed -i \"s/define('LOGGED_IN_KEY', '.*');/define('LOGGED_IN_KEY', '\$key');/\" \$PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    echo
    echo "$ key=\$(grep \"define('NONCE_KEY',\" \$PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('NONCE_KEY',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    echo
    echo "$ sed -i \"s/define('NONCE_KEY', '.*');/define('NONCE_KEY', '\$key');/\" \$PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    echo
    echo "$ key=\$(grep \"define('AUTH_SALT',\" \$PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('AUTH_SALT',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    echo
    echo "$ sed -i \"s/define('AUTH_SALT', '.*');/define('AUTH_SALT', '\$key');/\" \$PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    echo
    echo "$ key=\$(grep \"define('SECURE_AUTH_SALT',\" \$PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('SECURE_AUTH_SALT',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    echo
    echo "$ sed -i \"s/define('SECURE_AUTH_SALT', '.*');/define('SECURE_AUTH_SALT', '\$key');/\" \$PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    echo
    echo "$ key=\$(grep \"define('LOGGED_IN_SALT',\" \$PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('LOGGED_IN_SALT',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    echo
    echo "$ sed -i \"s/define('LOGGED_IN_SALT', '.*');/define('LOGGED_IN_SALT', '\$key');/\" \$PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    echo
    echo "$ key=\$(grep \"define('NONCE_SALT',\" \$PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('NONCE_SALT',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    echo
    echo "$ sed -i \"s/define('NONCE_SALT', '.*');/define('NONCE_SALT', '\$key');/\" \$PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    echo
    echo "$ cat <<EOF > \$PROJDIR/src/Dockerfile
# See https://hub.docker.com/_/wordpress/ for the latest
FROM wordpress:6.1.1-php8.0-apache 
EXPOSE 8080
# Use the PORT environment variable in Apache configuration files.
RUN sed -i 's/80/\${PORT}/g' /etc/apache2/sites-available/000-default.conf /etc/apache2/ports.conf 
# Update packages
RUN apt-get update -y && apt-get clean
# wordpress conf
COPY wordpress/wp-config.php /var/www/html/wp-config.php 
# copy themes
COPY themes /usr/src/wordpress/wp-content/themes/ 
# copy plugins
COPY plugins /usr/src/wordpress/wp-content/plugins/ 
# copy uploads
COPY plugins /usr/src/wordpress/wp-content/uploads/ 
# download and install cloud_sql_proxy
RUN apt-get update && apt-get -y install net-tools wget && wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O /usr/local/bin/cloud_sql_proxy && chmod +x /usr/local/bin/cloud_sql_proxy
# custom entrypoint
COPY wordpress/cloud-run-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/cloud-run-entrypoint.sh
ENTRYPOINT [\"cloud-run-entrypoint.sh\",\"docker-entrypoint.sh\"]
CMD [\"apache2-foreground\"]
EOF" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"
    echo
    echo "$ cd $PROJDIR # to change directory" | pv -qL 100
    cd $PROJDIR
    echo
    echo "$ mkdir -p $PROJDIR/src # to create directory" | pv -qL 100
    mkdir -p $PROJDIR/src
    if [[ -f $PROJDIR/$APPLICATION_CONTENT_UPLOAD ]]; then
        echo
        echo "$ unzip -q -o $APPLICATION_CONTENT_UPLOAD -d $PROJDIR/src # unzip plugin" | pv -qL 100
        unzip -q -o $APPLICATION_CONTENT_UPLOAD -d $PROJDIR/src
    fi
    echo
    echo "$ mkdir -p $PROJDIR/src/plugins # to create directory" | pv -qL 100
    mkdir -p $PROJDIR/src/plugins
    echo
    echo "$ wget -q https://downloads.wordpress.org/plugin/file-manager-advanced.zip -O file-manager-advanced.zip # to download plugin" | pv -qL 100
    wget -q https://downloads.wordpress.org/plugin/file-manager-advanced.zip -O file-manager-advanced.zip
    echo 
    echo "$ wget -q https://downloads.wordpress.org/plugin/ilab-media-tools.4.5.19.zip # to download plugin" | pv -qL 100
    wget -q https://downloads.wordpress.org/plugin/ilab-media-tools.4.5.19.zip -O ilab-media-tools.4.5.19.zip
    echo
    echo "$ wget -q https://downloads.wordpress.org/plugin/updraftplus.1.22.24.zip -O updraftplus.1.22.24.zip # to download plugin" | pv -qL 100
    wget -q https://downloads.wordpress.org/plugin/updraftplus.1.22.24.zip -O updraftplus.1.22.24.zip
    echo
    echo "$ wget -q https://downloads.wordpress.org/plugin/all-in-one-wp-migration.7.72.zip # to download plugin" | pv -qL 100
    wget -q https://downloads.wordpress.org/plugin/all-in-one-wp-migration.7.72.zip
    echo
    echo "$ wget -q https://downloads.wordpress.org/plugin/wp-maximum-upload-file-size.1.0.9.zip # to download plugin" | pv -qL 100
    wget -q https://downloads.wordpress.org/plugin/wp-maximum-upload-file-size.1.0.9.zip
    echo
    echo "$ wget -q https://downloads.wordpress.org/plugin/amazon-s3-and-cloudfront.3.2.0.zip # to download plugin" | pv -qL 100
    wget -q https://downloads.wordpress.org/plugin/amazon-s3-and-cloudfront.3.2.0.zip
    echo
    echo "$ wget -q https://downloads.wordpress.org/plugin/http2-push-content.zip # to download plugin" | pv -qL 100
    wget -q https://downloads.wordpress.org/plugin/http2-push-content.zip
    echo
    echo "$ unzip -q -o file-manager-advanced.zip -d $PROJDIR/src/plugins # unzip plugin" | pv -qL 100
    unzip -q -o file-manager-advanced.zip -d $PROJDIR/src/plugins
    echo
    echo "$ unzip -q -o ilab-media-tools.4.5.19.zip -d $PROJDIR/src/plugins # unzip plugin" | pv -qL 100
    unzip -q -o ilab-media-tools.4.5.19.zip -d $PROJDIR/src/plugins
    echo
    echo "$ unzip -q -o updraftplus.1.22.24.zip -d $PROJDIR/src/plugins # unzip plugin" | pv -qL 100
    unzip -q -o updraftplus.1.22.24.zip -d $PROJDIR/src/plugins
    echo
    echo "$ unzip -q -o all-in-one-wp-migration.7.72.zip -d $PROJDIR/src/plugins # unzip plugin" | pv -qL 100
    unzip -q -o all-in-one-wp-migration.7.72.zip -d $PROJDIR/src/plugins
    echo
    echo "$ unzip -q -o wp-maximum-upload-file-size.1.0.9.zip -d $PROJDIR/src/plugins # unzip plugin" | pv -qL 100
    unzip -q -o wp-maximum-upload-file-size.1.0.9.zip -d $PROJDIR/src/plugins
    echo
    echo "$ unzip -q -o amazon-s3-and-cloudfront.3.2.0.zip -d $PROJDIR/src/plugins # unzip plugin" | pv -qL 100
    unzip -q -o amazon-s3-and-cloudfront.3.2.0.zip -d $PROJDIR/src/plugins
    echo
    echo "$ unzip -q -o http2-push-content.zip -d $PROJDIR/src/plugins # unzip plugin" | pv -qL 100
    unzip -q -o http2-push-content.zip -d $PROJDIR/src/plugins
    echo
    echo "$ mkdir -p $PROJDIR/src/themes # to create directory" | pv -qL 100
    mkdir -p $PROJDIR/src/themes
    echo
    echo "$ mkdir -p $PROJDIR/src/apache # to create directory" | pv -qL 100
    mkdir -p $PROJDIR/src/apache
    echo
    echo "$ rm -rf *.zip # to delete downloaded files" | pv -qL 100
    rm -rf  *.zip
    echo
    echo "$ cat <<EOF > $PROJDIR/src/apache/ports.conf
Listen 8080
<IfModule ssl_module>
        Listen 443
</IfModule>
<IfModule mod_gnutls.c>
        Listen 443
</IfModule>
EOF" | pv -qL 100
    cat <<EOF > $PROJDIR/src/apache/ports.conf
Listen 8080
<IfModule ssl_module>
        Listen 443
</IfModule>
<IfModule mod_gnutls.c>
        Listen 443
</IfModule>
EOF
    echo
    echo "$ cat <<EOF > $PROJDIR/src/apache/000-default.conf
<VirtualHost *:8080>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html
        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF" | pv -qL 100
    cat <<EOF > $PROJDIR/src/apache/000-default.conf
<VirtualHost *:8080>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html
        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
    echo
    echo "$ mkdir -p $PROJDIR/src/wordpress # to create directory"
    mkdir -p $PROJDIR/src/wordpress
    echo
    echo "$ cat <<EOF > $PROJDIR/src/wordpress/cloud-run-entrypoint.sh
#!/usr/bin/env bash
# Start the sql proxy
cloud_sql_proxy -instances=\$DB_CONNECTION=tcp:3306 &
# Execute ENTRYPOINT and CMD as expected
exec \"\$@\"
EOF" | pv -qL 100
   cat <<EOF > $PROJDIR/src/wordpress/cloud-run-entrypoint.sh
#!/usr/bin/env bash
# Start the sql proxy
cloud_sql_proxy -instances=\$DB_CONNECTION=tcp:3306 &
# Execute the rest of your ENTRYPOINT and CMD as expected.
exec "\$@"
EOF
    echo
    echo "$ chmod +x $PROJDIR/src/wordpress/cloud-run-entrypoint.sh # to make executable"
    chmod +x $PROJDIR/src/wordpress/cloud-run-entrypoint.sh
    echo
    echo "$ cat <<EOF > $PROJDIR/src/wordpress/wp-config.php
<?php
if (
    isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) &&
    strpos(\$_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false
) {
    define('FORCE_SSL_ADMIN', true);
    \$_SERVER['HTTPS'] = 'on';
}
define( 'AS3CF_SETTINGS', serialize( array(
    'provider' => 'gcp',
    'use-server-roles' => true,
) ) );
define('DB_NAME', getenv('DB_NAME'));
define('DB_USER', getenv('DB_USER'));
define('DB_PASSWORD', getenv('DB_PASSWORD'));
define('DB_HOST', getenv('DB_HOST'));
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', 'utf8mb4_0900_ai_ci');
#define('WP_HOME', 'http://example.com' );
#define('WP_SITEURL', 'http://example.com' );
define('AUTH_KEY', 'put your unique phrase here');
define('SECURE_AUTH_KEY', 'put your unique phrase here');
define('LOGGED_IN_KEY', 'put your unique phrase here');
define('NONCE_KEY', 'put your unique phrase here');
define('AUTH_SALT', 'put your unique phrase here');
define('SECURE_AUTH_SALT', 'put your unique phrase here');
define('LOGGED_IN_SALT', 'put your unique phrase here');
define('NONCE_SALT', 'put your unique phrase here');
define( 'WP_DEBUG', false );
\$table_prefix = 'wp_';
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', dirname( __FILE__ ) . '/' );
}
require_once( ABSPATH . 'wp-settings.php' );
EOF" | pv -qL 100
    cat <<EOF > $PROJDIR/src/wordpress/wp-config.php
<?php
if (
    isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) &&
    strpos(\$_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false
) {
    define('FORCE_SSL_ADMIN', true);
    \$_SERVER['HTTPS'] = 'on';
}
define( 'AS3CF_SETTINGS', serialize( array(
    'provider' => 'gcp',
    'use-server-roles' => true,
) ) );
define('DB_NAME', getenv('DB_NAME'));
define('DB_USER', getenv('DB_USER'));
define('DB_PASSWORD', getenv('DB_PASSWORD'));
define('DB_HOST', getenv('DB_HOST'));
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', 'utf8mb4_0900_ai_ci');
#define('WP_HOME', 'http://example.com' );
#define('WP_SITEURL', 'http://example.com' );
define('AUTH_KEY', 'put your unique phrase here');
define('SECURE_AUTH_KEY', 'put your unique phrase here');
define('LOGGED_IN_KEY', 'put your unique phrase here');
define('NONCE_KEY', 'put your unique phrase here');
define('AUTH_SALT', 'put your unique phrase here');
define('SECURE_AUTH_SALT', 'put your unique phrase here');
define('LOGGED_IN_SALT', 'put your unique phrase here');
define('NONCE_SALT', 'put your unique phrase here');
define( 'WP_DEBUG', false );
\$table_prefix = 'wp_';
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', dirname( __FILE__ ) . '/' );
}
require_once( ABSPATH . 'wp-settings.php' );
EOF
    echo
    echo "$ curl https://api.wordpress.org/secret-key/1.1/salt/ > $PROJDIR/src/wordpress/wp-config-salt.php" | pv -qL 100
    curl https://api.wordpress.org/secret-key/1.1/salt/ > $PROJDIR/src/wordpress/wp-config-salt.php
    echo
    echo "$ key=\$(grep \"define('AUTH_KEY',\" $PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('AUTH_KEY',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    key=$(grep "define('AUTH_KEY'," $PROJDIR/src/wordpress/wp-config-salt.php | sed "s/define('AUTH_KEY',\s*'\(.*\)'.*/\1/")
    echo
    echo "$ sed -i \"/^define('AUTH_KEY'/c\\define('AUTH_KEY', '\$key');\" $PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    sed -i "/^define('AUTH_KEY'/c\define('AUTH_KEY', '$key');" $PROJDIR/src/wordpress/wp-config.php
    echo
    echo "$ key=\$(grep \"define('SECURE_AUTH_KEY',\" $PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('SECURE_AUTH_KEY',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    key=$(grep "define('SECURE_AUTH_KEY'," $PROJDIR/src/wordpress/wp-config-salt.php | sed "s/define('SECURE_AUTH_KEY',\s*'\(.*\)'.*/\1/")
    echo
    echo "$ sed -i \"/^define('SECURE_AUTH_KEY'/c\\define('SECURE_AUTH_KEY', '\$key');\" $PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    sed -i "/^define('SECURE_AUTH_KEY'/c\define('SECURE_AUTH_KEY', '$key');" $PROJDIR/src/wordpress/wp-config.php
    echo
    echo "$ key=\$(grep \"define('LOGGED_IN_KEY',\" $PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('LOGGED_IN_KEY',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    key=$(grep "define('LOGGED_IN_KEY'," $PROJDIR/src/wordpress/wp-config-salt.php | sed "s/define('LOGGED_IN_KEY',\s*'\(.*\)'.*/\1/")
    echo
    echo "$ sed -i \"/^define('LOGGED_IN_KEY'/c\\define('LOGGED_IN_KEY', '\$key');\" $PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    sed -i "/^define('LOGGED_IN_KEY'/c\define('LOGGED_IN_KEY', '$key');" $PROJDIR/src/wordpress/wp-config.php
    echo
    echo "$ key=\$(grep \"define('NONCE_KEY',\" $PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('NONCE_KEY',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    key=$(grep "define('NONCE_KEY'," $PROJDIR/src/wordpress/wp-config-salt.php | sed "s/define('NONCE_KEY',\s*'\(.*\)'.*/\1/")
    echo
    echo "$ sed -i \"/^define('NONCE_KEY'/c\\define('NONCE_KEY', '\$key');\" $PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    sed -i "/^define('NONCE_KEY'/c\define('NONCE_KEY', '$key');" $PROJDIR/src/wordpress/wp-config.php
    echo
    echo "$ key=\$(grep \"define('AUTH_SALT',\" $PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('AUTH_SALT',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    key=$(grep "define('AUTH_SALT'," $PROJDIR/src/wordpress/wp-config-salt.php | sed "s/define('AUTH_SALT',\s*'\(.*\)'.*/\1/")
    echo
    echo "$ sed -i \"/^define('AUTH_SALT'/c\\define('AUTH_SALT', '\$key');\" $PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    sed -i "/^define('AUTH_SALT'/c\define('AUTH_SALT', '$key');" $PROJDIR/src/wordpress/wp-config.php
    echo
    echo "$ key=\$(grep \"define('SECURE_AUTH_SALT',\" $PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('SECURE_AUTH_SALT',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    key=$(grep "define('SECURE_AUTH_SALT'," $PROJDIR/src/wordpress/wp-config-salt.php | sed "s/define('SECURE_AUTH_SALT',\s*'\(.*\)'.*/\1/")
    echo
    echo "$ sed -i \"/^define('SECURE_AUTH_SALT'/c\\define('SECURE_AUTH_SALT', '\$key');\" $PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    sed -i "/^define('SECURE_AUTH_SALT'/c\define('SECURE_AUTH_SALT', '$key');" $PROJDIR/src/wordpress/wp-config.php
    echo
    echo "$ key=\$(grep \"define('LOGGED_IN_SALT',\" $PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('LOGGED_IN_SALT',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    key=$(grep "define('LOGGED_IN_SALT'," $PROJDIR/src/wordpress/wp-config-salt.php | sed "s/define('LOGGED_IN_SALT',\s*'\(.*\)'.*/\1/")
    echo
    echo "$ sed -i \"/^define('LOGGED_IN_SALT'/c\\define('LOGGED_IN_SALT', '\$key');\" $PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    sed -i "/^define('LOGGED_IN_SALT'/c\define('LOGGED_IN_SALT', '$key');" $PROJDIR/src/wordpress/wp-config.php
    echo
    echo "$ key=\$(grep \"define('NONCE_SALT',\" $PROJDIR/src/wordpress/wp-config-salt.php | sed \"s/define('NONCE_SALT',\\s*'\\(.*\\)'.*/\\1/\") # to get key" | pv -qL 100
    key=$(grep "define('NONCE_SALT'," $PROJDIR/src/wordpress/wp-config-salt.php | sed "s/define('NONCE_SALT',\s*'\(.*\)'.*/\1/")
    echo
    echo "$ sed -i \"/^define('NONCE_SALT'/c\\define('NONCE_SALT', '\$key');\" $PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    sed -i "/^define('NONCE_SALT'/c\define('NONCE_SALT', '$key');" $PROJDIR/src/wordpress/wp-config.php
    echo
    echo "$ cat <<EOF > $PROJDIR/src/Dockerfile
# See https://hub.docker.com/_/wordpress/ for the latest
FROM wordpress:6.1.1-php8.0-apache 
EXPOSE 8080
# Use the PORT environment variable in Apache configuration files.
RUN sed -i 's/80/\${PORT}/g' /etc/apache2/sites-available/000-default.conf /etc/apache2/ports.conf 
# Update packages
RUN apt-get update -y && apt-get clean
# wordpress conf
COPY wordpress/wp-config.php /var/www/html/wp-config.php 
# copy themes
COPY themes /usr/src/wordpress/wp-content/themes/ 
# copy plugins
COPY plugins /usr/src/wordpress/wp-content/plugins/ 
# copy uploads
COPY plugins /usr/src/wordpress/wp-content/uploads/ 
# download and install cloud_sql_proxy
RUN apt-get update && apt-get -y install net-tools wget && wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O /usr/local/bin/cloud_sql_proxy && chmod +x /usr/local/bin/cloud_sql_proxy
# custom entrypoint
COPY wordpress/cloud-run-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/cloud-run-entrypoint.sh
ENTRYPOINT [\"cloud-run-entrypoint.sh\",\"docker-entrypoint.sh\"]
CMD [\"apache2-foreground\"]
EOF" | pv -qL 100
    cat <<EOF > $PROJDIR/src/Dockerfile
FROM wordpress:6.1.1-php8.0-apache 
EXPOSE 8080
# Use the PORT environment variable in Apache configuration files.
RUN sed -i 's/80/\${PORT}/g' /etc/apache2/sites-available/000-default.conf /etc/apache2/ports.conf 
# Update packages
RUN apt-get update -y && apt-get clean
# wordpress conf
COPY wordpress/wp-config.php /var/www/html/wp-config.php 
# copy themes
COPY themes /usr/src/wordpress/wp-content/themes/ 
# copy plugins
COPY plugins /usr/src/wordpress/wp-content/plugins/
# copy uploads
COPY plugins /usr/src/wordpress/wp-content/uploads/ 
# download and install cloud_sql_proxy
RUN apt-get update && apt-get -y install net-tools wget && wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O /usr/local/bin/cloud_sql_proxy && chmod +x /usr/local/bin/cloud_sql_proxy
# custom entrypoint
COPY wordpress/cloud-run-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/cloud-run-entrypoint.sh
ENTRYPOINT ["cloud-run-entrypoint.sh","docker-entrypoint.sh"]
CMD ["apache2-foreground"]
EOF
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"
    echo
    echo "*** Nothing to delete ***"
else
    export STEP="${STEP},6i"   
    echo
    echo " 1. Create application artifacts" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"7")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},7i"   
    echo
    echo "$ gcloud iam service-accounts create gcp-cloudrun-sa # to create service account" | pv -qL 100
    echo
    echo "$ export CLOUDRUN_SA=\"gcp-cloudrun-sa@\$GCP_PROJECT.iam.gserviceaccount.com\" # to set service account" | pv -qL 100
    echo
    echo "$ mkdir -p \$PROJDIR/cicd # to create directory" | pv -qL 100
    echo
    echo "$ cat <<EOF > \$PROJDIR/cicd/deploy-dev.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: \${APPLICATION_NAME}-dev
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/binary-authorization: default
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/sessionAffinity: 'true'
        run.googleapis.com/vpc-access-egress: all-traffic
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/cloudsql-instances: \${GCP_PROJECT}:\${GCP_REGION}:\${DB_INSTANCE}
        run.googleapis.com/vpc-access-connector: projects/\${GCP_PROJECT}/locations/\${GCP_REGION}/connectors/serverless-vpc-connector
#        run.googleapis.com/cpu-throttling: 'true'
        run.googleapis.com/startup-cpu-boost: 'true'
        autoscaling.knative.dev/minScale: '\$APPLICATION_MIN_INSTANCES'
        autoscaling.knative.dev/maxScale: '\$APPLICATION_MAX_INSTANCES'
    spec:
      serviceAccountName: \$CLOUDRUN_SA
      containers:
      - image: app
        ports:
        - name: http1
          containerPort: 80
        env:
        - name: DB_USER
          value: \$DB_NAME
        - name: DB_NAME
          value: \$DB_NAME
        - name: DB_HOST
          value: \$DB_HOST
        - name: DB_CONNECTION
          value: \${GCP_PROJECT}:\${GCP_REGION}:\${DB_INSTANCE}
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              key: latest
              name: \${GCP_PROJECT}-\${DB_INSTANCE}-\${DB_NAME}-password
        resources:
          limits:
            cpu: 1000m
            memory: 1024Mi
  traffic:
  - percent: 100
    latestRevision: true
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF > \$PROJDIR/cicd/deploy-qa.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: \${APPLICATION_NAME}-dev
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/binary-authorization: default
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/sessionAffinity: 'true'
        run.googleapis.com/vpc-access-egress: all-traffic
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/cloudsql-instances: \${GCP_PROJECT}:\${GCP_REGION}:\${DB_INSTANCE}
        run.googleapis.com/vpc-access-connector: projects/\${GCP_PROJECT}/locations/\${GCP_REGION}/connectors/serverless-vpc-connector
#        run.googleapis.com/cpu-throttling: 'true'
        run.googleapis.com/startup-cpu-boost: 'true'
        autoscaling.knative.dev/minScale: '\$APPLICATION_MIN_INSTANCES'
        autoscaling.knative.dev/maxScale: '\$APPLICATION_MAX_INSTANCES'
    spec:
      serviceAccountName: \$CLOUDRUN_SA
      containers:
      - image: app
        ports:
        - name: http1
          containerPort: 80
        env:
        - name: DB_USER
          value: \$DB_NAME
        - name: DB_NAME
          value: \$DB_NAME
        - name: DB_HOST
          value: \$DB_HOST
        - name: DB_CONNECTION
          value: \${GCP_PROJECT}:\${GCP_REGION}:\${DB_INSTANCE}
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              key: latest
              name: \${GCP_PROJECT}-\${DB_INSTANCE}-\${DB_NAME}-password
        resources:
          limits:
            cpu: 1000m
            memory: 1024Mi
  traffic:
  - percent: 100
    latestRevision: true
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF > \$PROJDIR/cicd/deploy-prod.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: \${APPLICATION_NAME}-dev
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/binary-authorization: default
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/sessionAffinity: 'true'
        run.googleapis.com/vpc-access-egress: all-traffic
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/cloudsql-instances: \${GCP_PROJECT}:\${GCP_REGION}:\${DB_INSTANCE}
        run.googleapis.com/vpc-access-connector: projects/\${GCP_PROJECT}/locations/\${GCP_REGION}/connectors/serverless-vpc-connector
#        run.googleapis.com/cpu-throttling: 'true'
        run.googleapis.com/startup-cpu-boost: 'true'
        autoscaling.knative.dev/minScale: '\$APPLICATION_MIN_INSTANCES'
        autoscaling.knative.dev/maxScale: '\$APPLICATION_MAX_INSTANCES'
    spec:
      serviceAccountName: \$CLOUDRUN_SA
      containers:
      - image: app
        ports:
        - name: http1
          containerPort: 80
        env:
        - name: DB_USER
          value: \$DB_NAME
        - name: DB_NAME
          value: \$DB_NAME
        - name: DB_HOST
          value: \$DB_HOST
        - name: DB_CONNECTION
          value: \${GCP_PROJECT}:\${GCP_REGION}:\${DB_INSTANCE}
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              key: latest
              name: \${GCP_PROJECT}-\${DB_INSTANCE}-\${DB_NAME}-password
        resources:
          limits:
            cpu: 1000m
            memory: 1024Mi
  traffic:
  - percent: 100
    latestRevision: true
EOF" | pv -qL 100
    echo
    echo "$ cat <<SKAFFOLD > \$PROJDIR/cicd/skaffold.yaml
apiVersion: skaffold/v3alpha1
kind: Config
metadata: 
  name: \${APPLICATION_NAME}-config
build:
  tagPolicy:
    sha256: {}
  artifacts:
  - image: \$APPLICATION_IMAGE_URL
  googleCloudBuild:
    projectId: \$GCP_PROJECT
profiles:
- name: dev
  manifests:
    rawYaml:
    - deploy-dev.yaml
- name: qa
  manifests:
    rawYaml:
    - deploy-qa.yaml
- name: prod
  manifests:
    rawYaml:
    - deploy-prod.yaml
deploy:
  cloudrun: {}
SKAFFOLD" | pv -qL 100
        echo
        echo "$ cat <<EOF > \$PROJDIR/cicd/clouddeploy.yaml
apiVersion: deploy.cloud.google.com/v1
kind: DeliveryPipeline
metadata:
 name: \${APPLICATION_NAME}-cloudrun-delivery
description: application deployment pipeline
serialPipeline:
 stages:
 - targetId: dev-env
   profiles: [dev]
 - targetId: qa-env
   profiles: [qa]
 - targetId: prod-env
   profiles: [prod]
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: dev-env
description: Cloud Run development service
run:
 location: projects/\$GCP_PROJECT/locations/\$GCP_REGION
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: qa-env
description: Cloud Run QA service
run:
 location: projects/\$GCP_PROJECT/locations/\$GCP_REGION
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: prod-env
description: Cloud Run PROD service
requireApproval: true
run:
 location: projects/\$GCP_PROJECT/locations/\$GCP_REGION
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF > \$PROJDIR/cicd/cloudbuild.yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    id: Build
    args: ['build', '-t', '\$APPLICATION_IMAGE_URL:latest', '-t', '\$APPLICATION_IMAGE_URL:\$SHORT_SHA', '.']
  - name: 'gcr.io/cloud-builders/docker'
    id: Push
    args: ['push', '\$APPLICATION_IMAGE_URL']
  - name: 'gcr.io/k8s-skaffold/skaffold:v2.1.0'
    args:
      [
      'skaffold','build', '--interactive=false', '--file-output=/workspace/artifacts.json'
      ]
    id: Build and package app
  - name: 'gcr.io/\${GCP_PROJECT}/binauthz-attestation:latest'
    args:
      - '--artifact-url'
      - '\${APPLICATION_IMAGE_URL}'
      - '--attestor'
      - '\$ATTESTOR_NAME'
      - '--attestor-project'
      - '\$GCP_PROJECT'
      - '--keyversion'
      - '\$KMS_KEY_VERSION'
      - '--keyversion-project'
      - '\$GCP_PROJECT'
      - '--keyversion-location'
      - '\$GCP_REGION'
      - '--keyversion-keyring'
      - '\$KMS_KEYRING_NAME'
      - '--keyversion-key'
      - '\$KMS_KEY_NAME'
      - '--keyversion'
      - '\$KMS_KEY_VERSION'
  - name: gcr.io/google.com/cloudsdktool/cloud-sdk
    entrypoint: gcloud
    args: 
      [
        \"deploy\", \"releases\", \"create\", \"release-\$SHORT_SHA\",\"--delivery-pipeline\", \"\${APPLICATION_NAME}-cloudrun-delivery\",\"--region\", \"\$GCP_REGION\",\"--images\", \"app=\$APPLICATION_IMAGE_URL:latest\"
      ]
images: 
- '\$APPLICATION_IMAGE_URL:latest'
- '\$APPLICATION_IMAGE_URL:\$SHORT_SHA'
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF > \$PROJDIR/cicd/.dockerignore
Dockerfile
README.md
node_modules
npm-debug.log
deploy-dev.yaml
deploy-qa.yaml
deploy-prod.yaml
skaffold.yaml
clouddeploy.yaml
cloudbuild.yaml
EOF" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},7"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    export DB_HOST=$(gcloud --project $GCP_PROJECT sql instances describe $DB_INSTANCE --format 'value(ipAddresses[0].ipAddress)')
    gcloud iam service-accounts delete gcp-cloudrun-sa @$GCP_PROJECT.iam.gserviceaccount.com --quiet 2>/dev/null
    sleep 3
    echo
    echo "$ gcloud iam service-accounts create gcp-cloudrun-sa # to create service account" | pv -qL 100
    gcloud iam service-accounts create gcp-cloudrun-sa 2>/dev/null
    echo
    echo "$ export CLOUDRUN_SA=\"gcp-cloudrun-sa@$GCP_PROJECT.iam.gserviceaccount.com\" # to set service account" | pv -qL 100
    export CLOUDRUN_SA="gcp-cloudrun-sa@$GCP_PROJECT.iam.gserviceaccount.com"
    echo
    echo "$ gcloud -q projects add-iam-policy-binding $GCP_PROJECT --condition=None --member=serviceAccount:$CLOUDRUN_SA --role=\"roles/secretmanager.secretAccessor\" # to grant role" | pv -qL 100
    echo
    gcloud -q projects add-iam-policy-binding $GCP_PROJECT --condition=None --member=serviceAccount:$CLOUDRUN_SA --role="roles/secretmanager.secretAccessor" | pv -qL 100
    echo
    echo "$ mkdir -p $PROJDIR/cicd # to create directory" | pv -qL 100
    mkdir -p $PROJDIR/cicd
    echo
    export DB_NAME=${APPLICATION_NAME}_dev
    echo "$ cat <<EOF > $PROJDIR/cicd/deploy-dev.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${APPLICATION_NAME}-dev
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/binary-authorization: default
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/sessionAffinity: 'true'
        run.googleapis.com/vpc-access-egress: all-traffic
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/vpc-access-connector: projects/${GCP_PROJECT}/locations/${GCP_REGION}/connectors/serverless-vpc-connector
        run.googleapis.com/cloudsql-instances: ${GCP_PROJECT}:${GCP_REGION}:${DB_INSTANCE}
#        run.googleapis.com/cpu-throttling: 'true'
        run.googleapis.com/startup-cpu-boost: 'true'
        autoscaling.knative.dev/minScale: '$APPLICATION_MIN_INSTANCES'
        autoscaling.knative.dev/maxScale: '$APPLICATION_MAX_INSTANCES'
    spec:
      serviceAccountName: $CLOUDRUN_SA
      containers:
      - image: app
        ports:
        - name: http1
          containerPort: 80
        env:
        - name: DB_USER
          value: $DB_NAME
        - name: DB_NAME
          value: $DB_NAME
        - name: DB_HOST
          value: $DB_HOST
        - name: DB_CONNECTION
          value: ${GCP_PROJECT}:${GCP_REGION}:${DB_INSTANCE}
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              key: latest
              name: ${GCP_PROJECT}-${DB_INSTANCE}-${DB_NAME}-password
        resources:
          limits:
            cpu: 1000m
            memory: 1024Mi
  traffic:
  - percent: 100
    latestRevision: true
EOF" | pv -qL 100
    cat <<EOF > $PROJDIR/cicd/deploy-dev.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${APPLICATION_NAME}-dev
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/binary-authorization: default
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/sessionAffinity: 'true'
        run.googleapis.com/vpc-access-egress: all-traffic
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/vpc-access-connector: projects/${GCP_PROJECT}/locations/${GCP_REGION}/connectors/serverless-vpc-connector
        run.googleapis.com/cloudsql-instances: ${GCP_PROJECT}:${GCP_REGION}:${DB_INSTANCE}
#        run.googleapis.com/cpu-throttling: 'true'
        run.googleapis.com/startup-cpu-boost: 'true'
        autoscaling.knative.dev/minScale: '$APPLICATION_MIN_INSTANCES'
        autoscaling.knative.dev/maxScale: '$APPLICATION_MAX_INSTANCES'
    spec:
      serviceAccountName: $CLOUDRUN_SA
      containers:
      - image: app
        ports:
        - name: http1
          containerPort: 80
        env:
        - name: DB_USER
          value: $DB_NAME
        - name: DB_NAME
          value: $DB_NAME
        - name: DB_HOST
          value: $DB_HOST
        - name: DB_CONNECTION
          value: ${GCP_PROJECT}:${GCP_REGION}:${DB_INSTANCE}
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              key: latest
              name: ${GCP_PROJECT}-${DB_INSTANCE}-${DB_NAME}-password
        resources:
          limits:
            cpu: 1000m
            memory: 1024Mi
  traffic:
  - percent: 100
    latestRevision: true
EOF
    echo
    export DB_NAME=${APPLICATION_NAME}_qa
    echo "$ cat <<EOF > $PROJDIR/cicd/deploy-qa.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${APPLICATION_NAME}-dev
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/binary-authorization: default
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/sessionAffinity: 'true'
        run.googleapis.com/vpc-access-egress: all-traffic
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/vpc-access-connector: projects/${GCP_PROJECT}/locations/${GCP_REGION}/connectors/serverless-vpc-connector
        run.googleapis.com/cloudsql-instances: ${GCP_PROJECT}:${GCP_REGION}:${DB_INSTANCE}
#        run.googleapis.com/cpu-throttling: 'true'
        run.googleapis.com/startup-cpu-boost: 'true'
        autoscaling.knative.dev/minScale: '$APPLICATION_MIN_INSTANCES'
        autoscaling.knative.dev/maxScale: '$APPLICATION_MAX_INSTANCES'
    spec:
      serviceAccountName: $CLOUDRUN_SA
      containers:
      - image: app
        ports:
        - name: http1
          containerPort: 80
        env:
        - name: DB_USER
          value: $DB_NAME
        - name: DB_NAME
          value: $DB_NAME
        - name: DB_HOST
          value: $DB_HOST
        - name: DB_CONNECTION
          value: ${GCP_PROJECT}:${GCP_REGION}:${DB_INSTANCE}
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              key: latest
              name: ${GCP_PROJECT}-${DB_INSTANCE}-${DB_NAME}-password
        resources:
          limits:
            cpu: 1000m
            memory: 1024Mi
  traffic:
  - percent: 100
    latestRevision: true
EOF" | pv -qL 100
    cat <<EOF > $PROJDIR/cicd/deploy-qa.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${APPLICATION_NAME}-dev
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/binary-authorization: default
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/sessionAffinity: 'true'
        run.googleapis.com/vpc-access-egress: all-traffic
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/cloudsql-instances: ${GCP_PROJECT}:${GCP_REGION}:${DB_INSTANCE}
        run.googleapis.com/vpc-access-connector: projects/${GCP_PROJECT}/locations/${GCP_REGION}/connectors/serverless-vpc-connector
#        run.googleapis.com/cpu-throttling: 'true'
        run.googleapis.com/startup-cpu-boost: 'true'
        autoscaling.knative.dev/minScale: '$APPLICATION_MIN_INSTANCES'
        autoscaling.knative.dev/maxScale: '$APPLICATION_MAX_INSTANCES'
    spec:
      serviceAccountName: $CLOUDRUN_SA
      containers:
      - image: app
        ports:
        - name: http1
          containerPort: 80
        env:
        - name: DB_USER
          value: $DB_NAME
        - name: DB_NAME
          value: $DB_NAME
        - name: DB_HOST
          value: $DB_HOST
        - name: DB_CONNECTION
          value: ${GCP_PROJECT}:${GCP_REGION}:${DB_INSTANCE}
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              key: latest
              name: ${GCP_PROJECT}-${DB_INSTANCE}-${DB_NAME}-password
        resources:
          limits:
            cpu: 1000m
            memory: 1024Mi
  traffic:
  - percent: 100
    latestRevision: true
EOF
    echo
    export DB_NAME=${APPLICATION_NAME}_prod
    echo "$ cat <<EOF > $PROJDIR/cicd/deploy-prod.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${APPLICATION_NAME}-dev
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/binary-authorization: default
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/sessionAffinity: 'true'
        run.googleapis.com/vpc-access-egress: all-traffic
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/cloudsql-instances: ${GCP_PROJECT}:${GCP_REGION}:${DB_INSTANCE}
        run.googleapis.com/vpc-access-connector: projects/${GCP_PROJECT}/locations/${GCP_REGION}/connectors/serverless-vpc-connector
#        run.googleapis.com/cpu-throttling: 'true'
        run.googleapis.com/startup-cpu-boost: 'true'
        autoscaling.knative.dev/minScale: '$APPLICATION_MIN_INSTANCES'
        autoscaling.knative.dev/maxScale: '$APPLICATION_MAX_INSTANCES'
    spec:
      serviceAccountName: $CLOUDRUN_SA
      containers:
      - image: app
        ports:
        - name: http1
          containerPort: 80
        env:
        - name: DB_USER
          value: $DB_NAME
        - name: DB_NAME
          value: $DB_NAME
        - name: DB_HOST
          value: $DB_HOST
        - name: DB_CONNECTION
          value: ${GCP_PROJECT}:${GCP_REGION}:${DB_INSTANCE}
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              key: latest
              name: ${GCP_PROJECT}-${DB_INSTANCE}-${DB_NAME}-password
        resources:
          limits:
            cpu: 1000m
            memory: 1024Mi
  traffic:
  - percent: 100
    latestRevision: true
EOF" | pv -qL 100
    cat <<EOF > $PROJDIR/cicd/deploy-prod.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${APPLICATION_NAME}-dev
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/binary-authorization: default
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/sessionAffinity: 'true'
        run.googleapis.com/vpc-access-egress: all-traffic
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/cloudsql-instances: ${GCP_PROJECT}:${GCP_REGION}:${DB_INSTANCE}
        run.googleapis.com/vpc-access-connector: projects/${GCP_PROJECT}/locations/${GCP_REGION}/connectors/serverless-vpc-connector
#        run.googleapis.com/cpu-throttling: 'true'
        run.googleapis.com/startup-cpu-boost: 'true'
        autoscaling.knative.dev/minScale: '$APPLICATION_MIN_INSTANCES'
        autoscaling.knative.dev/maxScale: '$APPLICATION_MAX_INSTANCES'
    spec:
      serviceAccountName: $CLOUDRUN_SA
      containers:
      - image: app
        ports:
        - name: http1
          containerPort: 80
        env:
        - name: DB_USER
          value: $DB_NAME
        - name: DB_NAME
          value: $DB_NAME
        - name: DB_HOST
          value: $DB_HOST
        - name: DB_CONNECTION
          value: ${GCP_PROJECT}:${GCP_REGION}:${DB_INSTANCE}
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              key: latest
              name: ${GCP_PROJECT}-${DB_INSTANCE}-${DB_NAME}-password
        resources:
          limits:
            cpu: 1000m
            memory: 1024Mi
  traffic:
  - percent: 100
    latestRevision: true
EOF
    echo
    echo "$ cat <<SKAFFOLD > $PROJDIR/cicd/skaffold.yaml
apiVersion: skaffold/v3alpha1
kind: Config
metadata: 
  name: ${APPLICATION_NAME}-config
build:
  tagPolicy:
    sha256: {}
  artifacts:
  - image: $APPLICATION_IMAGE_URL
  googleCloudBuild:
    projectId: $GCP_PROJECT
profiles:
- name: dev
  manifests:
    rawYaml:
    - deploy-dev.yaml
- name: qa
  manifests:
    rawYaml:
    - deploy-qa.yaml
- name: prod
  manifests:
    rawYaml:
    - deploy-prod.yaml
deploy:
  cloudrun: {}
SKAFFOLD" | pv -qL 100
cat <<SKAFFOLD > $PROJDIR/cicd/skaffold.yaml
apiVersion: skaffold/v3alpha1
kind: Config
metadata: 
  name: ${APPLICATION_NAME}-config
build:
  tagPolicy:
    sha256: {}
  artifacts:
  - image: $APPLICATION_IMAGE_URL
  googleCloudBuild:
    projectId: $GCP_PROJECT
profiles:
- name: dev
  manifests:
    rawYaml:
    - deploy-dev.yaml
- name: qa
  manifests:
    rawYaml:
    - deploy-qa.yaml
- name: prod
  manifests:
    rawYaml:
    - deploy-prod.yaml
deploy:
  cloudrun: {}
SKAFFOLD
        echo
        echo "$ cat <<EOF > $PROJDIR/cicd/clouddeploy.yaml
apiVersion: deploy.cloud.google.com/v1
kind: DeliveryPipeline
metadata:
 name: ${APPLICATION_NAME}-cloudrun-delivery
description: application deployment pipeline
serialPipeline:
 stages:
 - targetId: dev-env
   profiles: [dev]
 - targetId: qa-env
   profiles: [qa]
 - targetId: prod-env
   profiles: [prod]
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: dev-env
description: Cloud Run development service
run:
 location: projects/$GCP_PROJECT/locations/$GCP_REGION
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: qa-env
description: Cloud Run QA service
run:
 location: projects/$GCP_PROJECT/locations/$GCP_REGION
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: prod-env
description: Cloud Run PROD service
requireApproval: true
run:
 location: projects/$GCP_PROJECT/locations/$GCP_REGION
EOF" | pv -qL 100
        cat <<EOF > $PROJDIR/cicd/clouddeploy.yaml
apiVersion: deploy.cloud.google.com/v1
kind: DeliveryPipeline
metadata:
 name: ${APPLICATION_NAME}-cloudrun-delivery
description: application deployment pipeline
serialPipeline:
 stages:
 - targetId: dev-env
   profiles: [dev]
 - targetId: qa-env
   profiles: [qa]
 - targetId: prod-env
   profiles: [prod]
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: dev-env
description: Cloud Run development service
run:
 location: projects/$GCP_PROJECT/locations/$GCP_REGION
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: qa-env
description: Cloud Run QA service
run:
 location: projects/$GCP_PROJECT/locations/$GCP_REGION
---
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
 name: prod-env
description: Cloud Run PROD service
requireApproval: true
run:
 location: projects/$GCP_PROJECT/locations/$GCP_REGION
EOF
    export RELEASE_TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
    echo
    echo "$ cat <<EOF > $PROJDIR/cicd/cloudbuild.yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    id: Build
    args: ['build', '-t', '$APPLICATION_IMAGE_URL:latest', '-t', '$APPLICATION_IMAGE_URL:\$SHORT_SHA', '.']
  - name: 'gcr.io/cloud-builders/docker'
    id: Push
    args: ['push', '$APPLICATION_IMAGE_URL']
  - name: 'gcr.io/k8s-skaffold/skaffold:v2.1.0'
    args:
      [
      'skaffold','build', '--interactive=false', '--file-output=/workspace/artifacts.json'
      ]
    id: Build and package app
  - name: 'gcr.io/${GCP_PROJECT}/binauthz-attestation:latest'
    args:
      - '--artifact-url'
      - '${APPLICATION_IMAGE_URL}'
      - '--attestor'
      - '$ATTESTOR_NAME'
      - '--attestor-project'
      - '$GCP_PROJECT'
      - '--keyversion'
      - '$KMS_KEY_VERSION'
      - '--keyversion-project'
      - '$GCP_PROJECT'
      - '--keyversion-location'
      - '$GCP_REGION'
      - '--keyversion-keyring'
      - '$KMS_KEYRING_NAME'
      - '--keyversion-key'
      - '$KMS_KEY_NAME'
      - '--keyversion'
      - '$KMS_KEY_VERSION'
  - name: gcr.io/google.com/cloudsdktool/cloud-sdk
    entrypoint: gcloud
    args: 
      [
        \"deploy\", \"releases\", \"create\", \"release-\$SHORT_SHA\",\"--delivery-pipeline\", \"${APPLICATION_NAME}-cloudrun-delivery\",\"--region\", \"$GCP_REGION\",\"--images\", \"app=$APPLICATION_IMAGE_URL:latest\"
      ]
images: 
- '$APPLICATION_IMAGE_URL:latest'
- '$APPLICATION_IMAGE_URL:\$SHORT_SHA'
EOF" | pv -qL 100
    cat <<EOF > $PROJDIR/cicd/cloudbuild.yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    id: Build
    args: ['build', '-t', '$APPLICATION_IMAGE_URL:latest', '-t', '$APPLICATION_IMAGE_URL:\$SHORT_SHA', '.']
  - name: 'gcr.io/cloud-builders/docker'
    id: Push
    args: ['push', '$APPLICATION_IMAGE_URL']
  - name: 'gcr.io/k8s-skaffold/skaffold:v2.1.0'
    args:
      [
      'skaffold','build', '--interactive=false', '--file-output=/workspace/artifacts.json'
      ]
    id: Build and package app
  - name: 'gcr.io/${GCP_PROJECT}/binauthz-attestation:latest'
    args:
      - '--artifact-url'
      - '${APPLICATION_IMAGE_URL}'
      - '--attestor'
      - '$ATTESTOR_NAME'
      - '--attestor-project'
      - '$GCP_PROJECT'
      - '--keyversion'
      - '$KMS_KEY_VERSION'
      - '--keyversion-project'
      - '$GCP_PROJECT'
      - '--keyversion-location'
      - '$GCP_REGION'
      - '--keyversion-keyring'
      - '$KMS_KEYRING_NAME'
      - '--keyversion-key'
      - '$KMS_KEY_NAME'
      - '--keyversion'
      - '$KMS_KEY_VERSION'
  - name: gcr.io/google.com/cloudsdktool/cloud-sdk
    entrypoint: gcloud
    args: 
      [
        "deploy", "releases", "create", "release-\$SHORT_SHA","--delivery-pipeline", "${APPLICATION_NAME}-cloudrun-delivery","--region", "$GCP_REGION","--images", "app=$APPLICATION_IMAGE_URL:latest"
      ]
images: 
- '$APPLICATION_IMAGE_URL:latest'
- '$APPLICATION_IMAGE_URL:\$SHORT_SHA'
EOF
    echo
    echo "$ cat <<EOF > $PROJDIR/cicd/.dockerignore
Dockerfile
README.md
node_modules
npm-debug.log
deploy-dev.yaml
deploy-qa.yaml
deploy-prod.yaml
skaffold.yaml
clouddeploy.yaml
cloudbuild.yaml
EOF" | pv -qL 100
    cat <<EOF > $PROJDIR/cicd/.dockerignore
Dockerfile
README.md
node_modules
npm-debug.log
deploy-dev.yaml
deploy-qa.yaml
deploy-prod.yaml
skaffold.yaml
clouddeploy.yaml
cloudbuild.yaml
EOF
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},7x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},7i"   
    echo
    echo " 1. Create CI/CD artifacts" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"8")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},8i"   
    echo
    echo "$ export CLOUDRUN_SA=\"gcp-cloudrun-sa@\$GCP_PROJECT.iam.gserviceaccount.com\" # to set service account" | pv -qL 100
    echo
    echo "$ export CLOUDBUILD_SA=\"\${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com\" # to set service account" | pv -qL 100
    echo
    echo "$ gcloud -q projects add-iam-policy-binding \$GCP_PROJECT --condition=None --member=serviceAccount:\$CLOUDRUN_SA --role=\"roles/secretmanager.secretAccessor\" # to grant role" | pv -qL 100
    echo
    echo "$ gcloud -q projects add-iam-policy-binding \$GCP_PROJECT --condition=None --member=serviceAccount:\$CLOUDRUN_SA --role=\"roles/run.developer\" # to grant role" | pv -qL 100
    echo
    echo
    echo "$ gcloud -q projects add-iam-policy-binding \$GCP_PROJECT --condition=None --member=serviceAccount:\$CLOUDBUILD_SA --role=\"roles/clouddeploy.operator\" # to grant role" | pv -qL 100
    echo
    echo "$ gcloud -q iam service-accounts add-iam-policy-binding \$CLOUDRUN_SA --member=\$(gcloud config get-value core/account) --role=roles/iam.serviceAccountUser --project=\$GCP_PROJECT # to assign role" | pv -qL 100
    echo
    echo "$ gcloud -q iam service-accounts add-iam-policy-binding \$CLOUDRUN_SA --member=serviceAccount:\$CLOUDBUILD_SA --role=roles/iam.serviceAccountUser --project=\$GCP_PROJECT # to assign role" | pv -qL 100
    echo
    echo "$ git config --global credential.https://source.developers.google.com.helper gcloud. # to cinfigure git" | pv -qL 100
    echo    
    echo "$ git config --global user.email \"\$(gcloud config get-value core/account)\" # to set email" | pv -qL 100
    echo
    echo "$ git config --global user.name \"Tech Equity\" # to set name" | pv -qL 100
    echo
    echo "$ git config --global init.defaultBranch main # to set default branch" | pv -qL 100
    echo 
    echo "$ gcloud source repos create \$APPLICATION_REPOSITORY # to create repo" | pv -qL 100
    echo
    echo "$ gcloud source repos clone \$APPLICATION_REPOSITORY --project \$GCP_PROJECT # to clone repo" | pv -qL 100
    echo
    echo "$ cd \$PROJDIR/\$APPLICATION_REPOSITORY # change to repo directory" | pv -qL 100
    echo
    echo "$ cp -r \$PROJDIR/src/* . > /dev/null 2>&1 # to copy application artifacts into repo" | pv -qL 100
    echo
    echo "$ cp -r \$PROJDIR/cicd/* \$PROJDIR/cicd/.dockerignore . > /dev/null 2>&1 # to copy cicd artifacts into repo" | pv -qL 100
    echo
    echo "$ cp -r \$PROJDIR/cicd/*.yaml . # to copy yaml artifacts into repo" | pv -qL 100
    echo
    echo "$ gcloud beta builds triggers create cloud-source-repositories --project \$GCP_PROJECT --name=\"\${APPLICATION_NAME}-cloudrun-trigger\" --repo=\$APPLICATION_REPOSITORY --branch-pattern=main --build-config=cloudbuild.yaml # to configure trigger" | pv -qL 100
    echo
    echo "$ gcloud beta deploy apply --file clouddeploy.yaml --region=\$GCP_REGION --project=\$GCP_PROJECT # to configure clouddeploy" | pv -qL 100
    echo
    echo "$ git checkout -B main # to checkout branch" | pv -qL 100
    echo
    echo "$ git add . # to add files" | pv -qL 100
    echo
    echo "$ git commit -m \"Added Cloud Deploy and Cloud Build config files\" # to commit change" | pv -qL 100
    echo
    echo "$ git push origin main --force # to push to Github" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},8"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    PROJECT_NUMBER=$(gcloud --project $GCP_PROJECT projects describe $GCP_PROJECT --format="value(projectNumber)")
    echo
    echo "$ export CLOUDRUN_SA=\"gcp-cloudrun-sa@$GCP_PROJECT.iam.gserviceaccount.com\" # to set service account" | pv -qL 100
    export CLOUDRUN_SA="gcp-cloudrun-sa@$GCP_PROJECT.iam.gserviceaccount.com"
    echo
    echo "$ export CLOUDBUILD_SA=\"${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com\" # to set service account" | pv -qL 100
    export CLOUDBUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
    cd $PROJDIR
    echo
    echo "$ gcloud -q projects add-iam-policy-binding $GCP_PROJECT --condition=None --member=serviceAccount:$CLOUDRUN_SA --role=\"roles/secretmanager.secretAccessor\" # to grant role" | pv -qL 100
    echo
    gcloud -q projects add-iam-policy-binding $GCP_PROJECT --condition=None --member=serviceAccount:$CLOUDRUN_SA --role="roles/secretmanager.secretAccessor" | pv -qL 100
    echo
    echo "$ gcloud -q projects add-iam-policy-binding $GCP_PROJECT --condition=None --member=serviceAccount:$CLOUDRUN_SA --role=\"roles/run.developer\" # to grant role" | pv -qL 100
    echo
    gcloud -q projects add-iam-policy-binding $GCP_PROJECT --condition=None --member=serviceAccount:$CLOUDRUN_SA --role="roles/run.developer" | pv -qL 100
    echo
    echo "$ gcloud -q projects add-iam-policy-binding $GCP_PROJECT --condition=None --member=serviceAccount:$CLOUDBUILD_SA --role=\"roles/clouddeploy.operator\" # to grant role" | pv -qL 100
    gcloud -q projects add-iam-policy-binding $GCP_PROJECT --condition=None --member=serviceAccount:$CLOUDBUILD_SA --role="roles/clouddeploy.operator"
    echo
    echo "$ gcloud -q iam service-accounts add-iam-policy-binding $CLOUDRUN_SA --member=serviceAccount:$CLOUDBUILD_SA --role=roles/iam.serviceAccountUser --project=$GCP_PROJECT # to assign role" | pv -qL 100
    gcloud -q iam service-accounts add-iam-policy-binding $CLOUDRUN_SA --member=serviceAccount:$CLOUDBUILD_SA --role=roles/iam.serviceAccountUser --project=$GCP_PROJECT
    echo
    echo "$ gcloud -q iam service-accounts add-iam-policy-binding $CLOUDRUN_SA --member \"\$(gcloud config get-value core/account)\" --role=roles/iam.serviceAccountUser --project=$GCP_PROJECT # to assign role" | pv -qL 100
    gcloud -q iam service-accounts add-iam-policy-binding $CLOUDRUN_SA --member "$(gcloud config get-value core/account)" --role=roles/iam.serviceAccountUser --project=$GCP_PROJECT
    echo
    echo "$ git config --global credential.https://source.developers.google.com.helper gcloud. # to cinfigure git" | pv -qL 100
    git config --global credential.https://source.developers.google.com.helper gcloud.
    echo    
    echo "$ git config --global user.email \"\$(gcloud config get-value core/account)\" # to set email" | pv -qL 100
    git config --global user.email "$(gcloud config get-value core/account)"
    echo
    echo "$ git config --global user.name \"Tech Equity\" # to set name" | pv -qL 100
    git config --global user.name "Tech Equity"
    echo
    echo "$ git config --global init.defaultBranch main # to set default branch" | pv -qL 100
    git config --global init.defaultBranch main
    if [[ -z $APPLICATION_MIRRORED_REPOSITORY ]]; then
        export APPLICATION_REPOSITORY=$APPLICATION_NAME-cloudrun-repository
        echo 
        echo "$  gcloud source repos delete $APPLICATION_REPOSITORY --project $GCP_PROJECT --quiet # to delete repo"
        gcloud source repos delete $APPLICATION_REPOSITORY --project $GCP_PROJECT --quiet
        echo
        echo "$ gcloud source repos create $APPLICATION_REPOSITORY --project $GCP_PROJECT # to create repo" | pv -qL 100
        gcloud source repos create $APPLICATION_REPOSITORY --project $GCP_PROJECT > /dev/null 2>&1
        echo
        rm -rf $APPLICATION_REPOSITORY
        echo "$ gcloud source repos clone $APPLICATION_REPOSITORY --project $GCP_PROJECT # to clone repo" | pv -qL 100
        gcloud source repos clone $APPLICATION_REPOSITORY --project $GCP_PROJECT
        echo
        echo "$ cd $PROJDIR/$APPLICATION_REPOSITORY # change to repo directory" | pv -qL 100
        cd $PROJDIR/$APPLICATION_REPOSITORY 
    else 
        export APPLICATION_REPOSITORY=$APPLICATION_MIRRORED_REPOSITORY
        echo
        echo "$ ssh-keygen -t ed25519 -C \"\$(gcloud config get-value core/account)\" # to generate a key" | pv -qL 100
        ssh-keygen -t ed25519 -C "$(gcloud config get-value core/account)"
        echo
        echo "$ gh auth login # to authenticate" | pv -qL 100
        gh auth login
        # echo
        # echo "$ gh repo create --public ${scriptname} -y # to create repo" | pv -qL 100
        # gh repo create --public ${scriptname} -y
        echo
        echo "$ export GITHUB_REPOSITORY=\$(echo \"\$APPLICATION_GITHUB_REPOSITORY\" | cut -d \"/\" -f 2) # to get repo name" | pv -qL 100
        export GITHUB_REPOSITORY=$(echo "$APPLICATION_GITHUB_REPOSITORY" | cut -d "/" -f 2)
        echo
        rm -rf $GITHUB_REPOSITORY
        echo "$ gh repo clone $APPLICATION_GITHUB_REPOSITORY # to authenticate" | pv -qL 100
        gh repo clone $APPLICATION_GITHUB_REPOSITORY
        echo
        echo "$ cd $PROJDIR/$GITHUB_REPOSITORY # to change directory" | pv -qL 100
        cd $PROJDIR/$GITHUB_REPOSITORY
        echo
        echo "$ git config pull.rebase false # to set strategy" | pv -qL 100
        git config pull.rebase false
        echo
        echo "$ git reset --hard # to remove local changes" | pv -qL 100
        git reset --hard
        echo
        echo "$ git pull origin main --allow-unrelated-histories # to pull resources" | pv -qL 100
        git pull origin main --allow-unrelated-histories
    fi
    if [[ ! -z $APPLICATION_MIRRORED_REPOSITORY ]]; then # RETAINED TO TEST WITHOUT REPO MIRRORING
        cp -r $PROJDIR/${APPLICATION_REPOSITORY}-clone/* $PROJDIR/$APPLICATION_REPOSITORY > /dev/null 2>&1 
    fi
    if [[ -z $APPLICATION_MIRRORED_REPOSITORY ]]; then
        echo
        echo "$ cp -r $PROJDIR/src/* . > /dev/null 2>&1 # to copy application artifacts into repo" | pv -qL 100
        cp -r $PROJDIR/src/* . > /dev/null 2>&1 
        echo
        echo "$ cp -r $PROJDIR/cicd/* $PROJDIR/cicd/.dockerignore . > /dev/null 2>&1 # to copy cicd artifacts into repo" | pv -qL 100
        cp -r $PROJDIR/cicd/* $PROJDIR/cicd/.dockerignore . > /dev/null 2>&1 
    else 
        echo
        echo "$ cp -r $PROJDIR/cicd/*.yaml . # to copy yaml artifacts into repo" | pv -qL 100
        cp -r $PROJDIR/cicd/*.yaml .
    fi
    echo
    echo "$ gcloud beta builds triggers delete ${APPLICATION_NAME}-cloudrun-trigger --project $GCP_PROJECT --region $GCP_REGION --quiet # to delete trigger" | pv -qL 100
    gcloud beta builds triggers delete ${APPLICATION_NAME}-cloudrun-trigger --project $GCP_PROJECT --region $GCP_REGION --quiet
    echo
    echo "$ gcloud beta builds triggers create cloud-source-repositories --project $GCP_PROJECT --region $GCP_REGION --name=\"${APPLICATION_NAME}-cloudrun-trigger\" --repo=$APPLICATION_REPOSITORY --branch-pattern=main --build-config=cloudbuild.yaml # to configure trigger" | pv -qL 100
    gcloud beta builds triggers create cloud-source-repositories --project $GCP_PROJECT --region $GCP_REGION --name="${APPLICATION_NAME}-cloudrun-trigger" --repo=$APPLICATION_REPOSITORY --branch-pattern=main --build-config=cloudbuild.yaml
    echo
    echo "$ gcloud beta deploy apply --file clouddeploy.yaml --region=$GCP_REGION --project=$GCP_PROJECT # to configure clouddeploy" | pv -qL 100
    gcloud beta deploy apply --file clouddeploy.yaml --region=$GCP_REGION --project=$GCP_PROJECT
    sleep 30
    echo
    echo "$ git checkout -B main # to checkout branch" | pv -qL 100
    git checkout -B main
    echo
    echo "$ git add . # to add files" | pv -qL 100
    git add .
    echo
    echo "$ git commit -m \"Added Cloud Deploy and Cloud Build config files\" # to commit change" | pv -qL 100
    git commit -m "Added files"
    echo
    echo "$ git push origin main --force # to push to Github" | pv -qL 100
    git push origin main --force
    stty echo # to ensure input characters are echoed on terminal
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},8x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    PROJECT_NUMBER=$(gcloud --project $GCP_PROJECT projects describe $GCP_PROJECT --format="value(projectNumber)")
    export CLOUDRUN_SA="gcp-cloudrun-sa@$GCP_PROJECT.iam.gserviceaccount.com"
    export CLOUDBUILD_SA=${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
    if [[ -z $APPLICATION_MIRRORED_REPOSITORY ]]; then
        export APPLICATION_REPOSITORY=$APPLICATION_NAME
    else 
        export APPLICATION_REPOSITORY=$APPLICATION_MIRRORED_REPOSITORY
    fi
    echo
    echo "$ gcloud beta deploy delete --file $PROJDIR/$APPLICATION_REPOSITORY/clouddeploy.yaml --region=$GCP_REGION --project=$GCP_PROJECT --force # to delete configuration" | pv -qL 100
    gcloud beta deploy delete --file $PROJDIR/$APPLICATION_REPOSITORY/clouddeploy.yaml --region=$GCP_REGION --project=$GCP_PROJECT --force 
    echo
    echo "$ gcloud beta builds triggers delete ${APPLICATION_NAME}-cloudrun-trigger --project $GCP_PROJECT --region=$GCP_REGION # to delete trigger" | pv -qL 100
    gcloud beta builds triggers delete ${APPLICATION_NAME}-cloudrun-trigger --project $GCP_PROJECT --region=$GCP_REGION 
    echo
    echo "*** DO NOT DELETE REPO IF YOU INTEND TO RE-RUN THIS LAB. DELETED REPOS CANNOT BE REUSED WITHIN 7 DAYS ***" | pv -qL 100
    echo
    echo "$ gcloud source repos delete $APPLICATION_REPOSITORY --project $GCP_PROJECT --region=$GCP_REGION # to delete repo" | pv -qL 100
    gcloud source repos delete $APPLICATION_REPOSITORY --project $GCP_PROJECT --region=$GCP_REGION
    echo
    echo "$ gcloud -q iam service-accounts remove-iam-policy-binding $CLOUDRUN_SA --member=serviceAccount:$CLOUDBUILD_SA --role=roles/iam.serviceAccountUser --project=$GCP_PROJECT # to revoke role" | pv -qL 100
    gcloud -q iam service-accounts remove-iam-policy-binding $CLOUDRUN_SA --member=serviceAccount:$CLOUDBUILD_SA --role=roles/iam.serviceAccountUser --project=$GCP_PROJECT
    echo
    echo "$ gcloud -q projects remove-iam-policy-binding $GCP_PROJECT --condition=None --member=serviceAccount:$CLOUDBUILD_SA --role=\"roles/clouddeploy.operator\" # to revoke role" | pv -qL 100
    gcloud -q projects remove-iam-policy-binding $GCP_PROJECT --condition=None --member=serviceAccount:$CLOUDBUILD_SA --role="roles/clouddeploy.operator"
    echo
    echo "$ gcloud -q projects remove-iam-policy-binding $GCP_PROJECT --condition=None --member=serviceAccount:$CLOUDRUN_SA --role=\"roles/container.developer\" # to revoke role" | pv -qL 100
    echo
    gcloud -q projects remove-iam-policy-binding $GCP_PROJECT --condition=None --member=serviceAccount:$CLOUDRUN_SA --role="roles/container.developer" | pv -qL 100
else
    export STEP="${STEP},8i"   
    echo
    echo "1. Set service account" | pv -qL 100
    echo "2. Grant roles" | pv -qL 100
    echo "3. Configure git" | pv -qL 100
    echo "4. Set branch" | pv -qL 100
    echo "5. Create repo" | pv -qL 100
    echo "6. Configure trigger" | pv -qL 100
    echo "7. Configure clouddeploy" | pv -qL 100
    echo "8. Commit change" | pv -qL 100
    echo "9. Push change to main" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"9")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},9i"
    echo
    echo "$ gcloud beta run services add-iam-policy-binding \${APPLICATION_NAME}-dev --platform managed --region \$GCP_REGION --member=user:\$(gcloud config get-value core/account) --role roles/run.admin # to set role" | pv -qL 100
    echo
    echo "$ gcloud beta run services add-iam-policy-binding \${APPLICATION_NAME}-dev --platform managed --region \$GCP_REGION --member=allUsers --role roles/run.invoker # to set role" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT run services update \${APPLICATION_NAME}-dev --region \$GCP_REGION --vpc-connector serverless-vpc-connector --vpc-egress all-traffic # to use VPC connector"
    echo
    echo "$ gcloud --project \$GCP_PROJECT beta run services update \${APPLICATION_NAME}-dev --region \$GCP_REGION --session-affinity # to enable session affinity"
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},9"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud beta run services add-iam-policy-binding ${APPLICATION_NAME}-dev --platform managed --region $GCP_REGION --member=user:\$(gcloud config get-value core/account) --role roles/run.admin # to set role" | pv -qL 100
    gcloud beta run services add-iam-policy-binding ${APPLICATION_NAME}-dev --platform managed --region $GCP_REGION --member=user:$(gcloud config get-value core/account) --role roles/run.admin
    echo
    echo "$ gcloud beta run services add-iam-policy-binding ${APPLICATION_NAME}-dev --platform managed --region $GCP_REGION --member=allUsers --role roles/run.invoker # to set role" | pv -qL 100
    gcloud beta run services add-iam-policy-binding ${APPLICATION_NAME}-dev --platform managed --region $GCP_REGION --member=allUsers --role roles/run.invoker
    echo
    echo "$ gcloud --project $GCP_PROJECT run services update ${APPLICATION_NAME}-dev --region $GCP_REGION --vpc-connector serverless-vpc-connector --vpc-egress all-traffic # to use VPC connector"
    gcloud --project $GCP_PROJECT run services update ${APPLICATION_NAME}-dev --region $GCP_REGION --vpc-connector serverless-vpc-connector --vpc-egress all-traffic
    echo
    echo "$ gcloud --project $GCP_PROJECT beta run services update ${APPLICATION_NAME}-dev --region $GCP_REGION --session-affinity # to enable session affinity"
    gcloud --project $GCP_PROJECT beta run services update ${APPLICATION_NAME}-dev --region $GCP_REGION --session-affinity
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},9x"
    echo
    echo "$ export USER=\$(gcloud config get-value core/account) # to set user" | pv -qL 100
    export USER=$(gcloud config get-value core/account)
    echo
    echo "$ gcloud beta run services remove-iam-policy-binding ${APPLICATION_NAME}-dev --platform managed --region $GCP_REGION --member=user:$USER --role roles/run.admin # to set role" | pv -qL 100
    gcloud beta run services remove-iam-policy-binding ${APPLICATION_NAME}-dev --platform managed --region $GCP_REGION --member=user:$USER --role roles/run.invoker
    echo
    echo "$ gcloud beta run services remove-iam-policy-binding ${APPLICATION_NAME}-dev --platform managed --region $GCP_REGION --member=allUsers --role roles/run.admin # to set role" | pv -qL 100
    gcloud beta run services remove-iam-policy-binding ${APPLICATION_NAME}-dev --platform managed --region $GCP_REGION --member=allUsers --role roles/run.invoker
else
    export STEP="${STEP},9i"
    echo
    echo "1. Grant IAM privileges" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"10")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},10i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT storage buckets create gs://\${GCP_PROJECT}-public --default-storage-class=STANDARD --location=\$GCP_REGION # to create bucket" | pv -qL 100
    echo
    echo "$ gcloud storage buckets update gs://\${GCP_PROJECT}-public --uniform-bucket-level-access # to enable policy" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT storage buckets add-iam-policy-binding gs://\${GCP_PROJECT}-public --member=allUsers --role=roles/storage.objectViewer # to assign role" | pv -qL 100
    # echo
    # echo "$ gcloud --project \$GCP_PROJECT iam service-accounts create media-cloud # to create service account" | pv -qL 100
    # echo
    # echo "$ export CLOUDRUN_SA=media-cloud@\$GCP_PROJECT.iam.gserviceaccount.com # to configure service account" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT projects add-iam-policy-binding \$GCP_PROJECT --member=\"serviceAccount:gcp-cloudrun-sa@\$GCP_PROJECT.iam.gserviceaccount.com\" --role roles/storage.admin # to assign role" | pv -qL 100
    # echo
    # echo "$ gcloud --project \$GCP_PROJECT iam service-accounts keys create \$PROJDIR/media-cloud.json --iam-account=\$CLOUDRUN_SA --key-file-type=json # to download key" | pv -qL 100
    # echo
    # echo "$ gcloud --project \$SECRETS_PROJECT secrets create \$GCP_PROJECT-public-gcs-sa-key --data-file=\$PROJDIR/media-cloud.json # to service account key" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},10"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT storage buckets create gs://${GCP_PROJECT}-public --default-storage-class=STANDARD --location=$GCP_REGION # to create bucket" | pv -qL 100
    gcloud --project $GCP_PROJECT storage buckets create gs://${GCP_PROJECT}-public --default-storage-class=STANDARD --location=$GCP_REGION
    echo
    echo "$ gcloud storage buckets update gs://${GCP_PROJECT}-public --uniform-bucket-level-access # to enable policy" | pv -qL 100
    gcloud storage buckets update gs://${GCP_PROJECT}-public --uniform-bucket-level-access
    echo
    echo "$ gcloud --project $GCP_PROJECT storage buckets add-iam-policy-binding gs://${GCP_PROJECT}-public --member=allUsers --role=roles/storage.objectViewer # to assign role" | pv -qL 100
    gcloud --project $GCP_PROJECT storage buckets add-iam-policy-binding gs://${GCP_PROJECT}-public --member=allUsers --role=roles/storage.objectViewer
    # echo
    # echo "$ gcloud --project $GCP_PROJECT iam service-accounts create media-cloud # to create service account" | pv -qL 100
    # gcloud --project $GCP_PROJECT iam service-accounts create media-cloud
    # echo
    # echo "$ export CLOUDRUN_SA=media-cloud@$GCP_PROJECT.iam.gserviceaccount.com # to configure service account" | pv -qL 100
    # export CLOUDRUN_SA=media-cloud@$GCP_PROJECT.iam.gserviceaccount.com
    echo
    echo "$ gcloud --project $GCP_PROJECT projects add-iam-policy-binding $GCP_PROJECT --member=\"serviceAccount:gcp-cloudrun-sa@$GCP_PROJECT.iam.gserviceaccount.com\" --role roles/storage.admin # to assign role" | pv -qL 100
    gcloud --project $GCP_PROJECT projects add-iam-policy-binding $GCP_PROJECT --member="serviceAccount:gcp-cloudrun-sa@$GCP_PROJECT.iam.gserviceaccount.com" --role roles/storage.admin
    # echo
    # echo "$ gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/media-cloud.json --iam-account=$CLOUDRUN_SA --key-file-type=json # to download key" | pv -qL 100
    # gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/media-cloud.json --iam-account=$CLOUDRUN_SA --key-file-type=json
    # echo
    # echo "$ gcloud --project $SECRETS_PROJECT secrets create $GCP_PROJECT-public-gcs-sa-key --data-file=$PROJDIR/media-cloud.json # to service account key" | pv -qL 100
    # gcloud --project $SECRETS_PROJECT secrets create $GCP_PROJECT-public-gcs-sa-key --data-file=$PROJDIR/media-cloud.json
    # rm -rf $PROJDIR/media-cloud.json
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},10x"
else
    export STEP="${STEP},10i"
    echo
    echo "1. Grant IAM privileges" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"11")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},11i"   
    echo
    echo "$ gcloud beta run services update \${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT} --platform managed --region \$GCP_REGION --ingress=internal-and-cloud-load-balancing # to update ingress" | pv -qL 100
    echo
    echo "$ gcloud compute addresses create --global \${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-ip # create static IP address" | pv -qL 100
    echo
    echo "$ export EXT_IP=\$(gcloud --project $GCP_PROJECT compute addresses describe \${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-ip --global --format=\"value(address)\") # to set IP" | pv -qL 100
    echo
    echo "$ gcloud compute network-endpoint-groups create \${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-neg --region=\$GCP_REGION --network-endpoint-type=serverless --cloud-run-service=\${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT} # to create serverless NEG" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services create \${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-service --load-balancing-scheme=EXTERNAL --global --enable-cdn --cache-mode=CACHE_All_STATIC --custom-response-header='Cache-Status: {cdn_cache_status}' --custom-response-header='Cache-ID: {cdn_cache_id}' # to create backend service" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services add-backend \${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-service --network-endpoint-group=\${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-neg --network-endpoint-group-region=\$GCP_REGION --global # to add serverless NEG to backend service" | pv -qL 100
    echo
    echo "$ gcloud compute url-maps create \${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-url-map --default-service \${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-service # to create URL map" | pv -qL 100
    echo "$ gcloud beta compute ssl-certificates create \${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-cert --domains \$DOMAIN # to create managed SSL cert" | pv -qL 100
    echo
    echo "$ gcloud compute target-https-proxies create \${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-https-proxy --ssl-certificates=\${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-cert --url-map=\${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-url-map # to create target HTTPS proxy" | pv -qL 100
    echo
    echo "$ gcloud compute forwarding-rules create \${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-fwd-rule --target-https-proxy=\${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-https-proxy --global --ports=443 --address=\${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-ip # to create forwarding rules" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},11"
    echo
    echo "$ gcloud beta run services update ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT} --platform managed --region $GCP_REGION --ingress=internal-and-cloud-load-balancing # to update ingress" | pv -qL 100
    gcloud beta run services update ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT} --platform managed --region $GCP_REGION --ingress=internal-and-cloud-load-balancing
    echo
    echo "$ gcloud compute addresses create --global ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-ip # create static IP address" | pv -qL 100
    gcloud compute addresses create --global ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-ip
    echo
    sleep 10 # wait 10 seconds
    echo "$ export EXT_IP=\$(gcloud --project $GCP_PROJECT compute addresses describe ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-ip --global --format=\"value(address)\") # to set IP" | pv -qL 100
    export EXT_IP=$(gcloud --project $GCP_PROJECT compute addresses describe ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-ip --global --format="value(address)")
    echo
    echo "$ gcloud compute network-endpoint-groups create ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-neg --region=$GCP_REGION --network-endpoint-type=serverless --cloud-run-service=${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT} # to create serverless NEG" | pv -qL 100
    gcloud compute network-endpoint-groups create ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-neg --region=$GCP_REGION --network-endpoint-type=serverless --cloud-run-service=${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}
    echo
    echo "$ gcloud compute backend-services create ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-service --load-balancing-scheme=EXTERNAL --global --enable-cdn --cache-mode=CACHE_All_STATIC --custom-response-header='Cache-Status: {cdn_cache_status}' --custom-response-header='Cache-ID: {cdn_cache_id}' # to create backend service" | pv -qL 100
    gcloud compute backend-services create ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-service --load-balancing-scheme=EXTERNAL --global --enable-cdn --cache-mode=CACHE_All_STATIC --custom-response-header='Cache-Status: {cdn_cache_status}' --custom-response-header='Cache-ID: {cdn_cache_id}' 
    echo
    echo "$ gcloud compute backend-services add-backend ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-service --network-endpoint-group=${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-neg --network-endpoint-group-region=$GCP_REGION --global # to add serverless NEG to backend service" | pv -qL 100
    gcloud compute backend-services add-backend ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-service --network-endpoint-group=${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-neg --network-endpoint-group-region=$GCP_REGION --global
    echo
    echo "$ gcloud compute url-maps create ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-url-map --default-service ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-service # to create URL map" | pv -qL 100
    gcloud compute url-maps create ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-url-map --default-service ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-service
    echo
    if [[ -z "$APPLICATION_CUSTOM_DOMAIN" ]] ; then
        export DOMAIN=$EXT_IP.nip.io
    else 
        export DOMAIN=$APPLICATION_CUSTOM_DOMAIN
    fi
    echo "$ gcloud beta compute ssl-certificates create ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-cert --domains $DOMAIN # to create managed SSL cert" | pv -qL 100
    gcloud beta compute ssl-certificates create ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-cert --domains $DOMAIN
    echo
    echo "$ gcloud compute target-https-proxies create ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-https-proxy --ssl-certificates=${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-cert --url-map=${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-url-map # to create target HTTPS proxy" | pv -qL 100
    gcloud compute target-https-proxies create ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-https-proxy --ssl-certificates=${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-cert --url-map=${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-url-map
    echo
    echo "$ gcloud compute forwarding-rules create ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-fwd-rule --target-https-proxy=${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-https-proxy --global --ports=443 --address=${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-ip # to create forwarding rules" | pv -qL 100
    gcloud compute forwarding-rules create ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-fwd-rule --target-https-proxy=${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-https-proxy --global --ports=443 --address=${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-ip
    export MANAGED_STATUS=$(gcloud compute ssl-certificates list --filter="managed.domains:$DOMAIN" --format 'value(MANAGED_STATUS)')
    echo
    while [[ "$MANAGED_STATUS" != "ACTIVE" ]]; do
        sleep 30
        echo "*** Managed SSL certificate status is $MANAGED_STATUS ***"
        export MANAGED_STATUS=$(gcloud compute ssl-certificates list --filter="managed.domains:$DOMAIN" --format 'value(MANAGED_STATUS)')
    done
    echo
    echo "*** Wait 10-15 minutes until cert provisions and run command \"curl https://$DOMAIN\" to verify app is running ***" | pv -qL 100
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},11x"
    echo
    echo "$ gcloud compute forwarding-rules delete ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-fwd-rule --global # to delete forwarding rules" | pv -qL 100
    gcloud compute forwarding-rules delete ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-fwd-rule --global 
    echo
    echo "$ gcloud compute target-https-proxies delete ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-https-proxy # to delete target HTTPS proxy" | pv -qL 100
    gcloud compute target-https-proxies delete ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-https-proxy
    echo
    echo "$ gcloud beta compute ssl-certificates delete ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-cert # to delete managed SSL cert" | pv -qL 100
    gcloud beta compute ssl-certificates delete ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-cert
    echo
    echo "$ gcloud compute url-maps delete ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-url-map # to delete URL map" | pv -qL 100
    gcloud compute url-maps delete ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-url-map
    echo
    echo "$ gcloud compute backend-services remove-backend ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-service --network-endpoint-group=${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-neg --network-endpoint-group-region=$GCP_REGION --global # to remove serverless NEG to backend service" | pv -qL 100
    gcloud compute backend-services remove-backend ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-service --network-endpoint-group=${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-neg --network-endpoint-group-region=$GCP_REGION --global
    echo
    echo "$ gcloud compute backend-services delete ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-service --global # to delete backend service" | pv -qL 100
    gcloud compute backend-services delete ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-service --global
    echo
    echo "$ gcloud compute network-endpoint-groups delete ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-neg --region=$GCP_REGION # to delete serverless NEG" | pv -qL 100
    gcloud compute network-endpoint-groups delete ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-neg --region=$GCP_REGION
    echo
    echo "$ gcloud compute addresses delete --global ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-ip # to delete static IP address" | pv -qL 100
    gcloud compute addresses delete --global ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-ip
else
    export STEP="${STEP},11i"
    echo
    echo " 1. Update ingress to accept traffic via load balancer" | pv -qL 100
    echo " 2. Create a global static IP address" | pv -qL 100
    echo " 3. Create serverless network endpoint group (NEG)" | pv -qL 100
    echo " 4. Create backend service" | pv -qL 100
    echo " 5. Add serverless NEG to backend service" | pv -qL 100
    echo " 6. Create URL map" | pv -qL 100
    echo " 7. Create managed SSL cert" | pv -qL 100
    echo " 8. Create target HTTPS proxy" | pv -qL 100
    echo " 9. Create forwarding rules" | pv -qL 100
    echo "10. Access service via the global load balancer" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"12")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},12i"   
    echo
    echo "$ export EXT_IP=\$(gcloud --project \$GCP_PROJECT compute addresses describe \${APPLICATION_NAME}-\${APPLICATION_ENVIRONMENT}-ip --global --format=\"value(address)\") # to set IP" | pv -qL 100
    echo
    echo "$ sed -i \"/^#define('WP_HOME'/c\\define('WP_HOME', 'https://\$DOMAIN');\" \$PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    echo
    echo "$ sed -i \"/^#define('WP_SITEURL'/c\\define('WP_SITEURL', 'https://\$DOMAIN');\" \$PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    echo
    echo "$ sed -i 's/run\\.googleapis\\.com\\/ingress: all/run.googleapis.com\\/ingress: internal-and-cloud-load-balancing/g' \$PROJDIR/cicd/deploy-dev.yaml # to route traffic via load balancer"
    echo
    echo "$ cd \$PROJDIR/\$APPLICATION_NAME # change to repo directory" | pv -qL 100
    echo
    echo "$ cp -r \$PROJDIR/src/* . > /dev/null 2>&1 # to copy application artifacts into repo" | pv -qL 100
    echo
    echo "$ cp -r \$PROJDIR/cicd/* \$PROJDIR/cicd/.dockerignore . > /dev/null 2>&1 # to copy cicd artifacts into repo" | pv -qL 100
    echo
    echo "$ git checkout -B main # to checkout branch" | pv -qL 100
    echo
    echo "$ git add . # to add files" | pv -qL 100
    echo
    echo "$ git commit -m \"Added Cloud Deploy and Cloud Build config files\" # to commit change" | pv -qL 100
    echo
    echo "$ git push origin main --force # to push to Github" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},12"
    echo
    echo "$ export EXT_IP=\$(gcloud --project $GCP_PROJECT compute addresses describe ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-ip --global --format=\"value(address)\") # to set IP" | pv -qL 100
    export EXT_IP=$(gcloud --project $GCP_PROJECT compute addresses describe ${APPLICATION_NAME}-${APPLICATION_ENVIRONMENT}-ip --global --format="value(address)")
    if [[ -z "$APPLICATION_CUSTOM_DOMAIN" ]] ; then
        export DOMAIN=$EXT_IP.nip.io
    else 
        export DOMAIN=$APPLICATION_CUSTOM_DOMAIN
    fi
    echo
    echo "$ sed -i \"/^#define('WP_HOME'/c\\define('WP_HOME', 'https://\$DOMAIN');\" $PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    sed -i "/^#define('WP_HOME'/c\define('WP_HOME', 'https://$DOMAIN');" $PROJDIR/src/wordpress/wp-config.php
    echo
    echo "$ sed -i \"/^#define('WP_SITEURL'/c\\define('WP_SITEURL', 'https://\$DOMAIN');\" $PROJDIR/src/wordpress/wp-config.php # to update key" | pv -qL 100
    sed -i "/^#define('WP_SITEURL'/c\define('WP_SITEURL', 'https://$DOMAIN');" $PROJDIR/src/wordpress/wp-config.php
    echo
    echo "$ sed -i 's/run\\.googleapis\\.com\\/ingress: all/run.googleapis.com\\/ingress: internal-and-cloud-load-balancing/g' $PROJDIR/cicd/deploy-dev.yaml # to route traffic via load balancer"
    sed -i 's/run\.googleapis\.com\/ingress: all/run.googleapis.com\/ingress: internal-and-cloud-load-balancing/g' $PROJDIR/cicd/deploy-dev.yaml
    if [[ -z $APPLICATION_MIRRORED_REPOSITORY ]]; then
        export APPLICATION_REPOSITORY=$APPLICATION_NAME-cloudrun-repository
        echo
        echo "$ cd $PROJDIR/$APPLICATION_REPOSITORY # change to repo directory" | pv -qL 100
        cd $PROJDIR/$APPLICATION_REPOSITORY 
        echo
        echo "$ cp -r $PROJDIR/src/* . > /dev/null 2>&1 # to copy application artifacts into repo" | pv -qL 100
        cp -r $PROJDIR/src/* . > /dev/null 2>&1 
        echo
        echo "$ cp -r $PROJDIR/cicd/* $PROJDIR/cicd/.dockerignore . > /dev/null 2>&1 # to copy cicd artifacts into repo" | pv -qL 100
        cp -r $PROJDIR/cicd/* $PROJDIR/cicd/.dockerignore . > /dev/null 2>&1 
    else 
        echo
        echo "$ cd $PROJDIR/$GITHUB_REPOSITORY # to change directory" | pv -qL 100
        cd $PROJDIR/$GITHUB_REPOSITORY
        echo
        echo "$ cp -r $PROJDIR/cicd/*.yaml . # to copy yaml artifacts into repo" | pv -qL 100
        cp -r $PROJDIR/cicd/*.yaml .
        echo
        echo "$ export GITDIR=\$(echo \"\$APPLICATION_GITHUB_REPOSITORY\" | cut -d \"/\" -f 2) # to get repo name" | pv -qL 100
        export GITHUB_REPOSITORY=$(echo "$APPLICATION_GITHUB_REPOSITORY" | cut -d "/" -f 2)
    fi
    if [[ ! -z $APPLICATION_MIRRORED_REPOSITORY ]]; then # RETAINED TO TEST WITHOUT REPO MIRRORING
        cp -r $PROJDIR/${APPLICATION_REPOSITORY}-clone/* $PROJDIR/$APPLICATION_REPOSITORY > /dev/null 2>&1 
    fi
    echo "$ git checkout -B main # to checkout branch" | pv -qL 100
    git checkout -B main
    echo
    echo "$ git add . # to add files" | pv -qL 100
    git add .
    echo
    echo "$ git commit -m \"Added Cloud Deploy and Cloud Build config files\" # to commit change" | pv -qL 100
    git commit -m "Added files"
    echo
    echo "$ git push origin main --force # to push to Github" | pv -qL 100
    git push origin main --force
    stty echo # to ensure input characters are echoed on terminal
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},12x"
    echo
    echo "*** Nothing to delete ***"
else
    export STEP="${STEP},12i"   
    echo
    echo " 1. Create application artifacts" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"13")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},13i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT storage buckets create gs://\${GCP_PROJECT}-backup --default-storage-class=STANDARD --location=\$GCP_REGION # to create bucket" | pv -qL 100
    echo
    echo "$ gcloud storage buckets update gs://\${GCP_PROJECT}-backup --uniform-bucket-level-access # to enable policy" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT iam service-accounts create database-backup # to create service account" | pv -qL 100
    echo
    echo "$ export CLOUDRUN_SA=database-backup@\$GCP_PROJECT.iam.gserviceaccount.com # to configure service account" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT projects add-iam-policy-binding \$GCP_PROJECT --member=\"serviceAccount:\$CLOUDRUN_SA\" --role roles/storage.objectAdmin # to assign role" | pv -qL 100
    echo
    echo "$ gcloud sql export sql \$DB_INSTANCE gs://\${GCP_PROJECT}-backup/\${DB_NAME}_mysqldumpfile_\$(date +\"%d%m%y\").gz --database=\${APPLICATION_NAME}_dev --offload # to backup db"
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},13"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT storage buckets create gs://${GCP_PROJECT}-backup --default-storage-class=STANDARD --location=$GCP_REGION # to create bucket" | pv -qL 100
    gcloud --project $GCP_PROJECT storage buckets create gs://${GCP_PROJECT}-backup --default-storage-class=STANDARD --location=$GCP_REGION
    echo
    echo "$ gcloud storage buckets update gs://${GCP_PROJECT}-backup --uniform-bucket-level-access # to enable policy" | pv -qL 100
    gcloud storage buckets update gs://${GCP_PROJECT}-backup --uniform-bucket-level-access
    echo
    echo "$ gcloud --project $GCP_PROJECT iam service-accounts create database-backup # to create service account" | pv -qL 100
    gcloud --project $GCP_PROJECT iam service-accounts create database-backup
    echo
    echo "$ export CLOUDRUN_SA=database-backup@$GCP_PROJECT.iam.gserviceaccount.com # to configure service account" | pv -qL 100
    export CLOUDRUN_SA=database-backup@$GCP_PROJECT.iam.gserviceaccount.com
    echo
    echo "$ gcloud --project $GCP_PROJECT projects add-iam-policy-binding $GCP_PROJECT --member=\"serviceAccount:$CLOUDRUN_SA\" --role roles/storage.objectAdmin # to assign role" | pv -qL 100
    gcloud --project $GCP_PROJECT projects add-iam-policy-binding $GCP_PROJECT --member="serviceAccount:$CLOUDRUN_SA" --role roles/storage.objectAdmin
    echo
    echo "$ gcloud sql export sql $DB_INSTANCE gs://${GCP_PROJECT}-backup/${DB_NAME}_mysqldumpfile_$(date +"%d%m%y").gz --database=${APPLICATION_NAME}_dev --offload # to backup db"
    gcloud sql export sql $DB_INSTANCE gs://${GCP_PROJECT}-backup/${DB_NAME}_mysqldumpfile_$(date +"%d%m%y").gz --database=${APPLICATION_NAME}_dev --offload
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},13x"
    echo
    echo "*** Not implemented ***" | pv -qL 100
else
    export STEP="${STEP},13i"
    echo
    echo "*** Not implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"14")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},14i"
    echo
    echo "$ export CLOUDRUN_SA=database-backup@\$GCP_PROJECT.iam.gserviceaccount.com # to configure service account" | pv -qL 100
    echo
    echo "$ gcloud sql import sql \$DB_INSTANCE gs://\${GCP_PROJECT}-backup/\${DB_NAME}_mysqldumpfile.gz --database=\${APPLICATION_NAME}_dev # to backup db"
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},14"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ export CLOUDRUN_SA=database-backup@$GCP_PROJECT.iam.gserviceaccount.com # to configure service account" | pv -qL 100
    export CLOUDRUN_SA=database-backup@$GCP_PROJECT.iam.gserviceaccount.com
    echo
    echo "$ gcloud sql import sql $DB_INSTANCE gs://${GCP_PROJECT}-backup/${DB_NAME}_mysqldumpfile.gz --database=${APPLICATION_NAME}_dev # to backup db"
    gcloud sql import sql $DB_INSTANCE gs://${GCP_PROJECT}-backup/${DB_NAME}_mysqldumpfile.gz --database=${APPLICATION_NAME}_dev
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},14x"
    echo
    echo "*** Not implemented ***" | pv -qL 100
else
    export STEP="${STEP},14i"
    echo
    echo "*** Not implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"15")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},15i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql -q instances patch \$DB_INSTANCE --assign-ip --authorized-networks=\$AUTHORIZED_NETWORK # to authorize access from the local client IP" | pv -qL 100
    echo
    echo "$ gsutil mb -p \$GCP_PROJECT -c regional -l \$GCP_REGION \$GCP_PROJECT # to create bucket"
    echo
    echo "$ mysqldump -h\${DB_HOST} -P3306 -u\$DB_USER  --routines --triggers --add-locks --disable-keys --single-transaction \${DB_NAME} > \$PROJDIR/\${DB_NAME}_mysql_\$(date +\"%d%m%y\").sql # to dump database" | pv -qL 100
    echo
    echo "$ gsutil cp \$PROJDIR/\${DB_NAME}_mysql_\$(date +\"%d%m%y\").sql.gz gs://\$GCP_PROJECT/${DB_NAME}_mysql_\$(date +\"%d%m%y\").sql.gz # to copy backup" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql -q instances patch \$DB_INSTANCE --no-assign-ip --clear-authorized-networks # to disable access from the local IP" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},15"
    export LOCALIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
    export AUTHORIZED_NETWORK=${LOCALIP}/32
    export DATABASE_NAME=${APPLICATION_NAME}_dev
    export DB_NAME=$DATABASE_NAME
    export DB_USER=$DB_NAME
    export DB_HOST=$(gcloud --project $GCP_PROJECT sql instances describe $DB_INSTANCE --format 'value(ipAddresses[0].ipAddress)')
    export DB_PASSWORD=$(gcloud --project $SECRETS_PROJECT secrets versions access latest --secret=${GCP_PROJECT}-${DB_INSTANCE}-${DATABASE_NAME}-password)
    export MYSQL_PWD=$DB_PASSWORD
    echo
    echo "$ gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --assign-ip --authorized-networks=$AUTHORIZED_NETWORK # to authorize access from the local client IP" | pv -qL 100
    gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --assign-ip --authorized-networks=$AUTHORIZED_NETWORK
    missing=$(gsutil ls $GCP_PROJECT |& grep BucketNotFound | wc -l)
    if [ ${missing} == 1 ]; then
        echo
        echo "$ gsutil mb -p $GCP_PROJECT -c regional -l $GCP_REGION $GCP_PROJECT # to create bucket"
        gsutil mb -p $GCP_PROJECT -c regional -l $GCP_REGION $GCP_PROJECT
    fi
    echo
    export DB_HOST=$(gcloud --project $GCP_PROJECT sql instances describe $DB_INSTANCE --format 'value(ipAddresses[0].ipAddress)')
    echo "$ mysqldump -h${DB_HOST} -P3306 -u$DB_USER  --routines --triggers --add-locks --disable-keys --single-transaction ${DB_NAME} > $PROJDIR/${DB_NAME}_mysql_\$(date +\"%d%m%y\").sql # to dump database" | pv -qL 100
    mysqldump -h${DB_HOST} -P3306 -u$DB_USER  --routines --triggers --add-locks --disable-keys --single-transaction ${DB_NAME} > $PROJDIR/${DB_NAME}_mysql_$(date +"%d%m%y").sql
    echo
    gzip -f $PROJDIR/${DB_NAME}_mysql_$(date +"%d%m%y").sql
    echo "$ gsutil cp $PROJDIR/${DB_NAME}_mysql_$(date +"%d%m%y").sql.gz gs://$GCP_PROJECT/${DB_NAME}_mysql_$(date +"%d%m%y").sql.gz # to copy backup" | pv -qL 100
    gsutil cp $PROJDIR/${DB_NAME}_mysql_$(date +"%d%m%y").sql.gz gs://$GCP_PROJECT/${DB_NAME}_mysql_$(date +"%d%m%y").sql.gz
    echo
    rm -rf $PROJDIR/${DB_NAME}_mysql_$(date +"%d%m%y").sql.gz
    echo "$ gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --no-assign-ip --clear-authorized-networks # to disable access from the local IP" | pv -qL 100
    gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --no-assign-ip --clear-authorized-networks
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},15x"
    echo
    echo "*** Not implemented ***"
else
    export STEP="${STEP},15i"
    echo
    echo "*** Not implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"16")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},16i"
    echo
    echo "$ gsutil cp gs://\$GCP_PROJECT/\${DB_NAME}_mysql.sql.gz \$PROJDIR/${DB_NAME}_mysql.sql.gz # to copy database backup" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql -q instances patch \$DB_INSTANCE --assign-ip --authorized-networks=\$AUTHORIZED_NETWORK # to authorize access from the local client IP" | pv -qL 100
    echo
    echo "$ mysql -h\$DB_HOST -p\$DB_PASSWORD -P3306 -u\$DB_USER \$DB_NAME < \$PROJDIR/\${DB_NAME}_mysql.sql # to restore database" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql -q instances patch \$DB_INSTANCE --no-assign-ip --clear-authorized-networks # to disable access from the local IP" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},16"
    export LOCALIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
    export AUTHORIZED_NETWORK=${LOCALIP}/32
    export DATABASE_NAME=${APPLICATION_NAME}_dev
    export DB_NAME=$DATABASE_NAME
    export DB_USER=$DB_NAME
    export DB_HOST=$(gcloud --project $GCP_PROJECT sql instances describe $DB_INSTANCE --format 'value(ipAddresses[0].ipAddress)')
    export DB_PASSWORD=$(gcloud --project $SECRETS_PROJECT secrets versions access latest --secret=${GCP_PROJECT}-${DB_INSTANCE}-${DATABASE_NAME}-password)
    export MYSQL_PWD=$DB_PASSWORD
    echo
    echo "$ gsutil cp gs://$GCP_PROJECT/${DB_NAME}_mysql.sql.gz $PROJDIR/${DB_NAME}_mysql.sql.gz # to copy database backup" | pv -qL 100
    gsutil cp gs://$GCP_PROJECT/${DB_NAME}_mysql.sql.gz $PROJDIR/${DB_NAME}_mysql.sql.gz
    gunzip -f $PROJDIR/${DB_NAME}_mysql.sql.gz
    echo
    echo "$ gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --assign-ip --authorized-networks=$AUTHORIZED_NETWORK # to authorize access from the local client IP" | pv -qL 100
    gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --assign-ip --authorized-networks=$AUTHORIZED_NETWORK
    sleep 15
    export DB_HOST=$(gcloud sql instances describe $DB_INSTANCE --project $GCP_PROJECT --format 'value(ipAddresses[0].ipAddress)')
    echo
    echo "$ mysql -h$DB_HOST -P3306 -u$DB_USER $DB_NAME < $PROJDIR/${DB_NAME}_mysql.sql # to restore database" | pv -qL 100
    mysql -h$DB_HOST -P3306 -u$DB_USER $DB_NAME < $PROJDIR/${DB_NAME}_mysql.sql
    echo
    rm -rf $PROJDIR/${DB_NAME}_mysql.sql
    echo "$ gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --no-assign-ip --clear-authorized-networks # to disable access from the local IP" | pv -qL 100
    gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --no-assign-ip --clear-authorized-networks
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},16x"
    echo
    echo "*** Not implemented ***"
else
    export STEP="${STEP},16i"
    echo
    echo "*** Not implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"17")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},17i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql -q instances patch \$DB_INSTANCE --assign-ip --authorized-networks=\$AUTHORIZED_NETWORK # to authorize access from the local client IP" | pv -qL 100
    echo
    echo "$ mysql -h\$DB_HOST -p\$DB_PASSWORD -P3306 -u\$DB_USER -e 'DROP DATABASE \$APPLICATION_NAME;'\" # to drop databases" | pv -qL 100
    echo
    echo "$ gcloud sql databases delete \$DB_NAME --instance \$DB_INSTANCE --quiet # to drop database" | pv -qL 100
    echo
    echo "$ mysql -h\$DB_HOST -p\$DB_PASSWORD -P3306 -u\$DB_USER -e 'SHOW DATABASES;' # to display databases" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT sql -q instances patch \$DB_INSTANCE --no-assign-ip --clear-authorized-networks # to disable access from the local IP" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},17"
    export LOCALIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
    export AUTHORIZED_NETWORK=${LOCALIP}/32
    export DATABASE_NAME=${APPLICATION_NAME}_dev
    export DB_NAME=$DATABASE_NAME
    export DB_USER=$DB_NAME
    export DB_HOST=$(gcloud --project $GCP_PROJECT sql instances describe $DB_INSTANCE --format 'value(ipAddresses[0].ipAddress)')
    export DB_PASSWORD=$(gcloud --project $SECRETS_PROJECT secrets versions access latest --secret=${GCP_PROJECT}-${DB_INSTANCE}-${DATABASE_NAME}-password)
    export MYSQL_PWD=$DB_PASSWORD
    echo
    echo "$ gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --assign-ip --authorized-networks=$AUTHORIZED_NETWORK # to authorize access from the local client IP" | pv -qL 100
    gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --assign-ip --authorized-networks=$AUTHORIZED_NETWORK
    sleep 15
    export DB_HOST=$(gcloud sql instances describe $DB_INSTANCE --project $GCP_PROJECT --format 'value(ipAddresses[0].ipAddress)')
    sleep 5
    echo
    echo "$ mysql -h$DB_HOST -P3306 -u$DB_USER -e 'DROP DATABASE $APPLICATION_NAME;'\" # to drop databases" | pv -qL 100
    mysql -h$DB_HOST -P3306 -u$DB_USER -e 'DROP DATABASE $APPLICATION_NAME;'
    echo
    echo "$ gcloud sql databases delete $DB_NAME --instance $DB_INSTANCE --quiet # to drop database" | pv -qL 100
    gcloud sql databases delete $DB_NAME --instance $DB_INSTANCE --quiet
    echo
    echo "$ mysql -h$DB_HOST -P3306 -u$DB_USER -e 'SHOW DATABASES;' # to display databases" | pv -qL 100
    mysql -h$DB_HOST -P3306 -u$DB_USER -e 'SHOW DATABASES;'
    echo
    echo "$ gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --no-assign-ip --clear-authorized-networks # to disable access from the local IP" | pv -qL 100
    gcloud --project $GCP_PROJECT sql -q instances patch $DB_INSTANCE --no-assign-ip --clear-authorized-networks
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},17x"
    echo
    echo "*** Not implemented ***"
else
    export STEP="${STEP},17i"
    echo
    echo "*** Not implemented ***" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud
 
Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
