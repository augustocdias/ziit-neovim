local Path = require('plenary.path')

local M = {}

local queue_file = nil
local queue_cache = {}
local is_dirty = false

local function get_queue_file_path()
    if queue_file then
        return queue_file
    end

    local data_dir = vim.fn.stdpath('data')
    local ziit_dir = Path:new(data_dir, 'ziit')

    if not ziit_dir:exists() then
        ziit_dir:mkdir({ parents = true })
    end

    queue_file = ziit_dir / 'queue.json'
    return queue_file
end

local function load_queue()
    local file_path = get_queue_file_path()

    if not file_path:exists() then
        queue_cache = {}
        return
    end

    local content = file_path:read()
    if not content or content == '' then
        queue_cache = {}
        return
    end

    local ok, data = pcall(vim.json.decode, content)
    if ok and type(data) == 'table' then
        queue_cache = data
    else
        queue_cache = {}
        local config = require('ziit.config')
        if config.is_debug() then
            vim.notify('Ziit: Failed to load queue file, starting with empty queue', vim.log.levels.WARN)
        end
    end
end

local function save_queue()
    if not is_dirty then
        return
    end

    local file_path = get_queue_file_path()
    local content = vim.json.encode(queue_cache)

    file_path:write(content, 'w')
    is_dirty = false
end

local function clean_old_heartbeats()
    local config = require('ziit.config')
    local max_age = config.get('max_heartbeat_age')
    local cutoff_time = os.time() - max_age

    local cleaned = {}
    for _, heartbeat in ipairs(queue_cache) do
        local timestamp_str = heartbeat.timestamp
        if timestamp_str then
            local timestamp = os.time({
                year = tonumber(timestamp_str:sub(1, 4)),
                month = tonumber(timestamp_str:sub(6, 7)),
                day = tonumber(timestamp_str:sub(9, 10)),
                hour = tonumber(timestamp_str:sub(12, 13)),
                min = tonumber(timestamp_str:sub(15, 16)),
                sec = tonumber(timestamp_str:sub(18, 19)),
            })

            if timestamp > cutoff_time then
                table.insert(cleaned, heartbeat)
            end
        end
    end

    if #cleaned ~= #queue_cache then
        queue_cache = cleaned
        is_dirty = true

        local config = require('ziit.config')
        if config.is_debug() then
            vim.notify(string.format('Ziit: Cleaned %d old heartbeats', #queue_cache - #cleaned), vim.log.levels.INFO)
        end
    end
end

function M.init()
    load_queue()
    clean_old_heartbeats()
end

function M.add(heartbeat)
    if not heartbeat then
        return
    end

    table.insert(queue_cache, heartbeat)
    is_dirty = true

    clean_old_heartbeats()
    save_queue()

    local config = require('ziit.config')
    if config.is_debug() then
        vim.notify(string.format('Ziit: Added heartbeat to queue (total: %d)', #queue_cache), vim.log.levels.DEBUG)
    end
end

function M.get_all()
    return vim.deepcopy(queue_cache)
end

function M.remove_batch(count)
    if count <= 0 or #queue_cache == 0 then
        return
    end

    count = math.min(count, #queue_cache)

    for i = 1, count do
        table.remove(queue_cache, 1)
    end

    is_dirty = true
    save_queue()

    local config = require('ziit.config')
    if config.is_debug() then
        vim.notify(
            string.format('Ziit: Removed %d heartbeats from queue (remaining: %d)', count, #queue_cache),
            vim.log.levels.DEBUG
        )
    end
end

function M.clear()
    queue_cache = {}
    is_dirty = true
    save_queue()

    local config = require('ziit.config')
    if config.is_debug() then
        vim.notify('Ziit: Cleared queue', vim.log.levels.INFO)
    end
end

function M.size()
    return #queue_cache
end

function M.is_empty()
    return #queue_cache == 0
end

function M.sync()
    if M.is_empty() then
        return
    end

    local http = require('ziit.http')
    local heartbeats = M.get_all()
    local batch_size = math.min(#heartbeats, 1000)
    local batch = vim.list_slice(heartbeats, 1, batch_size)

    http.send_batch(batch, function(success, result)
        if success then
            M.remove_batch(batch_size)

            local config = require('ziit.config')
            if config.is_debug() then
                vim.notify(string.format('Ziit: Successfully synced %d heartbeats', batch_size), vim.log.levels.INFO)
            end

            if not M.is_empty() then
                vim.defer_fn(function()
                    M.sync()
                end, 1000)
            end
        else
            local config = require('ziit.config')
            if config.is_debug() then
                vim.notify('Ziit: Failed to sync heartbeats: ' .. (result or 'Unknown error'), vim.log.levels.ERROR)
            end
        end
    end)
end

function M.start_sync_timer()
    local config = require('ziit.config')
    local interval = config.get('offline_sync_interval')

    if not interval or interval <= 0 then
        return
    end

    local timer = vim.loop.new_timer()
    if timer then
        timer:start(
            interval * 1000,
            interval * 1000,
            vim.schedule_wrap(function()
                if not M.is_empty() then
                    M.sync()
                end
            end)
        )
    end
end

return M
