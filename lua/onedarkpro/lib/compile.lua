local config = require("onedarkpro.config")

local M = {}

---Parse a comma separated styles string into a table
---For example: "bold,italic" -> {bold = true, italic = true}"
---@param style string
---@return table
local function parse_style(style)
    if not style or style == "NONE" then return {} end

    local result = {}
    for token in string.gmatch(style, "([^,]+)") do
        result[token] = true
    end

    return result
end

---Expand the highlight group's values into a string from a table
---@param tbl table of values
---@return string
local function expand_values(tbl)
    local values = {}
    for k, v in pairs(tbl) do
        local q = type(v) == "string" and [["]] or ""
        table.insert(values, string.format([[%s = %s%s%s]], k, q, v, q))
    end

    table.sort(values)
    return string.format([[{ %s }]], table.concat(values, ", "))
end

--- Resolve a highlight group's value from a table
---@param value table|string highlight group values
---@param theme table the theme
---@return table|string|nil
local function resolve_value(value, theme)
    if type(value) == "table" then
        if value[theme.meta.background] then return value[theme.meta.background] end
        if value[theme.meta.name] then return value[theme.meta.name] end
        return
    end

    return value
end

---Form highlights using the Neovim API
---@param name string the highlight group name
---@param values table the highlight group values
---@param theme table the theme
---@return string
local function highlight(name, values, theme)
    if values.link then return string.format([[set_hl(0, "%s", { link = "%s" })]], name, values.link) end

    local val = parse_style(values.style)
    val.bg = resolve_value(values.bg, theme)
    val.fg = resolve_value(values.fg, theme)
    val.sp = values.sp
    val.blend = values.blend

    return string.format([[set_hl(0, "%s", %s)]], name, expand_values(val))
end

---Compile the colorscheme
---@param theme string
---@return function
function M.compile(theme)
    theme = require("onedarkpro.theme").load(theme or config.theme)
    local highlight_groups = require("onedarkpro.highlight").groups(theme)

    --Encase the colorscheme's logic in a function which can be executed with a
    --string.dump function call. In turn this converts it into a binary form
    --(source: https://www.gammon.com.au/scripts/doc.php?lua=string.dump)
    local lines = {
        string.format(
            [[
return string.dump(function()
local set_hl = vim.api.nvim_set_hl
if vim.g.colors_name then vim.cmd("hi clear") end
vim.o.termguicolors = true
vim.g.colors_name = "%s"
vim.o.background = "%s"
    ]],
            theme.meta.name,
            theme.meta.background
        ),
    }

    -- Terminal colors
    if config.config.options.terminal_colors then
        local terminal_colours = require("onedarkpro.highlights.terminal").groups(theme)
        for name, value in pairs(terminal_colours) do
            table.insert(lines, string.format([[vim.g.%s = "%s"]], name, value))
        end
    end

    -- Highlight groups
    for name, values in pairs(highlight_groups) do
        table.insert(lines, highlight(name, values, theme))
    end

    -- Autocmds
    if config.config.options.highlight_inactive_windows or config.config.options.window_unfocused_color then
        local autocmds = require("onedarkpro.highlights.autocmd").groups(theme)
        for _, values in pairs(autocmds) do
            table.insert(lines, values)
        end
    end

    -- End the function
    table.insert(lines, [[end)]])

    --Compile lua with the load function. The use of assert ensures that errors
    --in the compilation process bubble up to be handled later in the plugin
    --(source: https://www.lua.org/pil/8.html)
    local ld = load or loadstring
    return assert(ld(table.concat(lines, "\n"), "="))()
end

return M
