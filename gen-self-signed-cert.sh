#!/bin/bash
#
# Created: Sakharov Sergey
# Version: 2.3
#
#

SSL_DOMAIN_NAME="test.example.local"
CA_DOMAIN_NAME="privat-ca.sbs.local"

SCRIPT_FULL_PATH=$0
DIR_SCRIPT_FULL_PATH=$(dirname "$0")
DIR_CURRENT=$(pwd)


function help_output {

echo -en "\nUsage: $0 <Option>
\t-n	:	Domain Name
\t-h	:	Output Help
\n"

}

while getopts "n:h" OPTION
do
    case "$OPTION" in
    
    ### Option For Add Donmain Name
    n)
    
    SSL_DOMAIN_NAME="${OPTARG}"
    
    ;;
    
    
    ### Option For Help
    h)
    
    help_output
    exit 1
    
    ;;
    
    esac
done


CA_CERT_DIR_NAME="_certs-${CA_DOMAIN_NAME}"
CA_KEY="${CA_DOMAIN_NAME}.key"
CA_CERT="${CA_DOMAIN_NAME}.crt"
CA_EXPIRE="3653"
CA_SUBJECT="\
/C=RU\
/ST=Local\
/O=SBS_Local\
/OU=SBS_Local_Privat_CA\
/CN=${CA_DOMAIN_NAME}\
"


SSL_CERT_DIR_NAME="certs_${SSL_DOMAIN_NAME}"
SSL_KEY="${SSL_DOMAIN_NAME}.key"
SSL_CSR="${SSL_DOMAIN_NAME}.csr"
SSL_EXT="${SSL_DOMAIN_NAME}.ext"
SSL_CERT="${SSL_DOMAIN_NAME}.crt"
SSL_CERT_CHAIN="${SSL_DOMAIN_NAME}-chain.crt"
SSL_EXPIRE="3653"
SSL_SUBJECT="\
/C=RU\
/ST=Local\
/O=SBS_Local\
/OU=SBS_Local\
/CN=${SSL_DOMAIN_NAME}\
"
SSL_ALT_DOMAIN_NAMES="\
${SSL_DOMAIN_NAME}
www.${SSL_DOMAIN_NAME}
*.${SSL_DOMAIN_NAME}
"

echo -en " SSL_DOMAIN_NAME: ${SSL_DOMAIN_NAME}"

##### Show Banner

echo -en "
-----------------------------------
| SSL Self Signed Certs Generator |
-----------------------------------
\n"


##### Create Certs Directories

cd $DIR_SCRIPT_FULL_PATH
echo -en "====> Work Directory $DIR_SCRIPT_FULL_PATH
\n"


if [ -d "${CA_CERT_DIR_NAME}" ]; then
    echo -en "====> Using existing CA Certs Directory:
    \r./${CA_CERT_DIR_NAME}
    \n"

else
    echo -en "====> Create New CA Certs Directory: 
    \r./${CA_CERT_DIR_NAME}
    \n"
    mkdir ./${CA_CERT_DIR_NAME}

fi

if [ -d "${SSL_CERT_DIR_NAME}" ]; then
    echo -en "====> Using existing Certs Directory:
    \r./${SSL_CERT_DIR_NAME}
    \n"

else
    echo -en "====> Create New Certs Directory: 
    \r./${SSL_CERT_DIR_NAME}
    \n"
    mkdir ./${SSL_CERT_DIR_NAME}

fi


##### Create CA Key And CA Certificate

if [[ -e ./${CA_CERT_DIR_NAME}/${CA_KEY} ]] && [[ -e ./${CA_CERT_DIR_NAME}/${CA_CERT} ]]; then
    echo -en "====> Using Existing Old
    \rCA Key: ./${CA_CERT_DIR_NAME}/${CA_KEY}
    \rCA Certificate: ./${CA_CERT_DIR_NAME}/${CA_CERT}
    \n"

else
    echo -en "CA Key & CA Certificate Not EXIST !!!
    \n"
    
    echo -en "====> Generating New
    \rCA key ./${CA_CERT_DIR_NAME}/${CA_KEY}
    \rCA Certificate ./${CA_CERT_DIR_NAME}/${CA_CERT}
    \n"
    
    echo -en "
    \rCA_KEY: ${CA_KEY} 
    \rCA_CERT: ${CA_CERT}
    \rCA_EXPIRE: ${CA_EXPIRE}
    \rCA_SUBJECT: ${CA_SUBJECT}
    \n"
    
    openssl genpkey -algorithm RSA -out ./${CA_CERT_DIR_NAME}/${CA_KEY} -outform PEM -pkeyopt rsa_keygen_bits:4096
    
    openssl req \
    -x509 -new -nodes -sha256 \
    -days ${CA_EXPIRE} \
    -key ./${CA_CERT_DIR_NAME}/${CA_KEY} \
    -subj "${CA_SUBJECT}" \
    -out ./${CA_CERT_DIR_NAME}/${CA_CERT} || exit 1

fi


##### Create SSL Self Signed Key And CA Certificate

if [[ -e ./${SSL_CERT_DIR_NAME}/${SSL_KEY} ]] && [[ -e ./${SSL_CERT_DIR_NAME}/${SSL_CERT} ]]; then

    echo -en "====> Already Exist
    \rSSL Key: ./${SSL_CERT_DIR_NAME}/${SSL_KEY}
    \rSSL Certificate: ./${SSL_CERT_DIR_NAME}/${SSL_CERT}
    \n"

else
    echo -en "
    \rCA_KEY: ./${CA_CERT_DIR_NAME}/${CA_KEY} 
    \rCA_CERT: ./${CA_CERT_DIR_NAME}/${CA_CERT}
    \rSSL_EXPIRE: ${SSL_EXPIRE}
    \rSSL_SUBJECT: ${SSL_SUBJECT}
    \rSSL_ALT_DOMAIN_NAMES: ${SSL_ALT_DOMAIN_NAMES}
    \n"

    echo -en "====> Generating SSL Key
    \r./${SSL_CERT_DIR_NAME}/${SSL_KEY}
    \n"

    openssl genpkey -algorithm RSA -outform PEM -pkeyopt rsa_keygen_bits:4096 \
    -out ./${SSL_CERT_DIR_NAME}/${SSL_KEY}

    echo -en "====> Generating SSL Request
    \r./${SSL_CERT_DIR_NAME}/${SSL_CSR}
    \n"

    openssl req -new \
    -key ./${SSL_CERT_DIR_NAME}/${SSL_KEY} \
    -subj "${SSL_SUBJECT}" \
    -out ./${SSL_CERT_DIR_NAME}/${SSL_CSR} || exit 1

    echo -en "====> Generating SSL Extensions File
    \r./${SSL_CERT_DIR_NAME}/${SSL_EXT}
    \n"

    cat > ./${SSL_CERT_DIR_NAME}/${SSL_EXT} <<EOM
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
EOM

    if [[ -n ${SSL_ALT_DOMAIN_NAMES} ]]; then
        cat >> ./${SSL_CERT_DIR_NAME}/${SSL_EXT} <<EOM
subjectAltName = @alt_names
[alt_names]
EOM

        dns=(${SSL_ALT_DOMAIN_NAMES})
        for i in "${!dns[@]}"; do
            echo DNS.$((i+1)) = ${dns[$i]} >> ./${SSL_CERT_DIR_NAME}/${SSL_EXT}
        done
    fi

    echo -en "====> Generating SSL Certificate 
    \r./${SSL_CERT_DIR_NAME}/${SSL_CERT}
    \n"

    openssl x509 \
    -req -sha256 \
    -days ${SSL_EXPIRE} \
    -CAcreateserial \
    -CA ./${CA_CERT_DIR_NAME}/${CA_CERT} \
    -CAkey ./${CA_CERT_DIR_NAME}/${CA_KEY} \
    -in ./${SSL_CERT_DIR_NAME}/${SSL_CSR} \
    -extfile ./${SSL_CERT_DIR_NAME}/${SSL_EXT} \
    -out ./${SSL_CERT_DIR_NAME}/${SSL_CERT} || exit 1

    echo -en "\n====> Create Chain From SSL And CA Certs
    \r./${SSL_CERT_DIR_NAME}/${SSL_CERT_CHAIN}
    \n"
    
    cat ./${SSL_CERT_DIR_NAME}/${SSL_CERT} ./${CA_CERT_DIR_NAME}/${CA_CERT} >> ./${SSL_CERT_DIR_NAME}/${SSL_CERT_CHAIN} || exit 1

fi


##### Check SSL Key And Certificate Hash

echo -en "====> Check SSL Key And Certificate Hash
\r./${SSL_CERT_DIR_NAME}/${SSL_CERT}\n"
openssl x509 -noout -modulus -in ./${SSL_CERT_DIR_NAME}/${SSL_CERT} | openssl md5
    
echo -en "
\r./${SSL_CERT_DIR_NAME}/${SSL_KEY}\n"
openssl rsa -noout -modulus -in ./${SSL_CERT_DIR_NAME}/${SSL_KEY} | openssl md5


