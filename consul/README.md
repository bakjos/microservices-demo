# Consul

```bash
 curl --get http://localhost:8500/v1/health/service/frontend | jq
curl --get http://localhost:8500/v1/connect/ca/configuration | jq
curl --get http://localhost:8500/v1/connect/ca/roots | jq
```

```bash
cat <<EOF > external-counting.json
{
       "Name": "external-counting",
       "Tags": [
"v0.0.4" ],
       "Address": "$(hostname -i)",
       "Port": 10001,
       "Check": {
"Method": "GET",
"HTTP": "http://$(hostname -i):10001/health", "Interval": "1s"
} }
EOF

curl -X PUT -d @external-counting.json http://localhost:8500/v1/agent/service/register
```

```bash
curl -s http://localhost:8500/v1/config/service-defaults/frontend | jq
```
