local M = {}

local last_heartbeat = nil
local heartbeat_timer = nil
local is_initialized = false

local function send_heartbeat()
    local config = require('ziit.config')

    if not config.is_enabled() then
        return
    end

    local heartbeat = require('ziit.heartbeat')
    local new_heartbeat = heartbeat.create()

    if not new_heartbeat then
        return
    end

    -- Rate limiting: don't send if we just sent a heartbeat recently
    if last_heartbeat and last_heartbeat.timestamp then
        local last_time = last_heartbeat.timestamp
        local current_time = os.time()
        
        -- Parse ISO timestamp to seconds
        local last_timestamp = os.time({
            year = tonumber(last_time:sub(1, 4)),
            month = tonumber(last_time:sub(6, 7)),
            day = tonumber(last_time:sub(9, 10)),
            hour = tonumber(last_time:sub(12, 13)),
            min = tonumber(last_time:sub(15, 16)),
            sec = tonumber(last_time:sub(18, 19)),
        })
        
        -- Minimum 10 seconds between heartbeats
        if (current_time - last_timestamp) < 10 then
            return
        end
    end

    last_heartbeat = new_heartbeat

    local http = require('ziit.http')
    local queue = require('ziit.queue')

    http.send_heartbeat(new_heartbeat, function(success)
        if not success then
            queue.add(new_heartbeat)

            if config.is_debug() then
                vim.notify('Ziit: Heartbeat queued for later sync', vim.log.levels.DEBUG)
            end
        elseif config.is_debug() then
            vim.notify('Ziit: Heartbeat sent successfully', vim.log.levels.DEBUG)
        end
    end)
end

local function start_heartbeat_timer()
    local config = require('ziit.config')
    local interval = config.get('heartbeat_interval')

    if not interval or interval <= 0 then
        return
    end

    -- Stop existing timer if running
    if heartbeat_timer then
        heartbeat_timer:stop()
        heartbeat_timer:close()
        heartbeat_timer = nil
    end

    heartbeat_timer = vim.loop.new_timer()
    if heartbeat_timer then
        -- Start immediately, then repeat every interval
        heartbeat_timer:start(
            0,
            interval * 1000,
            vim.schedule_wrap(function()
                send_heartbeat()
            end)
        )

        if config.is_debug() then
            vim.notify('Ziit: Started heartbeat timer (interval: ' .. interval .. 's)', vim.log.levels.INFO)
        end
    end
end

local function stop_heartbeat_timer()
    if heartbeat_timer then
        heartbeat_timer:stop()
        heartbeat_timer:close()
        heartbeat_timer = nil

        local config = require('ziit.config')
        if config.is_debug() then
            vim.notify('Ziit: Stopped heartbeat timer', vim.log.levels.INFO)
        end
    end
end

local function setup_autocmds()
    local group = vim.api.nvim_create_augroup('Ziit', { clear = true })

    -- Activity-based events that trigger immediate heartbeats
    local events = {
        'BufEnter',
        'BufWinEnter',
        'CursorMoved',
        'CursorMovedI',
        'TextChanged',
        'TextChangedI',
        'InsertEnter',
        'InsertLeave',
    }

    vim.api.nvim_create_autocmd(events, {
        group = group,
        callback = function()
            -- Send heartbeat immediately on activity
            send_heartbeat()
        end,
        desc = 'Send Ziit heartbeat on activity',
    })

    vim.api.nvim_create_autocmd('VimLeavePre', {
        group = group,
        callback = function()
            stop_heartbeat_timer()
            local queue = require('ziit.queue')
            queue.sync()
        end,
        desc = 'Stop Ziit timer and sync queue on exit',
    })
end

local function setup_commands()
    vim.api.nvim_create_user_command('ZiitEnable', function()
        local config = require('ziit.config')
        config.set('enabled', true)
        start_heartbeat_timer()
        vim.notify('Ziit: Enabled', vim.log.levels.INFO)
    end, { desc = 'Enable Ziit tracking' })

    vim.api.nvim_create_user_command('ZiitDisable', function()
        local config = require('ziit.config')
        config.set('enabled', false)
        stop_heartbeat_timer()
        vim.notify('Ziit: Disabled', vim.log.levels.INFO)
    end, { desc = 'Disable Ziit tracking' })

    vim.api.nvim_create_user_command('ZiitSync', function()
        local queue = require('ziit.queue')

        if queue.is_empty() then
            vim.notify('Ziit: No heartbeats to sync', vim.log.levels.INFO)
            return
        end

        vim.notify('Ziit: Syncing heartbeats...', vim.log.levels.INFO)
        queue.sync()
    end, { desc = 'Sync queued heartbeats' })

    vim.api.nvim_create_user_command('ZiitTest', function()
        local http = require('ziit.http')

        vim.notify('Ziit: Testing connection...', vim.log.levels.INFO)
        http.test_connection(function(success, message)
            vim.notify('Ziit: ' .. message, success and vim.log.levels.INFO or vim.log.levels.ERROR)
        end)
    end, { desc = 'Test Ziit connection' })

    vim.api.nvim_create_user_command('ZiitStats', function()
        M.get_stats(function(success, stats)
            if success and stats then
                local message = string.format('Today: %s, This week: %s', stats.today or 'N/A', stats.week or 'N/A')
                vim.notify('Ziit: ' .. message, vim.log.levels.INFO)
            else
                vim.notify('Ziit: Failed to fetch stats', vim.log.levels.ERROR)
            end
        end)
    end, { desc = 'Show Ziit stats' })

    vim.api.nvim_create_user_command('ZiitClearQueue', function()
        local queue = require('ziit.queue')
        queue.clear()
        vim.notify('Ziit: Queue cleared', vim.log.levels.INFO)
    end, { desc = 'Clear heartbeat queue' })

    vim.api.nvim_create_user_command('ZiitDebugOn', function()
        M.enable_debug()
    end, { desc = 'Enable debug mode' })

    vim.api.nvim_create_user_command('ZiitDebugOff', function()
        M.disable_debug()
    end, { desc = 'Disable debug mode' })

    vim.api.nvim_create_user_command('ZiitDebugToggle', function()
        M.toggle_debug()
    end, { desc = 'Toggle debug mode' })
end

function M.setup(user_config)
    if is_initialized then
        return
    end

    local config = require('ziit.config')
    config.setup(user_config)

    if not config.is_enabled() then
        if config.is_debug() then
            vim.notify('Ziit: Plugin disabled or not configured', vim.log.levels.INFO)
        end
        return
    end

    local queue = require('ziit.queue')
    queue.init()
    queue.start_sync_timer()

    setup_autocmds()
    setup_commands()

    -- Start the heartbeat timer
    start_heartbeat_timer()

    is_initialized = true

    if config.is_debug() then
        vim.notify('Ziit: Plugin initialized', vim.log.levels.INFO)
    end
end

function M.send_heartbeat()
    send_heartbeat()
end

function M.get_status()
    local config = require('ziit.config')
    local queue = require('ziit.queue')

    return {
        enabled = config.is_enabled(),
        queue_size = queue.size(),
        last_heartbeat = last_heartbeat,
    }
end

function M.get_stats(callback)
    local http = require('ziit.http')
    http.get_stats(callback)
end

function M.test_connection(callback)
    local http = require('ziit.http')
    http.test_connection(callback)
end

function M.enable_debug()
    local config = require('ziit.config')
    config.set('debug', true)
    vim.notify('Ziit: Debug mode enabled', vim.log.levels.INFO)
end

function M.disable_debug()
    local config = require('ziit.config')
    config.set('debug', false)
    vim.notify('Ziit: Debug mode disabled', vim.log.levels.INFO)
end

function M.toggle_debug()
    local config = require('ziit.config')
    local current_debug = config.get('debug')
    config.set('debug', not current_debug)
    vim.notify('Ziit: Debug mode ' .. (current_debug and 'disabled' or 'enabled'), vim.log.levels.INFO)
    return not current_debug
end

return M
