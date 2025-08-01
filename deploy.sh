./build.sh
aws ecs update-service --cluster cluster-bia --service services-bia  --force-new-deployment
