-- Start beancount language server for beancount files
local home = vim.env.HOME
local root = vim.fs.dirname(vim.fs.find({'main.beancount', 'main.bean', '.git'}, { upward = true })[1])
vim.lsp.start({
  name = 'beancount',
  cmd = { home .. '/.cargo/bin/beancount-language-server', '--stdio' },
  root_dir = root,
  init_options = {
    journal_file = root .. '/main.beancount',
  },
})
