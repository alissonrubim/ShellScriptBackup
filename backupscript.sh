#!/bin/bash

##Globais
G_DATABASE_USER=""
G_DATABASE_PASSWORD=""  
G_DATABASE_DATABASE=""  
G_DATABASE_RECOVERY_FILE=""
G_DATABASE_TYPE="" #1 - Mysql, 2 - Postgree
G_DATABASE_TYPE_NAME="" 
G_SYSTEM_MODE=""  #1 - Backup, 2 - Recovery

## Constantes
C_DIALOG_BACKTITLE="Sistema de Backup"
C_LOG_FILE="logs.txt"
C_SYSTEM_PATH="/var/backupscript"
C_SYSTEM_BACKUPS_PATH="$C_SYSTEM_PATH/backups"
C_SYSTEM_BACKUPS_PATH_MYSQL="$C_SYSTEM_BACKUPS_PATH/mysql"
C_SYSTEM_BACKUPS_PATH_POSTGREE="$C_SYSTEM_BACKUPS_PATH/postgree"


Reset(){
	G_DATABASE_USER=""
	G_DATABASE_PASSWORD=""  
	G_DATABASE_DATABASE=""  
	G_DATABASE_RECOVERY_FILE=""
	G_DATABASE_TYPE=""
	G_DATABASE_TYPE_NAME="" 
}

ShowOptionDialog(){ 
	###############
	# Exibe um dialog com um option na tela
	# Parametros: (title, mensagem, opcoes)
	###############
	TITLE=$1
	MENU=$2
 	OPTIONS=("${!3}")

	RESULT=$(dialog --clear --backtitle "$C_DIALOG_BACKTITLE" \
		--title "$TITLE" \
		--menu "$MENU" \
        15 40 4 \
        "${OPTIONS[@]}" \
		2>&1 >/dev/tty)

	if [ -z "$RESULT" ] #Corrige o valor vazio do option
	then
		RESULT=0
	fi
	echo $RESULT
}

ShowInputDialog(){
	TITLE=$1
	LABEL=$2

	RESULT=$(dialog --clear --backtitle "$C_DIALOG_BACKTITLE" \
		--title "$1" \
		--inputbox "$2" \
        10 40 \
		2>&1 >/dev/tty)
	echo $RESULT
}

ShowPasswordDialog(){
	TITLE=$1
	LABEL=$2

	RESULT=$(dialog --clear --insecure --backtitle "$C_DIALOG_BACKTITLE" \
		--title "$1" \
		--passwordbox "$2" \
        10 40 \
		2>&1 >/dev/tty)
	echo $RESULT
}

ShowAlertDialog(){
	dialog --backtitle "$C_DIALOG_BACKTITLE" --msgbox "$1" 5 40 2>&1 >/dev/tty
}

VerifyDependences(){
	dialogpkg=$(dpkg-query -l | awk '{if($2 == "dialog") print $2}' | wc -l)
	if [ $dialogpkg == 0 ]
	then
		echo ">> Erro: Pacote dialog não instalado!"
		exit
	fi
	
	$(mkdir -p $C_SYSTEM_BACKUPS_PATH)
	$(mkdir -p $C_SYSTEM_BACKUPS_PATH_MYSQL)
	$(mkdir -p $C_SYSTEM_BACKUPS_PATH_POSTGREE)
}

## --- Log --- ##
Log(){
	currentDate=$(date '+%Y-%m-%d %H:%M:%S')
	echo "Log $currentDate" >> $C_LOG_FILE
	echo ">> " $1 >> $C_LOG_FILE
	echo "-------" >> $C_LOG_FILE
}

GetUTCDate(){
	echo $(date '+%Y%m%d%H%M%S');
}

## --- Backup/Restore --- ##
Backup_Mysql(){
	Log "Iniciando backup do Mysql (databse: $G_DATABASE_DATABASE)"
	currentDate=$(GetUTCDate)
	sqlfilename="${C_SYSTEM_BACKUPS_PATH_MYSQL}/mysql_${G_DATABASE_DATABASE}_${currentDate}.sql"
 	
	$(mysqldump --user=$G_DATABASE_USER --password=$G_DATABASE_PASSWORD --default-character-set=utf8 $G_DATABASE_DATABASE > $sqlfilename);
	$(bzip2 $sqlfilename);
	$(rm $sqlfilename);

	Log "Backup do Mysql (databse: $G_DATABASE_DATABASE) realizado com sucesso!"
	ShowAlertDialog "Backup realizado com sucesso!"
	Reset
}

Restore_Mysql(){
	Log "Iniciando restauração do Mysql (databse: $G_DATABASE_DATABASE)"
	filename="$C_SYSTEM_BACKUPS_PATH_MYSQL/$G_DATABASE_RECOVERY_FILE"
	sqlfilename="${filename}"
	extension="${filename##*.}"
	if [ $extension == "bz2" ]
	then
		sqlfilename="${filename%.*}"
		$(bzip2 -d $filename)
	fi

	query_result=$(mysql --user=$G_DATABASE_USER --password=$G_DATABASE_PASSWORD $G_DATABASE_DATABASE < $sqlfilename);

	Log "Restauração do Mysql (databse: $G_DATABASE_DATABASE, backup: $G_DATABASE_RECOVERY_FILE) realizado com sucesso!"
	ShowAlertDialog "Backup restaurado com sucesso!"

	if [ $extension == "bz2" ]
	then
		$(bzip2 $sqlfilename);
	fi
	Reset
} 

Backup_Postgree(){
	Log "Iniciando backup do Postgree (databse: $G_DATABASE_DATABASE)"
	currentDate=$(GetUTCDate)
	sqlfilename="${C_SYSTEM_BACKUPS_PATH_POSTGREE}/postgree_${G_DATABASE_DATABASE}_${currentDate}.sql"
 	
	$(PGPASSWORD=$G_DATABASE_PASSWORD; psql --username=$G_DATABASE_USER -F c -Z 9 -b $G_DATABASE_DATABASE > $sqlfilename);
	$(bzip2 $sqlfilename);
	$(rm $sqlfilename);

	Log "Backup do Postgree (databse: $G_DATABASE_DATABASE) realizado com sucesso!"
	ShowAlertDialog "Backup realizado com sucesso!"
	Reset
} 

Restore_Postgree(){
	Log "Iniciando restauração do Postgree (databse: $G_DATABASE_DATABASE)"
	filename="$C_SYSTEM_BACKUPS_PATH_POSTGREE/$G_DATABASE_RECOVERY_FILE"
	sqlfilename="${filename}"
	extension="${filename##*.}"
	if [ $extension == "bz2" ]
	then
		sqlfilename="${filename%.*}"
		$(bzip2 -d $filename)
	fi

	query_result=$(PGPASSWORD=$G_DATABASE_PASSWORD; psql --username=$G_DATABASE_USER -d $G_DATABASE_DATABASE -F c -W < $sqlfilename);

	Log "Restauração do Postgree (databse: $G_DATABASE_DATABASE, backup: $G_DATABASE_RECOVERY_FILE) realizado com sucesso!"
	ShowAlertDialog "Backup restaurado com sucesso!"

	if [ $extension == "bz2" ]
	then
		$(bzip2 $sqlfilename);
	fi
	Reset
}

## --- Menus --- ##
GetDatabaseName(){
	result=""
	options_db=()
	i=0
	query_result=""

	if [ $G_DATABASE_TYPE == 1 ]
	then
		query_result=$(mysql --user=$G_DATABASE_USER --password=$G_DATABASE_PASSWORD -e "show databases;"| awk '{if(NR > 1) print $0}')
	else
		query_result=$(PGPASSWORD=$G_DATABASE_PASSWORD; psql --username=$G_DATABASE_USER -A -t -c "SELECT datname FROM pg_database"| awk '{print $0}')
	fi

	for dbname in $query_result
	do
		i=$((i+1))
		options_db+=($i $dbname)
	done

	if [ ${#options_db[@]} == 0 ] 
	then
		ShowAlertDialog "Erro ao acessar o banco!"
	else 
		if [ ${#options_db[@]} != 0 ] 
		then
			title_main="Backup"
			message_main="Selecione um banco de dados para backup:"
			database_index=$(ShowOptionDialog "$title_main" "$message_main" options_db[@])
			aux=$[database_index-1]
			database_index=$[database_index+aux]			
			result=${options_db[database_index]}
		fi
	fi

	echo $result
}

GetRecoveryFile(){
	result=""
	options_db=()
	i=0

	if [ $G_DATABASE_TYPE == 1 ]
	then
		query_result=$(ls $C_SYSTEM_BACKUPS_PATH_MYSQL | awk '{print $0}')
	else
		query_result=$(ls $C_SYSTEM_BACKUPS_PATH_POSTGREE | awk '{print $0}')
	fi
	
	for dbname in $query_result
	do
		i=$((i+1))
		options_db+=($i $dbname)
	done

	if [ ${#options_db[@]} == 0 ] 
	then
		ShowAlertDialog "Não existem backups feitos!"
	else 
		if [ ${#options_db[@]} != 0 ] 
		then
			title_main="Backup"
			message_main="Selecione um arquivo para restaurar:"
			file_index=$(ShowOptionDialog "$title_main" "$message_main" options_db[@])
			aux=$[file_index-1]
			file_index=$[file_index+aux]
		fi
	fi
	
	result=${options_db[file_index]}

	echo $result
}

MenuGetInfo(){
	if [ $G_SYSTEM_MODE == 2 ] 
	then
		G_DATABASE_RECOVERY_FILE=$(GetRecoveryFile)
	fi

	if [[ ($G_SYSTEM_MODE == 1 ) || ( ($G_SYSTEM_MODE == 2 ) &&  ($G_DATABASE_RECOVERY_FILE != "" ) ) ]]
	then  
		G_DATABASE_USER=$(ShowInputDialog "Dados de Acesso - $G_DATABASE_TYPE_NAME" "Usuário:")
		G_DATABASE_PASSWORD=$(ShowPasswordDialog "Dados de Acesso - $G_DATABASE_TYPE_NAME" "Senha:")
		G_DATABASE_DATABASE=$(GetDatabaseName)

		if [ $G_DATABASE_DATABASE != "" ]
		then 
			if [ $G_DATABASE_TYPE == 1 ] && [ $G_SYSTEM_MODE == 1 ]
			then
				Backup_Mysql
			elif [ $G_DATABASE_TYPE == 1 ] && [ $G_SYSTEM_MODE == 2 ]
			then
				Restore_Mysql
			elif [ $G_DATABASE_TYPE == 2 ] && [ $G_SYSTEM_MODE == 1 ]
			then
				Backup_Postgree
			elif [ $G_DATABASE_TYPE == 2 ] && [ $G_SYSTEM_MODE == 2 ]
			then
				Restore_Postgree
			fi
		fi
	fi
}
 

MenuDatabase(){
	title_database="Menu de Banco de Dados"
	message_database="Selecione uma opção:"
	options_database=(1 "MySQL" 2 "Postgree")
	G_DATABASE_TYPE=$(ShowOptionDialog "$title_database" "$message_database" options_database[@])
	
	if [ $G_DATABASE_TYPE != 0 ]
	then 
		if [ $G_DATABASE_TYPE == 1 ] 
		then
			G_DATABASE_TYPE_NAME="MySQL"
		else 
			if [ $G_DATABASE_TYPE == 1 ] 
			then 
				G_DATABASE_TYPE_NAME="Postgree"
			fi
		fi

		MenuGetInfo
	fi
}

MenuMain(){ 
	VerifyDependences
	ShowAlertDialog "Seja Bem-Vindo(a)!"
	G_SYSTEM_MODE=1
	while [ $G_SYSTEM_MODE != 0 ]
	do
		title_main="Menu Principal"
		message_main="Selecione uma opção:"
		options_main=(1 "Realizar Backup" 2 "Restaurar backup")
		G_SYSTEM_MODE=$(ShowOptionDialog "$title_main" "$message_main" options_main[@])

		if [ $G_SYSTEM_MODE != 0 ]
		then
			MenuDatabase
		fi
	done
	echo "Saindo..."
	clear
}

MenuMain