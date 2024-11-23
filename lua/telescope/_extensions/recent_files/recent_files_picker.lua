local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local make_entry = require "telescope.make_entry"
local conf = require"telescope.config".values
local utils = require "telescope._extensions.recent_files.utils"

local M = {}

--Effective extension options, available after the setup call.
local options

local defaults = {
  stat_files = true,
  ignore_patterns = {"/tmp/"},
  only_cwd = false,
  transform_file_path = function (path)
    return path
  end,
  show_current_file = false,
}

--Map from file path to its recency number. The higher the number,
--the more recently the file was used.
local recent_bufs = {}
--Global counter of recent files. Increased when a buffer was entered.
local recent_cnt = 0

M.setup = function(opts)
  options = utils.assign({}, defaults, opts)
end

--We keep track of recent buffer by listening to BufEnter events,
--and giving each file its monotonically increasing recency number.
_G.telescope_recent_files_buf_register =
  function()
    local bufnr = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(bufnr)
    if options.transform_file_path then
      file = options.transform_file_path(file)
    end
    if file ~= "" then
      recent_bufs[file] = recent_cnt
      recent_cnt = recent_cnt + 1
    end
  end
vim.cmd [[
augroup telescope_recent_files
  au!
  au! BufEnter * lua telescope_recent_files_buf_register()
augroup END
]]

local function stat(filename)
  local s = vim.loop.fs_stat(filename)
  if not s then
    return nil
  end
  return s.type
end

local function is_ignored(file_path, opts)
  if opts.ignore_patterns == nil then
    return false
  end
  for _,p in ipairs(opts.ignore_patterns) do
   if string.find(file_path, p) then return true end
  end
  return false
end

--- @type fun(path: string): string
local function normalize(path)
  path = path:gsub('\\', '/')
  if path:sub(-1) == '/' then
    path = path:sub(1, -2)
  end
  return path
end

local function is_in_cwd(file_path)
  local cwd = vim.loop.cwd()
  local parent_path = normalize(cwd)
  local child_path = normalize(file_path)

  local is_parent_prefix  = child_path:sub(1, #parent_path) == parent_path
  local is_direct_child_or_same_path = child_path:sub(#parent_path + 1, #parent_path + 1) == '/' or child_path:sub(#parent_path + 1, #parent_path + 1) == ''

  return is_parent_prefix and is_direct_child_or_same_path
end

local function add_recent_file(result_list, result_map, file_path, opts)
  if opts.transform_file_path then
    file_path = opts.transform_file_path(file_path)
  end
  local should_add = file_path ~= nil and file_path ~= ""
  if result_map[file_path] then
    should_add = false
  elseif is_ignored(file_path, opts) then
    should_add = false
  end
  if should_add and opts.stat_files and not stat(file_path) then
    should_add = false
  end
  if should_add and opts.only_cwd and not is_in_cwd(file_path) then
    should_add = false
  end

  if should_add then
    table.insert(result_list, file_path)
    result_map[file_path] = true
  end
end

local function prepare_recent_files(opts)
  local current_buffer = vim.api.nvim_get_current_buf()
  local current_file = vim.api.nvim_buf_get_name(current_buffer)
  local result_list = {}
  local result_map = {}
  local old_files_map = {}

  for i, file in ipairs(vim.v.oldfiles) do
    if opts.show_current_file or file ~= current_file then
      add_recent_file(result_list, result_map, file, opts)
      old_files_map[file] = i
    end
  end
  for buffer_file in pairs(recent_bufs) do
    if opts.show_current_file or buffer_file ~= current_file then
      add_recent_file(result_list, result_map, buffer_file, opts)
    end
  end
  table.sort(result_list, function(a, b)
    local a_recency = recent_bufs[a]
    local b_recency = recent_bufs[b]
    if a_recency == nil and b_recency == nil then
      local a_old = old_files_map[a]
      local b_old = old_files_map[b]
      if a_old == nil and b_old == nil then
        return a < b
      end
      if a_old == nil then
        return false
      end
      if b_old == nil then
        return true
      end
      return a_old < b_old
    end
    if a_recency == nil then
      return false
    end
    if b_recency == nil then
      return true
    end
    return b_recency < a_recency
  end)
  return result_list
end

M.pick = function(opts)
  if not options then
    error("Plugin is not set up, call require('telescope').load_extension('recent_files')")
  end
  opts = utils.assign({}, options, opts)
  pickers.new(opts, {
    prompt_title = "Recent files",
    finder = finders.new_table {
      results = prepare_recent_files(opts),
      entry_maker = make_entry.gen_from_file(opts)
    },
    sorter = conf.file_sorter(),
    previewer = conf.file_previewer(opts)
  }):find()
end

return M
