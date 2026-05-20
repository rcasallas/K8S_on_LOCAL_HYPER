#VBoxManage storagectl "Nombre_de_tu_VM" --name "NVMe Controller" --portcount 8
#VBoxManage list hdds
# Busca el UUID del disco que apunte a esa ruta y luego:
#VBoxManage closemedium disk <UUID> --delete

SHELL := /bin/bash

# Include sensitive data from CONFIG.mk
-include CONFIG.mk
-include LB.mk
export MASTER_IP
export HOSTNAME_MASTER

export WORKER_IP
export HOSTNAME_WORKER

generate-hosts:
	@echo "Generando archivo hosts en ../../dynamic/hosts..."
	@mkdir -p ../../dynamic
	@echo "127.0.0.1       localhost             localhost.localdomain localhost4 localhost4.localdomain4" > ../../dynamic/hosts
	@echo "::1             localhost             localhost.localdomain localhost6 localhost6.localdomain6" >> ../../dynamic/hosts
	@master_ip_clean=$$(echo $(MASTER_IP) | tr -d '"') ; \
	hostname_master_clean=$$(echo $(HOSTNAME_MASTER) | tr -d '"') ; \
	ips=($$master_ip_clean) ; \
	hosts=($$hostname_master_clean) ; \
	len_master_ip=$${#ips[@]} ; \
	len_hostname_master=$${#hosts[@]} ; \
	if [[ $$len_master_ip -ne $$len_hostname_master ]]; then \
	echo "Error: The number of master IPs does not match the number of master hostnames." ; \
	exit 1 ; \
	fi ; \
	for (( i=0; i<$$len_master_ip; i++ )); do \
	echo "$${ips[$$i]}   $${hosts[$$i]}" >> ../../dynamic/hosts ; \
	done


	@worker_ip_clean=$$(echo $(WORKER_IP) | tr -d '"') ; \
	hostname_worker_clean=$$(echo $(HOSTNAME_WORKER) | tr -d '"') ; \
	ips=($$worker_ip_clean) ; \
	hosts=($$hostname_worker_clean) ; \
	len_worker_ip=$${#ips[@]} ; \
	len_hostname_worker=$${#hosts[@]} ; \
	if [[ $$len_worker_ip -ne $$len_hostname_worker ]]; then \
		echo "Error: The number of worker IPs does not match the number of worker hostnames." ; \
	exit 1 ; \
	fi ; \
	for (( i=0; i<$$len_worker_ip; i++ )); do \
	echo "$${ips[$$i]}   $${hosts[$$i]}" >> ../../dynamic/hosts ; \
	done
	@echo "Archivo hosts generado correctamente."

deleteLB:
	@hostname_lb_clean=$$(echo $(HOSTNAME_LB) | tr -d '"') ; \
	for HOSTNAME in $$hostname_lb_clean; do \
	echo "$$HOSTNAME - HOSTNAME"; \
	./deleteLB.sh "$$HOSTNAME"; \
	done
deleteVM:


	@for MASTER in $(DATA_MASTER); do \
		HOSTNAME=$$(echo $$MASTER | cut -d: -f1); \
		#echo "hostname - $$HOSTNAME"; \
		IPADDRESS=$$(echo $$MASTER | cut -d: -f2); \
		#echo "$$IPADDRESS - IPAddressVM"; \
		#echo "$(MASK_MASTER) - mask"; \
		#echo "$(GATEWAY_MASTER) - gateway"; \
		DNS_TMP="$(DNS_MASTER)"; \
		#echo "$${DNS_TMP// /;} - dns"; \
		#echo "$(HTTP_PROTO_IGNITION) - httpProtocolIgnition"; \
		#echo "$(HTTP_IP_IGNITION) - IPAddressHttpIgnition"; \
		#echo "$(HTTP_PORT_IGNITION) - httpPortIgnition"; \
		#echo "$(OVA_FILE) - OVAFILE"; \
		#echo "$(K8S_VERSION) - k8s_version"; \
		./deleteVM.sh "$$HOSTNAME"; \
	done


	@for WORKER in $(DATA_WORKER); do \
		HOSTNAME=$$(echo $$WORKER | cut -d: -f1); \
		#echo "hostname - $$HOSTNAME"; \
		IPADDRESS=$$(echo $$WORKER | cut -d: -f2); \
		#echo "$$IPADDRESS - IPAddressVM"; \
		#echo "$(MASK_WORKER) - mask"; \
		#echo "$(GATEWAY_WORKER) - gateway"; \
		DNS_TMP="$(DNS_WORKER)"; \
		#echo "$${DNS_TMP// /;} - dns"; \
		#echo "$(HTTP_PROTO_IGNITION) - httpProtocolIgnition"; \
		#echo "$(HTTP_IP_IGNITION) - IPAddressHttpIgnition"; \
		#echo "$(HTTP_PORT_IGNITION) - httpPortIgnition"; \
		#echo "$(OVA_FILE) - OVAFILE"; \
		#echo "$(K8S_VERSION) - k8s_version"; \
		./deleteVM.sh "$$HOSTNAME"; \
	done
startVM:

	@echo "DATA_MASTER: $(DATA_MASTER)"
	@echo "DATA_WORKER: $(DATA_WORKER)"

	@KUBEADM_TOKEN_DYN=$$(openssl rand -hex 3).$$(openssl rand -hex 8); \
	CERTIFICATE_KEY_DYN=$$(openssl rand -hex 32); \
	echo "Generated Kubeadm Token: $$KUBEADM_TOKEN_DYN"; \
	echo "Generated Certificate Key: $$CERTIFICATE_KEY_DYN"; \
	for MASTER in $(DATA_MASTER); do \
		HOSTNAME=$$(echo $$MASTER | cut -d: -f1); \
		#echo "hostname - $$HOSTNAME"; \
		IPADDRESS=$$(echo $$MASTER | cut -d: -f2); \
		#echo "$$IPADDRESS - IPAddressVM"; \
		#echo "$(MASK_MASTER) - mask"; \
		#echo "$(GATEWAY_MASTER) - gateway"; \
		DNS_TMP="$(DNS_MASTER)"; \
		#echo "$${DNS_TMP// /;} - dns"; \
		#echo "$(HTTP_PROTO_IGNITION) - httpProtocolIgnition"; \
		#echo "$(HTTP_IP_IGNITION) - IPAddressHttpIgnition"; \
		#echo "$(HTTP_PORT_IGNITION) - httpPortIgnition"; \
		#echo "$(HTTP_PROTO_CA) - httpProtocolCA"; \
		#echo "$(HTTP_PORT_CA) - httpPortCA"; \
		#echo "$(OVA_FILE) - OVAFILE"; \
		FIRST_MASTER=$$(echo $(HOSTNAME_MASTER) | tr -d '"' | awk '{print $$1}'); \
		NUM_MASTERS=$$(echo $(DATA_MASTER) | wc -w); \
		./startVM.sh --nameVM "$$HOSTNAME" --role master --prefixButaneIgnitionName preconfig --IPAddressVM "$$IPADDRESS" --maskVM "$(MASK_MASTER)" --gatewayVM "$(GATEWAY_MASTER)" --dnsVM "$${DNS_TMP// /;}"  --httpProtocolIgnition "$(HTTP_PROTO_IGNITION)" --IPAddressHttpIgnition "$(HTTP_IP_IGNITION)" --httpPortIgnition "$(HTTP_PORT_IGNITION)" --HTTP_PROTO_CA "$(HTTP_PROTO_CA)" --HTTP_PORT_CA "$(HTTP_PORT_CA)" --OVAFILE "$(OVA_FILE)" --k8s_version "$(K8S_VERSION)" --endpointIP "$(ENDPOINT_IP)" --endpointHost "$(ENDPOINT_HOST)" --endpointPort "$(ENDPOINT_PORT)" --prefixMaster "$(PREFIX_MASTER)" --authorizationUser "$(HTTP_USER_IGNITION)" --authorizationPassword "$(HTTP_PASSWORD_IGNITION)" --kubeadmToken "$$KUBEADM_TOKEN_DYN" --certificateKey "$$CERTIFICATE_KEY_DYN" --firstMaster "$$FIRST_MASTER" --ciliumVersion "$(CILIUM_VERSION)" --numMasters "$$NUM_MASTERS" --SUBNET_POD "$(SUBNET_POD)" --SUBNET_SERVICE "$(SUBNET_SERVICE)"; \
	done; \
	for WORKER in $(DATA_WORKER); do \
		HOSTNAME=$$(echo $$WORKER | cut -d: -f1); \
		#echo "hostname - $$HOSTNAME"; \
		IPADDRESS=$$(echo $$WORKER | cut -d: -f2); \
		#echo "$$IPADDRESS - IPAddressVM"; \
		#echo "$(MASK_WORKER) - mask"; \
		#echo "$(GATEWAY_WORKER) - gateway"; \
		DNS_TMP="$(DNS_WORKER)"; \
		#echo "$${DNS_TMP// /;} - dns"; \
		#echo "$(HTTP_PROTO_IGNITION) - httpProtocolIgnition"; \
		#echo "$(HTTP_IP_IGNITION) - IPAddressHttpIgnition"; \
		#echo "$(HTTP_PORT_IGNITION) - httpPortIgnition"; \
		#echo "$(HTTP_PROTO_CA) - httpProtocolCA"; \
		#echo "$(HTTP_PORT_CA) - httpPortCA"; \
		#echo "$(OVA_FILE) - OVAFILE"; \
		FIRST_MASTER=$$(echo $(HOSTNAME_MASTER) | tr -d '"' | awk '{print $$1}'); \
		NUM_MASTERS=$$(echo $(DATA_MASTER) | wc -w); \
		./startVM.sh --nameVM "$$HOSTNAME" --role worker --prefixButaneIgnitionName preconfig --IPAddressVM "$$IPADDRESS" --maskVM "$(MASK_WORKER)" --gatewayVM "$(GATEWAY_WORKER)" --dnsVM "$${DNS_TMP// /;}"  --httpProtocolIgnition "$(HTTP_PROTO_IGNITION)" --IPAddressHttpIgnition "$(HTTP_IP_IGNITION)" --httpPortIgnition "$(HTTP_PORT_IGNITION)" --HTTP_PROTO_CA "$(HTTP_PROTO_CA)" --HTTP_PORT_CA "$(HTTP_PORT_CA)" --OVAFILE "$(OVA_FILE)" --k8s_version "$(K8S_VERSION)" --endpointIP "$(ENDPOINT_IP)" --endpointHost "$(ENDPOINT_HOST)" --endpointPort "$(ENDPOINT_PORT)" --prefixMaster "$(PREFIX_MASTER)" --authorizationUser "$(HTTP_USER_IGNITION)" --authorizationPassword "$(HTTP_PASSWORD_IGNITION)" --kubeadmToken "$$KUBEADM_TOKEN_DYN" --certificateKey "$$CERTIFICATE_KEY_DYN" --firstMaster "$$FIRST_MASTER" --ciliumVersion "$(CILIUM_VERSION)" --numMasters "$$NUM_MASTERS" --SUBNET_POD "$(SUBNET_POD)" --SUBNET_SERVICE "$(SUBNET_SERVICE)"; \
	done; \
	FIRST_MASTER=$$(echo $(HOSTNAME_MASTER) | tr -d '"' | awk '{print $$1}'); \
	for WORKER in $(DATA_WORKER); do \
		HOSTNAME=$$(echo $$WORKER | cut -d: -f1); \
		echo "Waiting for worker $$HOSTNAME to join the cluster to label it..."; \
		while ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ../../keys/myKeys -l devopsadmin $$FIRST_MASTER "kubectl get node $$HOSTNAME > /dev/null 2>&1"; do \
			sleep 10; \
		done; \
		echo "Labeling $$HOSTNAME as worker..."; \
		ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ../../keys/myKeys -l devopsadmin $$FIRST_MASTER "kubectl label node $$HOSTNAME node-role.kubernetes.io/worker=worker --overwrite"; \
	done
	
startLB:
	@hostname_lb_clean=$$(echo $(HOSTNAME_LB) | tr -d '"') ; \
	ip_lb_clean=$$(echo $(LB_IP) | tr -d '"') ; \
	prio_lb_clean=$$(echo $(KEEPALIVED_PRIORITIES) | tr -d '"') ; \
	hosts=($$hostname_lb_clean) ; \
	ips=($$ip_lb_clean) ; \
	prios=($$prio_lb_clean) ; \
	dns_relay=$$(echo $(DNS_RELAY) | tr -d '"' | tr ' ' ';') ; \
	len=$${#hosts[@]} ; \
	for (( i=0; i<$$len; i++ )); do \
	echo "Starting LB $${hosts[$$i]} with IP $${ips[$$i]} and Priority $${prios[$$i]}..." ; \
	./startLB.sh \
	--nameVM "$${hosts[$$i]}" \
	--role "primary" \
	--prefixButaneIgnitionName "preconfig" \
	--IPAddressVM "$${ips[$$i]}" \
	--maskVM "$(MASK_LB)" \
	--gatewayVM "$(GATEWAY_LB)" \
	--dnsVM "$(DNS_LB)" \
	--dnsRelay "$$dns_relay" \
	--prefixLB "$(PREFIX_LB)" \
	--keepalivedPriority "$${prios[$$i]}" \
	--keepalivedNic "$(KEEPALIVED_NIC)" \
	--httpProtocolIgnition "$(HTTP_PROTO_IGNITION)" \
	--IPAddressHttpIgnition "$(HTTP_IP_IGNITION)" \
	--httpPortIgnition "$(HTTP_PORT_IGNITION)" \
	--OVAFILE "$(OVA_FILE)" \
	--vip_lb "$(LB_VIP_IP)" \
	--keepalivedPass "$(KEEPALIVED_PASS)" \
	--configK8S "CONFIG.mk" \
	--authorizationUser "$(HTTP_USER_IGNITION)" \
	--authorizationPassword "$(HTTP_PASSWORD_IGNITION)" \
	--HTTP_PROTO_CA "$(HTTP_PROTO_CA)" \
	--HTTP_PORT_CA "$(HTTP_PORT_CA)" ; \
	done
listNICS:
	vboxmanage list hostonlyifs
