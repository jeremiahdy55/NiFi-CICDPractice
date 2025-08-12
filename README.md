# NiFi-CICDPractice

# STEPS (make me pretty later)
- Setup terraform instance (standard setup)
- SSH into terraform instance and put .pem key file corresponding to the same key used for the instances that will be provisioned (place in both `/terraform` and `/terraform/ansible`)
```
terraform apply --auto-approve
sh generate_ansible_files.sh <PRIVATE KEY PATH> nifi-1.26.0
```
```
cd ansible
ansible-playbook -i inventory.ini configure_ec2instances.yml
```
```
cd ../../..
aws eks update-kubeconfig --region us-west-2 --name my-eks-cluster
kubectl apply -f k8s/aws-auth.yaml
```
The last line will allow the Jenkins instance to access the eks cluster.


after this, Jenkins will be running. SSH or connect to the EC2 instance manually and obtain the auto-generated admin password. Install recommended plugins. Add SSH Agent plugin. Add a maven version in "Tools" named {maven3.9.3}. Configure `github_credentials`, `dockerhub_credentials`, and `nifi_ssh_key`.
Create the jenkins job. Build.
-------------------------------------------------------------------------------------
in terraform, after successful jenkins build, in the `/ansible` directory.
```
ansible-playbook -i inventory.ini start_nifi.yml
```
Get the public ip for the nifi server either using console or terraform output
Use port 8080/8443.
NiFi should be up

Other, get the public URL for the K8S load balancer exposed by service.yaml. Access using that URL + `/nifi`.
