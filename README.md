# gwlb-debug-script
A script to reproduce gateway load balancer endpoint creation error 

When create AWS Gateway Load Balancer endpoint, there is a bug that GWLB endpoint craetion will fail.
If the GWLB is created immediatly after GWLB endpoint service creation, first a few calls may fail. 
Manual creation probably won't be an issue. Programtic creation will likly trigger it.
