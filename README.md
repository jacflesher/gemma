
#### USAGE:
```sh
TOKEN=$(gcloud auth print-identity-token)

curl "https://gemma-app-123456789.us-central1.run.app/v1/chat/completions" \
 --location --silent --request "POST" \
 --header "Authorization: Bearer $TOKEN" \
 --header "Content-Type: application/json" \
 --data-raw '{
    "model": "google/gemma-4-E2B-it",
    "messages": [
      {
        "role": "user",
        "content": "what are the core principles of bells theorem?"
      }
    ],
    "temperature": 0.1,
    "max_tokens": 1024,
    "chat_template_kwargs": {
      "enable_thinking": false
    }
  }' | jq -r ".choices[0].message.content"
```
