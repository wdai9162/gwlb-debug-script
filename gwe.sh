#!/bin/bash

echo "Please input CloudFormation template:"
read -p 'CF File name: ' cftemp

stack_id=$(aws cloudformation create-stack --stack-name gw-endpoint-test-2 --template-body file://$cftemp --region us-east-1 | jq -r '.StackId')

echo 'CloudFormation stack ID: ' $stack_id
echo 'Awaiting for GatewayLoadBalancer Endpoint Service to be created...' 



while true 
  do
  read service_id resource_status last_updated_timestamp < <(echo $(aws cloudformation describe-stack-resource --stack-name $stack_id --logical-resource-id GatewayLoadBalancerEndpointService --region us-east-1 | jq -r '.StackResourceDetail.PhysicalResourceId, .StackResourceDetail.ResourceStatus, .StackResourceDetail.LastUpdatedTimestamp'))
  
  printf '%s： ' "$(date +'%Y-%m-%dT%H:%M:%S %Z')" 
  echo "LastUpdatedTimestamp: $last_updated_timestamp; ResourceStatus: $resource_status; EndpointServiceId: $service_id;"
  echo 
  if [ ! -z "$service_id" ] && [ $resource_status = "CREATE_COMPLETE" ]
  then 
    printf '%s： ' "$(date +'%Y-%m-%dT%H:%M:%S %Z')" 
    echo 'GatewayLoadBalancer Endpoint Service created, see below Service State:' 
    break
  fi
done

printf '%s： ' "$(date +'%Y-%m-%dT%H:%M:%S %Z')" 
echo "$ aws ec2 describe-vpc-endpoint-service-configurations --service-ids $service_id --region us-east-1"
#aws ec2 describe-vpc-endpoint-service-configurations --service-ids $service_id --region us-east-1
#service_name=$(aws ec2 describe-vpc-endpoint-service-configurations --service-ids $service_id --region us-east-1 | jq -r ".ServiceConfigurations[0].ServiceName")

read service_name describe_vpc_endpoint_service_configurations_output < <(echo $(aws ec2 describe-vpc-endpoint-service-configurations --service-ids $service_id --region us-east-1 | jq -r ".ServiceConfigurations[0].ServiceName, ."))

printf '%s： ' "$(date +'%Y-%m-%dT%H:%M:%S %Z')" 
echo $describe_vpc_endpoint_service_configurations_output | jq .

printf '%s： ' "$(date +'%Y-%m-%dT%H:%M:%S %Z')" 
echo "Creating VPC endpoint now: "
read subnet_id vpc_id < <(echo $(aws cloudformation describe-stack-resources --stack-name $stack_id --region us-east-1 | jq -r '.StackResources[] | select((.LogicalResourceId | contains("VPC")) or (.LogicalResourceId | contains("DataSubnet0"))).PhysicalResourceId'))
read vpc_endpoint_id creation_timestamp create_vpc_endpoint < <(echo $(aws ec2 create-vpc-endpoint --vpc-id $vpc_id --subnet-ids $subnet_id --vpc-endpoint-type GatewayLoadBalancer --service-name $service_name --region us-east-1 | jq -r ".VpcEndpoint.VpcEndpointId, .VpcEndpoint.CreationTimestamp, ."))

printf '%s： ' "$(date +'%Y-%m-%dT%H:%M:%S %Z')" 
echo $create_vpc_endpoint | jq .

for i in 1 2 3 4 5
do
   printf '%s： ' "$(date +'%Y-%m-%dT%H:%M:%S %Z')"
   aws ec2 create-vpc-endpoint --vpc-id $vpc_id --subnet-ids $subnet_id --vpc-endpoint-type GatewayLoadBalancer --service-name $service_name --region us-east-1
   sleep 2
done

while true 
  do   
  read endpoint_state describe_vpc_endpoints < <(echo $(aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $vpc_endpoint_id --region us-east-1 | jq -r ".VpcEndpoints[0].State, .")) 
  if [ $endpoint_state != "pending" ]
  then
    printf '%s： ' "$(date +'%Y-%m-%dT%H:%M:%S %Z')"
    aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $vpc_endpoint_id --region us-east-1 | jq .
  break
  fi
done
