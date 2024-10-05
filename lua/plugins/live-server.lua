-- live serve 实时加载本地开发服务
return
{
  "barrett-ruth/live-server.nvim",
  build = "pnpm add -g live-server",
  cmd = { "LiveServerStart", "LiveServerStop" },
  config = true,
}
