#!/usr/bin/env bash

set -e
# set -u
shopt -s nullglob

timeout=${2:-'3'}
app=jq


read -p 'Vault Address (prod, nonprod, ist): ' vaultAddress
read -s -p 'Vault Token: (input hidden)' VAULT_TOKEN
echo 
read -p 'Project name: ' projectName
read -p "Environment(s) separated by 'space' - default: ist uat nft stg prd : (Enter to finish)" environments
read -p 'Application name: ' appName
read -p "Co-oridinator(s) sID(s) separated by 'space' : (Enter to finish)" coords



if [ $vaultAddress == "ist" ]
then
  VAULT_ADDR="https://lb.vault.ist.bns:8200"
elif [ $vaultAddress == "local" ]
then
  VAULT_ADDR="https://10.0.0.186:8200"
elif [ $vaultAddress == "prod" ] || [ $vaultAddress == "nonprod" ]
then
  VAULT_ADDR="https://lb.vault."$vaultAddress".bns:8200"
else
  echo "Please select a proper vault Address (prod, nonprod, local)"
  exit 1
fi

echo "using vault address at $VAULT_ADDR"

# 

#creating the required folder structure 
mkdir -p content/sys/policy
mkdir -p content/secret/data
mkdir -p content/auth/ldap/groups
mkdir -p content/auth/ldap/users

chmod -R 775 content

if [ -z $environments ]
then
  echo "using default environments collection of ist uat nft stg prd"
  environments=(ist uat nft stg prd)
else
  echo "using user entered environments: $environments"
fi



pathToCoordPolicy="content/sys/policy/"$projectName-$appName-coordinator".json"
rootPathToSecretFolder="content/secret/data/"
pathToCoordGroup="content/auth/ldap/groups/"$projectName-$appName"-coordinators.json"
pathToCoordUsers="content/auth/ldap/users/"

### Create Co-ord group
cat > $pathToCoordGroup << EOF1
{
  "policies": "$projectName-$appName-coordinator,default"
}
EOF1

function exists() {
  command -v "$1" >/dev/null 2>&1
}


### check if JQ is available. install it if not.
if exists $app; then
  echo "JQ exists"
else
  echo "******************************"
  echo "installing jq ... "
  echo "******************************"
  sudo wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
  sudo chmod +x ./jq
  sudo cp jq /usr/bin
fi


for coord in ${coords[@]}
do

 echo "***********************************"
 echo "checking if $coord belongs to any current groups"
 
 existingGroups=`curl \
        --location \
        --connect-timeout $timeout \
        --header "X-Vault-Token: ${VAULT_TOKEN}" \
        --fail \
        --silent \
        "${VAULT_ADDR}/v1/auth/ldap/users/$coord" | jq .data.groups`


 if [ -z $existingGroups ]
 then
  echo "$coord does not currently belong to any other groups"
  else
    echo "$coord currently belongs to $existingGroups, appending $projectName-$appName-coordinators to current user membership"
    existingGroups=", ${existingGroups:1:`expr ${#existingGroups} - 2`}"
  fi


cat > $pathToCoordUsers/$coord.json << EOF1
{
  "groups": "$projectName-$appName-coordinators$existingGroups"
}
EOF1
done



### Create coordinator policy
cat > $pathToCoordPolicy << EOF1
{
  "path": {
    "sys/mounts": {
      "capabilities": [
        "list",
        "read"
      ]
    },
    "secret/data/$projectName/ist/$appName/*": {
      "capabilities": [
        "create",
        "update",
        "read",
        "delete",
        "list",
        "sudo"
      ]
    },
    "secret/metadata/$projectName/*": {
      "capabilities": [
        "list"
      ]
    },
    "auth/approle/role/$projectName-ist-$appName/role-id": {
      "capabilities": [
        "read"
      ]
    },
    "auth/approle/role/$projectName-uat-$appName/role-id": {
      "capabilities": [
        "read"
      ]
    },
    "auth/approle/role/$projectName-nft-$appName/role-id": {
      "capabilities": [
        "read"
      ]
    },
    "auth/approle/role/$projectName-stg-$appName/role-id": {
      "capabilities": [
        "read"
      ]
    },
    "auth/approle/role/$projectName-ist-$appName/secret-id": {
      "capabilities": [
        "update"
      ]
    },
    "auth/approle/role/$projectName-prd-$appName/role-id": {
      "capabilities": [
        "read"
      ]
    }
  }
}
EOF1

mkdir -p content/auth/approle/role
chmod -R 777 content



for environment in ${environments[@]}
do

pathToPolicy="content/sys/policy/"$projectName-$environment-$appName".json"
pathToApprolePayload="content/auth/approle/role/"$projectName-$environment-$appName".json"
PathToSecretFolder="content/secret/data/"$projectName/$environment/$appName



### Create application policy
cat > $pathToPolicy << EOF1
{
  "path": {
      "secret/data/$projectName/$environment/$appName/*": {
      "capabilities": [
          "read",
          "list"
      ]
    },
      "secret/metadata/$projectName/$environment/$appName/*": {
      "capabilities": [
          "read",
          "list"
      ]
    }
  }
}
EOF1

cat > $pathToApprolePayload << EOF1
{
  "bind_secret_id": true,
  "policies": ["$projectName-$environment-$appName"],
  "secret_id_ttl": "72h",
  "secret_id_num_uses": 3,
  "token_ttl": "24h",
  "token_num_uses": 0,
  "token_max_ttl":0
}
EOF1

### create directory structure for dumy secret
mkdir -p $rootPathToSecretFolder/$projectName/$environment/$appName


### create dummy secret payload
cat > $PathToSecretFolder/dummy01.json << EOF1
{
  "data": {
      "TestSecret": "$environment-SecretData"
  }
}
EOF1
done


function provision() {
    set +e
    pushd "$1" > /dev/null
    # echo $1
    for f in $(ls "$1"/*.json); do
      fname=${f%.json}

      p="$1/${f%.json}"

      echo {$p}
    if [[ $1 =~ ^sys/policy.* ]]; then
      string="$(echo "$(cat ${f})" | jq '@json')"
      payload='{"policy":'"${string}"'}'

    else
      if [[ -f "$f" ]]; then
        payload="$(cat ${f})"
      fi
    fi

    if [[ -f "$f" ]]; then
      res=`echo $(curl --write-out %{http_code} \
        --location \
        --connect-timeout $timeout \
        --header "X-Vault-Token: ${VAULT_TOKEN}" \
        --data "$(echo "${payload}")" \
        --fail \
        --silent \
        "${VAULT_ADDR}/v1/${p}" )`

      case $res in
        000) echo "Not responding within $timeout seconds, Failed to connect to $VAULT_ADDR"
              exit 1
        ;;
        100) echo "Informational: Continue" ;;
        101) echo "Informational: Switching Protocols" ;;
        200) echo "Successful: OK within $timeout seconds" ;;
        201) echo "Successful: Created" ;;
        202) echo "Successful: Accepted" ;;
        203) echo "Successful: Non-Authoritative Information" ;;
        204) echo " "$fname":  has successfuly provisioned " ;;
        205) echo "Successful: Reset Content" ;;
        206) echo "Successful: Partial Content" ;;
        300) echo "Redirection: Multiple Choices" ;;
        301) echo "Redirection: Moved Permanently" ;;
        302) echo "Redirection: Found residing temporarily under different URI" ;;
        303) echo "Redirection: See Other" ;;
        304) echo "Redirection: Not Modified" ;;
        305) echo "Redirection: Use Proxy" ;;
        306) echo "Redirection: status not defined" ;;
        307) echo "Redirection: Temporary Redirect" ;;
        400) echo "Client Error: A device/backend exits at the path with the same neme." ;;
        401) echo "Client Error: Unauthorized" ;;
        402) echo "Client Error: Payment Required" ;;
        403) echo "Authentication failed: permission denied" ;;
        404) echo "Client Error: Not Found" ;;
        405) echo "Client Error: Method Not Allowed" ;;
        406) echo "Client Error: Not Acceptable" ;;
        407) echo "Client Error: Proxy Authentication Required" ;;
        408) echo "Client Error: Request Timeout within $timeout seconds" ;;
        409) echo "Client Error: Conflict" ;;
        410) echo "Client Error: Gone" ;;
        411) echo "Client Error: Length Required" ;;
        412) echo "Client Error: Precondition Failed" ;;
        413) echo "Client Error: Request Entity Too Large" ;;
        414) echo "Client Error: Request-URI Too Long" ;;
        415) echo "Client Error: Unsupported Media Type" ;;
        416) echo "Client Error: Requested Range Not Satisfiable" ;;
        417) echo "Client Error: Expectation Failed" ;;
        500) echo "Server Error: Internal Server Error" ;;
        501) echo "Server Error: Not Implemented" ;;
        502) echo "Server Error: Bad Gateway" ;;
        503) echo "Server Error: Service Unavailable" ;;
        504) echo "Server Error: Gateway Timeout within $timeout seconds" ;;
        505) echo "Server Error: HTTP Version Not Supported" ;;
          *) echo " "$fname":  has successfuly provisioned "
      esac

    fi

    done
    popd > /dev/null
    set -e
}



#Pushing the "content" folder to $1
pushd content >/dev/null

###  Registring new project/application ####
echo "****************************"
for environment in ${environments[@]}
do
echo " Writing "$projectName-$environment-$appName" policy ... "
done
echo "****************************"
provision sys/policy
for environment in ${environments[@]}
do
echo "***********************************"
echo " Load dummy01 to "secret/$projectName/$environment/$appName" ... "
echo "***********************************"
provision secret/data/$projectName/$environment/$appName
done
echo "***********************************"
for environment in ${environments[@]}
do
echo " Create an Application role for "$projectName-$environment-$appName" ... "
done
echo "***********************************"
provision auth/approle/role
echo "********************************"
echo " Creating $projectName-$appName LDAP group ... "
echo "********************************"
provision auth/ldap/groups
echo "*************************************"
echo " Creating $projectName-$appName user(s) ... "
echo "*************************************"
provision auth/ldap/users
popd > /dev/null

## clean up
pathToPolicy="content/sys/policy/"$projectName-$environment-$appName".json"
pathToApprolePayload="content/auth/approle/role/"$projectName-$environment-$appName".json"
PathToSecretFolder="content/secret/data/"$projectName/$environment/$appName
pathToCoordPolicy="content/sys/policy/"$projectName-$appName-coordinator".json"
rootPathToSecretFolder="content/secret/data/"
pathToCoordGroup="content/auth/ldap/groups/"$projectName-$appName"-coordinators.json"
pathToCoordUsers="content/auth/ldap/users/"
rm -rf content
