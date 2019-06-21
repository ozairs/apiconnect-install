FROM coredns/coredns

ADD ./Corefile /etc/coredns/Corefile
ADD ./db.ozairs.fyre.ibm.com /etc/coredns/db.ozairs.fyre.ibm.com

EXPOSE 53
EXPOSE 9153

ENTRYPOINT ["/coredns"]
CMD ["-conf", "/etc/coredns/Corefile"]
