#!/bin/bash

DIALOG_BACKTITLE="Sistema de Backup"
DATABASE_HOST="" 
DATABASE_USER=""
DATABASE_PASSWORD=""
DATABASE_TYPE="" 
SYSTEM_MODE=""  #1 - Backup, 2 - Recovery


ShowOptionDialog(){ 
	###############
	# Exibe um dialog com um option na tela
	# Parametros: (title, mensagem, opcoes)
	###############
	TITLE=$1
	MENU=$2
 	OPTIONS=("${!3}")

	RESULT=$(dialog --clear --backtitle "$DIALOG_BACKTITLE" \
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

	RESULT=$(dialog --clear --backtitle "$DIALOG_BACKTITLE" \
		--title "$1" \
		--inputbox "$2" \
        10 40 \
		2>&1 >/dev/tty)
	echo $RESULT
}

ShowPasswordDialog(){
	TITLE=$1
	LABEL=$2

	RESULT=$(dialog --clear --insecure --backtitle "$DIALOG_BACKTITLE" \
		--title "$1" \
		--passwordbox "$2" \
        10 40 \
		2>&1 >/dev/tty)
	echo $RESULT
}

ShowAlertDialog(){
	dialog --backtitle "$DIALOG_BACKTITLE" --msgbox "$1" 5 40 2>&1 >/dev/tty
}

VerifyDependences(){
	dialogpkg=$(dpkg-query -l | grep dialog | wc -l)
	if [ $dialogpkg == 0 ]
	then
		echo ">> Erro: Pacote dialog não instalado!"
		exit
	fi
}


## --- Menus --- ##
MenuGetInfo(){
	DATABASE_HOST=$(ShowInputDialog "Dados de Acesso - $DATABASE_TYPE" "Endereço do servidor:")
	DATABASE_USER=$(ShowInputDialog "Dados de Acesso - $DATABASE_TYPE" "Usuário:")
	DATABASE_PASSWORD=$(ShowPasswordDialog "Dados de Acesso - $DATABASE_TYPE" "Senha:")

	#ShowAlertDialog "$DATABASE_HOST"
}


MenuDatabase(){
	###############
	# Exibe um dialog com as opçoes de banco
	###############
	title_database="Menu de Banco de Dados"
	message_database="Selecione uma opção:"
	options_database=(1 "MySQL" 2 "Postgree")
	option_database=$(ShowOptionDialog "$title_database" "$message_database" options_database[@])
	
	if [ $option_database != 0 ]
	then 
		if [ $option_database == 1 ] 
		then
			DATABASE_TYPE="MySQL"
		else 
			if [ $option_database == 1 ] 
			then
				DATABASE_TYPE="Postgree"
			fi
		fi
		MenuGetInfo
	fi
}

MenuMain(){ 
	VerifyDependences
	ShowAlertDialog "Seja Bem-Vindo(a)!"
	SYSTEM_MODE=1
	while [ $SYSTEM_MODE != 0 ]
	do
		title_main="Menu Principal"
		message_main="Selecione uma opção:"
		options_main=(1 "Realizar Backup" 2 "Restaurar backup")
		SYSTEM_MODE=$(ShowOptionDialog "$title_main" "$message_main" options_main[@])

		if [ $SYSTEM_MODE != 0 ]
		then
			MenuDatabase
		fi
	done
	echo "Saindo..."
}

MenuMain