$ORIGIN ozairs.fyre.ibm.com.
@    3600 IN    SOA sns.dns.icann.org. noc.dns.icann.org. (
                2017042745 ; serial
                7200       ; refresh (2 hours)
                3600       ; retry (1 hour)
                1209600    ; expire (2 weeks)
                3600       ; minimum (1 hour)
                )

    3600 IN NS a.iana-servers.net.
    3600 IN NS b.iana-servers.net.

manager          IN A     10.1.2.3 ;9.1.2.3
cloud            IN A     10.1.2.3 ;9.1.2.3
platform         IN A     10.1.2.3 ;9.1.2.3
consumer         IN A     10.1.2.3 ;9.1.2.3
gateway          IN A     10.1.2.3 ;9.1.2.3
gateway-service  IN A     10.1.2.3 ;9.1.2.3
portal           IN A     10.1.2.3 ;9.1.2.3
portal-admin     IN A     10.1.2.3 ;9.1.2.3
analytics-ingest IN A     10.1.2.3 ;9.1.2.3
analytics-client IN A     10.1.2.3 ;9.1.2.3