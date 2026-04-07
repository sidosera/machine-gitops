.PHONY: lint lint-ansible lint-yaml lint-sh lint-py

# So `pip install --user` tools are found (macOS/Linux).
USER_BASE_BIN := $(shell python3 -c "import site; print(site.getuserbase() + '/bin')" 2>/dev/null)
export PATH := $(USER_BASE_BIN):$(PATH)

lint: lint-ansible lint-yaml lint-sh lint-py

lint-ansible:
	cd ansible && ansible-lint -c .ansible-lint playbook.yml roles inventory controller_layout.yml

lint-yaml:
	python3 -m yamllint -c .yamllint.yml local-env.example.yaml ansible/controller_layout.yml ansible/inventory/localhost.yml
	python3 -m yamllint -c .yamllint.yml k8s k8s/system

lint-sh:
	shellcheck hm-playbook.sh

lint-py:
	@test -z "$$(find ansible -type f -name '*.py' 2>/dev/null | head -1)" || python3 -m ruff check ansible/
