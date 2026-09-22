return {
  "olimorris/codecompanion.nvim",
  version = "*",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  cmd = {
    "CodeCompanion",
    "CodeCompanionActions",
    "CodeCompanionChat",
    "CodeCompanionCmd",
  },
  opts = {
    adapters = {
      acp = {
        codex = function()
          return require("codecompanion.adapters").extend("codex", {
            defaults = {
              -- Use the existing Codex/ChatGPT subscription login instead of
              -- an OPENAI_API_KEY billed separately through the API platform.
              auth_method = "chat-gpt",
            },
          })
        end,
      },
    },
    interactions = {
      chat = {
        adapter = "codex",
      },
    },
    display = {
      chat = {
        window = {
          layout = "vertical",
          position = "right",
          width = 0.42,
        },
      },
    },
  },
  keys = {
    {
      "<leader>cc",
      "<cmd>CodeCompanionChat Toggle<cr>",
      desc = "Codex: toggle chat",
    },
    {
      "<leader>cn",
      "<cmd>CodeCompanionChat<cr>",
      desc = "Codex: new chat",
    },
  },
}
