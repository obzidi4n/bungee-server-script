
#!/bin/bash

if [ $1 = 'help' ]; then

		echo "
		*******
		Obzidi4n's Nifty Server Scripts
                Visit us at play.minecartmob.com and play.delphicraft.net

		SERVER CONTROLS
		./mc help - this menu

		./mc backup - backup configs and world files
		./mc console - quick connect to tmux session
		./mc dumplogs - clean up all log files
		./mc eula - update all eulas at once
		./mc list - list servers and configurations
		./mc mirror <servername> - copy plugins and configs from one server to the test server.
		./mc pluginlist - list plugins
		./mc shutdown - kill all servers now (emergency only)
		./mc start <servername> - start a server
		./mc stop <servername> - graceful shutdown

		UPDATES
		./mc update bungee - get the latest bungee build
		./mc update spigot - download latest buildtools, run git and write to server.
		./mc update spigotjars - copy updated spigot.jar to server folders
		./mc update plugins - get latest plugin builds & write to servers
		./mc update pluginlist - get a fresh list of plugins

		*******
		"
fi

if [ $1 = 'mirror' ]; then

# remove old plugins
rm -rf servers/mirror/plugins/*
echo 'old plugins removed'

# copy the targeted server's plugin directory
rsync -avr servers/$2/plugins/ servers/test/plugins/ --exclude dynmap/web
echo $2' plugins copied.  Done!'
fi


if [ $1 = 'backup' ]; then


	# set backup and cloud locations
	backup_loc='backups/servers'
	cloud_loc='delphi:delphicraft/backups/'

	# backup bungee
	echo 'Backing up: bungee'
	rsync -arzu --delete servers/bungee "$backup_loc"

	# backup servers, incporating exclude list
	while read server megs; do

			echo 'Backing up: '$server
			rsync -arzu --delete --exclude-from "config/backup-excludes" "servers/$server" "$backup_loc"

	done < config/serverlist

	# create zip file
	echo "Zipping.."

	if [ -e "$backup_loc"-*.zip ]
		then
			rm "$backup_loc"-*.zip
	fi

	zip -rq "$backup_loc"-$(date +%m%d%y).zip "$backup_loc"

	echo "Created $backup_loc"-"$(date +%m%d%y)".zip
	echo "Send to Cloud? (y/n)"

	read sendCloud

        if [ $sendCloud == "y" ]
            then

			# send to cloud
			echo 'Sending to Cloud..'
			rclone sync "$backup_loc"-"$(date +%m%d%y)".zip "$cloud_loc"

			# report
			echo "Done! Backed up $backup_loc"-"$(date +%m%d%y)".zip to "$cloud_loc"

		fi

	echo "All done!"

fi

if [ $1 = 'list' ]; then

	echo ''

	while read server megs; do

		echo $server '('$megs' MB)'

	done < config/serverlist

	echo ''

fi

if [ $1 = 'pluginlist' ]; then

	while read plugin url; do

		echo $plugin

	done < config/pluginlist

fi


if [ $1 = 'dumplogs' ]; then

	while read server megs; do

		rm servers/$server/logs/*
		echo 'Dumped logs: ' $server

	done < config/serverlist

fi

if [ $1 = 'eula' ]; then

	while read server megs; do

		if [ $server != 'bungee' ]; then

			\cp common-files/eula/eula.txt servers/$server/eula.txt

			echo 'Updated EULA: '$server
			fi

	done < config/serverlist

fi

if [ $1 = 'console' ]; then

	if (tmux has-session -t 'minecraft' 2> /dev/null); then

		tmux attach -t minecraft
		exit

	else
                tmux new-session -d -s minecraft
                tmux attach -t minecraft
		exit
	fi
fi


if [ $1 = 'shutdown' ]; then

	if (tmux has-session -t 'minecraft' 2> /dev/null); then

		echo "A sudden stop might cause data loss! Try ./server stop all instead for a graceful shutdown."

		read -r -p "Are you sure? [y/N] " response

			response=${response,,}    # tolower

			if [[ $response =~ ^(yes|y)$ ]]; then

				tmux kill-session -t minecraft
				echo 'Shutting down session.'
			else
				echo 'Shutdown aborted.'
				exit
			fi

		else

			echo "No session found."
			exit
	fi
fi

if [ $1 = 'stop' ]; then

	if [ $2 = 'all' ]; then

		if (tmux has-session -t 'minecraft' 2> /dev/null); then

			tmux list-windows -t minecraft|cut -d: -f1|xargs -I{} tmux send-keys -t minecraft:{} '/stop' ENTER
			echo 'All servers stopped.'
		else
			echo 'No servers found.'
			exit
		fi
		exit

	fi

	if [ $2 = 'bungee' ]; then

		tmux send -t minecraft:bungee 'e'
		tmux send -t minecraft:bungee 'nd' ENTER
		echo 'Bungee stopped.'

	fi

	if [ $2 != 'bungee' ]; then

		tmux send -t minecraft:$2 'stop' ENTER
		echo $2' stopped.'
	fi
fi

if [ $1 = 'start' ]; then

	if [ $2 = 'all' ]; then

		# check if session exists

        if (tmux has-session -t 'minecraft' 2> /dev/null); then

			echo 'Sorry, already running.'
			exit

		else

			# ok start new session
			tmux new-session -d -s minecraft

			# start windows

			i=0

			while read server megs; do

				if [ $server = 'bungee' ]; then

					tmux new-window -t minecraft -n "$server" -c "servers/$server" 'java -Xmx'$megs'M -Xms'$megs'M -jar BungeeCord.jar'

					else

			        	tmux new-window -t minecraft -n "$server" -c "servers/$server" 'java -Xmx'$megs'M -Xms'$megs'M -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:MaxGCPauseMillis=50 -XX:TargetSurvivorRatio=90 -XX:G1NewSizePercent=50 -XX:G1MaxNewSizePercent=80 -XX:InitiatingHeapOccupancyPercent=10 -XX:G1MixedGCLiveThresholdPercent=50 -XX:+AggressiveOpts -jar spigot.jar'

	       		fi

	       		(( i++ ))

			done < config/serverlist

			tmux select-window -t minecraft:1
			echo 'All servers started.'
			exit
                fi
                exit
	fi

	if [ $2 = 'bungee' ]; then

		# check if session exists
        if ! (tmux has-session -t 'minecraft' 2> /dev/null); then

			tmux new-session -d -s minecraft

		fi

		# match serverlist to grab memory settings
		megs=$(awk '/'$2'/ {print $2}' config/serverlist);

		# start tmux window
		tmux new-window -t minecraft -n $2 -c 'servers/'$2 'java -Xmx'$megs'M -Xms'$megs'M -jar BungeeCord.jar'
		echo $2' started with '$megs' megs.'
		exit
	fi

	if [ $2 != 'bungee' ]; then

        # check if session exists
        if ! (tmux has-session -t 'minecraft' 2> /dev/null); then

        	tmux new-session -d -s minecraft

        fi

		# match serverlist to grab memory settings
		megs=$(awk '/'$2'/ {print $2}' config/serverlist);

		# start tmux window
		tmux new-window -t minecraft -n $2 -c 'servers/'$2 'java -Xmx'$megs'M -Xms'$megs'M -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:MaxGCPauseMillis=50 -XX:TargetSurvivorRatio=90 -XX:G1NewSizePercent=50 -XX:G1MaxNewSizePercent=80 -XX:InitiatingHeapOccupancyPercent=10 -XX:G1MixedGCLiveThresholdPercent=50 -XX:+AggressiveOpts -jar spigot.jar'
		echo $2' started with '$megs' megs.'

		exit
	fi
fi

if [ $1 = 'update' ]; then

	if [ $2 = 'plugins' ]; then

        echo
		echo 'Cleaning up plugins directory'
		rm common-files/plugins/*

		## download latest plugin builds - call python script ##
		python scripts/plugins.py

        # find zips and unzip them
        for file in common-files/plugins/*.zip
            do

                echo
                echo 'Unzipping ' $file
                unzip -jo $file -d ${file%.*}

                # copy jars up from unzipped folders
                for jarfile in ${file%.*}/*.jar
                    do

                        jarfile_base=${jarfile##*/}
                        echo
                        echo 'Moving ' $jarfile_base
                        cp $jarfile common-files/plugins/$jarfile_base

                    done

            done

        # cleanup: remove sub-directories
        echo
        echo 'Removing subdirectories'

        rm -rf common-files/plugins/*/

        # cleanup: remove zips
        echo
        echo 'Removing zips'

        for file in common-files/plugins/*.zip
            do

                    rm $file

            done

        echo
        echo 'Plugin jars downloaded'

        # cleanup: delete unwanted files
        rm common-files/plugins/*{javadoc,sources}*

        echo
        echo 'Unwanted files removed'

        # cleanup: remove spaces in filenames
        for file in common-files/plugins/*
            do
                newfile=${file// /}

                if [ "$newfile" != "$file" ]; then

                    mv "$file" "$newfile"

                fi

            done

        echo
        echo 'Filename spaces removed'

        # cleanup: remove version numbers
        for plugin in common-files/plugins/*.jar
            do

                # separate path from base
                plugin_path=${plugin%/*}'/'
                plugin_base=${plugin##*/}

                # remove all special characters
                plugin_base=${plugin_base//_/}

                # trim off 'version' info from base
                plugin_base=${plugin_base%%[[0123456789]*}

                # replace any non-.jar endings
                if ! [[ $plugin_base =~ (jar)$ ]]; then

                    jar='.jar'
                    plugin_base=$plugin_base$jar

                fi

                # remove any trailing dashes
                plugin_base=${plugin_base/-.jar/.jar}

                # rename files
                if ! [[ $plugin == $plugin_path$plugin_base ]]; then

                    mv $plugin $plugin_path$plugin_base

                fi

            done

        echo
        echo 'Version information cleaned up.'


		## check plugins against common-files directory, update if needed.
		echo
		echo 'Please add any manually-updated plugins to the /common-files/plugins directory now, then press any key to continue..'

		read pluginContinue

        echo 'Type T to copy plugins to Test only, or any key to copy to all servers..'

        read pluginContinue

        if [ "$pluginContinue" = "T" ] || [ "$pluginContinue" = "t" ]; then

            server='test'

            for plugin in servers/$server/plugins/*.jar
                    do

                        plugin_base="${plugin##*/}"
                        echo
                        echo "server: "$server
                        echo "plugin: "$plugin_base
                        if diff common-files/plugins/$plugin_base servers/$server/plugins/$plugin_base > /dev/null; then
                            echo -e "\e[32mUp to Date\e[0m"
                            else
                                cp -f common-files/plugins/$plugin_base servers/$server/plugins/$plugin_base
                                echo -e "\e[32mUpdated\e[0m"
                            fi

                    done

        else

            while read server megs
            do

                for plugin in servers/$server/plugins/*.jar
                    do

                        plugin_base="${plugin##*/}"
                        echo
                        echo "server: "$server
                        echo "plugin: "$plugin_base
                        if diff common-files/plugins/$plugin_base servers/$server/plugins/$plugin_base > /dev/null; then
                            echo -e "\e[32mUp to Date\e[0m"
                            else
                                cp -f common-files/plugins/$plugin_base servers/$server/plugins/$plugin_base
                                echo -e "\e[32mUpdated\e[0m"
                            fi

                    done

            done < config/serverlist

        fi

		echo
		echo 'Plugins updated.'
		echo
		echo 'Done!'
	fi


	if [ $2 = 'bungee' ]; then

		# todo: check if directory exists, if not, create and then CD
		cd servers/bungee
		rm BungeeCord.jar
		wget http://ci.md-5.net/job/BungeeCord/lastSuccessfulBuild/artifact/bootstrap/target/BungeeCord.jar
		echo "Done!"
	fi

	if [ $2 = 'spigot' ]; then

		# todo: check if directory exists, if not, create and then CD
		# empty old builds
        chmod -R 777 common-files/buildtools/*
        rm -rf common-files/buildtools/*
		cd common-files/buildtools
		wget "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar" -O BuildTools.jar
		git config --global --unset core.autocrlf

		# run git .. this takes awhile, run inside tmux
		tmux new -d -s spigot 'java -jar -Xmx2G -Xms2G BuildTools.jar --dev'

		echo  "Running buildtools in a tmux session called 'spigot'. Join session? (y/n)"
        read joinsession

                if [ $joinsession = "y" ]; then
                    tmux attach -t spigot
                else
                     exit
                fi

	fi

	if [ $2 = 'spigotjars' ]; then

		# strip version numbers from spigot.jar

		cd common-files/buildtools

		if  [ ! -f spigot.jar ]; then

			mv spigot*.jar spigot.jar
		fi

		cd ../..

		# copy to servers
		while read server megs; do

			cp -f common-files/buildtools/spigot.jar servers/$server/spigot.jar

		done < config/serverlist

		echo 'Done!'
		exit
	fi

	if [ $2 = 'pluginlist' ]; then

		# retrieve filenames from servers
		i=0
		for file in servers/*/plugins/*.jar
		do
			plugins[$i]=$(basename "$file");
			((i++));
		done

		# dedupe array
		readarray -t allPlugins < <(printf '%s\n' "${plugins[@]}" | sort -u);

		# update file
		rm config/pluginlist
		for each in "${allPlugins[@]}"
		do
			echo $each >> config/pluginlist
		done

	fi
fi
