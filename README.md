# cloud-assessment

# Simulation
1. Run mosquitto
docker run -d --name mosquitto -p 1883:1883 eclipse-mosquitto

2. Run Database
docker run -d --name postgres -e POSTGRES_PASSWORD=dontforgettoprotectme -e POSTGRES_DB=tiiassessment -p 5432:5432 postgres:15-alpine
