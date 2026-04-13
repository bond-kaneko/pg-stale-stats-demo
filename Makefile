.PHONY: setup query analyze psql psql-super clean reset

setup:
	./scripts/setup.sh

query:
	./scripts/query.sh

analyze:
	./scripts/analyze.sh

psql:
	@PGPASSWORD=app_user psql -h localhost -p 15432 -U app_user -d demo

psql-super:
	@PGPASSWORD=demo psql -h localhost -p 15432 -U demo -d demo

clean:
	docker compose down -v
	rm -rf results/

reset: clean setup
