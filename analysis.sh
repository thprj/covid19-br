#!/bin/bash

function create_database() {
	database_filename="$1"

	rm -rf "$database_filename"
	for table in boletim caso obito_cartorio caso_full; do
		echo "Downloading $table"
		filename="data/${table}.csv.gz"
		url="https://data.brasil.io/dataset/covid19/${table}.csv.gz"
		rm -rf "$filename"
		wget -q -c -t 0 -O "$filename" "$url"
		rows csv2sqlite --schemas=schema/${table}.csv "$filename" "$database_filename"
	done
	for table in populacao-estimada-2019 epidemiological-week; do
		rows csv2sqlite --schemas=schema/${table}.csv data/${table}.csv $database_filename
	done
}

function execute_sql_file_no_output() {
	database=$1; shift
	filename=$1

	cat "$filename" | sqlite3 "$database"
}

function execute_sql_file_with_output() {
	database=$1; shift
	sql_filename=$1; shift
	output_filename=$1

	rows query \
		"$(cat $sql_filename)" \
		"$database" \
		--output="$output_filename"
}

function setup_database() {
	database=$1; shift

	echo "Running sql/00-setup.sql"
	execute_sql_file_no_output "$database" "sql/00-setup.sql"
	echo "Running sql/01-obitos-setup.sql"
	execute_sql_file_no_output "$database" "sql/01-obitos-setup.sql"
}

function execute_sql_files() {
	database=$1; shift
	files=$@

	for filename in $files; do
		if [ $(basename $filename) != "00-setup.sql" ] && [ $(basename $filename) != "01-obitos-setup.sql" ]; then
			echo "Running $filename"
			output="data/analysis/$(basename $filename | sed 's/\.sql$/.csv.gz/')"
			execute_sql_file_with_output "$DATABASE" "$filename" "$output"
		fi
	done
}

DATABASE="data/covid19.sqlite"
mkdir -p data/analysis
create_database $DATABASE
setup_database $DATABASE
execute_sql_files $DATABASE sql/*.sql
