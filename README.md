# NiFi-CICDPractice

- Setup EC2 Terraform instance with at least 24GB and t2.medium [see previous terraform setup steps here](https://github.com/jeremiahdy55/DevOps-CICDProject/blob/main/README.md)
- SFTP into Terraform instance and put `.pem` key file corresponding to the same key used for the instances that will be provisioned (place in both `/terraform` and `/terraform/ansible`)
  - NOTE: this key is provided explicitly in `variables.tf` as `key_name`. It will be pulled directly from AWS if a key exists on this account with the given name.
- Run Terraform and generate the dynamically created Ansible scripts to setup the Jenkins and manual NiFi instances

```
terraform apply --auto-approve
sh generate_ansible_files.sh <PRIVATE KEY PATH> nifi-1.26.0
```

- After generating the Ansible scripts, `cd` into `/ansible` to run them and configure the Jenkins and manual NiFi instance.

```
cd ansible
ansible-playbook -i inventory.ini configure_ec2instances.yml
```

- Manually set the region and name where the EKS cluster will live. It will also use the AWS account as additional identifying data. Remember that each cluster's name must be unique per region. Finally, prepare  the EKS nodegroup to be accessed by Jenkins using the `aws-auth.yaml` file. 

```
cd ../../..
aws eks update-kubeconfig --region us-west-2 --name my-eks-cluster
kubectl apply -f k8s/aws-auth.yaml
```

After all this, Jenkins will be running. SSH or connect to the EC2 instance manually and obtain the auto-generated admin password (i.e. follow the instructions that Jenkins will tell you). Afterwards:
 - Install recommended plugins.
 - Add SSH Agent plugin.
 - Add a maven version in "Tools" named {maven3.9.3}.
 - Configure credentials:
   - `github_credentials` as password
   - `dockerhub_credentials` as password
   - `nifi_ssh_key` as SSH key

Finally, create the Jenkins job using this Github repository from GIT SCM. Remember to change form `/master` to `/main`. Use default settings for the rest. Then run the job. The EKS cluster should now be running after about 20-30 minutes. Retrieve the public URL for the K8S load balancer exposed by `service.yaml` by running:
```
kubectl get svc -n nifi
```
Access the NiFI Application by using that URL + `/nifi`.
---

In the Terraform instance, after a successful Jenkins build, in the `/ansible` directory:
```
ansible-playbook -i inventory.ini start_nifi.yml
```
This will start the manual NiFi instance. You can retrieve the manual NiFi instance's public IP either from the AWS Console Home UI or by using `terraform output`. Please use port 8080 OR 8083. The NiFi application should be running on that public IP with the exposed port.


