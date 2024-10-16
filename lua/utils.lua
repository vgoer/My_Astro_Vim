local M = {}
local astro = require "astrocore"
local is_win = vim.loop.os_uname().version:find "Windows"

function M.get_global_npm_path()
  if is_win then
    return vim.fn.system("cmd.exe /c npm root -g") 
  end
  return vim.fn.system("npm root -g")
end

function M.file_exists(filepath) return vim.fn.glob(filepath) ~= "" end

local uv = vim.uv or vim.loop

function M.insert_to_file_first_line(path, content)
  local stat, fd, err_msg, original_content
  fd, _, err_msg = uv.fs_open(path, "r", 438)
  if not fd then
    print("Error opening file: " .. (err_msg or "unknown error"))
    return
  end

  stat, _, err_msg = uv.fs_fstat(fd)
  if not stat then
    print("Error getting file stats: " .. (err_msg or "unknown error"))
    uv.fs_close(fd)
    return
  end

  original_content, _, err_msg = uv.fs_read(fd, stat.size, 0)
  if not original_content then
    print("Error reading file: " .. (err_msg or "unknown error"))
    uv.fs_close(fd)
    return
  end

  uv.fs_close(fd)

  fd, _, err_msg = uv.fs_open(path, "w", 438)
  if not fd then
    print("Error opening file for writing: " .. (err_msg or "unknown error"))
    return
  end

  _, _, err_msg = uv.fs_write(fd, content, -1)
  if err_msg then
    print("Error writing to file: " .. err_msg)
    uv.fs_close(fd)
    return
  end

  _, _, err_msg = uv.fs_write(fd, original_content, -1)
  if err_msg then
    print("Error writing original content to file: " .. err_msg)
    uv.fs_close(fd)
    return
  end

  uv.fs_close(fd)
end

function M.write_to_file(file_path, content)
  uv.fs_open(file_path, "w", 438, function(err, fd)
    if err then
      print("Error opening file: " .. err)
      return
    end
    uv.fs_write(fd, content, -1, function(err)
      if err then print("Error writing to file: " .. err) end
      uv.fs_close(fd, function(err)
        if err then print("Error closing file: " .. err) end
      end)
    end)
  end)
end

-- Function to get the parent directory of a given file path
-- @param filepath: The full path of the file
-- @return: The parent directory of the file
function M.get_parent_directory(filepath)
  -- Use vim.fn.fnamemodify to modify the file path
  -- ":h" means to get the head (directory path) of the file
  return vim.fn.fnamemodify(filepath, ":h")
end

-- Function to get the immediate parent directory name of a given file path
-- @param filepath: The full path of the file
-- @return: The name of the parent directory or an empty string if no parent directory exists
function M.get_immediate_parent_directory(filepath)
  -- Use vim.fn.fnamemodify to get the head (directory path) of the file
  local parent_path = vim.fn.fnamemodify(filepath, ":h")
  -- Split the parent path by the directory separator and get the last part
  local parts = vim.split(parent_path, "/")
  -- Return the last part if it exists, otherwise return an empty string
  return parts[#parts] or nil
end

-- Function to check if a given path is a file or directory
-- @param path: The path to check
-- @return: "file" if it's a file, "directory" if it's a directory, or nil if it doesn't exist
function M.get_path_type(path)
  local stat = vim.loop.fs_stat(path)
  if stat then
    return stat.type
  else
    return nil
  end
end

-- Function to get the base name of a file (i.e., the file name without its extension)
-- e.g lua/init.lua => lua/init
-- @param filename: The full name of the file (including its extension)
-- @return: The base name of the file
function M.get_base_name(filename) return vim.fn.fnamemodify(filename, ":r") end

-- Function to get the extension of a file
-- e.g ./lua/init.lua => lua
-- @param filename: The full name of the file (including its extension)
-- @return: The extension of the file
function M.get_extension(filename) return vim.fn.fnamemodify(filename, ":e") end

-- Function to get the tail part (file name) of a file path
-- e.g ./lua/init.lua => init.lua
-- @param file_path: The full path of the file
-- @return: The file name with extension
function M.get_file_name_with_extension(file_path) return vim.fn.fnamemodify(file_path, ":t") end

-- Function to get the filename without extension from a given path
-- @param filepath: The full path of the file
-- @return: The filename without the path and extension
function M.get_filename_without_extension(filepath)
  -- Use vim.fn.fnamemodify to modify the file path
  -- ":t:r" means to get the tail (filename) and remove the extension
  return vim.fn.fnamemodify(filepath, ":t:r")
end

-- Function to get the current working directory relative to the given file path
-- current cwd: /Users/jayce.zhao/.config/nvim/
-- current file_path: /Users/jayce.zhao/.config/nvim/lua/plugins/visual-multi.lua
-- return lua/plugins/visual-multi.lua
-- @param file_path: The full path of the file
-- @return: The current working directory relative to the file path
function M.get_cwd(file_path) return vim.fn.fnamemodify(file_path, ":.") end

-- Function to get the file path relative to the home directory
-- input: /Users/jayce.zhao/.config/nvim/lua/plugins/visual-multi.lua
-- output: ~/.config/nvim/lua/plugins/visual-multi.lua
-- @param file_path: The full path of the file
-- @return: The file path relative to the home directory
function M.get_home(file_path) return vim.fn.fnamemodify(file_path, ":~") end

-- Function to get the URI from a file path
-- input: /Users/jayce.zhao/.config/nvim/lua/plugins/visual-multi.lua
-- output: file:///Users/jayce.zhao/.config/nvim/lua/plugins/visual-multi.lua
-- @param file_path: The full path of the file
-- @return: The URI corresponding to the file path
function M.get_uri(file_path) return vim.uri_from_fname(file_path) end

function M.on_confirm(prompt, callback)
  vim.ui.input({ prompt = prompt .. " (Yes/No): " }, function(input)
    if string.lower(input) == "yes" or string.lower(input) == "y" then
      if callback then callback() end
    end
  end)
end

function M.select_ui(vals, prompt, callback)
  local options = vim.tbl_filter(function(val) return vals[val] ~= "" end, vim.tbl_keys(vals))
  if vim.tbl_isempty(options) then
    astro.notify("No values to select", vim.log.levels.WARN)
    return
  end

  table.sort(options)

  vim.ui.select(options, {
    prompt = prompt,
    format_item = function(item) return ("%s: %s"):format(item, vals[item]) end,
  }, function(choice)
    local result = vals[choice]
    if result then
      if callback then callback(result) end
    else
      astro.notify("No item selected", vim.log.levels.WARN)
    end
  end)
end

-- Checks if a table is empty.
-- @param t The table to check.
-- @return true if the table is nil or empty, false otherwise.
function M.is_table_empty(t)
  if t == nil or next(t) == nil then
    return true
  else
    return false
  end
end

function M.decode_json(filename)
  -- Open the file in read mode
  local file = io.open(filename, "r")
  if not file then
    return false -- File doesn't exist or cannot be opened
  end

  -- Read the contents of the file
  local content = file:read "*all"
  file:close()

  -- Parse the JSON content
  local json_parsed, json = pcall(vim.fn.json_decode, content)
  if not json_parsed or type(json) ~= "table" then
    return false -- Invalid JSON format
  end
  return json
end

function M.check_json_key_exists(json, ...) return vim.tbl_get(json, ...) ~= nil end

function M.is_vue_project(bufnr)
  local lsp_rooter
  if type(bufnr) ~= "number" then bufnr = vim.api.nvim_get_current_buf() end
  local rooter = require "astrocore.rooter"
  if not lsp_rooter then
    lsp_rooter = rooter.resolve("lsp", {
      ignore = {
        servers = function(client)
          return not vim.tbl_contains({ "vtsls", "typescript-tools", "volar", "eslint", "tsserver" }, client.name)
        end,
      },
    })
  end

  local vue_dependency = false
  for _, root in ipairs(require("astrocore").list_insert_unique(lsp_rooter(bufnr), { vim.fn.getcwd() })) do
    local package_json = M.decode_json(root .. "/package.json")
    if
      package_json
      and (
        M.check_json_key_exists(package_json, "dependencies", "vue")
        or M.check_json_key_exists(package_json, "devDependencies", "vue")
      )
    then
      vue_dependency = true
      break
    end
  end

  return vue_dependency
end

function M.is_in_list(value, list)
  for i = 1, #list do
    if list[i] == value then return true end
  end
  return false
end

function M.get_parent_dir(path) return path:match "(.+)/" end

function M.copy_file(source_file, target_file)
  local target_file_parent_path = M.get_parent_dir(target_file)
  local cmd = string.format("mkdir -p %s", vim.fn.shellescape(target_file_parent_path))
  os.execute(cmd)
  cmd = string.format("cp %s %s", vim.fn.shellescape(source_file), vim.fn.shellescape(target_file))
  os.execute(cmd)

  vim.notify("File " .. target_file .. " created success.", vim.log.levels.INFO)
end

function M.get_filename_with_extension_from_path(path) return string.match(path, "([^/]+)$") end

function M.get_launch_json_by_source_file(source_file)
  local target_file = vim.fn.getcwd() .. "/.vscode/launch.json"
  local file_exist = M.file_exists(target_file)
  if file_exist then
    local confirm = vim.fn.confirm("File `.vscode/launch.json` Exist, Overwrite it?", "&Yes\n&No", 1, "Question")
    if confirm == 1 then M.copy_file(source_file, target_file) end
  else
    M.copy_file(source_file, target_file)
  end
end

function M.create_launch_json()
  vim.ui.select({
    "go",
    "node",
    "rust",
    "python",
  }, { prompt = "Select Language Debug Template", default = "go" }, function(select)
    if not select then return end
    if select == "go" then
      local source_file = vim.fn.stdpath "config" .. "/.vscode/go_launch.json"
      M.get_launch_json_by_source_file(source_file)
    elseif select == "node" then
      local source_file = vim.fn.stdpath "config" .. "/.vscode/node_launch.json"
      M.get_launch_json_by_source_file(source_file)
    elseif select == "rust" then
      local source_file = vim.fn.stdpath "config" .. "/.vscode/rust_launch.json"
      M.get_launch_json_by_source_file(source_file)
    elseif select == "python" then
      local source_file = vim.fn.stdpath "config" .. "/.vscode/python_launch.json"
      M.get_launch_json_by_source_file(source_file)
    end
  end)
end

function M.remove_lsp_cwd(path, client_name)
  local cwd = M.get_lsp_root_dir(client_name)

  if cwd == nil then return nil end
  cwd = M.escape_pattern(cwd)

  return path:gsub("^" .. cwd, "")
end

function M.remove_cwd(path)
  local cwd = vim.fn.getcwd()
  cwd = M.escape_pattern(cwd) .. "/"

  return path:gsub("^" .. cwd, "")
end

function M.escape_pattern(text) return text:gsub("([^%w])", "%%%1") end

function M.get_lsp_root_dir(client_name)
  local clients = vim.lsp.get_clients()

  if next(clients) == nil then return nil end

  for _, client in ipairs(clients) do
    if client.name == client_name then
      local root_dir = client.config.root_dir
      if root_dir then return root_dir end
    end
  end

  return nil
end

function M.write_log(file_name, content)
  local file = io.open(file_name, "w")
  if file then
    file:write(vim.inspect(content))
    file:close()
  end
end

function M.write_log_append(file_name, content)
  local file = io.open(file_name, "w")
  if file then
    file:write(vim.inspect(content))
    file:close()
  end
end

function M.save_client(client)
  if client.name then
    local file = io.open(client.name .. ".txt", "w")
    if file then
      file:write(vim.inspect(client))
      file:close()
    end
  end
end

function M.extend(t, key, values)
  local keys = vim.split(key, ".", { plain = true })
  for i = 1, #keys do
    local k = keys[i]
    t[k] = t[k] or {}
    if type(t) ~= "table" then return end
    t = t[k]
  end
  return vim.list_extend(t, values)
end

-- This file is automatically ran last in the setup process and is a good place to configure
-- augroups/autocommands and custom filetypes also this just pure lua so
-- anything that doesn't fit in the normal config locations above can go here
function M.yaml_ft(path, bufnr)
  local buf_text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  if
    -- check if file is in roles, tasks, or handlers folder
    vim.regex("(tasks\\|roles\\|handlers)/"):match_str(path)
    -- check for known ansible playbook text and if found, return yaml.ansible
    or vim.regex("hosts:\\|tasks:"):match_str(buf_text)
  then
    return "yaml.ansible"
  elseif vim.regex("AWSTemplateFormatVersion:"):match_str(buf_text) then
    return "yaml.cfn"
  else -- return yaml if nothing else
    return "yaml"
  end
end

function M.better_search(key)
  return function()
    local searched, error =
      pcall(vim.cmd.normal, { args = { (vim.v.count > 0 and vim.v.count or "") .. key }, bang = true })
    if not searched and type(error) == "string" then require("astrocore").notify(error, vim.log.levels.ERROR) end
  end
end

function M.remove_keymap(mode, key)
  for _, map in pairs(vim.api.nvim_get_keymap(mode)) do
    ---@diagnostic disable-next-line: undefined-field
    if map.lhs == key then vim.api.nvim_del_keymap(mode, key) end
  end
end

function M.toggle_lazy_docker()
  return function()
    require("astrocore").toggle_term_cmd {
      cmd = "lazydocker",
      direction = "float",
      hidden = true,
      on_open = function() M.remove_keymap("t", "<Esc>") end,
      on_close = function() vim.api.nvim_set_keymap("t", "<Esc>", [[<C-\><C-n>]], { silent = true, noremap = true }) end,
      on_exit = function() end,
    }
  end
end

function M.toggle_btm()
  return function()
    require("astrocore").toggle_term_cmd {
      cmd = "btm",
      direction = "float",
      hidden = true,
      on_open = function() M.remove_keymap("t", "<Esc>") end,
      on_close = function() vim.api.nvim_set_keymap("t", "<Esc>", [[<C-\><C-n>]], { silent = true, noremap = true }) end,
      on_exit = function() end,
    }
  end
end

-- 添加btop
function M.toggle_btop()
  return function()
    require("astrocore").toggle_term_cmd {
      cmd = "btop",
      direction = "float",
      hidden = true,
      on_open = function() M.remove_keymap("t", "<Esc>") end,
      on_close = function() vim.api.nvim_set_keymap("t", "<Esc>", [[<C-\><C-n>]], { silent = true, noremap = true }) end,
      on_exit = function() end,
    }
  end
end

-- 添加 asciiquarium
function M.toggle_asciiquarium()
  return function()
    require("astrocore").toggle_term_cmd {
      cmd = "asciiquarium | lolcat",
      direction = "float",
      hidden = true,
      on_open = function() M.remove_keymap("t", "<Esc>") end,
      on_close = function() vim.api.nvim_set_keymap("t", "<Esc>", [[<C-\><C-n>]], { silent = true, noremap = true }) end,
      on_exit = function() end,
    }
  end
end

-- 添加烟花 
function M.toggle_firework()
  return function()
    -- 随机
    math.randomseed(os.time())
    local random_number = math.random(0,4)
    require("astrocore").toggle_term_cmd {
      cmd = string.format("firework -l -g -d %d", random_number),
      direction = "float",
      hidden = true,
      on_open = function() M.remove_keymap("t", "<Esc>") end,
      on_close = function() vim.api.nvim_set_keymap("t", "<Esc>", [[<C-\><C-n>]], { silent = true, noremap = true }) end,
      on_exit = function() end,
    }
  end
end

-- 添加音乐播放
function M.toggle_musicfox()
  return function()
    -- 随机
    require("astrocore").toggle_term_cmd {
      cmd = "musicfox",
      direction = "float",
      hidden = true,
      on_open = function() M.remove_keymap("t", "<Esc>") end,
      on_close = function() vim.api.nvim_set_keymap("t", "<Esc>", [[<C-\><C-n>]], { silent = true, noremap = true }) end,
      on_exit = function() end,
    }
  end
end


function M.toggle_lazy_git()
  return function()
    local worktree = require("astrocore").file_worktree()
    local flags = worktree and (" --work-tree=%s --git-dir=%s"):format(worktree.toplevel, worktree.gitdir) or ""
    require("astrocore").toggle_term_cmd {
      cmd = "lazygit " .. flags,
      direction = "float",
      hidden = true,
      on_open = function() M.remove_keymap("t", "<Esc>") end,
      on_close = function() vim.api.nvim_set_keymap("t", "<Esc>", [[<C-\><C-n>]], { silent = true, noremap = true }) end,
      on_exit = function() end,
    }
  end
end

function M.removeValueFromTable(tbl, value)
  for i, v in ipairs(tbl) do
    if v == value then
      table.remove(tbl, i)
      return true
    end
  end
  return false
end

function M.list_remove_unique(lst, vals)
  if not lst then lst = {} end
  assert(vim.islist(lst), "Provided table is not a list like table")
  if not vim.islist(vals) then vals = { vals } end
  local added = {}
  vim.tbl_map(function(v) added[v] = true end, lst)
  for _, val in ipairs(vals) do
    if added[val] then
      M.removeValueFromTable(lst, val)
      added[val] = false
    end
  end
  return lst
end

function M.toggle_unicmatrix()
  return function()
    require("astrocore").toggle_term_cmd {
      cmd = "unimatrix -s 96 -o -b",
      hidden = false,
      direction = "float",
      float_opts = {
        -- Enable full screen
        width = vim.o.columns,
        height = vim.o.lines,
        border = "none",
      },
    }
  end
end

function M.tte(selection, open_callback, close_callback, flag)
  local current_path = vim.fn.expand "%:p" -- get current file path
  local cmd = "tte --input-file " .. current_path .. " --xterm-colors " .. selection
  require("astrocore").toggle_term_cmd {
    cmd = cmd,
    hidden = false,
    direction = "float",
    close_on_exit = false,
    float_opts = {
      width = vim.o.columns,
      height = vim.o.lines,
      border = "none",
    },
    on_open = function()
      if open_callback and type(open_callback) == "function" then open_callback() end
    end,
    on_close = function(t)
      if flag then t:send "\x03" end
    end,
    on_exit = function(t, _, _, _)
      if close_callback and type(close_callback) == "function" then close_callback() end
      if vim.api.nvim_buf_is_loaded(t.bufnr) then vim.api.nvim_buf_delete(t.bufnr, { force = true }) end
    end,
  }
end

function M.get_all_cmds()
  return {
    "beams",
    "binarypath",
    "blackhole",
    "bouncyballs",
    "bubbles",
    "burn",
    "colorshift",
    "crumble",
    "decrypt",
    "errorcorrect",
    "expand",
    "fireworks",
    "middleout",
    "orbittingvolley",
    "overflow",
    "pour",
    "print",
    "rain",
    "randomsequence",
    "rings",
    "scattered",
    "slice",
    "slide",
    "spotlights",
    "spray",
    "swarm",
    "synthgrid",
    "unstable",
    "vhstape",
    "waves",
    "wipe",
  }
end

function M.toggle_tte()
  if require("astrocore").is_available "telescope.nvim" then
    local actions = require "telescope.actions"
    local action_state = require "telescope.actions.state"
    local pickers = require "telescope.pickers"
    local finders = require "telescope.finders"
    local conf = require("telescope.config").values

    return function()
      pickers
        .new({}, {
          prompt_title = "Select TTE Effect",
          finder = finders.new_table {
            results = M.get_all_cmds(),
            entry_maker = function(entry)
              return {
                value = entry,
                display = entry,
                ordinal = entry,
              }
            end,
          },
          sorter = conf.generic_sorter {},
          attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
              local selection = action_state.get_selected_entry()
              actions.close(prompt_bufnr)
              M.tte(selection.value, nil, nil, true)
            end)
            return true
          end,
        })
        :find()
    end
  end
end

return M
