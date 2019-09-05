{
    "registry_type": "lur",
    "name": "local-user-registry",
    "title": "local-user-registry",
    "summary": "",
    "case_sensitive": false,
    "identity_providers": [
        {
            "title": "local-user-registry",
            "name": "local-user-registry"
        }
    ],
    "integration_url": "https://manager.apic2018.tor01.containers.appdomain.cloud/api/cloud/integrations/user-registry/e16755ba-86ab-4d04-af56-83c5364b97eb"
}


{
    "identity_providers": [
        {
            "name": "ldap-user-registry",
            "title": "ldap-user-registry"
        }
    ],
    "name": "ldap-user-registry",
    "title": "ldap-user-registry",
    "case_sensitive": false,
    "endpoint": {
        "endpoint": "ldap://ldaphost:389",
        "tls_client_profile_url": null
    },
    "configuration": {
        "authentication_method": "compose_dn",
        "authenticated_bind": "false",
        "search_dn_base": "ibm",
        "protocol_version": "3",
        "bind_prefix": "ibm",
        "bind_suffix": "cd"
    },
    "registry_type": "ldap",
    "integration_url": "https://manager.apic2018.tor01.containers.appdomain.cloud/api/cloud/integrations/user-registry/1e830ee9-10fa-41f6-9bf6-cf295de69321"
}