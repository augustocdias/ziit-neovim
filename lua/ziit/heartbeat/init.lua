local Path = require('plenary.path')

local M = {}

local function get_git_branch()
    local git_dir = vim.fn.finddir('.git', '.;')
    if git_dir == '' then
        return nil
    end

    local head_file = Path:new(git_dir, 'HEAD')
    if not head_file:exists() then
        return nil
    end

    local content = head_file:read()
    if not content then
        return nil
    end

    local branch = content:match('ref: refs/heads/(.+)')
    if branch then
        return vim.trim(branch)
    end

    return nil
end

local function get_git_project()
    local git_dir = vim.fn.finddir('.git', '.;')
    if git_dir == '' then
        return nil
    end

    local git_parent = Path:new(git_dir):parent()
    return git_parent:absolute():match('([^/]+)$')
end

local function get_language_from_filename(filename)
    if not filename then
        return nil
    end

    local ext = filename:match('%.([^%.]+)$')
    if not ext then
        return nil
    end

    local language_map = {
        lua = 'Lua',
        js = 'JavaScript',
        ts = 'TypeScript',
        jsx = 'JavaScript',
        tsx = 'TypeScript',
        py = 'Python',
        rb = 'Ruby',
        go = 'Go',
        rs = 'Rust',
        c = 'C',
        cpp = 'C++',
        cc = 'C++',
        cxx = 'C++',
        h = 'C',
        hpp = 'C++',
        java = 'Java',
        php = 'PHP',
        cs = 'C#',
        sh = 'Shell',
        bash = 'Shell',
        zsh = 'Shell',
        fish = 'Shell',
        vim = 'Vim Script',
        html = 'HTML',
        css = 'CSS',
        scss = 'SCSS',
        sass = 'Sass',
        json = 'JSON',
        xml = 'XML',
        yaml = 'YAML',
        yml = 'YAML',
        toml = 'TOML',
        md = 'Markdown',
        txt = 'Text',
        sql = 'SQL',
        r = 'R',
        swift = 'Swift',
        kt = 'Kotlin',
        dart = 'Dart',
        elm = 'Elm',
        hs = 'Haskell',
        clj = 'Clojure',
        ex = 'Elixir',
        exs = 'Elixir',
        erl = 'Erlang',
        pl = 'Perl',
        scala = 'Scala',
        groovy = 'Groovy',
        dockerfile = 'Dockerfile',
    }

    return language_map[ext:lower()]
end

local function get_language_from_filetype()
    local ft = vim.bo.filetype
    if not ft or ft == '' then
        return nil
    end

    local filetype_map = {
        lua = 'Lua',
        javascript = 'JavaScript',
        typescript = 'TypeScript',
        python = 'Python',
        ruby = 'Ruby',
        go = 'Go',
        rust = 'Rust',
        c = 'C',
        cpp = 'C++',
        java = 'Java',
        php = 'PHP',
        cs = 'C#',
        sh = 'Shell',
        vim = 'Vim Script',
        html = 'HTML',
        css = 'CSS',
        scss = 'SCSS',
        sass = 'Sass',
        json = 'JSON',
        xml = 'XML',
        yaml = 'YAML',
        toml = 'TOML',
        markdown = 'Markdown',
        text = 'Text',
        sql = 'SQL',
        r = 'R',
        swift = 'Swift',
        kotlin = 'Kotlin',
        dart = 'Dart',
        elm = 'Elm',
        haskell = 'Haskell',
        clojure = 'Clojure',
        elixir = 'Elixir',
        erlang = 'Erlang',
        perl = 'Perl',
        scala = 'Scala',
        groovy = 'Groovy',
        dockerfile = 'Dockerfile',
    }

    return filetype_map[ft]
end

local function get_os()
    local uname = vim.loop.os_uname()
    if uname then
        return uname.sysname
    end

    if vim.fn.has('win32') == 1 then
        return 'Windows'
    elseif vim.fn.has('mac') == 1 then
        return 'Darwin'
    elseif vim.fn.has('unix') == 1 then
        return 'Linux'
    end

    return 'Unknown'
end

local function get_current_file()
    local bufnr = vim.api.nvim_get_current_buf()
    local filepath = vim.api.nvim_buf_get_name(bufnr)

    if filepath == '' then
        return nil
    end

    if
        vim.startswith(filepath, 'fugitive://')
        or vim.startswith(filepath, 'oil://')
        or vim.startswith(filepath, 'neo-tree://')
        or vim.startswith(filepath, 'NvimTree_')
    then
        return nil
    end

    local path = Path:new(filepath)
    if not path:exists() then
        return nil
    end

    return filepath
end

local function format_timestamp()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

function M.create()
    local current_file = get_current_file()

    if not current_file then
        return nil
    end

    local config = require('ziit.config')
    if config.should_exclude(current_file) then
        return nil
    end

    local language = get_language_from_filetype() or get_language_from_filename(current_file)
    local branch = get_git_branch()
    local project = get_git_project()

    local config = require('ziit.config')
    local file_path = current_file
    
    -- Convert to relative path if configured
    if not config.get('use_absolute_paths') then
        local cwd = vim.fn.getcwd()
        if vim.startswith(current_file, cwd) then
            file_path = vim.fn.fnamemodify(current_file, ':.')
        end
    end

    local heartbeat = {
        timestamp = format_timestamp(),
        editor = 'Neovim',
        os = get_os(),
        file = file_path,
    }

    if language then
        heartbeat.language = language
    end

    if branch then
        heartbeat.branch = branch
    end

    if project then
        heartbeat.project = project
    end

    return heartbeat
end

return M
