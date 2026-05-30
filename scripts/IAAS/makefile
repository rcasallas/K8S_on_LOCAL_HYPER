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
	@echo "HOSTNAME_LB: $(HOSTNAME_LB)"
	@hostname_lb_clean=$$(echo $(HOSTNAME_LB) | tr -d '"') ; \
	for HOSTNAME in $$hostname_lb_clean; do \
	echo "$$HOSTNAME - HOSTNAME"; \
	./deleteLB.sh "$$HOSTNAME"; \
	done
deleteVM:
	@echo "DATA_MASTER: $(DATA_MASTER)"
	@echo "DATA_WORKER: $(DATA_WORKER)"
	@for MASTER in $(DATA_MASTER); do \
		HOSTNAME=$$(echo $$MASTER | cut -d: -f1); \
		IPADDRESS=$$(echo $$MASTER | cut -d: -f2); \
		DNS_TMP="$(DNS_MASTER)"; \
		./deleteVM.sh "$$HOSTNAME"; \
	done
	@for WORKER in $(DATA_WORKER); do \
		HOSTNAME=$$(echo $$WORKER | cut -d: -f1); \
		IPADDRESS=$$(echo $$WORKER | cut -d: -f2); \
		DNS_TMP="$(DNS_WORKER)"; \
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
		IPADDRESS=$$(echo $$MASTER | cut -d: -f2); \
		IP_EXT=$$(echo $$MASTER | cut -d: -f3); \
		DNS_TMP="$(DNS_MASTER)"; \
		FIRST_MASTER=$$(echo $(HOSTNAME_MASTER) | tr -d '"' | awk '{print $$1}'); \
		NUM_MASTERS=$$(echo $(DATA_MASTER) | wc -w); \
		./startVM.sh --nameVM "$$HOSTNAME" --role master --IPAddressVM "$$IPADDRESS" --maskVM "$(MASK_MASTER)" --gatewayVM "$(GATEWAY_MASTER)" --dnsVM "$${DNS_TMP// /;}" --kubeadmToken "$$KUBEADM_TOKEN_DYN" --certificateKey "$$CERTIFICATE_KEY_DYN" --firstMaster "$$FIRST_MASTER" --numMasters "$$NUM_MASTERS" --ipExt "$$IP_EXT" --maskExt "$(MASK_EXT)" --gatewayExt "$(GATEWAY_EXT)" --dnsExt "$(DNS_EXT)" ; \
	done; \
	for WORKER in $(DATA_WORKER); do \
		HOSTNAME=$$(echo $$WORKER | cut -d: -f1); \
		IPADDRESS=$$(echo $$WORKER | cut -d: -f2); \
		IP_EXT=$$(echo $$WORKER | cut -d: -f3); \
		DNS_TMP="$(DNS_WORKER)"; \
		FIRST_MASTER=$$(echo $(HOSTNAME_MASTER) | tr -d '"' | awk '{print $$1}'); \
		NUM_MASTERS=$$(echo $(DATA_MASTER) | wc -w); \
		./startVM.sh --nameVM "$$HOSTNAME" --role worker --IPAddressVM "$$IPADDRESS" --maskVM "$(MASK_WORKER)" --gatewayVM "$(GATEWAY_WORKER)" --dnsVM "$${DNS_TMP// /;}" --kubeadmToken "$$KUBEADM_TOKEN_DYN" --certificateKey "$$CERTIFICATE_KEY_DYN" --firstMaster "$$FIRST_MASTER" --numMasters "$$NUM_MASTERS" --ipExt "$$IP_EXT" --maskExt "$(MASK_EXT)" --gatewayExt "$(GATEWAY_EXT)" --dnsExt "$(DNS_EXT)" ; \
	done; \
	FIRST_MASTER_IP=$$(echo $(MASTER_IP) | tr -d '"' | awk '{print $$1}'); \
	for WORKER in $(DATA_WORKER); do \
		HOSTNAME=$$(echo $$WORKER | cut -d: -f1); \
		echo "Waiting for worker $$HOSTNAME to join the cluster to label it..."; \
		while ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ../../keys/myKeys -l devopsadmin $$FIRST_MASTER_IP "kubectl get node $$HOSTNAME > /dev/null 2>&1"; do \
			sleep 10; \
		done; \
		echo "Labeling $$HOSTNAME as worker..."; \
		ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ../../keys/myKeys -l devopsadmin $$FIRST_MASTER_IP "kubectl label node $$HOSTNAME node-role.kubernetes.io/worker=worker --overwrite"; \
	done
startLB:
	@hostname_lb_clean=$$(echo $(HOSTNAME_LB) | tr -d '"') ; \
	ip_lb_clean=$$(echo $(LB_IP) | tr -d '"') ; \
	ip_ext_clean=$$(echo $(LB_IP_EXT) | tr -d '"') ; \
	prio_lb_clean=$$(echo $(KEEPALIVED_PRIORITIES) | tr -d '"') ; \
	hosts=($$hostname_lb_clean) ; \
	ips=($$ip_lb_clean) ; \
	ips_ext=($$ip_ext_clean) ; \
	prios=($$prio_lb_clean) ; \
	dns_relay=$$(echo $(DNS_RELAY) | tr -d '"' | tr ' ' ';') ; \
	len=$${#hosts[@]} ; \
	for (( i=0; i<$$len; i++ )); do \
	echo "Starting LB $${hosts[$$i]} with IP $${ips[$$i]} and Priority $${prios[$$i]}..." ; \
	./startLB.sh \
	--nameVM "$${hosts[$$i]}" \
	--role "primary" \
	--IPAddressVM "$${ips[$$i]}" \
	--maskVM "$(MASK_LB)" \
	--gatewayVM "$(GATEWAY_LB)" \
	--dnsVM "$(DNS_LB)" \
	--dnsRelay "$$dns_relay" \
	--keepalivedPriority "$${prios[$$i]}" \
	--ipExt "$${ips_ext[$$i]}" \
	--maskExt "$(MASK_EXT)" \
	--gatewayExt "$(GATEWAY_EXT)" \
	--dnsExt "$(DNS_EXT)" ; \
	done
listNICS:
	vboxmanage list hostonlyifs
