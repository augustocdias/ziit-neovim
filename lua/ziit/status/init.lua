local M = {}

local status_cache = {
    enabled = false,
    queue_size = 0,
    last_update = 0,
}

local function update_cache()
    local current_time = vim.loop.hrtime()

    if current_time - status_cache.last_update < 5e9 then
        return
    end

    local config = require('ziit.config')
    local queue = require('ziit.queue')

    status_cache.enabled = config.is_enabled()
    status_cache.queue_size = queue.size()
    status_cache.last_update = current_time
end

function M.get_status_text()
    update_cache()

    if not status_cache.enabled then
        return ''
    end

    local icon = '⏱'
    local text = 'Ziit'

    if status_cache.queue_size > 0 then
        text = text .. ' (' .. status_cache.queue_size .. ')'
    end

    return icon .. ' ' .. text
end

function M.get_status_highlight()
    update_cache()

    if not status_cache.enabled then
        return 'Comment'
    end

    if status_cache.queue_size > 0 then
        return 'WarningMsg'
    end

    return 'StatusLine'
end

function M.setup_lualine()
    if not pcall(require, 'lualine') then
        return false
    end

    local lualine = require('lualine')
    local config = lualine.get_config()

    local ziit_component = {
        function()
            return M.get_status_text()
        end,
        color = function()
            local hl = M.get_status_highlight()
            if hl == 'WarningMsg' then
                return { fg = '#ff9e00' }
            elseif hl == 'Comment' then
                return { fg = '#6c7086' }
            end
            return nil
        end,
        cond = function()
            return M.get_status_text() ~= ''
        end,
    }

    if not config.sections.lualine_x then
        config.sections.lualine_x = {}
    end

    table.insert(config.sections.lualine_x, ziit_component)

    lualine.setup(config)
    return true
end

function M.setup_statusline()
    if M.setup_lualine() then
        return
    end

    local old_statusline = vim.o.statusline

    local function get_ziit_status()
        local status = M.get_status_text()
        if status == '' then
            return ''
        end
        return '%#' .. M.get_status_highlight() .. '#' .. status .. '%*'
    end

    if old_statusline and old_statusline ~= '' then
        vim.o.statusline = old_statusline .. ' ' .. '%{v:lua.require("ziit.status").get_statusline_component()}'
    else
        vim.o.statusline = '%f %m%r%h%w%=%{v:lua.require("ziit.status").get_statusline_component()} %l,%c %P'
    end
end

function M.get_statusline_component()
    local status = M.get_status_text()
    if status == '' then
        return ''
    end
    return status
end

function M.refresh()
    status_cache.last_update = 0
    update_cache()
end

return M
