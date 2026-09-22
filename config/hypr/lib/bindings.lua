local M = {}

local registry = {}
local modifier_rank = {
    SUPER = 1,
    CTRL = 2,
    ALT = 3,
    SHIFT = 4,
}

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function canonical(binding)
    if type(binding) ~= "string" or trim(binding) == "" then
        error("keybind must be a non-empty string", 3)
    end

    local parts = {}
    for part in binding:gmatch("[^+]+") do
        local normalized_part = trim(part)
        if normalized_part ~= "" then
            parts[#parts + 1] = normalized_part:upper()
        end
    end

    if #parts == 0 then
        error("keybind must contain a key", 3)
    end

    local key = table.remove(parts)
    table.sort(parts, function(left, right)
        local left_rank = modifier_rank[left] or 100
        local right_rank = modifier_rank[right] or 100
        if left_rank == right_rank then
            return left < right
        end
        return left_rank < right_rank
    end)
    parts[#parts + 1] = key

    return table.concat(parts, " + ")
end

local function copy_options(options)
    if options == nil then
        return {}
    end
    if type(options) ~= "table" then
        error("keybind options must be a table", 3)
    end

    local result = {}
    for key, value in pairs(options) do
        result[key] = value
    end
    return result
end

function M.bind(binding, dispatcher, options, label)
    if dispatcher == nil then
        error("keybind dispatcher is required", 2)
    end

    local id = canonical(binding)
    local owner = registry[id]
    label = label or binding

    if owner then
        error(string.format("duplicate keybind %q: %s conflicts with %s", id, label, owner), 2)
    end

    registry[id] = label
    options = copy_options(options)

    if next(options) == nil then
        return hl.bind(binding, dispatcher)
    end
    return hl.bind(binding, dispatcher, options)
end

function M.commands(entries)
    if type(entries) ~= "table" then
        error("application keybind config must return a table", 2)
    end

    local names = {}
    for name in pairs(entries) do
        if type(name) ~= "string" then
            error("application keybind names must be strings", 2)
        end
        names[#names + 1] = name
    end
    table.sort(names)

    local handles = {}
    for _, name in ipairs(names) do
        local entry = entries[name]
        local command
        local global
        local binding
        local options
        local description
        local enabled = true

        if type(entry) == "string" then
            command = name
            binding = entry
            description = "[Apps] " .. name
        elseif type(entry) == "table" then
            global = entry.global
            command = entry.command or name
            if global ~= nil and entry.command ~= nil then
                error(string.format("entry %q has both global and command", name), 2)
            end
            binding = entry.bind
            options = entry.options
            description = entry.description
            enabled = entry.enabled ~= false
        else
            error(string.format("entry %q must be a shortcut string or a table", name), 2)
        end

        if enabled then
            if global ~= nil and (type(global) ~= "string" or trim(global) == "") then
                error(string.format("entry %q has no global shortcut", name), 2)
            end
            if type(command) ~= "string" or trim(command) == "" then
                error(string.format("entry %q has no command", name), 2)
            end
            if type(binding) ~= "string" or trim(binding) == "" then
                error(string.format("entry %q has no bind", name), 2)
            end

            options = copy_options(options)
            if description and options.description == nil then
                options.description = description
            elseif options.description == nil then
                options.description = "[Apps] " .. name
            end

            handles[name] = M.bind(
                binding,
                global and hl.dsp.global(global) or hl.dsp.exec_cmd(command),
                options,
                string.format("command %q", name)
            )
        end
    end

    return handles
end

return M
