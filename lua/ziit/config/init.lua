local Path = require('plenary.path')

local M = {}

M.defaults = {
    base_url = 'https://ziit.app',
    api_key = nil,
    enabled = true,
    debug = false,
    heartbeat_interval = 120,
    offline_sync_interval = 300,
    max_heartbeat_age = 86400,
    use_absolute_paths = true,
    exclude_patterns = {
        '%.git/',
        '%.svn/',
        '%.hg/',
        '/tmp/',
        '%.tmp$',
        '%.log$',
        'node_modules/',
        '%.cache/',
    },
}

local config = vim.tbl_deep_extend('force', {}, M.defaults)

local function merge_config(user_config)
    config = vim.tbl_deep_extend('force', config, user_config or {})
end

local function load_config_file(filepath)
    local path = Path:new(filepath)
    if not path:exists() then
        return nil
    end

    local content = path:read()
    if not content then
        return nil
    end

    local ok, decoded = pcall(vim.json.decode, content)
    if not ok then
        vim.notify('Ziit: Failed to parse config file: ' .. filepath, vim.log.levels.WARN)
        return nil
    end

    return decoded
end

local function find_project_config()
    local current_dir = vim.fn.getcwd()
    local path = Path:new(current_dir)

    while path and tostring(path) ~= '/' do
        local config_file = path / '.ziit.json'
        if config_file:exists() then
            return tostring(config_file)
        end
        path = path:parent()
    end

    return nil
end

local function load_env_config()
    local env_config = {}

    local api_key = vim.fn.getenv('ZIIT_API_KEY')
    if api_key and api_key ~= vim.v.null and api_key ~= '' then
        env_config.api_key = api_key
    end

    local base_url = vim.fn.getenv('ZIIT_BASE_URL')
    if base_url and base_url ~= vim.v.null and base_url ~= '' then
        env_config.base_url = base_url
    end

    local enabled = vim.fn.getenv('ZIIT_ENABLED')
    if enabled and enabled ~= vim.v.null and enabled ~= '' then
        env_config.enabled = enabled:lower() == 'true' or enabled == '1'
    end

    local debug = vim.fn.getenv('ZIIT_DEBUG')
    if debug and debug ~= vim.v.null and debug ~= '' then
        env_config.debug = debug:lower() == 'true' or debug == '1'
    end

    return next(env_config) and env_config or nil
end

function M.load()
    local configs = {}

    local env_config = load_env_config()
    if env_config then
        table.insert(configs, env_config)
    end

    local home_config = load_config_file(vim.fn.expand('~/.ziit.json'))
    if home_config then
        table.insert(configs, home_config)
    end

    local project_config_path = find_project_config()
    if project_config_path then
        local project_config = load_config_file(project_config_path)
        if project_config then
            table.insert(configs, project_config)
        end
    end

    if vim.g.ziit_config then
        table.insert(configs, vim.g.ziit_config)
    end

    for _, user_config in ipairs(configs) do
        merge_config(user_config)
    end

    if M.is_debug() then
        vim.notify('Ziit: Configuration loaded', vim.log.levels.INFO)
    end
end

function M.get(key)
    if key then
        return config[key]
    end
    return config
end

function M.set(key, value)
    config[key] = value
end

function M.is_enabled()
    return config.enabled and config.api_key ~= nil
end

function M.is_debug()
    return config.debug
end

function M.should_exclude(filepath)
    if not filepath then
        return true
    end

    for _, pattern in ipairs(config.exclude_patterns) do
        if string.match(filepath, pattern) then
            return true
        end
    end

    return false
end

function M.validate()
    local errors = {}

    if not config.api_key then
        table.insert(errors, 'API key is required')
    end

    if not config.base_url then
        table.insert(errors, 'Base URL is required')
    end

    if #errors > 0 then
        return false, errors
    end

    return true, {}
end

function M.setup(user_config)
    merge_config(user_config)
    M.load()

    local valid, errors = M.validate()
    if not valid and M.is_debug() then
        vim.notify('Ziit: Configuration errors: ' .. table.concat(errors, ', '), vim.log.levels.ERROR)
    end
end

return M
