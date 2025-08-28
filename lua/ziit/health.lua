local M = {}

local function check_plenary()
    local ok, _ = pcall(require, 'plenary.curl')
    if ok then
        vim.health.ok('plenary.nvim is available')
        return true
    else
        vim.health.error('plenary.nvim is not installed', {
            'Install plenary.nvim: https://github.com/nvim-lua/plenary.nvim',
            'Required for HTTP requests and file operations',
        })
        return false
    end
end

local function check_neovim_version()
    if vim.fn.has('nvim-0.7') == 1 then
        vim.health.ok('Neovim version is supported (' .. vim.inspect(vim.version()) .. ')')
        return true
    else
        vim.health.error('Neovim version is too old', {
            'Requires Neovim 0.7 or later',
            'Current version: ' .. vim.inspect(vim.version()),
        })
        return false
    end
end

local function check_configuration()
    local config = require('ziit.config')
    local conf = config.get()

    if not conf.api_key then
        vim.health.error('No API key configured', {
            "Set API key via setup(): require('ziit').setup({api_key = 'your-key'})",
            "Or via environment: export ZIIT_API_KEY='your-key'",
            'Or via config file: ~/.ziit.json with {"api_key": "your-key"}',
        })
        return false
    end

    if conf.api_key == 'test-api-key' or conf.api_key == 'your-api-key-here' then
        vim.health.warn('Using test/placeholder API key', {
            'Replace with your actual Ziit API key',
        })
    else
        vim.health.ok('API key is configured')
    end

    if conf.base_url then
        vim.health.ok('Base URL: ' .. conf.base_url)
    else
        vim.health.error('No base URL configured')
        return false
    end

    return true
end

local function check_plugin_status()
    local config = require('ziit.config')

    if config.is_enabled() then
        vim.health.ok('Plugin is enabled and ready')

        local queue = require('ziit.queue')
        local queue_size = queue.size()

        if queue_size == 0 then
            vim.health.ok('No queued heartbeats (online)')
        else
            vim.health.warn('Heartbeats queued: ' .. queue_size, {
                'This indicates offline mode or connection issues',
                'Run :ZiitSync to manually sync queued heartbeats',
                'Check your network connection and server URL',
            })
        end
    else
        vim.health.error('Plugin is disabled', {
            "Enable with: require('ziit.config').set('enabled', true)",
            'Or ensure API key is configured',
        })
        return false
    end

    return true
end

local function check_file_permissions()
    local data_dir = vim.fn.stdpath('data')

    if vim.fn.isdirectory(data_dir) == 0 then
        vim.health.error('Neovim data directory not accessible: ' .. data_dir)
        return false
    end

    if vim.fn.filewritable(data_dir) == 0 then
        vim.health.error('Cannot write to data directory: ' .. data_dir, {
            'Check directory permissions',
            'Required for offline queue storage',
        })
        return false
    end

    vim.health.ok('File system permissions are correct')
    return true
end

local function check_connection_readiness()
    local config = require('ziit.config')

    if not config.is_enabled() then
        vim.health.info('Skipping connection check (plugin disabled)')
        return
    end

    local conf = config.get()

    -- Validate URL format
    if conf.base_url then
        if conf.base_url:match('^https?://') then
            vim.health.ok('Server URL format is valid')
        else
            vim.health.warn('Server URL should start with http:// or https://', {
                'Current URL: ' .. conf.base_url,
                'Example: https://ziit.app',
            })
        end
    end

    -- Check if API key looks reasonable
    if conf.api_key then
        if #conf.api_key >= 10 then
            vim.health.ok('API key length looks reasonable')
        else
            vim.health.warn('API key seems too short', {
                'Current length: ' .. #conf.api_key .. ' characters',
                'Make sure you have a valid Ziit API key',
            })
        end
    end

    vim.health.info('Use :ZiitTest to perform a live connection test')
end

local function show_debug_info()
    local config = require('ziit.config')
    local conf = config.get()

    vim.health.info('Configuration sources (in priority order):')
    vim.health.info('1. Lua setup() function')
    vim.health.info('2. Global variable vim.g.ziit_config')
    vim.health.info('3. Project .ziit.json file')
    vim.health.info('4. Home ~/.ziit.json file')
    vim.health.info('5. Environment variables')

    vim.health.info('Current settings:')
    vim.health.info('- Enabled: ' .. tostring(conf.enabled))
    vim.health.info('- Debug: ' .. tostring(conf.debug))
    vim.health.info('- Heartbeat interval: ' .. conf.heartbeat_interval .. 's')
    vim.health.info('- Offline sync interval: ' .. conf.offline_sync_interval .. 's')
    vim.health.info('- Max heartbeat age: ' .. conf.max_heartbeat_age .. 's')

    local queue = require('ziit.queue')
    vim.health.info('- Queue size: ' .. queue.size())

    local ziit = require('ziit')
    local status = ziit.get_status()
    if status.last_heartbeat then
        vim.health.info('- Last heartbeat: ' .. (status.last_heartbeat.timestamp or 'unknown'))
    else
        vim.health.info('- Last heartbeat: none')
    end
end

function M.check()
    vim.health.start('Ziit Time Tracking')

    local deps_ok = check_neovim_version() and check_plenary()
    if not deps_ok then
        vim.health.info('Fix dependency issues above before continuing')
        return
    end

    local perms_ok = check_file_permissions()
    local config_ok = check_configuration()
    local status_ok = check_plugin_status()

    if config_ok then
        check_connection_readiness()
    end

    vim.health.start('Ziit Debug Information')
    show_debug_info()

    if deps_ok and perms_ok and config_ok and status_ok then
        vim.health.start('Summary')
        vim.health.ok('Ziit plugin is healthy and ready to track activity!')
    end
end

return M
