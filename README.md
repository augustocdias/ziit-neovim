# ziit-neovim

A Neovim plugin for automatic time tracking with [Ziit](https://ziit.app). Track your coding activity seamlessly while you work.

## Features

- 🕐 Automatic activity tracking with heartbeats
- 📱 Offline queue management for unreliable connections
- 📊 Status bar integration (lualine support included)
- ⚙️ Configurable tracking intervals and exclusions
- 🎯 Smart project and language detection
- 🌿 Git branch tracking
- 🔧 Comprehensive command interface
- 🐛 Debug mode for troubleshooting

## Requirements

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- A Ziit server instance and API key

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'your-username/ziit-neovim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('ziit').setup({
      api_key = 'your-api-key-here',
      -- base_url = 'https://your-ziit-instance.com' -- optional, defaults to https://ziit.app
    })
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'your-username/ziit-neovim',
  requires = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('ziit').setup({
      api_key = 'your-api-key-here'
    })
  end
}
```

## Configuration

### Lua Configuration

```lua
require('ziit').setup({
  base_url = 'https://ziit.app',         -- Ziit server URL
  api_key = 'your-api-key-here',         -- Your Ziit API key (required)
  enabled = true,                        -- Enable/disable tracking
  debug = false,                         -- Enable debug logging
  heartbeat_interval = 120,              -- Minimum seconds between heartbeats
  offline_sync_interval = 300,           -- Seconds between offline sync attempts
  max_heartbeat_age = 86400,             -- Maximum age of queued heartbeats (seconds)
  use_absolute_paths = true,             -- Use absolute file paths (false for relative)
  exclude_patterns = {                   -- Patterns to exclude from tracking
    '%.git/',
    '%.svn/',
    'node_modules/',
    '%.tmp$',
    '%.log$',
  }
})
```

### Environment Variables

The plugin supports environment variables (highest priority):

```bash
export ZIIT_API_KEY="your-api-key-here"
export ZIIT_BASE_URL="https://ziit.app"
export ZIIT_ENABLED="true"
export ZIIT_DEBUG="false"
```

### JSON Configuration Files

The plugin supports configuration files in order of priority:

1. Environment variables (highest priority)
2. Project-specific: `.ziit.json` (in git root or current directory)
3. User-specific: `~/.ziit.json`

Example `~/.ziit.json`:

```json
{
  "api_key": "your-api-key-here",
  "base_url": "https://ziit.app",
  "enabled": true,
  "debug": false
}
```

### Global Variable Configuration

```lua
vim.g.ziit_config = {
  api_key = 'your-api-key-here',
  enabled = true
}
```

## Usage

The plugin automatically starts tracking once configured. It sends heartbeats based on your activity in Neovim.

### Commands

| Command                | Description                                |
| ---------------------- | ------------------------------------------ |
| `:ZiitSetup [options]` | Initialize plugin with optional parameters |
| `:ZiitEnable`          | Enable tracking                            |
| `:ZiitDisable`         | Disable tracking                           |
| `:checkhealth ziit`    | Check plugin health and status             |
| `:ZiitSync`            | Manually sync queued heartbeats            |
| `:ZiitTest`            | Test connection to Ziit server             |
| `:ZiitStats`           | Show today's coding statistics             |
| `:ZiitClearQueue`      | Clear the offline heartbeat queue          |
| `:ZiitDebugOn`         | Enable debug mode                          |
| `:ZiitDebugOff`        | Disable debug mode                         |
| `:ZiitDebugToggle`     | Toggle debug mode                          |

### Status Bar Integration

For **lualine** users, the plugin automatically integrates with your statusline showing:

- ⏱ Ziit - Normal operation
- ⏱ Ziit (5) - Offline with 5 queued heartbeats

For custom statuslines:

```lua
-- Get status text
local status = require('ziit.status').get_status_text()

-- Get highlight group
local hl = require('ziit.status').get_status_highlight()
```

## API

### Core Functions

```lua
-- Initialize the plugin
require('ziit').setup(config)

-- Manual heartbeat
require('ziit').send_heartbeat()

-- Get status
local status = require('ziit').get_status()
-- Returns: { enabled = bool, queue_size = number, last_heartbeat = table }

-- Get stats
require('ziit').get_stats(function(success, stats)
  if success then
    -- check https://docs.ziit.app/api/stats for the schema of the result
  end
end)

-- Test connection
require('ziit').test_connection(function(success, message)
  print('Connection: ' .. (success and 'OK' or 'Failed'))
end)

-- Debug control
require('ziit').enable_debug()        -- Turn on debug mode
require('ziit').disable_debug()       -- Turn off debug mode
local is_debug = require('ziit').toggle_debug()  -- Toggle and return new state
```

### Status Functions

```lua
local status = require('ziit.status')

-- Get formatted status text
local text = status.get_status_text()

-- Get appropriate highlight group
local highlight = status.get_status_highlight()

-- Refresh cached status
status.refresh()
```

## Troubleshooting

### Enable Debug Mode

```lua
require('ziit').setup({ debug = true })
```

Or temporarily:

```vim
:lua require('ziit.config').set('debug', true)
```

### Common Issues

**Plugin not tracking:**

- Verify API key with `:ZiitTest`
- Check status with `:checkhealth ziit`
- Ensure file isn't in exclude patterns

**Heartbeats not reaching server:**

- Check internet connection
- Verify server URL is correct
- Heartbeats are queued offline and sync automatically

**High queue size:**

- Indicates network/server issues
- Heartbeats sync automatically when connection restored
- Old heartbeats (>24h) are auto-purged

## How It Works

1. **Hybrid Tracking**: Combines timer-based (2 minutes) and activity-based heartbeats
2. **Rate Limiting**: Prevents spam with minimum 10-second intervals between heartbeats
3. **Heartbeat Creation**: Collects file path, language, project, branch, and timestamp
4. **Current File Detection**: Only sends heartbeats when actively working on a file
5. **Offline Queue**: Stores heartbeats when offline, syncs when connection restored
6. **Data Cleanup**: Automatically purges old queued heartbeats

## Contributing

Contributions welcome! Please read the contributing guidelines and submit pull requests.

## License

[AGPL-3.0 License](LICENSE)
