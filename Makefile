publish:
	BOT_TOKEN=${BOT_TOKEN} docker build . -t "thaibeouu/lang-bot:latest"
	docker push "thaibeouu/lang-bot:latest"
