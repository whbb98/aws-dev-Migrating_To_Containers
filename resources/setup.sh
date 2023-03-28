#!/bin/bash
sudo yum -y remove python36
sudo yum -y install python38
sudo update-alternatives --set python /usr/bin/python3.8
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm awscliv2.zip
sudo pip install boto3

#delete old key if exists
existingKeys=$(aws secretsmanager list-secrets --output text | grep c9key)
if [[ "$existingKeys" != "" ]]; then
  acctId=$(curl http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | cut -d '"' -f4)
  aws secretsmanager delete-secret --secret-id arn:aws:secretsmanager:us-east-1:$acctId:secret:c9key --force-delete-without-recovery --region us-east-1
fi
#create a new key
ssh-keygen -b 2048 -t rsa -f /home/ec2-user/.ssh/id_rsa -q -N ""
#add the key to Cloud9 ssh client
sudo cat /home/ec2-user/.ssh/id_rsa.pub >> /home/ec2-user/.ssh/authorized_keys
#encode the key
base64 /home/ec2-user/.ssh/id_rsa > /home/ec2-user/.ssh/id_rsa-encoded
#place the key where grading script can find it
aws secretsmanager create-secret --name c9key --secret-string file:///home/ec2-user/.ssh/id_rsa-encoded --region us-east-1
#Open port 22 on Cloud9 instance so grading script can access it
c9sgId=$(aws ec2 describe-security-groups --filters Name=tag:Name,Values=*Cloud9* | grep GroupId | cut -d '"' -f4)
aws ec2 authorize-security-group-ingress \
    --group-id $c9sgId \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

#config Docker to write to syslog by creating this file
echo '{"log-driver": "syslog"}' | sudo tee -a /etc/docker/daemon.json
#restart Docker
#sudo systemctl restart docker
sudo service docker restart
