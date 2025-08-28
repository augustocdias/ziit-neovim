local curl = require('plenary.curl')

local M = {}

local function build_url(endpoint)
    local config = require('ziit.config')
    local base_url = config.get('base_url')

    if not base_url then
        return nil
    end

    base_url = base_url:gsub('/$', '')
    endpoint = endpoint:gsub('^/', '')

    return base_url .. '/api/external/' .. endpoint
end

local function get_headers()
    local config = require('ziit.config')
    local api_key = config.get('api_key')

    if not api_key then
        return nil
    end

    return {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer ' .. api_key,
        ['User-Agent'] = 'ziit-neovim/1.0.0',
    }
end

local function handle_response(response, success_callback, error_callback)
    local config = require('ziit.config')

    if config.is_debug() then
        vim.notify(string.format('Ziit HTTP: %d %s', response.status, response.body or ''), vim.log.levels.DEBUG)
    end

    if response.status >= 200 and response.status < 300 then
        if success_callback then
            success_callback(response)
        end
    else
        local error_msg = string.format('HTTP %d: %s', response.status, response.body or 'Unknown error')

        if config.is_debug() then
            vim.notify('Ziit: ' .. error_msg, vim.log.levels.ERROR)
        end

        if error_callback then
            error_callback(error_msg, response)
        end
    end
end

function M.send_heartbeat(heartbeat, callback)
    local url = build_url('heartbeats')
    local headers = get_headers()

    if not url or not headers then
        if callback then
            callback(false, 'Configuration error: missing URL or API key')
        end
        return
    end

    local body = vim.json.encode(heartbeat)

    curl.post(url, {
        body = body,
        headers = headers,
        timeout = 10000,
        callback = function(response)
            handle_response(response, function(res)
                if callback then
                    callback(true, res)
                end
            end, function(error_msg, res)
                if callback then
                    callback(false, error_msg)
                end
            end)
        end,
    })
end

function M.send_batch(heartbeats, callback)
    if not heartbeats or #heartbeats == 0 then
        if callback then
            callback(true, 'No heartbeats to send')
        end
        return
    end

    if #heartbeats > 1000 then
        heartbeats = vim.list_slice(heartbeats, 1, 1000)
    end

    local url = build_url('batch')
    local headers = get_headers()

    if not url or not headers then
        if callback then
            callback(false, 'Configuration error: missing URL or API key')
        end
        return
    end

    local body = vim.json.encode(heartbeats)

    curl.post(url, {
        body = body,
        headers = headers,
        timeout = 30000,
        callback = function(response)
            handle_response(response, function(res)
                if callback then
                    callback(true, res)
                end
            end, function(error_msg, res)
                if callback then
                    callback(false, error_msg)
                end
            end)
        end,
    })
end

function M.get_stats(callback)
    local url = build_url('stats')
    local headers = get_headers()

    if not url or not headers then
        if callback then
            callback(false, 'Configuration error: missing URL or API key')
        end
        return
    end

    local timezone_offset = os.difftime(os.time(), os.time(os.date('!*t')))

    curl.get(url, {
        query = {
            timeRange = 'today',
            midnightOffsetSeconds = tostring(timezone_offset),
        },
        headers = headers,
        timeout = 10000,
        callback = function(response)
            handle_response(response, function(res)
                local ok, data = pcall(vim.json.decode, res.body)
                if ok then
                    if callback then
                        callback(true, data)
                    end
                else
                    if callback then
                        callback(false, 'Failed to parse response')
                    end
                end
            end, function(error_msg)
                if callback then
                    callback(false, error_msg)
                end
            end)
        end,
    })
end

function M.test_connection(callback)
    local config = require('ziit.config')

    if not config.is_enabled() then
        if callback then
            callback(false, 'Plugin not enabled or API key missing')
        end
        return
    end

    M.get_stats(function(success, result)
        if callback then
            if success then
                callback(true, 'Connection successful')
            else
                callback(false, 'Connection failed: ' .. (result or 'Unknown error'))
            end
        end
    end)
end

return M
