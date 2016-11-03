#!/bin/bash

sudo runuser -l postgres -c "psql -x -c 'select * from pg_stat_replication;'"
