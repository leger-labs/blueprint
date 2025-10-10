### API Services

Create an account for each of those services and save the api keys repectively in the yaml file below:


| API Service        | URL                                                                                              |
| ------------------ | ------------------------------------------------------------------------------------------------ |
| Anthropic          | [https://console.anthropic.com/settings/billing](https://console.anthropic.com/settings/billing) |
| AI Studio (Google) | [https://aistudio.google.com/app/api-keys](https://aistudio.google.com/app/api-keys)             |
| Groq               | [https://console.groq.com/login](https://console.groq.com/login)                                 |
| Mistral            | [https://console.mistral.ai/upgrade/details](https://console.mistral.ai/upgrade/details)         |
| OpenAI             | [https://platform.openai.com](https://platform.openai.com)                                       |
| OpenRouter         | [https://openrouter.ai/settings/keys](https://openrouter.ai/settings/keys)                       |
| Tavily             | [https://app.tavily.com/home](https://app.tavily.com/home)                                       |
| Perplexity         | [https://www.perplexity.ai/account/api/keys](https://www.perplexity.ai/account/api/keys)         |

---

### Example `secrets.yaml` snippet (with placeholders)

```yaml
secrets:
  # ═════════════════════════════════════════════════════════════════════════
  # 🌐 TAILSCALE OAUTH AND GITHUB CREDENTIALS
  # ═════════════════════════════════════════════════════════════════════════
  tailscale:
    oauth_client_id: "<YOUR_TAILSCALE_CLIENT_ID>"
    oauth_client_secret: "<YOUR_TAILSCALE_CLIENT_SECRET>"

  github:
    cli_pat: "<YOUR_GITHUB_PAT>"

  # ═════════════════════════════════════════════════════════════════════════
  # 🤖 LLM PROVIDERS - Cloud APIs
  # ═════════════════════════════════════════════════════════════════════════
  llm_providers:
    openai: "<YOUR_OPENAI_KEY>"
    anthropic: "<YOUR_ANTHROPIC_KEY>"
    gemini: "<YOUR_GOOGLE_AI_KEY>"
    groq: "<YOUR_GROQ_KEY>"
    mistral: "<YOUR_MISTRAL_KEY>"
    openrouter: "<YOUR_OPENROUTER_KEY>"

  # ═════════════════════════════════════════════════════════════════════════
  # 🔍 SEARCH PROVIDERS - Optional
  # ═════════════════════════════════════════════════════════════════════════
  search_providers:
    perplexity: "<YOUR_PERPLEXITY_KEY>"
    tavily: "<YOUR_TAVILY_KEY>"
    brave: ""

  # ═════════════════════════════════════════════════════════════════════════
  # 🔊 AUDIO PROVIDERS - Optional
  # ═════════════════════════════════════════════════════════════════════════
  audio_providers:
    elevenlabs: ""  # Add if using ElevenLabs TTS
    deepgram: ""    # Add if using Deepgram STT
```

