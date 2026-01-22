## objective

ssh hosts schrep-ofin, ashia-lxc

schrep-ofin has docker containers that run monitoring and security, in the container namespace manager-

the objective is to replicate the monitoring and security from schrep-ofin onto ashia-lxc

challenges: schrep-ofin runs docker containers with caddy as a proxy
- ashia-lxc run dokploy that uses traefik as proxy
- implementations for monitory and security should account for this 

prepare a plan to replicate and implement monitoring and security on ashia-lxc based on what is found on schrep-ofin
- prepare a plan file with detailed steps and identify possible challenges and potentials remdiations
- use standard problem solving techniques, tools and methddologies 

- create a dokploy compose project that replicate the manager compose project from schrep-ofin on ashia-lxc
- also replicate security for services like crowdsec from schrep-ofin to ashia-lxc

## ashia-lxc
- dokploy dir :/etc/dokploy

## api key for dokploy
gemikyYvJzGmKnqSxXlxFMnwMMLRQaVFJCJscRMboQwNcHphdPxdranDbTIeJOPTptKnO


## open api spec for dokploy

