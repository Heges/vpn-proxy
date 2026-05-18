# Мой кастомный vpn-proxy через выделенный VPS
Проект для проксирования локальных приложений через HTTP-Proxy без необходимости переподключаться между разными VPN.

# Предустановка
Обязательно необходимо чтобы было установлено настроено:
1. Установлен openvpn на отдельном выделенном VPS, например Германии. 
2. Установлен Docker Desktop на вашем Windows.

Пример настройки openvpn и выпуска ключевых файлов.
https://github.com/angristan/openvpn-install

# Как запустить
перейти в корень проекта и запустить

docker compose up -d

# Настроить прокси для Visual Studio Code
Добавить в Visual Studio Code в Settings.json

*Необходимо добавить ctrl + shift + p -> Preferences: Open User Settings(JSON) и добавить
```
"http.proxy": "http://127.0.0.1:8888",
"http.proxyStrictSSL": true,
"http.systemCertificates": true
```
или например браузер FireFox
Ручная настройка прокси:
```
	HTTP прокси: 127.0.0.1 порт: 8888
	Использовать этот прокси и для HTTPS
```