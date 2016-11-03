#!/bin/bash

psql -U pgpool -h onmssrv01 -p 9999 -d postgres -c "show pool_nodes"
