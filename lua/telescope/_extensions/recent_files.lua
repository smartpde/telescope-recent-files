local has_telescope, telescope = pcall(require, 'telescope')
local picker = require('telescope._extensions.recent_files.recent_files_picker')

if not has_telescope then
  error('This plugins requires nvim-telescope/telescope.nvim')
end

return telescope.register_extension {
  setup = picker.setup,
  exports = {
    pick = picker.pick,
    -- Needed to handle the command "Telescope recent_files"
    recent_files = picker.pick,
  },
}
