now = $(shell date "+%Y%m%d%H%M%S")
app = isucari
service = isucari.golang.service
.PHONY: bn
bn:
	make re
	../bin/benchmarker -target-url http://localhost:80

# アプリ､nginx､mysqlの再起動
.PHONY: re
re:
	make arestart
	make nrestart
	make mrestart
	echo "正常にMake reが完了しました"

# アプリ､nginx､mysqlの再起動
.PHONY: re-ssh-db
re-ssh-db:
	make arestart
	make nrestart
	make mrestart
# DBを分割した時このコメントアウトをとる。 リフレッシュしたいDBのPrivate IPを指定
# ssh 192.168.0.12 -A "cd webapp && make mrestart"

# アプリの再起動
.PHONY: arestart
arestart:
	sudo systemctl restart ${service}
	sudo systemctl status ${service}

# nginxの再起動
.PHONY: nrestart
nrestart:
	sudo touch /var/log/nginx/access.log
	sudo rm /var/log/nginx/access.log
	sudo systemctl reload nginx
	sudo systemctl status nginx

# mysqlの再起動
.PHONY: mrestart
mrestart:
	sudo touch /var/log/mysql/slow.log
	sudo rm /var/log/mysql/slow.log
	sudo mysqladmin flush-logs -proot
	sudo systemctl restart mysql
	sudo systemctl status mysql
	echo "set global slow_query_log = 1;" | sudo mysql -proot
	echo "set global slow_query_log_file = '/var/log/mysql/slow.log';" | sudo mysql -proot
	echo "set global long_query_time = 0;" | sudo mysql -proot

# 分割後のMysqlの再起動(二代目でmrestartを実行する)
# .PHONY: mrestart
# mrestart:
# 	ssh 192.168.0.12 -A "cd webapp && make mrestart"

# アプリのログを見る
.PHONY: nalp
nalp:
	sudo cat /var/log/nginx/access.log | alp ltsv -m "/items/[0-9]+.json, /upload/[a-zA-Z0-9]+.jpg, /transactions/[0-9]+.png, /users/[0-9]+.json, /new_items/[0-9]+.json" --sort=sum --reverse

# mysqlのslowlogを見る
.PHONY: pt
pt:
	sudo pt-query-digest /var/log/mysql/slow.log > ~/pt.log

# pprofを実行する
.PHONY: pprof
pprof:
	go tool pprof http://localhost:6060/debug/pprof/profile?seconds=45

# Goのビルド
.PHONY: build
build:
	cd go && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o ${app}

# Goのビルドと1台目へのGoのバイナリアップロード
.PHONY: upload1
upload1: build
	ssh isucon@i1 'sudo systemctl stop ${service}'
	scp ./go/${app} isucon@i1:/home/isucon/webapp/go/${app}
	ssh isucon@i1 'sudo systemctl restart ${service}'
	ssh isucon@i1 'sudo systemctl status ${service}'

# Goのビルドと2台目へのGoのバイナリアップロード
.PHONY: upload2
upload2: build
	ssh isucon@i2 'sudo systemctl stop ${service}'
	scp ./go/${app} isucon@i2:/home/isucon/webapp/go/${app}
	ssh isucon@i2 'sudo systemctl restart ${service}'
	ssh isucon@i2 'sudo systemctl status ${service}'

# Goのビルドと3台目へのGoのバイナリアップロード
.PHONY: upload3
upload3: build
	ssh isucon@i3 'sudo systemctl stop ${service}'
	scp ./go/${app} isucon@i3:/home/isucon/webapp/go/${app}
	ssh isucon@i3 'sudo systemctl restart ${service}'
	ssh isucon@i3 'sudo systemctl status ${service}'

# 1台目､2台目､3台目へのGoのバイナリアップロード
.PHONY:
all:
	make upload1
	make upload2
	make upload3

.PHONY: zenbu
zenbu:
	make all
	ssh isucon@i1 -A 'cd webapp && make re'
	ssh isucon@i2 -A 'cd webapp && make re'
	ssh isucon@i3 -A 'cd webapp && make re'

.PHONY: pbnalp1
pbnalp1:
	ssh isucon@i1 -A "cd webapp && make nalp" | pbcopy

.PHONY: pbnalp2
pbnalp2:
	ssh isucon@i2 -A "cd webapp && make nalp" | pbcopy

.PHONY: pbnalp3
pbnalp3:
	ssh isucon@i3 -A "cd webapp && make nalp" | pbcopy

.PHONY: pbpt1
pbpt1:
	ssh isucon@i1 -A "cd webapp && make pt && cat ~/pt.log" | pbcopy

.PHONY: pbpt1
pbpt2:
	ssh isucon@i2 -A "cd webapp && make pt && cat ~/pt.log" | pbcopy

.PHONY: pbpt3
pbpt3:
	ssh isucon@i3 -A "cd webapp && make pt && cat ~/pt.log" | pbcopy

.PHONY: upmakefile2
upmakefile2:
	scp ./Makefile isucon@i2:/home/isucon/webapp/Makefile

.PHONY: upmakefile3
upmakefile3:
	scp ./Makefile isucon@i3:/home/isucon/webapp/Makefile
