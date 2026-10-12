.PHONY: preflight deploy deploy-hybrid deploy-frr verify failover status destroy graph

TOPO_SRL := topology.clab.yml
TOPO_HYBRID := topology-hybrid-srl-frr.clab.yml
TOPO_FRR := topology-frr.clab.yml

preflight:
	@bash scripts/host-preflight.sh

deploy: preflight
	@bash scripts/deploy.sh $(TOPO_SRL)

deploy-hybrid: preflight
	@bash scripts/deploy.sh $(TOPO_HYBRID)

deploy-frr: preflight
	@bash scripts/deploy.sh $(TOPO_FRR)

verify:
	@bash scripts/verify-all.sh

failover:
	@bash scripts/failover-chaos-test.sh

status:
	@sudo containerlab inspect -t $(TOPO_SRL)

graph:
	@sudo containerlab graph -t $(TOPO_SRL)

destroy:
	@sudo containerlab destroy -t $(TOPO_SRL) --cleanup || sudo containerlab destroy --all --cleanup
