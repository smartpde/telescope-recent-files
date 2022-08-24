local has_telescope, telescope = pcall(require, 'telescope')
local picker = require('telescope._extensions.recent-files.recent-files-picker')

if not has_telescope then
  error('This plugins requires nvim-telescope/telescope.nvim')
end

return telescope.register_extension {
  setup = picker.setup,
  exports = {recent_files = picker.recent_files}
}
