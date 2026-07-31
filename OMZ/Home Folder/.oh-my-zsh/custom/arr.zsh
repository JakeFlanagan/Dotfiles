alias radarr-clear='curl -s -X POST "http://192.168.69.50:7878/api/v3/command" -H "X-Api-Key: f8145cdb899345388973c665f07c1921" -H "Content-Type: application/json" -d "{\"name\":\"ClearLog\"}" > /dev/null'
alias sonarr-clear='curl -s -X POST "http://192.168.69.50:8989/api/v3/command" -H "X-Api-Key: fba16fc756ef4710894cbd50822b892d" -H "Content-Type: application/json" -d "{\"name\":\"ClearLog\"}" > /dev/null'
alias arr-clear='radarr-clear && sonarr-clear && echo "Cleared"'
