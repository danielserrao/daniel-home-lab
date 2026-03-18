# Load Balancing and routing

For load balancing and routing I use Gateway API, NGINX Gateway Fabric (NGF) and AWS Load Balancer (LB) Controller. Some notes on how it works:

- Gateway API allows creating multiple Kubernetes resources of type Gateway, each referencing a GatewayClass.

- NGF has a controller and a data plane (NGINX pods), typically exposed via a Kubernetes `Service`, often `LoadBalancer` when running in the cloud or `ClusterIP` when running locally.

- The NGF controller reconciles Gateways that reference its GatewayClass and programs the NGINX data plane based on each Gateway's listeners and routes.  

- The AWS LB Controller provisions an AWS load balancer for the annotated Kubernetes Service and forwards traffic to the NGINX data plane Service.

The same AWS load balancer can accept multiple hostnames, and the NGINX data plane then routes traffic to the correct Kubernetes Services according to the NGINX configuration.
