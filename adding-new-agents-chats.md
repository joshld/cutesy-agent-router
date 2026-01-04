# Adding New AI Agents and Chat Services

The architecture uses **factory pattern + abstraction** so you can add new agents and services without changing core code.

---

## Quick Start: Adding a New PTY Agent

### Example: Adding a custom CLI agent (MyAgent)

**Step 1: Create the agent class**

```python
class MyAgentCLI(PTYAgent):
    """My custom CLI agent"""
    
    def __init__(self, config: Dict[str, Any]):
        config.setdefault("name", "MyAgent")
        config.setdefault("command", ["myagent"])
        super().__init__(config)
    
    def _should_filter_output(self, output: str) -> bool:
        """MyAgent-specific filtering"""
        # Remove MyAgent's welcome screen
        if "myagent v" in output.lower():
            return True
        
        # Filter any UI boxes
        if re.match(r"^[\s═╔╗╚╝║]+$", output.strip()):
            return True
        
        return False
    
    def _get_prompt_patterns(self) -> list:
        """MyAgent's custom prompt patterns"""
        return [
            r"\[y/n\]\s*$",
            r"Enter command:\s*$",
            r">>>>\s*$",  # MyAgent's custom prompt
        ]
```

**Step 2: Register in factory**

```python
def create_agent(agent_type: str, config: Dict[str, Any]) -> AgentInterface:
    """Factory function to create agents"""
    agents = {
        # Existing agents...
        "cline": ClineAgent,
        "codex-cli": CodexCLIAgent,
        
        # NEW: Add your agent
        "myagent": MyAgentCLI,
        
        # ACP agents...
        "claude-api": ClaudeAAPIAgent,
        "openai-api": OpenAIAPIAgent,
        "codex-api": CodexAPIAgent,
    }
    
    if agent_type not in agents:
        raise ValueError(f"Unknown agent type: {agent_type}")
    
    return agents[agent_type](config)
```

**Step 3: Add configuration**

```python
agent_config = {
    # Existing configs...
    "cline": { ... },
    "codex-cli": { ... },
    
    # NEW: Add your agent config
    "myagent": {
        "command": ["myagent"],
        "name": "MyAgent",
        # Add any custom config your agent needs
        "custom_setting": "value",
    },
    
    # ACP agents...
    "claude-api": { ... },
}
```

**Step 4: Use it**

```bash
AGENT_TYPE=myagent
TELEGRAM_BOT_TOKEN=...
AUTHORIZED_USER_ID=...
```

---

## Quick Start: Adding a New ACP Agent

### Example: Adding Anthropic Sonnet 3 or another API

**Step 1: Create the ACP agent class**

```python
class AnthropicSonnet3Agent(ACPAgent):
    """Claude 3 Sonnet via Anthropic API"""
    
    def __init__(self, config: Dict[str, Any]):
        config.setdefault("name", "Claude 3 Sonnet")
        config.setdefault("api_url", "https://api.anthropic.com/v1/messages")
        config.setdefault("model", "claude-3-sonnet-20240229")
        super().__init__(config)

    async def _call_api(self, messages: list) -> Optional[str]:
        """Call Anthropic Claude 3 Sonnet API"""
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.api_url,
                    headers={
                        "x-api-key": self.api_key,
                        "anthropic-version": "2023-06-01",
                        "content-type": "application/json",
                    },
                    json={
                        "model": self.model,
                        "max_tokens": 2048,
                        "messages": messages,
                        "system": "You are a helpful assistant. Be concise.",
                    },
                    timeout=30.0,
                )
                
                if response.status_code == 200:
                    data = response.json()
                    if data.get("content"):
                        return data["content"][0]["text"]
                else:
                    debug_log(DEBUG_ERROR, f"API error: {response.status_code}")
                    return None
        except Exception as e:
            debug_log(DEBUG_ERROR, f"Failed to call Sonnet 3 API: {e}")
            return None
```

**Step 2: Register in factory**

```python
def create_agent(agent_type: str, config: Dict[str, Any]) -> AgentInterface:
    agents = {
        # PTY agents...
        "cline": ClineAgent,
        "codex-cli": CodexCLIAgent,
        "myagent": MyAgentCLI,
        
        # ACP agents...
        "claude-api": ClaudeAAPIAgent,
        "claude-3-sonnet": AnthropicSonnet3Agent,  # NEW
        "openai-api": OpenAIAPIAgent,
        "codex-api": CodexAPIAgent,
    }
    
    if agent_type not in agents:
        raise ValueError(f"Unknown agent type: {agent_type}")
    
    return agents[agent_type](config)
```

**Step 3: Add configuration**

```python
agent_config = {
    # ... existing ...
    
    "claude-3-sonnet": {
        "api_key": os.getenv("ANTHROPIC_API_KEY"),
        "model": "claude-3-sonnet-20240229",
        "name": "Claude 3 Sonnet",
    },
}
```

**Step 4: Use it**

```bash
AGENT_TYPE=claude-3-sonnet
ANTHROPIC_API_KEY=sk-ant-...
TELEGRAM_BOT_TOKEN=...
AUTHORIZED_USER_ID=...
```

---

## Quick Start: Adding a New Chat Service

### Example: Adding Discord support

**Step 1: Create the chat service class**

First, install Discord library:
```bash
pip install discord.py
```

Then create the service:

```python
import discord
from discord.ext import commands

class DiscordChatService:
    """Discord chat service"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.token = config.get("token")
        self.channel_id = config.get("channel_id")
        self.authorized_user_id = config.get("authorized_user_id")
        self.bot = None
        self.message_handler = None
        self.app = None
    
    def set_message_handler(self, handler: Callable) -> None:
        """Set handler for incoming messages"""
        self.message_handler = handler
    
    async def send_message(self, user_id: str, text: str) -> None:
        """Send message to Discord user or channel"""
        try:
            # Option 1: DM the user
            user = await self.bot.fetch_user(int(user_id))
            await user.send(text)
            
            # Option 2: Send to specific channel
            # channel = self.bot.get_channel(self.channel_id)
            # await channel.send(text)
        except Exception as e:
            debug_log(DEBUG_ERROR, f"Failed to send Discord message: {e}")
    
    async def start(self) -> None:
        """Start Discord bot"""
        self.bot = commands.Bot(command_prefix="/", intents=discord.Intents.default())
        
        @self.bot.event
        async def on_ready():
            debug_log(DEBUG_INFO, f"Discord bot logged in as {self.bot.user}")
        
        @self.bot.event
        async def on_message(message):
            # Ignore bot's own messages
            if message.author == self.bot.user:
                return
            
            # Check authorization
            if message.author.id != int(self.authorized_user_id):
                await message.reply("❌ Unauthorized")
                return
            
            # Handle commands and messages
            if message.content.startswith("/"):
                cmd = message.content
                if self.message_handler:
                    await self.message_handler(
                        Message(MessageType.COMMAND, cmd, sender="discord_user"),
                        str(message.author.id)
                    )
            else:
                if self.message_handler:
                    await self.message_handler(
                        Message(MessageType.USER_INPUT, message.content, sender="discord_user"),
                        str(message.author.id)
                    )
        
        # Store app reference for bridge
        self.app = self.bot
        
        # Start bot (non-blocking)
        await self.bot.start(self.token)
    
    async def stop(self) -> None:
        """Stop Discord bot"""
        if self.bot:
            await self.bot.close()
```

**Step 2: Update the bridge to work with Discord**

The `AgentChatBridge` already works! Just needs one small update for Discord's slightly different message reply style:

```python
class AgentChatBridge:
    """Works with any chat service"""
    
    def __init__(self, agent: AgentInterface, app: Any, user_id: str, 
                 service_type: str = "telegram"):
        self.agent = agent
        self.app = app
        self.user_id = user_id
        self.service_type = service_type
        self.output_monitor_task = None
        self._recent_hashes = deque(maxlen=10)
    
    async def send_message(self, user_id: str, text: str) -> None:
        """Send message - works with any service"""
        try:
            if self.service_type == "telegram":
                await self.app.bot.send_message(chat_id=int(user_id), text=text)
            elif self.service_type == "discord":
                user = await self.app.fetch_user(int(user_id))
                await user.send(text)
        except Exception as e:
            debug_log(DEBUG_ERROR, f"Failed to send message: {e}")
```

**Step 3: Update main() to choose service**

```python
def main():
    debug_log(DEBUG_INFO, "Starting Agent-Chat Bridge")
    
    token = os.getenv("BOT_TOKEN")  # Works for both
    user_id = os.getenv("AUTHORIZED_USER_ID")
    agent_type = os.getenv("AGENT_TYPE", "cline")
    chat_service = os.getenv("CHAT_SERVICE", "telegram")  # NEW
    
    # Create agent (unchanged)
    agent = create_agent(agent_type, agent_config[agent_type])
    
    # Create appropriate chat service
    if chat_service == "telegram":
        from telegram.ext import Application
        application = Application.builder().token(token).build()
        service_type = "telegram"
    elif chat_service == "discord":
        application = None  # Discord.py manages its own event loop
        service_type = "discord"
    else:
        raise ValueError(f"Unknown chat service: {chat_service}")
    
    # Create bridge
    bridge = AgentChatBridge(agent, application, user_id, service_type)
    
    # Set handlers (service-specific)
    if chat_service == "telegram":
        application.add_handler(CommandHandler(["start", "stop", "status"], bridge.handle_command))
        application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, bridge.handle_message))
        application.run_polling()
    elif chat_service == "discord":
        discord_service = DiscordChatService({
            "token": token,
            "channel_id": int(os.getenv("DISCORD_CHANNEL_ID", "0")),
            "authorized_user_id": user_id,
        })
        discord_service.set_message_handler(bridge.process_message)
        asyncio.run(discord_service.start())
```

**Step 4: Use it**

```bash
CHAT_SERVICE=discord
BOT_TOKEN=your_discord_token
AUTHORIZED_USER_ID=your_discord_user_id
DISCORD_CHANNEL_ID=your_channel_id
AGENT_TYPE=cline
```

---

## Adding a Slack Service (Another Example)

```python
from slack_bolt.async_app import AsyncApp

class SlackChatService:
    """Slack chat service"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.token = config.get("token")
        self.authorized_user_id = config.get("authorized_user_id")
        self.app = AsyncApp(token=self.token)
        self.message_handler = None
    
    def set_message_handler(self, handler: Callable) -> None:
        self.message_handler = handler
    
    async def send_message(self, user_id: str, text: str) -> None:
        """Send DM to Slack user"""
        try:
            await self.app.client.chat_postMessage(
                channel=user_id,
                text=text
            )
        except Exception as e:
            debug_log(DEBUG_ERROR, f"Failed to send Slack message: {e}")
    
    async def start(self) -> None:
        """Start Slack bot"""
        
        @self.app.message(re.compile(".*"))
        async def handle_message(message, say):
            if message["user"] != self.authorized_user_id:
                await say("❌ Unauthorized")
                return
            
            if self.message_handler:
                await self.message_handler(
                    Message(MessageType.USER_INPUT, message["text"]),
                    message["user"]
                )
        
        await self.app.start(port=3000)
    
    async def stop(self) -> None:
        pass
```

---

## The Extensibility Pattern

### Current State
```
AgentInterface
├── PTYAgent (runs locally)
│   ├── ClineAgent
│   ├── CodexCLIAgent
│   └── MyAgentCLI ← Add here
└── ACPAgent (calls API)
    ├── ClaudeAAPIAgent
    ├── OpenAIAPIAgent
    ├── CodexAPIAgent
    └── AnthropicSonnet3Agent ← Add here

Chat Service
├── TelegramChatService
├── DiscordChatService ← Add here
└── SlackChatService ← Add here
```

### How It All Connects

```python
create_agent(agent_type) → AgentInterface
                              ↓
                        AgentChatBridge
                              ↓
                         ChatService
```

The bridge doesn't care:
- What agent type (PTY or ACP)
- What chat service (Telegram, Discord, Slack)
- It just calls abstract methods

---

## Summary: Adding New Components

| What | Where | How |
|------|-------|-----|
| **New PTY Agent** | Create `class MyAgent(PTYAgent)` | Override `_should_filter_output()`, `_get_prompt_patterns()` |
| **New ACP Agent** | Create `class MyAgent(ACPAgent)` | Override `_call_api()` |
| **New Chat Service** | Create `class MyService` | Implement `send_message()`, `start()`, `stop()` |
| **Register Agent** | `create_agent()` factory | Add to `agents` dict |
| **Register Service** | `main()` function | Add service creation logic |
| **Configure** | Environment variables | Add to `.env` file |

**Zero changes needed to:**
- `AgentChatBridge` core logic
- `_output_monitor()` logic
- Message filtering logic
- Thread/lock management

Everything is modular! 🎯