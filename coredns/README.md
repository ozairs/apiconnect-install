# CoreDNS

CoreDNS is a customizable DNS server that provides name resolution services. As of Kubernetes 1.11, it is the default DNS service replacing KubeDNS.

CoreDNS allows you to create custom hostname to IP address mappings for your Kubernetes cluster. You can two options to configure CoreDNS

1. Modify the default CoreDNS container
2. Run a seperate CoreDNS container

## Option 1. Modify the default CoreDNS container

In this approach, you use the existing CoreDNS containers in your Kubernetes master node and modify its configuration to include custom hostname to IP address mappings.

1. View existing CoreDNS containers

```
    > kubectl get configmap -n kube-system
    NAME                                 DATA   AGE
    calico-config                        2      26h
    coredns                              2      26h

```

2. View the existing `coredns` configuration

```
    > kubectl describe configmap -n kube-system

```

3. Create a backup of the default configuration, simply copy and paste the contents into another file.

4. Before you build a CoreDNS config map, you will need the API Connect subsystem names from `apiconnect-up.yaml` file.
 - Gateway: apigateway.ozairs.fyre.ibm.com apigateway-service.ozairs.fyre.ibm.com
 - Analytics: analytics-client.ozairs.fyre.ibm.com analytics-ingestion.ozairs.fyre.ibm.com
 - Manager: platform.ozairs.fyre.ibm.com consumer.ozairs.fyre.ibm.com cloud.ozairs.fyre.ibm.com manager.ozairs.fyre.ibm.com
 - Portal: portal-admin.ozairs.fyre.ibm.com portal.cluster.ozairs.fyre.ibm.com

You will build the CoreDNS in sections, create a file named `coredns-k8.yaml`:

5. Part 1: Copy and paste the contents below:

    ```
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: coredns
      namespace: kube-system
    data:
    Corefile: |
        .:53 {
            errors
            health
            kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            upstream
            fallthrough in-addr.arpa ip6.arpa
            }
            prometheus :9153
            proxy . /etc/resolv.conf
            cache 30
            loop
            reload
            loadbalance
        }
    ```

6. Part 2, replace the sub-domain (ie `ozairs.fyre.ibm.com:53`) with your sub-domain (`mydomain:53`) and the filename to reflect your subdomain (`db.ozairs.fyre.ibm.com`)

    ```
    ozairs.fyre.ibm.com:53 {
      file /etc/coredns/db.ozairs.fyre.ibm.com
      errors
      log . {
        class denial
        class success
      }
    }
    ```

7. Part 3, replace the environment-specific entries in the snippet below:
  - filename: db.ozairs.fyre.ibm.com
  - origin: ozairs.fyre.ibm.com
  - DNS entry: manager IN A 10.31.19.175 ;9.24.160.16

    ```
    db.ozairs.fyre.ibm.com: |
        $ORIGIN ozairs.fyre.ibm.com.
        @     3600 IN    SOA sns.dns.icann.org. noc.dns.icann.org. (
                2017042745 ; serial
                7200       ; refresh (2 hours)
                3600       ; retry (1 hour)
                1209600    ; expire (2 weeks)
                3600       ; minimum (1 hour)
            )

            3600 IN NS a.iana-servers.net.
            3600 IN NS b.iana-servers.net.

        manager          IN A     10.31.19.175 ;9.24.160.16
        cloud            IN A     10.31.19.175 ;9.24.160.16
        platform         IN A     10.31.19.175 ;9.24.160.16
        consumer         IN A     10.31.19.175 ;9.24.160.16
        gateway          IN A     10.31.19.175 ;9.24.160.16
        gateway-service  IN A     10.31.19.175 ;9.24.160.16
        portal           IN A     10.31.19.175 ;9.24.160.16
        portal-admin     IN A     10.31.19.175 ;9.24.160.16
        analytics-ingest IN A     10.31.19.175 ;9.24.160.16
        analytics-client IN A     10.31.19.175 ;9.24.160.16
    ```

8. The final file is shown below:

    ```
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: coredns
      namespace: kube-system
    data:
      Corefile: |
        .:53 {
            errors
            health
            kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            upstream
            fallthrough in-addr.arpa ip6.arpa
            }
            prometheus :9153
            proxy . /etc/resolv.conf
            cache 30
            loop
            reload
            loadbalance
        }
        ozairs.fyre.ibm.com:53 {
        file /etc/coredns/db.ozairs.fyre.ibm.com
        errors
        log . {
            class denial
            class success
        }
        }
    db.ozairs.fyre.ibm.com: |
        $ORIGIN ozairs.fyre.ibm.com.
        @     3600 IN    SOA sns.dns.icann.org. noc.dns.icann.org. (
                2017042745 ; serial
                7200       ; refresh (2 hours)
                3600       ; retry (1 hour)
                1209600    ; expire (2 weeks)
                3600       ; minimum (1 hour)
            )

            3600 IN NS a.iana-servers.net.
            3600 IN NS b.iana-servers.net.

        manager          IN A     10.31.19.175 ;9.24.160.16
        cloud            IN A     10.31.19.175 ;9.24.160.16
        platform         IN A     10.31.19.175 ;9.24.160.16
        consumer         IN A     10.31.19.175 ;9.24.160.16
        gateway          IN A     10.31.19.175 ;9.24.160.16
        gateway-service  IN A     10.31.19.175 ;9.24.160.16
        portal           IN A     10.31.19.175 ;9.24.160.16
        portal-admin     IN A     10.31.19.175 ;9.24.160.16
        analytics-ingest IN A     10.31.19.175 ;9.24.160.16
        analytics-client IN A     10.31.19.175 ;9.24.160.16
    ```

9. Apply the `coredns` config map 

    ```
    kubectl apply -f coredns-k8.yaml
    ```

10. You will need to modify the existing coredns deployment to include the above file (`db.ozairs.fyre.ibm.com`) - modify the name to reflect your environment. Edit the `volumes` section of the Pod template spec:

```
> kubectl edit deployment coredns -n kube-system


volumes:
- name: config-volume
    configMap:
    name: coredns
    items:
    - key: Corefile
      path: Corefile
    - key: db.ozairs.fyre.ibm.com
      path: db.ozairs.fyre.ibm.com

```

11. The coredns containers will restart. It will take 2 minutes for the changes to apply.

    ```
    > kubectl get pods -n kube-system
    NAME                                                     READY   STATUS    RESTARTS   AGE
    calico-node-58jl5                                        2/2     Running   0          26h
    coredns-75d687d9fc-prtpz                                 1/1     Running   2          5h3m
    coredns-75d687d9fc-v488d                                 1/1     Running   2          5h3m

    ```

## Option 2.Run a seperate CoreDNS container

1. Modify the `Corefile` to update the names (`ozairs.fyre.ibm.com`) in the file. You can follow the same pattern if you want to add multiple files.

2. Perform a build of the image
    ```
    docker build -t coredns:1.0.0 .
    ```

3. Run the container on port 53
    ```
    docker run --restart unless-stopped -d -p 53:53 -p 53:53/udp coredns:1.0.0
    ```

4. Modify `/etc/resolvconf/resolv.conf.d/head` with the IP address of the host machine where the container is running

    ```
    options rotate
    options timeout:1
    nameserver 9.1.2.3
    ```

5. Restart your network interface `invoke-rc.d networking restart`

6. Verify that your DNS server appears

    ```
    cat  /etc/resolv.conf
    # Dynamic resolv.conf(5) file for glibc resolver(3) generated by resolvconf(8)
    #     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
    options rotate
    options timeout:1
    nameserver 9.1.2.3
    ```
Note: Alternative (to step 4-6), you can modify the CoreDNS configuration and point to the CoreDNS container via the `upstream` configuration, see [here](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/#configuration-of-stub-domain-and-upstream-nameserver-using-coredns)

## Reference

- https://coredns.io/2017/05/08/custom-dns-entries-for-kubernetes/
- https://kubernetes.io/docs/tasks/administer-cluster/coredns/
- https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/#coredns-configmap-options