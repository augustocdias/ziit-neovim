if vim.g.loaded_ziit then
    return
end

if vim.fn.has('nvim-0.7') == 0 then
    vim.notify('Ziit: Requires Neovim 0.7+', vim.log.levels.ERROR)
    return
end

local has_plenary = pcall(require, 'plenary.curl')
if not has_plenary then
    vim.notify('Ziit: Requires plenary.nvim', vim.log.levels.ERROR)
    return
end

vim.api.nvim_create_user_command('ZiitSetup', function(opts)
    local config = {}

    if opts.args and opts.args ~= '' then
        local parts = vim.split(opts.args, ' ')
        for _, part in ipairs(parts) do
            local key, value = part:match('([^=]+)=(.+)')
            if key and value then
                if key == 'enabled' or key == 'debug' then
                    config[key] = value == 'true'
                elseif key == 'heartbeat_interval' or key == 'offline_sync_interval' or key == 'max_heartbeat_age' then
                    config[key] = tonumber(value)
                else
                    config[key] = value
                end
            end
        end
    end

    require('ziit').setup(config)
end, {
    nargs = '*',
    desc = 'Setup Ziit plugin with optional configuration',
    complete = function()
        return {
            'api_key=',
            'base_url=https://ziit.app',
            'enabled=true',
            'debug=false',
            'heartbeat_interval=120',
            'offline_sync_interval=300',
        }
    end,
})

local function auto_setup()
    local config_file = vim.fn.expand('~/.ziit.json')
    if vim.fn.filereadable(config_file) == 1 then
        require('ziit').setup()
        return
    end

    local git_dir = vim.fn.finddir('.git', '.;')
    if git_dir ~= '' then
        local project_config = vim.fn.fnamemodify(git_dir, ':h') .. '/.ziit.json'
        if vim.fn.filereadable(project_config) == 1 then
            require('ziit').setup()
            return
        end
    end

    if vim.g.ziit_config then
        require('ziit').setup()
    end
end

vim.defer_fn(auto_setup, 100)

vim.g.loaded_ziit = 1
