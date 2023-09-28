filepath        :=      $(PWD)
versionfile     :=      $(filepath)/version.txt
version         :=      $(shell cat $(versionfile))

release: 
	docker build -t minaprotocol/gcloud-cleaner:$(version) -f Dockerfile  .
	docker tag minaprotocol/gcloud-cleaner:$(version) gcr.io/o1labs-192920/gcloud-cleaner:$(version)
	docker push gcr.io/o1labs-192920/gcloud-cleaner:$(version)

latest:
	docker tag minaprotocol/gcloud-cleaner:$(version) gcr.io/o1labs-192920/gcloud-cleaner:latest
	docker push gcr.io/o1labs-192920/gcloud-cleaner:latest

build: 
	docker build -t minaprotocol/gcloud-cleaner:$(version) -f Dockerfile .
